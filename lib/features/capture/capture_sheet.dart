import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/brand_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/features/feature_registry.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/plan_collection_service.dart';
import '../../core/services/quick_capture_service.dart';
import '../../core/utils/human_time.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_composer.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/schedule_picker.dart';

/// Opens the one global capture sheet (CLAUDE.md §1.5).
///
/// Type anything, one item per line. Each line is routed on the device
/// ("spent 250 on lunch" → Money, "idea: …" → Mind, "call mom at 6" → a to-do
/// at 6 pm) and shown as a live preview the user can adjust before saving.
/// Saving shows "N saved" with Undo, which removes exactly what was created.
Future<void> showCaptureSheet(BuildContext context, {String initial = ''}) {
  HapticFeedback.selectionClick();
  return showAscentSheet<void>(
    context: context,
    builder: (_) => CaptureSheet(initial: initial),
  );
}

/// Kinds a capture may create, given which features are switched on.
Set<CaptureKind> allowedCaptureKinds(Set<AscentFeature> unlocked) => {
  CaptureKind.todo,
  CaptureKind.reminder,
  CaptureKind.timer,
  CaptureKind.routine,
  if (unlocked.contains(AscentFeature.mind)) CaptureKind.thought,
  if (unlocked.contains(AscentFeature.money)) ...[
    CaptureKind.expense,
    CaptureKind.income,
  ],
  if (unlocked.contains(AscentFeature.care)) CaptureKind.water,
};

IconData captureIcon(CaptureKind kind) => switch (kind) {
  CaptureKind.todo => Icons.check_circle_outline_rounded,
  CaptureKind.reminder => Icons.notifications_none_rounded,
  CaptureKind.timer => Icons.timer_outlined,
  CaptureKind.thought => Icons.lightbulb_outline_rounded,
  CaptureKind.routine => Icons.repeat_rounded,
  CaptureKind.expense => Icons.payments_outlined,
  CaptureKind.income => Icons.savings_outlined,
  CaptureKind.water => Icons.water_drop_outlined,
};

String _pillar(CaptureKind kind) => switch (kind) {
  CaptureKind.thought => 'mind',
  CaptureKind.expense || CaptureKind.income => 'money',
  CaptureKind.water => 'hydration',
  CaptureKind.timer => 'focus',
  _ => 'things',
};

/// The prefix that forces a line to [kind] when the user changes it.
String _prefixFor(CaptureKind kind) => switch (kind) {
  CaptureKind.todo => 'todo',
  CaptureKind.reminder => 'reminder',
  CaptureKind.timer => 'focus',
  CaptureKind.thought => 'thought',
  CaptureKind.routine => 'routine',
  CaptureKind.expense => 'expense',
  CaptureKind.income => 'income',
  CaptureKind.water => 'water',
};

class CaptureSheet extends ConsumerStatefulWidget {
  const CaptureSheet({super.key, this.initial = ''});
  final String initial;

  @override
  ConsumerState<CaptureSheet> createState() => _CaptureSheetState();
}

class _CaptureSheetState extends ConsumerState<CaptureSheet> {
  late final TextEditingController _input;
  final _focus = FocusNode();
  List<CaptureDraft> _drafts = const [];

  /// Changes the user made to a line, keyed by the line's text so they
  /// survive edits to other lines.
  final _kindOverrides = <String, CaptureKind>{};
  final _timeOverrides = <String, DateTime>{};
  List<String> _lines = const [];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _input = TextEditingController(text: widget.initial);
    _reparse();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Set<CaptureKind> get _allowed =>
      allowedCaptureKinds(ref.read(unlockedFeaturesProvider));

