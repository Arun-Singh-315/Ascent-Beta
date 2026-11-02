import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../core/services/quick_capture_service.dart';
import '../../core/services/plan_collection_service.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_star_button.dart';
import '../../shared/widgets/schedule_picker.dart';

const _draftKey = 'ascent_quick_capture_draft_v1';

Future<void> showQuickCapture(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (_) => const QuickCaptureSheet(),
    );

class QuickCaptureSheet extends ConsumerStatefulWidget {
  const QuickCaptureSheet({super.key});
  @override
  ConsumerState<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<QuickCaptureSheet> {
  final _input = TextEditingController();
  late SharedPreferences _prefs;
  late String _requestId;
  List<CaptureDraft> _drafts = [];
  CaptureReceipt? _receipt;
  Timer? _debounce;
  bool _review = false,
      _saving = false,
      _loading = true,
      _alertsPending = false;
  String? _error, _editing;
  String _reviewSource = '';
  final _cardKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _prefs = ref.read(sharedPreferencesProvider);
    _requestId = planningId();
    unawaited(_restore());
    _input.addListener(_changed);
  }

  Future<void> _restore() async {
    try {
      final stored = _prefs.getString(_draftKey);
      if (stored != null) {
        final json = jsonDecode(stored) as Map<String, dynamic>;
        _requestId = json['requestId'] as String;
        _input.text = json['text'] as String? ?? '';
        _reviewSource = json['source'] as String? ?? _input.text;
        _drafts = [
          for (final d in json['drafts'] as List? ?? [])
            CaptureDraft.fromJson(Map<String, dynamic>.from(d as Map)),
        ];
        _review = json['review'] == true && _drafts.isNotEmpty;
        final db = ref.read(databaseProvider);
        final rows = await (db.select(
          db.aiCommandTable,
        )..where((r) => r.requestId.equals('quick.capture:$_requestId'))).get();
        if (rows.isNotEmpty) {
          _receipt = CaptureReceipt.fromJson(
            jsonDecode(rows.first.resultJson) as Map<String, dynamic>,
          );
          await _prefs.remove(_draftKey);
        }
      }
    } catch (_) {
      _error =
          'Your previous draft could not be loaded. You can start a new capture.';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _changed() {
    if (_saving || _receipt != null) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_persist()),
    );
  }

