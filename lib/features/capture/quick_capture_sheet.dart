import '../../shared/widgets/ascent_sheet.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../core/services/quick_capture_service.dart';
import '../../core/services/plan_collection_service.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_star_button.dart';
import '../../shared/widgets/schedule_picker.dart';

const _draftKey = 'ascent_quick_capture_draft_v1';

Future<void> showQuickCapture(BuildContext context) async {
  await showAscentSheet<void>(
    context: context,
    useRootNavigator: true,
    framed: false,
    builder: (_) => const QuickCaptureSheet(),
  );
}

/// Quick capture is a three-beat flow:
///
/// 1. **Write**  – one calm composer. As you type, the sheet shows what it
///    understood (type, destination, when) so nothing is a surprise.
/// 2. **Review** – one compact card per item. Required details come first and
///    are tap-first (chips instead of typing); optional extras stay folded.
/// 3. **Placed** – a receipt showing where each thing went.
class QuickCaptureSheet extends ConsumerStatefulWidget {
  const QuickCaptureSheet({super.key});
  @override
  ConsumerState<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends ConsumerState<QuickCaptureSheet> {
  static const _timedKinds = [
    CaptureKind.todo,
    CaptureKind.timer,
    CaptureKind.reminder,
    CaptureKind.routine,
  ];
  static const _moneyCategories = [
    'Other',
    'Food & Groceries',
    'Transport',
    'Shopping',
    'Education',
    'Bills & Subscriptions',
    'Health',
    'Entertainment',
    'Savings',
  ];

  final _input = TextEditingController();
  final _scroll = ScrollController();
  late SharedPreferences _prefs;
  late String _requestId;
  List<CaptureDraft> _drafts = [];
  List<CaptureDraft> _preview = const [];
  String _previewSource = '';
  CaptureReceipt? _receipt;
  Timer? _debounce;
  bool _review = false,
      _saving = false,
      _loading = true,
      _alertsPending = false,
      _attempted = false;
  String? _error, _editing;
  String _reviewSource = '';
  final _cardKeys = <String, GlobalKey>{};
  final _notesOpen = <String>{};

  /// Bumped when a chip rewrites a typed value so its text field refreshes
  /// without being rebuilt (and losing focus) on every keystroke.
  int _epoch = 0;

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
    if (mounted) {
      _refreshPreview(notify: false);
      setState(() => _loading = false);
    }
  }