  void _reparse() {
    final now = DateTime.now();
    List<String> lines;
    try {
      lines = PlanItemDraft.parseList(_input.text).take(30).toList();
    } catch (_) {
      lines = const [];
    }
    final drafts = <CaptureDraft>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final forced = _kindOverrides[line];
      final source = forced == null ? line : '${_prefixFor(forced)}: $line';
      final draft = parseCaptureLine(source, now, i, allowed: _allowed);
      if (forced != null) draft.alternative = null;
      final at = _timeOverrides[line];
      if (at != null) {
        draft
          ..at = at
          ..day = DateTime(at.year, at.month, at.day)
          ..needsClock = false;
      }
      drafts.add(draft);
    }
    setState(() {
      _lines = lines;
      _drafts = drafts;
      _error = null;
    });
  }

  bool get _canSave =>
      !_saving &&
      _drafts.isNotEmpty &&
      _drafts.every((d) => d.validate(DateTime.now()) == null);

  Future<void> _changeKind(int index) async {
    final draft = _drafts[index];
    final allowed = _allowed;
    final kind = await showAscentActionMenu<CaptureKind>(
      context: context,
      title: 'Save as',
      actions: [
        for (final k in CaptureKind.values)
          if (allowed.contains(k))
            AscentAction(k, captureLabel(k), captureIcon(k)),
      ],
    );
    if (kind == null || kind == draft.kind || !mounted) return;
    HapticFeedback.selectionClick();
    _kindOverrides[_lines[index]] = kind;
    _reparse();
  }

  void _useAlternative(int index) {
    final alt = _drafts[index].alternative;
    if (alt == null) return;
    HapticFeedback.selectionClick();
    _kindOverrides[_lines[index]] = alt;
    _reparse();
  }

  Future<void> _pickTime(int index) async {
    final draft = _drafts[index];
    final at = await pickFutureSchedule(
      context,
      purpose: captureLabel(draft.kind),
      initial: draft.at,
    );
    if (at == null || !mounted) return;
    _timeOverrides[_lines[index]] = at;
    _reparse();
  }

  Future<void> _save() async {
    if (!_canSave) {
      final problem = _drafts
          .map((d) => d.validate(DateTime.now()))
          .whereType<String>()
          .firstOrNull;
      setState(() => _error = problem);
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final service = QuickCaptureService(db);
    try {
      final receipt = await service.save(
        _drafts,
        requestId: '${DateTime.now().microsecondsSinceEpoch}',
      );
      HapticFeedback.lightImpact();
      if (receipt.reminderIds.isNotEmpty) {
        ReminderAlertSync.device(
          db,
        ).sync(ids: receipt.reminderIds, onlyPending: true).ignore();
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      if (messenger == null || !rootContext.mounted) return;
      _confirm(rootContext, service, receipt);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is ArgumentError
            ? '${e.message}'
            : 'Could not save. Your text is still here, try again.';
      });
    }
  }

  static void _confirm(
    BuildContext context,
    QuickCaptureService service,
    CaptureReceipt receipt,
  ) {
    final count = receipt.items.length;
    final first = receipt.items.first;
    final message = count == 1
        ? 'Saved to ${first.destination}'
        : '$count items saved';
    AscentSnackBar.show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      duration: const Duration(seconds: 6),
      actionLabel: 'Undo',
      onAction: () async {
        await service.undo(receipt);
        for (final id in receipt.reminderIds) {
          NotificationService.instance.cancelChecked(id).ignore();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final now = DateTime.now();
    return SingleChildScrollView(
      primary: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AscentButton.ghost(
                key: const ValueKey('capture_cancel'),
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  'Capture',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.cardTitle.copyWith(color: g.ink),
                ),
              ),
              AscentButton.ghost(
                key: const ValueKey('capture_save'),
                label: _drafts.length > 1 ? 'Save ${_drafts.length}' : 'Save',
                loading: _saving,
                onPressed: _drafts.isEmpty ? null : _save,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          AscentComposer(
            controller: _input,
            focusNode: _focus,
            fieldKey: const ValueKey('capture_input'),
            sendKey: const ValueKey('capture_send'),
            hint: 'e.g. Call mom at 6, spent 250 on lunch',
            minLines: 2,
            maxLines: 6,
            busy: _saving,
            onChanged: (_) => _reparse(),
            onSend: (_) => _save(),
          ),
          const SizedBox(height: AppSpace.s12),
          if (_drafts.isEmpty)
            _Hints(
              onPick: (text) {
                _input.text = text;
                _input.selection = TextSelection.collapsed(offset: text.length);
                _reparse();
              },
            )
          else
            for (var i = 0; i < _drafts.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == _drafts.length - 1 ? 0 : AppSpace.s8,
                ),
                child: _PreviewRow(
                  key: ValueKey('capture_preview_$i'),
                  draft: _drafts[i],
                  now: now,
                  onKind: () => _changeKind(i),
                  onTime: () => _pickTime(i),
                  onAlternative: () => _useAlternative(i),
                ),
              ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              _error!,
              style: AscentTextStyles.caption.copyWith(color: g.errorInk),
            ),
          ],
        ],
      ),
    );
  }
}