  Future<void> _persist() async {
    if (_receipt != null || (_input.text.trim().isEmpty && _drafts.isEmpty)) {
      await _prefs.remove(_draftKey);
      return;
    }
    await _prefs.setString(
      _draftKey,
      jsonEncode({
        'requestId': _requestId,
        'text': _input.text,
        'review': _review,
        'source': _reviewSource,
        'drafts': [for (final d in _drafts) d.toJson()],
      }),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (!_loading) unawaited(_persist());
    _input.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _error = null;
    });
    _changed();
  }

  void _prepare() {
    try {
      final drafts = _drafts.isNotEmpty && _reviewSource == _input.text
          ? _drafts
          : parseQuickCapture(_input.text, DateTime.now());
      if (drafts.isEmpty) {
        setState(() => _error = 'Write at least one thing to capture.');
        return;
      }
      FocusScope.of(context).unfocus();
      _update(() {
        _drafts = drafts;
        _reviewSource = _input.text;
        _review = true;
        _editing = drafts.first.key;
      });
    } catch (e) {
      setState(
        () => _error = e is ArgumentError
            ? '${e.message}'
            : 'Could not read this capture. Try one item per line.',
      );
    }
  }

  Future<void> _save() async {
    final invalid = _drafts
        .where((d) => d.validate(DateTime.now()) != null)
        .firstOrNull;
    if (invalid != null) {
      setState(() {
        _error = invalid.validate(DateTime.now());
        _editing = invalid.key;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _cardKeys[invalid.key]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
      return;
    }
    if (_saving) return;
    _debounce?.cancel();
    setState(() {
      _saving = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    try {
      await _persist();
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      final db = ref.read(databaseProvider);
      final receipt = await QuickCaptureService(
        db,
      ).save(_drafts, requestId: _requestId);
      if (!mounted) return;
      setState(() {
        _receipt = receipt;
        _saving = false;
      });
      await _prefs.remove(_draftKey);
      if (receipt.reminderIds.isNotEmpty) {
        try {
          final synced = await ReminderAlertSync.device(
            db,
          ).sync(ids: receipt.reminderIds, onlyPending: true);
          if (mounted) setState(() => _alertsPending = !synced.complete);
        } catch (_) {
          if (mounted) setState(() => _alertsPending = true);
        }
      }
    } catch (e) {
      if (mounted && _receipt == null) {
        setState(
          () => _error = e is ArgumentError
              ? '${e.message}'
              : 'Could not save this capture. Your draft is kept; retry safely.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDay(CaptureDraft d, {bool end = false}) async {
    final now = DateTime.now();
    final logged = [
      CaptureKind.expense,
      CaptureKind.income,
      CaptureKind.water,
    ].contains(d.kind);
    final first = end
        ? (d.at ?? now)
        : logged
        ? DateTime(2000)
        : DateTime(now.year, now.month, now.day);
    final last = end
        ? DateTime(first.year, first.month, first.day + 90)
        : logged
        ? now
        : DateTime(now.year + 3, 12, 31);
    var initial = end ? (d.end ?? first) : d.day ?? now;
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final value = await showDatePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDate: initial,
      helpText: end ? 'Routine end date' : 'Date',
    );
    if (value != null && mounted) {
      _update(() {
        if (end) {
          d.end = value;
        } else {
          d.day = value;
        }
      });
    }
  }

  Future<void> _pickTime(CaptureDraft d) async {
    final value = await pickFutureSchedule(
      context,
      purpose: d.kind == CaptureKind.routine ? 'Routine starts' : 'Reminder',
      initial: d.at,
    );
    if (value != null && mounted) {
      _update(() {
        d.at = value;
        d.day = DateTime(value.year, value.month, value.day);
        d.needsClock = false;
      });
    }
  }

  IconData _icon(CaptureKind kind) => switch (kind) {
    CaptureKind.todo => Icons.check_circle_outline_rounded,
    CaptureKind.reminder => Icons.notifications_none_rounded,
    CaptureKind.timer => Icons.timer_outlined,
    CaptureKind.thought => Icons.lightbulb_outline_rounded,
    CaptureKind.routine => Icons.repeat_rounded,
    CaptureKind.expense ||
    CaptureKind.income => Icons.account_balance_wallet_outlined,
    CaptureKind.water => Icons.water_drop_outlined,
  };

  Widget _fieldLabel(String label) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: g.inkMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _glassFieldContainer({
    required Widget child,
    EdgeInsetsGeometry? padding,
  }) {
    final g = context.glass;
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: g.fill.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g.line.withValues(alpha: 0.6), width: 0.8),
      ),
      child: child,
    );
  }

  Widget _editor(CaptureDraft d) {
    final g = context.glass;
    final expanded = _drafts.length == 1 || _editing == d.key;
    final timed = [
      CaptureKind.todo,
      CaptureKind.timer,
      CaptureKind.reminder,
      CaptureKind.routine,
    ].contains(d.kind);
    final money = [CaptureKind.expense, CaptureKind.income].contains(d.kind);
    final categories =
        ref.watch(thoughtCategoriesStreamProvider).value ?? {'general': 'Wall'};

    return Padding(
      key: _cardKeys.putIfAbsent(d.key, GlobalKey.new),
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: g.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: expanded
                ? g.primaryButtonBg.withValues(alpha: 0.45)
                : g.line.withValues(alpha: 0.6),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: g.fill.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon(d.kind), size: 18, color: g.primaryButtonBg),
              ),
              title: Text(
                d.title.isEmpty ? captureLabel(d.kind) : d.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: g.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${captureLabel(d.kind)} → ${captureDestination(d.kind)}${d.at != null ? ' · ${DateFormat.MMMd().add_jm().format(d.at!)}' : ''}',
                style: TextStyle(color: g.inkMuted, fontSize: 12.5),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                _update(() => _editing = expanded ? null : d.key);
              },
              trailing: IconButton(
                tooltip: 'Remove item',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _update(() => _drafts.remove(d));
                },
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _fieldLabel('Save as'),
                    _glassFieldContainer(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<CaptureKind>(
                          value: d.kind,
                          isExpanded: true,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: g.inkMuted,
                          ),
                          dropdownColor: g.surface,
                          items: [
                            for (final kind in CaptureKind.values)
                              DropdownMenuItem(
                                value: kind,
                                child: Row(
                                  children: [
                                    Icon(
                                      _icon(kind),
                                      size: 16,
                                      color: g.primaryButtonBg,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      captureLabel(kind),
                                      style: TextStyle(
                                        color: g.ink,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (kind) => _update(() {
                            if (kind == null) return;
                            d.kind = kind;
                            d.needsClock = false;
                            if (![
                              CaptureKind.todo,
                              CaptureKind.timer,
                              CaptureKind.reminder,
                              CaptureKind.routine,
                            ].contains(kind)) {
                              d.at = null;
                            }
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (d.kind != CaptureKind.water) ...[
                      _fieldLabel('Title'),
                      _glassFieldContainer(
                        child: TextFormField(
                          key: ValueKey('${d.key}.title'),
                          initialValue: d.title,
                          maxLines: 2,
                          minLines: 1,
                          maxLength: money ? 200 : 300,
                          style: TextStyle(color: g.ink, fontSize: 14.5),
                          decoration: InputDecoration(
                            hintText: 'Enter title…',
                            hintStyle: TextStyle(
                              color: g.inkMuted.withValues(alpha: 0.5),
                            ),
                            counterText: '',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onChanged: (v) => _update(() => d.title = v),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (![
                      CaptureKind.reminder,
                      CaptureKind.water,
                    ].contains(d.kind)) ...[
                      _fieldLabel('Notes · optional'),
                      _glassFieldContainer(
                        child: TextFormField(
                          key: ValueKey('${d.key}.notes'),
                          initialValue: d.notes,
                          maxLines: 3,
                          minLines: 1,
                          style: TextStyle(color: g.ink, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Add extra details…',
                            hintStyle: TextStyle(
                              color: g.inkMuted.withValues(alpha: 0.5),
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onChanged: (v) => {d.notes = v, _changed()},
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (d.kind == CaptureKind.timer) ...[
                      _fieldLabel('Focus target'),
                      _glassFieldContainer(
                        child: TextFormField(
                          key: ValueKey('${d.key}.minutes'),
                          initialValue: '${d.minutes}',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Minutes (e.g. 25)',
                            hintStyle: TextStyle(
                              color: g.inkMuted.withValues(alpha: 0.5),
                            ),
                            suffixText: 'min',
                            suffixStyle: TextStyle(
                              color: g.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onChanged: (v) => {
                            d.minutes = int.tryParse(v) ?? 0,
                            _changed(),
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (money || d.kind == CaptureKind.water) ...[
                      _fieldLabel(
                        d.kind == CaptureKind.water
                            ? 'Water volume (ml)'
                            : 'Amount',
                      ),
                      _glassFieldContainer(
                        child: TextFormField(
                          key: ValueKey('${d.key}.amount'),
                          initialValue: d.amount?.toString() ?? '',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: d.kind == CaptureKind.water
                                ? 'e.g. 250'
                                : '0.00',
                            hintStyle: TextStyle(
                              color: g.inkMuted.withValues(alpha: 0.5),
                            ),
                            prefixText: money ? '₹ ' : null,
                            prefixStyle: TextStyle(
                              color: g.ink,
                              fontWeight: FontWeight.w600,
                            ),
                            suffixText: d.kind == CaptureKind.water
                                ? 'ml'
                                : null,
                            suffixStyle: TextStyle(
                              color: g.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                          ),
                          onChanged: (v) => {
                            d.amount = double.tryParse(v.replaceAll(',', '')),
                            _changed(),
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (money) ...[
                      _fieldLabel('Category'),
                      _glassFieldContainer(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: d.category,
                            isExpanded: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: g.inkMuted,
                            ),
                            dropdownColor: g.surface,
                            items: [
                              for (final c in [
                                'Other',
                                'Food & Groceries',
                                'Transport',
                                'Shopping',
                                'Education',
                                'Bills & Subscriptions',
                                'Health',
                                'Entertainment',
                                'Savings',
                              ])
                                DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: TextStyle(color: g.ink, fontSize: 14),
                                  ),
                                ),
                            ],
                            onChanged: (v) => _update(() => d.category = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (d.kind == CaptureKind.thought) ...[
                      _fieldLabel('Space'),
                      _glassFieldContainer(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: categories.containsKey(d.space)
                                ? d.space
                                : 'general',
                            isExpanded: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: g.inkMuted,
                            ),
                            dropdownColor: g.surface,
                            items: [
                              for (final c in categories.entries)
                                DropdownMenuItem(
                                  value: c.key,
                                  child: Text(
                                    c.value,
                                    style: TextStyle(color: g.ink, fontSize: 14),
                                  ),
                                ),
                            ],
                            onChanged: (v) => _update(() => d.space = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (d.kind != CaptureKind.thought &&
                        d.kind != CaptureKind.reminder &&
                        d.kind != CaptureKind.routine) ...[
                      AscentButton.outlined(
                        label: DateFormat.yMMMd().format(
                          d.day ?? DateTime.now(),
                        ),
                        icon: Icons.calendar_today_outlined,
                        onPressed: () => _pickDay(d),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (timed) ...[
                      Row(
                        children: [
                          Expanded(
                            child: AscentButton.outlined(
                              label: d.at == null
                                  ? (d.kind == CaptureKind.routine
                                        ? 'Start date & time'
                                        : d.kind == CaptureKind.reminder
                                        ? 'Choose date & time'
                                        : 'Add reminder · optional')
                                  : DateFormat.MMMd().add_jm().format(d.at!),
                              icon: Icons.notifications_none_rounded,
                              onPressed: () => _pickTime(d),
                            ),
                          ),
                          if (d.at != null &&
                              [
                                CaptureKind.todo,
                                CaptureKind.timer,
                              ].contains(d.kind))
                            IconButton(
                              tooltip: 'Remove reminder',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => _update(() => d.at = null),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (d.kind == CaptureKind.routine) ...[
                      _fieldLabel('Repeat'),
                      _glassFieldContainer(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: ['daily', 'weekdays'].contains(d.recurrence)
                                ? d.recurrence
                                : null,
                            isExpanded: true,
                            hint: Text(
                              'Select recurrence',
                              style: TextStyle(color: g.inkMuted, fontSize: 14),
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: g.inkMuted,
                            ),
                            dropdownColor: g.surface,
                            items: const [
                              DropdownMenuItem(
                                value: 'daily',
                                child: Text('Daily'),
                              ),
                              DropdownMenuItem(
                                value: 'weekdays',
                                child: Text('Weekdays'),
                              ),
                            ],
                            onChanged: (v) => _update(() => d.recurrence = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AscentButton.outlined(
                        label: d.end == null
                            ? 'Choose an end date'
                            : 'Ends ${DateFormat.yMMMd().format(d.end!)}',
                        icon: Icons.event_outlined,
                        onPressed: () => _pickDay(d, end: true),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if ([CaptureKind.todo, CaptureKind.timer].contains(d.kind))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            AscentStarButton(
                              selected: d.starred,
                              onChanged: (v) => _update(() => d.starred = v),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Important',
                              style: TextStyle(
                                color: g.ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _success() {
    final receipt = _receipt!;
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: g.primaryButtonBg.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 38,
            color: g.primaryButtonBg,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'A little less on your mind.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${receipt.items.length} ${receipt.items.length == 1 ? 'thing is' : 'things are'} right where ${receipt.items.length == 1 ? 'it belongs' : 'they belong'}.',
          textAlign: TextAlign.center,
          style: TextStyle(color: g.inkMuted, fontSize: 14),
        ),
        const SizedBox(height: 24),
        Material(
          color: g.fill.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: g.line.withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: Column(
            children: [
              for (final item in receipt.items)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  title: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: g.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    item.destination,
                    style: TextStyle(color: g.inkMuted, fontSize: 12.5),
                  ),
                  trailing: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: g.fill.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: g.primaryButtonBg,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push(item.route);
                  },
                ),
            ],
          ),
        ),
      ),
        if (_alertsPending) ...[
          const SizedBox(height: 16),
          Text(
            'Everything is saved. Some alerts still need notification access or a retry.',
            style: TextStyle(color: g.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          AscentButton.outlined(
            label: 'Enable notifications & retry',
            icon: Icons.notifications_none_rounded,
            onPressed: () async {
              await NotificationService.instance.requestPermissions();
              if (!mounted) return;
              final result = await ReminderAlertSync.device(
                ref.read(databaseProvider),
              ).sync(ids: receipt.reminderIds, onlyPending: true);
              if (mounted) setState(() => _alertsPending = !result.complete);
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final height = math.max(
      240.0,
      MediaQuery.sizeOf(context).height * .9 - keyboard,
    );

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(
                color: g.line.withValues(alpha: 0.6),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: g.ink.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: g.fill.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _receipt != null
                              ? Icons.check_circle_outline_rounded
                              : _review
                              ? Icons.tune_rounded
                              : Icons.bolt_rounded,
                          size: 19,
                          color: g.primaryButtonBg,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _receipt != null
                              ? 'All in place'
                              : _review
                              ? 'Check the details'
                              : 'Quick capture',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close capture',
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: g.fill.withValues(alpha: 0.4),
                          foregroundColor: g.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _saving && _receipt == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(),
                              const SizedBox(height: 16),
                              Text(
                                'Putting your things in place…',
                                style: TextStyle(
                                  color: g.inkMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          child: _receipt != null
                              ? _success()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (!_review) ...[
                                      Text(
                                        'One place for everything on your mind.',
                                        style: TextStyle(
                                          color: g.ink,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Tasks, reminders, thoughts, routines, money and water. One item per line; review every detail before saving.',
                                        style: TextStyle(
                                          color: g.inkMuted,
                                          fontSize: 13.5,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: [
                                            for (final (label, icon) in [
                                              ('Todo', Icons.check_circle_outline_rounded),
                                              ('Reminder', Icons.notifications_none_rounded),
                                              ('Thought', Icons.lightbulb_outline_rounded),
                                              ('Expense', Icons.account_balance_wallet_outlined),
                                            ]) ...[
                                              Material(
                                                color: Colors.transparent,
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(16),
                                                  onTap: () {
                                                    HapticFeedback.lightImpact();
                                                    _input.text =
                                                        '${_input.text}${_input.text.isEmpty ? '' : '\n'}$label: ';
                                                    _input.selection =
                                                        TextSelection.collapsed(
                                                          offset: _input.text.length,
                                                        );
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 7,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: g.fill.withValues(alpha: 0.65),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: g.line.withValues(alpha: 0.6),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          icon,
                                                          size: 14,
                                                          color: g.primaryButtonBg,
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '+ $label',
                                                          style: TextStyle(
                                                            color: g.ink,
                                                            fontSize: 12.5,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: g.fill.withValues(alpha: 0.45),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: g.line.withValues(alpha: 0.7),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            TextField(
                                              key: const ValueKey(
                                                'quick_capture_input',
                                              ),
                                              controller: _input,
                                              minLines: 4,
                                              maxLines: 8,
                                              maxLength: 6000,
                                              style: TextStyle(
                                                color: g.ink,
                                                fontSize: 15,
                                                height: 1.45,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Todo: send the proposal tomorrow\n'
                                                    'Reminder: call Sam tomorrow at 6pm\n'
                                                    'Thought: a quiet morning idea',
                                                hintStyle: TextStyle(
                                                  color: g.inkMuted.withValues(alpha: 0.55),
                                                  fontSize: 14,
                                                  height: 1.4,
                                                ),
                                                counterText: '',
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4),
                                        child: Text(
                                          'Your unfinished capture stays here if you close this popup.',
                                          style: TextStyle(
                                            color: g.inkMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Text(
                                        '${_drafts.length} ${_drafts.length == 1 ? 'item' : 'items'} · tap one to edit its details',
                                        style: TextStyle(
                                          color: g.inkMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      for (final d in _drafts) _editor(d),
                                      AscentButton.outlined(
                                        label: 'Add another item',
                                        icon: Icons.add_rounded,
                                        onPressed: _drafts.length >= 30
                                            ? null
                                            : () => _update(() {
                                                final d = CaptureDraft(
                                                  key: planningId(),
                                                  title: '',
                                                );
                                                _drafts.add(d);
                                                _editing = d.key;
                                              }),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: g.errorInk,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: _receipt != null
                      ? AscentButton.outlined(
                          label: 'Done',
                          onPressed: () => Navigator.pop(context),
                        )
                      : _review
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AscentButton.primary(
                              key: const ValueKey('quick_capture_save'),
                              label:
                                  'Save ${_drafts.length} ${_drafts.length == 1 ? 'item' : 'items'}',
                              loading: _saving,
                              onPressed: _loading || _saving || _drafts.isEmpty
                                  ? null
                                  : _save,
                            ),
                            if (keyboard == 0) const SizedBox(height: 8),
                            if (keyboard == 0)
                              AscentButton.ghost(
                                label: 'Back to writing',
                                onPressed: _saving
                                    ? null
                                    : () => _update(() => _review = false),
                              ),
                          ],
                        )
                      : AscentButton.primary(
                          key: const ValueKey('quick_capture_review'),
                          label: 'Review capture',
                          icon: Icons.arrow_forward_rounded,
                          onPressed: _loading ? null : _prepare,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