  void _changed() {
    _refreshPreview();
    if (_saving || _receipt != null) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_persist()),
    );
  }

  /// Reads the written text the same way "Review" will, so the person sees
  /// what was understood while they are still typing.
  void _refreshPreview({bool notify = true}) {
    final text = _input.text;
    if (text == _previewSource) return;
    _previewSource = text;
    List<CaptureDraft> next;
    try {
      next = text.trim().isEmpty
          ? const []
          : parseQuickCapture(text, DateTime.now());
    } catch (_) {
      next = const [];
    }
    if (notify && mounted) {
      setState(() => _preview = next);
    } else {
      _preview = next;
    }
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
    _scroll.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _error = null;
    });
    _changed();
  }

  void _toTop() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  });

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
        _attempted = false;
        // A single item opens by itself; with several, start with the first
        // one that still needs something so the next step is obvious.
        _editing =
            drafts
                .where((d) => d.validate(DateTime.now()) != null)
                .firstOrNull
                ?.key ??
            drafts.first.key;
      });
      _toTop();
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
        _attempted = true;
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
      HapticFeedback.mediumImpact();
      setState(() {
        _receipt = receipt;
        _saving = false;
      });
      _toTop();
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

  // ── Date and time helpers ─────────────────────────────────────────────────

  static DateTime _dayOf(DateTime v) => DateTime(v.year, v.month, v.day);
  static bool _sameDay(DateTime? a, DateTime b) =>
      a != null && a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isLogged(CaptureKind k) =>
      k == CaptureKind.expense ||
      k == CaptureKind.income ||
      k == CaptureKind.water;

  void _setDay(CaptureDraft d, DateTime day) {
    d.day = _dayOf(day);
    final at = d.at;
    if (at != null) {
      d.at = DateTime(day.year, day.month, day.day, at.hour, at.minute);
    }
  }

  void _setAt(CaptureDraft d, DateTime value) {
    d.at = value;
    d.day = _dayOf(value);
    d.needsClock = false;
  }

  /// One-tap reminder times that are always in the future.
  List<({String label, DateTime at})> _quickTimes() {
    final n = DateTime.now();
    final tonight = DateTime(n.year, n.month, n.day, 20);
    final next = DateTime(n.year, n.month, n.day, n.hour + 1, n.minute);
    final tomorrow = DateTime(n.year, n.month, n.day + 1, 9);
    return [
      if (tonight.isAfter(n.add(const Duration(minutes: 30))))
        (label: 'Tonight 8 pm', at: tonight),
      (label: 'In 1 hour', at: next),
      (label: 'Tomorrow 9 am', at: tomorrow),
    ];
  }

  Future<void> _pickDay(CaptureDraft d, {bool end = false}) async {
    final now = DateTime.now();
    final logged = _isLogged(d.kind);
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
          _setDay(d, value);
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
    if (value != null && mounted) _update(() => _setAt(d, value));
  }

  // ── Presentation helpers ──────────────────────────────────────────────────

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

  String _amountText(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 2);

  /// One calm line that tells the person what this item will become.
  String _facts(CaptureDraft d) {
    final parts = <String>[
      captureLabel(d.kind),
      captureDestination(d.kind),
      if (d.at != null) DateFormat.MMMd().add_jm().format(d.at!),
      if (d.at == null && d.day != null && d.kind != CaptureKind.routine)
        DateFormat.MMMd().format(d.day!),
      if (d.amount != null &&
          (d.kind == CaptureKind.expense || d.kind == CaptureKind.income))
        '₹${_amountText(d.amount!)}',
      if (d.amount != null && d.kind == CaptureKind.water)
        '${d.amount!.toInt()} ml',
      if (d.kind == CaptureKind.timer) '${d.minutes} min',
    ];
    return parts.join(' · ');
  }

  String _titleOf(CaptureDraft d) {
    if (d.kind == CaptureKind.water) {
      return d.amount == null ? 'Water' : '${d.amount!.toInt()} ml water';
    }
    return d.title.trim().isEmpty
        ? 'Untitled ${captureLabel(d.kind).toLowerCase()}'
        : d.title;
  }

  // ── Small building blocks (one look for every control in this sheet) ─────

  InputDecoration _dec(String hint, {String? prefix, String? suffix}) {
    final g = context.glass;
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
          borderSide: BorderSide(color: color, width: width),
        );
    final rest = g.controlOutline.withValues(alpha: 0.45);
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: g.recessed,
      hintText: hint,
      hintStyle: TextStyle(color: g.inkMuted.withValues(alpha: 0.8)),
      prefixText: prefix,
      prefixStyle: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
      suffixText: suffix,
      suffixStyle: TextStyle(color: g.inkMuted, fontWeight: FontWeight.w600),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: border(rest),
      enabledBorder: border(rest),
      focusedBorder: border(g.focusRing, 1.5),
    );
  }

  Widget _field(String label, Widget child) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              label,
              style: TextStyle(
                color: g.inkMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  /// Small selectable pill: type picker, dates, times, categories.
  Widget _pill({
    required String label,
    required VoidCallback? onTap,
    IconData? icon,
    bool selected = false,
    Key? key,
  }) {
    final g = context.glass;
    final fg = selected ? g.tonalFg : g.inkSecondary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: selected
            ? g.tonalFg.withValues(alpha: 0.45)
            : g.controlOutline.withValues(alpha: 0.4),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        key: key,
        color: selected ? g.tonalBg : Colors.transparent,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap();
                },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: fg),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chips(List<Widget> children) => Wrap(
    spacing: 6,
    runSpacing: 6,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );

  Widget _scrollRow(List<Widget> children) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          children[i],
        ],
      ],
    ),
  );

  Widget _badge(CaptureKind kind, {double size = 34}) {
    final g = context.glass;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: g.tonalBg,
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(_icon(kind), size: size * .53, color: g.tonalFg),
    );
  }

  Widget _countChips(Iterable<CaptureDraft> drafts) {
    final counts = <CaptureKind, int>{};
    for (final d in drafts) {
      counts[d.kind] = (counts[d.kind] ?? 0) + 1;
    }
    return _chips([
      for (final e in counts.entries)
        _pill(
          icon: _icon(e.key),
          label: '${e.value} ${captureLabel(e.key)}',
          selected: true,
          onTap: null,
        ),
    ]);
  }

  Widget _textField(
    CaptureDraft d,
    String id, {
    required String initial,
    required String hint,
    required ValueChanged<String> onChanged,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    String? prefix,
    String? suffix,
    bool bold = false,
    Object? epoch,
  }) {
    final g = context.glass;
    return TextFormField(
      key: ValueKey(epoch == null ? '${d.key}.$id' : '${d.key}.$id.$epoch'),
      initialValue: initial,
      minLines: 1,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      textCapitalization: keyboardType == null
          ? TextCapitalization.sentences
          : TextCapitalization.none,
      style: TextStyle(
        color: g.ink,
        fontSize: 14.5,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
      ),
      decoration: _dec(hint, prefix: prefix, suffix: suffix),
      onChanged: onChanged,
    );
  }

  // ── Review: one editor per item, required details first ───────────────────

  Widget _dayChips(CaptureDraft d) {
    final now = DateTime.now();
    final today = _dayOf(now);
    final logged = _isLogged(d.kind);
    final other = logged
        ? today.subtract(const Duration(days: 1))
        : today.add(const Duration(days: 1));
    final current = d.day == null ? today : _dayOf(d.day!);
    final custom = !_sameDay(current, today) && !_sameDay(current, other);
    return _chips([
      _pill(
        label: 'Today',
        selected: _sameDay(current, today),
        onTap: () => _update(() => _setDay(d, today)),
      ),
      _pill(
        label: logged ? 'Yesterday' : 'Tomorrow',
        selected: _sameDay(current, other),
        onTap: () => _update(() => _setDay(d, other)),
      ),
      _pill(
        icon: Icons.calendar_today_outlined,
        label: custom ? DateFormat.MMMd().format(current) : 'Pick date',
        selected: custom,
        onTap: () => _pickDay(d),
      ),
    ]);
  }

  Widget _timeChips(CaptureDraft d) {
    final routine = d.kind == CaptureKind.routine;
    final quick = routine
        ? const <({String label, DateTime at})>[]
        : _quickTimes();
    final matched =
        d.at != null && quick.any((q) => q.at.isAtSameMomentAs(d.at!));
    final custom = d.at != null && !matched;
    final optional = d.kind == CaptureKind.todo || d.kind == CaptureKind.timer;
    return _chips([
      for (final q in quick)
        _pill(
          label: q.label,
          selected: d.at != null && d.at!.isAtSameMomentAs(q.at),
          onTap: () => _update(() => _setAt(d, q.at)),
        ),
      _pill(
        icon: Icons.schedule_rounded,
        label: custom
            ? DateFormat.MMMd().add_jm().format(d.at!)
            : routine
            ? 'Start date & time'
            : 'Pick date & time',
        selected: custom,
        onTap: () => _pickTime(d),
      ),
      if (optional && d.at != null)
        _pill(
          icon: Icons.close_rounded,
          label: 'No reminder',
          onTap: () => _update(() => d.at = null),
        ),
    ]);
  }

  Widget _editor(CaptureDraft d) {
    final g = context.glass;
    final expanded = _drafts.length == 1 || _editing == d.key;
    final problem = d.validate(DateTime.now());
    final flagged = _attempted && problem != null;
    return Padding(
      key: _cardKeys.putIfAbsent(d.key, GlobalKey.new),
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: g.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AscentDimensions.radiusLg),
          side: BorderSide(
            color: flagged
                ? g.warningInk.withValues(alpha: 0.7)
                : expanded
                ? g.focusRing.withValues(alpha: 0.5)
                : g.line,
            width: expanded || flagged ? 1.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _drafts.length == 1
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      _update(() => _editing = expanded ? null : d.key);
                    },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  children: [
                    _badge(d.kind),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _titleOf(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: g.ink,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            problem != null && !expanded
                                ? 'Needs a detail · tap to fix'
                                : _facts(d),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: problem != null && !expanded
                                  ? g.warningInk
                                  : g.inkMuted,
                              fontSize: 12.5,
                              fontWeight: problem != null && !expanded
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AscentButton.icon(
                      icon: Icons.close_rounded,
                      tooltip: 'Remove item',
                      compact: true,
                      onPressed: () {
                        _update(() {
                          _drafts.remove(d);
                          if (_drafts.isEmpty) _review = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _editorFields(d),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Field order is the same for every type: what it is, the one thing that
  /// makes it complete, when, then optional extras.
  List<Widget> _editorFields(CaptureDraft d) {
    final g = context.glass;
    final money = d.kind == CaptureKind.expense || d.kind == CaptureKind.income;
    final task = d.kind == CaptureKind.todo || d.kind == CaptureKind.timer;
    final categories =
        ref.watch(thoughtCategoriesStreamProvider).value ?? {'general': 'Wall'};
    final notesOpen = _notesOpen.contains(d.key) || d.notes.isNotEmpty;
    return [
      _field(
        'Save as',
        _scrollRow([
          for (final kind in CaptureKind.values)
            _pill(
              key: ValueKey('${d.key}.kind.${kind.name}'),
              icon: _icon(kind),
              label: captureLabel(kind),
              selected: d.kind == kind,
              onTap: () => _update(() {
                d.kind = kind;
                d.needsClock = false;
                if (!_timedKinds.contains(kind)) d.at = null;
              }),
            ),
        ]),
      ),
      if (d.kind != CaptureKind.water)
        _field(
          'Title',
          _textField(
            d,
            'title',
            initial: d.title,
            hint: 'What is it?',
            maxLines: 2,
            maxLength: money ? 200 : 300,
            onChanged: (v) => _update(() => d.title = v),
          ),
        ),
      if (money) ...[
        _field(
          'Amount',
          _textField(
            d,
            'amount',
            initial: d.amount == null ? '' : _amountText(d.amount!),
            hint: '0',
            prefix: '₹ ',
            bold: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) {
              d.amount = double.tryParse(v.replaceAll(',', ''));
              _changed();
            },
          ),
        ),
        _field(
          'Category',
          _chips([
            for (final c in _moneyCategories)
              _pill(
                label: c,
                selected: d.category == c,
                onTap: () => _update(() => d.category = c),
              ),
          ]),
        ),
      ],
      if (d.kind == CaptureKind.water) ...[
        _field(
          'Volume',
          _chips([
            for (final ml in const [150, 250, 500, 750])
              _pill(
                label: '$ml ml',
                selected: d.amount == ml.toDouble(),
                onTap: () => _update(() {
                  d.amount = ml.toDouble();
                  _epoch++;
                }),
              ),
          ]),
        ),
        _field(
          'Or type an amount',
          _textField(
            d,
            'amount',
            epoch: _epoch,
            initial: d.amount == null ? '' : _amountText(d.amount!),
            hint: '250',
            suffix: 'ml',
            bold: true,
            keyboardType: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              d.amount = double.tryParse(v);
              _update(() {});
            },
          ),
        ),
      ],
      if (d.kind == CaptureKind.timer)
        _field(
          'Focus target',
          _chips([
            for (final m in {15, 25, 45, 60, 90, d.minutes}.toList()..sort())
              _pill(
                label: '$m min',
                selected: d.minutes == m,
                onTap: () => _update(() => d.minutes = m),
              ),
          ]),
        ),
      if (d.kind == CaptureKind.thought)
        _field(
          'Space',
          _chips([
            for (final c in categories.entries)
              _pill(
                label: c.value,
                selected:
                    (categories.containsKey(d.space) ? d.space : 'general') ==
                    c.key,
                onTap: () => _update(() => d.space = c.key),
              ),
          ]),
        ),
      if (task || _isLogged(d.kind))
        _field(task ? 'Day' : 'Date', _dayChips(d)),
      if (_timedKinds.contains(d.kind))
        _field(switch (d.kind) {
          CaptureKind.reminder => 'Remind me',
          CaptureKind.routine => 'Starts',
          _ => 'Reminder · optional',
        }, _timeChips(d)),
      if (d.kind == CaptureKind.routine) ...[
        _field(
          'Repeat',
          ['daily', 'weekdays'].contains(d.recurrence)
              ? AscentSegmentedControl<String>(
                  segments: const [
                    AscentSegment(value: 'daily', label: 'Daily'),
                    AscentSegment(value: 'weekdays', label: 'Weekdays'),
                  ],
                  selected: d.recurrence,
                  onChanged: (v) => _update(() => d.recurrence = v),
                )
              : _chips([
                  _pill(
                    label: 'Daily',
                    onTap: () => _update(() => d.recurrence = 'daily'),
                  ),
                  _pill(
                    label: 'Weekdays',
                    onTap: () => _update(() => d.recurrence = 'weekdays'),
                  ),
                ]),
        ),
        _field('Ends', _endChips(d)),
      ],
      if (task)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              AscentStarButton(
                selected: d.starred,
                onChanged: (v) => _update(() => d.starred = v),
              ),
              const SizedBox(width: 6),
              Text(
                'Mark important',
                style: TextStyle(
                  color: g.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      if (d.kind != CaptureKind.reminder && d.kind != CaptureKind.water)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: notesOpen
              ? _field(
                  'Notes · optional',
                  _textField(
                    d,
                    'notes',
                    initial: d.notes,
                    hint: 'Add a detail',
                    maxLines: 3,
                    onChanged: (v) {
                      d.notes = v;
                      _changed();
                    },
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: _pill(
                    icon: Icons.notes_rounded,
                    label: 'Add notes',
                    onTap: () => setState(() => _notesOpen.add(d.key)),
                  ),
                ),
        ),
    ];
  }

  Widget _endChips(CaptureDraft d) {
    final start = d.at == null ? null : _dayOf(d.at!);
    DateTime? after(int days) => start?.add(Duration(days: days));
    final options = [('1 week', 7), ('1 month', 30), ('3 months', 90)];
    return _chips([
      for (final (label, days) in options)
        _pill(
          label: label,
          selected:
              d.end != null && _sameDay(d.end, after(days) ?? DateTime(0)),
          onTap: start == null
              ? null
              : () => _update(() => d.end = after(days)),
        ),
      _pill(
        icon: Icons.event_outlined,
        label:
            d.end != null &&
                !options.any((o) => _sameDay(d.end, after(o.$2) ?? DateTime(0)))
            ? DateFormat.yMMMd().format(d.end!)
            : 'Choose date',
        selected:
            d.end != null &&
            !options.any((o) => _sameDay(d.end, after(o.$2) ?? DateTime(0))),
        onTap: () => _pickDay(d, end: true),
      ),
    ]);
  }

  // ── Steps ─────────────────────────────────────────────────────────────────

  Widget _writeStep() {
    final g = context.glass;
    final shown = _preview.take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What’s on your mind?',
          style: TextStyle(
            color: g.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Write it the way you’d say it, one line per thing. '
          'We’ll sort it and you confirm.',
          style: TextStyle(color: g.inkMuted, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: g.recessed,
            borderRadius: BorderRadius.circular(AscentDimensions.radiusLg),
            border: Border.all(color: g.controlOutline.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: TextField(
                  key: const ValueKey('quick_capture_input'),
                  controller: _input,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 6000,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: g.ink, fontSize: 15.5, height: 1.45),
                  decoration: InputDecoration(
                    hintText:
                        'Todo: send the proposal tomorrow\n'
                        'Reminder: call Sam tomorrow at 6pm\n'
                        'Expense: 120 for lunch',
                    hintMaxLines: 4,
                    hintStyle: TextStyle(
                      color: g.inkMuted.withValues(alpha: 0.65),
                      fontSize: 14,
                      height: 1.45,
                    ),
                    counterText: '',
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: _scrollRow([
                  for (final (label, icon) in const [
                    ('Todo', Icons.check_circle_outline_rounded),
                    ('Reminder', Icons.notifications_none_rounded),
                    ('Thought', Icons.lightbulb_outline_rounded),
                    ('Expense', Icons.account_balance_wallet_outlined),
                    ('Water', Icons.water_drop_outlined),
                  ])
                    _pill(
                      icon: icon,
                      label: label,
                      onTap: () {
                        final needsBreak =
                            _input.text.isNotEmpty &&
                            !_input.text.endsWith('\n');
                        _input.text =
                            '${_input.text}${needsBreak ? '\n' : ''}$label: ';
                        _input.selection = TextSelection.collapsed(
                          offset: _input.text.length,
                        );
                      },
                    ),
                ]),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: shown.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 18),
                    Text(
                      _preview.length == 1
                          ? 'Found 1 item'
                          : 'Found ${_preview.length} items',
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final d in shown) _previewRow(d),
                    if (_preview.length > shown.length)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, top: 2),
                        child: Text(
                          '+ ${_preview.length - shown.length} more',
                          style: TextStyle(color: g.inkMuted, fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        Text(
          'Unfinished? It stays here if you close this.',
          style: TextStyle(color: g.inkMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _previewRow(CaptureDraft d) {
    final g = context.glass;
    final needs = d.validate(DateTime.now()) != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          _badge(d.kind, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleOf(d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: g.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  needs
                      ? '${captureLabel(d.kind)} · add a detail next'
                      : _facts(d),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: needs ? g.warningInk : g.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewStep() {
    final g = context.glass;
    final attention = _drafts
        .where((d) => d.validate(DateTime.now()) != null)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${_drafts.length} ${_drafts.length == 1 ? 'item' : 'items'} ready to place',
          style: TextStyle(
            color: g.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 8),
        _countChips(_drafts),
        if (attention > 0) ...[
          const SizedBox(height: 8),
          Text(
            attention == 1
                ? '1 item needs a detail before saving.'
                : '$attention items need a detail before saving.',
            style: TextStyle(
              color: g.warningInk,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 14),
        for (final d in _drafts) _editor(d),
        Align(
          alignment: Alignment.centerLeft,
          child: AscentButton.ghost(
            label: 'Add another item',
            icon: Icons.add_rounded,
            compact: true,
            onPressed: _drafts.length >= 30
                ? null
                : () => _update(() {
                    final d = CaptureDraft(key: planningId(), title: '');
                    _drafts.add(d);
                    _editing = d.key;
                  }),
          ),
        ),
      ],
    );
  }

  Widget _success() {
    final receipt = _receipt!;
    final g = context.glass;
    final count = receipt.items.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: g.successSoftBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 30, color: g.successInk),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'A little less on your mind.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$count ${count == 1 ? 'thing is' : 'things are'} right where ${count == 1 ? 'it belongs' : 'they belong'}.',
          textAlign: TextAlign.center,
          style: TextStyle(color: g.inkMuted, fontSize: 14),
        ),
        const SizedBox(height: 18),
        Container(
          decoration: BoxDecoration(
            color: g.surface,
            borderRadius: BorderRadius.circular(AscentDimensions.radiusLg),
            border: Border.all(color: g.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < receipt.items.length; i++) ...[
                if (i > 0) Divider(height: 1, indent: 14, color: g.line),
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    context.push(receipt.items[i].route);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                receipt.items[i].title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: g.ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                receipt.items[i].destination,
                                style: TextStyle(
                                  color: g.inkMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: g.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_alertsPending) ...[
          const SizedBox(height: 14),
          Text(
            'Everything is saved. Some alerts still need notification access or a retry.',
            style: TextStyle(color: g.inkMuted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: AscentButton.tonal(
              label: 'Enable notifications & retry',
              icon: Icons.notifications_none_rounded,
              compact: true,
              onPressed: () async {
                await NotificationService.instance.requestPermissions();
                if (!mounted) return;
                final result = await ReminderAlertSync.device(
                  ref.read(databaseProvider),
                ).sync(ids: receipt.reminderIds, onlyPending: true);
                if (mounted) setState(() => _alertsPending = !result.complete);
              },
            ),
          ),
        ],
      ],
    );
  }

  // ── Chrome ────────────────────────────────────────────────────────────────

  /// Two quiet segments: Write → Review. Both fill once everything is placed.
  Widget _progress() {
    final g = context.glass;
    final done = _receipt != null;
    Widget bar(bool on) => Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        height: 3,
        decoration: BoxDecoration(
          color: on
              ? (done ? g.successInk : g.primaryButtonBg)
              : g.ink.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Row(
        children: [bar(true), const SizedBox(width: 4), bar(_review || done)],
      ),
    );
  }

  Widget _footer(double keyboard) {
    final stack = MediaQuery.textScalerOf(context).scale(14) > 19;
    if (_receipt != null) {
      return AscentButton.tonal(
        label: 'Done',
        expanded: true,
        onPressed: () => Navigator.pop(context),
      );
    }
    if (!_review) {
      final n = _preview.length;
      return AscentButton.primary(
        key: const ValueKey('quick_capture_review'),
        label: n == 0
            ? 'Review capture'
            : 'Review $n ${n == 1 ? 'item' : 'items'}',
        icon: Icons.arrow_forward_rounded,
        onPressed: _loading ? null : _prepare,
      );
    }
    final save = AscentButton.primary(
      key: const ValueKey('quick_capture_save'),
      label: 'Save ${_drafts.length} ${_drafts.length == 1 ? 'item' : 'items'}',
      loading: _saving,
      onPressed: _loading || _saving || _drafts.isEmpty ? null : _save,
    );
    final back = AscentButton.ghost(
      label: 'Back to writing',
      expanded: stack,
      onPressed: _saving ? null : () => _update(() => _review = false),
    );
    if (keyboard > 0) return save;
    if (stack) {
      return Column(mainAxisSize: MainAxisSize.min, children: [save, back]);
    }
    return Row(
      children: [
        back,
        const SizedBox(width: 8),
        Expanded(child: save),
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
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
                const AscentSheetHandle(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 8, 4),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: g.tonalBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _receipt != null
                              ? Icons.check_rounded
                              : _review
                              ? Icons.tune_rounded
                              : Icons.bolt_rounded,
                          size: 18,
                          color: g.tonalFg,
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
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.2,
                              ),
                        ),
                      ),
                      AscentButton.icon(
                        icon: Icons.close_rounded,
                        tooltip: 'Close capture',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                _progress(),
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
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                          child: _receipt != null
                              ? _success()
                              : _review
                              ? _reviewStep()
                              : _writeStep(),
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
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: _footer(keyboard),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