/// One line's live preview: what it becomes, where it goes, and when.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    super.key,
    required this.draft,
    required this.now,
    required this.onKind,
    required this.onTime,
    required this.onAlternative,
  });
  final CaptureDraft draft;
  final DateTime now;
  final VoidCallback onKind, onTime, onAlternative;

  String? get _meta {
    switch (draft.kind) {
      case CaptureKind.expense:
      case CaptureKind.income:
        final a = draft.amount;
        if (a == null) return null;
        final whole = a == a.roundToDouble();
        return '₹${whole ? a.toInt() : a.toStringAsFixed(2)}';
      case CaptureKind.water:
        return draft.amount == null ? null : '${draft.amount!.toInt()} ml';
      case CaptureKind.thought:
        return null;
      case CaptureKind.timer:
        final when = draft.at != null
            ? humanWhen(draft.at!, now: now)
            : draft.day != null
            ? humanDay(draft.day!, now: now)
            : 'Today';
        return '$when · ${draft.minutes} min';
      case CaptureKind.routine:
        if (draft.at == null) return null;
        final repeat = draft.recurrence == 'weekdays' ? 'Weekdays' : 'Daily';
        return '$repeat from ${humanWhen(draft.at!, now: now)}';
      case CaptureKind.todo:
      case CaptureKind.reminder:
        if (draft.at != null) return humanWhen(draft.at!, now: now);
        if (draft.day != null) return humanDay(draft.day!, now: now);
        return 'Today';
    }
  }

  bool get _hasTime => const {
    CaptureKind.todo,
    CaptureKind.reminder,
    CaptureKind.timer,
    CaptureKind.routine,
  }.contains(draft.kind);

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final tint = BrandPalette.pillarTint(_pillar(draft.kind), dark: g.isDark);
    final problem = draft.validate(now);
    final raw = _meta;
    final meta = raw == null || raw.isEmpty
        ? raw
        : raw[0].toUpperCase() + raw.substring(1);
    final title = draft.title.trim().isEmpty
        ? captureLabel(draft.kind)
        : draft.title.trim();
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: g.recessed,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: problem == null ? Colors.transparent : g.warningInk,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(captureIcon(draft.kind), size: 18, color: tint),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
                ),
                const SizedBox(height: AppSpace.s4),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Pill(
                      key: const ValueKey('capture_kind'),
                      label:
                          '${captureLabel(draft.kind)} · '
                          '${captureDestination(draft.kind)}',
                      color: tint,
                      onTap: onKind,
                      trailing: Icons.expand_more_rounded,
                    ),
                    if (meta != null)
                      _Pill(
                        key: const ValueKey('capture_time'),
                        label: meta,
                        color: g.inkSecondary,
                        onTap: _hasTime ? onTime : null,
                      ),
                    if (meta == null && _hasTime)
                      _Pill(
                        key: const ValueKey('capture_time'),
                        label: 'Add time',
                        color: g.actionInk,
                        onTap: onTime,
                      ),
                    if (draft.alternative != null)
                      _Pill(
                        key: const ValueKey('capture_alternative'),
                        label: 'Make it a ${captureLabel(draft.alternative!)}',
                        color: g.actionInk,
                        onTap: onAlternative,
                      ),
                  ],
                ),
                if (problem != null) ...[
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    problem,
                    style: AscentTextStyles.caption.copyWith(
                      color: g.warningInk,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A small tappable label inside a preview row (44 pt tall hit area).
class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.trailing,
  });
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final text = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: AscentTextStyles.caption.copyWith(color: color),
          ),
        ),
        if (trailing != null) Icon(trailing, size: 16, color: color),
      ],
    );
    if (onTap == null) return text;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Align(
            widthFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
              child: text,
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown while the field is empty: what you can type, each one tappable.
class _Hints extends StatelessWidget {
  const _Hints({required this.onPick});
  final ValueChanged<String> onPick;

  static const examples = [
    ('Call mom at 6', CaptureKind.todo),
    ('Spent 250 on lunch', CaptureKind.expense),
    ('Idea: a reading corner', CaptureKind.thought),
    ('Study 45m', CaptureKind.timer),
    ('2 glasses of water', CaptureKind.water),
    ('Walk every morning', CaptureKind.routine),
  ];

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Type naturally, one thing per line. Try:',
          style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
        ),
        const SizedBox(height: AppSpace.s8),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final (text, kind) in examples)
              AppChip(
                key: ValueKey('capture_hint_$text'),
                label: text,
                icon: captureIcon(kind),
                iconColor: BrandPalette.pillarTint(
                  _pillar(kind),
                  dark: g.isDark,
                ),
                onTap: () => onPick(text),
              ),
          ],
        ),
      ],
    );
  }
}
