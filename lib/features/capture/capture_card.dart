import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_navigation.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../core/features/feature_registry.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/quick_capture_service.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import 'capture_sheet.dart' show allowedCaptureKinds;

/// The four places the capture card can send a line to.
enum CaptureTarget { thing, reminder, thought, money }

CaptureTarget captureTargetOf(CaptureKind kind) => switch (kind) {
  CaptureKind.reminder => CaptureTarget.reminder,
  CaptureKind.thought => CaptureTarget.thought,
  CaptureKind.expense ||
  CaptureKind.income ||
  CaptureKind.water => CaptureTarget.money,
  _ => CaptureTarget.thing,
};

/// Drafts for [raw] (one per line). [force] is the card's toggle: it adds
/// the matching prefix so parsing keeps that type; `null` routes by meaning.
List<CaptureDraft> cardDrafts(
  String raw,
  DateTime now, {
  CaptureTarget? force,
  Set<CaptureKind>? allowed,
}) {
  final prefix = switch (force) {
    null => '',
    CaptureTarget.thing => 'todo: ',
    CaptureTarget.reminder => 'reminder: ',
    CaptureTarget.thought => 'thought: ',
    CaptureTarget.money => 'spent ',
  };
  final lines = raw
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => '$prefix$l')
      .join('\n');
  final drafts = parseQuickCapture(lines, now, allowed: allowed);
  // A flipped toggle is a promise: never let parsing move the line elsewhere.
  if (force == CaptureTarget.money) {
    for (final d in drafts) {
      if (captureTargetOf(d.kind) != CaptureTarget.money) {
        d
          ..kind = CaptureKind.expense
          ..at = null
          ..needsClock = false;
      }
    }
  }
  return drafts;
}

/// Line icon for each place a capture can land.
IconData captureTargetIcon(CaptureTarget? t) => switch (t) {
  null => Icons.auto_awesome_outlined,
  CaptureTarget.thing => Icons.check_circle_outline_rounded,
  CaptureTarget.reminder => Icons.notifications_none_rounded,
  CaptureTarget.thought => Icons.lightbulb_outline_rounded,
  CaptureTarget.money => Icons.account_balance_wallet_outlined,
};

String captureTargetLabel(CaptureTarget? t) => switch (t) {
  null => 'Auto',
  CaptureTarget.thing => 'Thing',
  CaptureTarget.reminder => 'Reminder',
  CaptureTarget.thought => 'Thought',
  CaptureTarget.money => 'Money',
};

String _hint(CaptureTarget? t) => switch (t) {
  null => 'e.g. Call mom at 6 · idea: … · ₹250 lunch',
  CaptureTarget.thing => 'e.g. Gym 7 am tomorrow',
  CaptureTarget.reminder => 'e.g. Pay rent at 9 am',
  CaptureTarget.thought => 'e.g. A gift idea for Sam',
  CaptureTarget.money => 'e.g. 250 lunch',
};

/// "Today 6:00 pm", "Tomorrow", "Fri 12 Dec", or `null` for no date.
String? captureWhen(CaptureDraft d, DateTime now) {
  final at = d.at;
  final day = at ?? d.day;
  if (day == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(day.year, day.month, day.day);
  final diff = date.difference(today).inDays;
  final dayLabel = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ => DateFormat('EEE d MMM').format(date),
  };
  if (at == null) return dayLabel;
  return '$dayLabel ${DateFormat('h:mm a').format(at).toLowerCase()}';
}

String _meta(CaptureDraft d, DateTime now) {
  final target = captureTargetOf(d.kind);
  final parts = <String>[
    switch (d.kind) {
      CaptureKind.routine => 'Routine',
      CaptureKind.timer => 'Focus',
      CaptureKind.income => 'Income',
      CaptureKind.water => 'Water',
      _ => captureTargetLabel(target),
    },
  ];
  if (d.amount != null && d.kind != CaptureKind.water) {
    parts.add(
      NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹',
        decimalDigits: d.amount! % 1 == 0 ? 0 : 2,
      ).format(d.amount),
    );
  }
  final when = captureWhen(d, now);
  if (when != null) parts.add(when);
  return parts.join(' · ');
}

/// One captured item shown in the card's "Just captured" list.
class _Captured {
  _Captured(this.draft, this.receipt, this.index, this.route, this.batch);
  final CaptureDraft draft;
  final int batch;
  final CaptureReceipt receipt;
  final int index;
  final String route;
}

/// Capture from anywhere: one bordered card with an input and type toggles.
///
/// Type one line (or paste many) and press Enter. Each line goes where it
/// belongs: a thing, a reminder, a thought or money. Leave the toggle on
/// Auto and parsing routes it, or flip it to force a type. Nothing asks
/// for details: smart defaults fill time and space, and each saved item can
/// be undone or opened from the list below the field.
class CaptureCard extends ConsumerStatefulWidget {
  const CaptureCard({
    super.key,
    this.autofocus = false,
    this.framed = true,
    this.onClose,
  });

  final bool autofocus;

  /// Shows a close button in the header (used by the capture sheet).
  final VoidCallback? onClose;

  /// Draw the bordered card (Home). Off inside a sheet, which is the frame.
  final bool framed;

  @override
  ConsumerState<CaptureCard> createState() => _CaptureCardState();
}

class _CaptureCardState extends ConsumerState<CaptureCard> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  CaptureTarget? _target;
  String? _error;
  bool _saving = false;
  final List<_Captured> _captured = [];
  int _batch = 0;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onText);
  }

  @override
  void dispose() {
    _text.removeListener(_onText);
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _last = '';

  void _onText() {
    // Selection and focus changes notify too; only edits clear the error.
    if (_text.text == _last) return;
    _last = _text.text;
    setState(() => _error = null);
  }

  Set<CaptureKind> get _allowed =>
      allowedCaptureKinds(ref.read(unlockedFeaturesProvider));

  List<CaptureDraft> _preview() {
    if (_text.text.trim().isEmpty) return const [];
    try {
      return cardDrafts(
        _text.text,
        DateTime.now(),
        force: _target,
        allowed: _allowed,
      );
    } catch (_) {
      return const [];
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final raw = _text.text.trim();
    if (raw.isEmpty) return;
    final now = DateTime.now();
    List<CaptureDraft> drafts;
    try {
      drafts = cardDrafts(raw, now, force: _target, allowed: _allowed);
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
      return;
    }
    final bad = drafts
        .map((d) => d.validate(now))
        .whereType<String>()
        .firstOrNull;
    if (bad != null) {
      final money = drafts.any(
        (d) => captureTargetOf(d.kind) == CaptureTarget.money,
      );
      setState(
        () => _error = money && bad.contains('amount')
            ? 'Add an amount, e.g. 250 lunch.'
            : bad,
      );
      return;
    }
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final service = QuickCaptureService(db);
    try {
      // One receipt per line, so each saved row can be undone on its own.
      final saved = <_Captured>[];
      for (final (i, d) in drafts.indexed) {
        final receipt = await service.save(
          [d],
          requestId: 'card:${now.microsecondsSinceEpoch}:$_batch:$i',
        );
        saved.add(_Captured(d, receipt, i, receipt.items.first.route, _batch));
        if (receipt.reminderIds.isNotEmpty) {
          ReminderAlertSync.device(
            db,
          ).sync(ids: receipt.reminderIds, onlyPending: true).ignore();
        }
      }
      _batch++;
      HapticFeedback.lightImpact();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _text.clear();
        _captured.insertAll(0, saved);
      });
      _focus.requestFocus();
      AscentSnackBar.undo(
        context,
        message: saved.length == 1
            ? 'Saved to ${saved.first.receipt.items.first.destination}'
            : '${saved.length} items saved',
        onUndo: () async {
          for (final c in saved) {
            await _undo(c);
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e is ArgumentError
              ? '${e.message}'
              : 'Couldn’t save that. Your text is still here.';
        });
      }
    }
  }

  Future<void> _undo(_Captured c) async {
    final db = ref.read(databaseProvider);
    await QuickCaptureService(db).undo(c.receipt);
    HapticFeedback.mediumImpact();
    for (final id in c.receipt.reminderIds) {
      NotificationService.instance.cancelChecked(id).ignore();
    }
    if (mounted) setState(() => _captured.remove(c));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final preview = _preview();
    final now = DateTime.now();
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Capture',
              style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                'One per line · Enter saves',
                maxLines: 1,
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
              ),
            ),
            if (widget.onClose != null)
              AscentButton.icon(
                icon: Icons.close_rounded,
                tooltip: 'Close capture',
                semanticLabel: 'Close capture',
                onPressed: widget.onClose,
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s12),
        AppTextField(
          key: const ValueKey('capture_card_field'),
          controller: _text,
          focusNode: _focus,
          autofocus: widget.autofocus,
          hintText: _hint(_target),
          minLines: 1,
          maxLines: 5,
          keyboardType: TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          suffixIcon: _text.text.trim().isEmpty
              ? null
              : AscentButton.icon(
                  key: const ValueKey('capture_card_save'),
                  icon: Icons.arrow_upward_rounded,
                  tooltip: 'Save',
                  semanticLabel: 'Save',
                  onPressed: _saving ? null : _save,
                ),
        ),
        const SizedBox(height: AppSpace.s12),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final t in <CaptureTarget?>[null, ...CaptureTarget.values])
              Semantics(
                selected: _target == t,
                child: AppChip(
                  key: ValueKey('capture_toggle_${t?.name ?? 'auto'}'),
                  label: captureTargetLabel(t),
                  icon: captureTargetIcon(t),
                  isSelected: _target == t,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _target = t);
                  },
                ),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpace.s8),
          Text(
            _error!,
            key: const ValueKey('capture_card_error'),
            style: AscentTextStyles.caption.copyWith(color: g.errorInk),
          ),
        ] else if (preview.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          for (final d in preview.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s4),
              child: Row(
                children: [
                  Icon(
                    captureTargetIcon(captureTargetOf(d.kind)),
                    size: 16,
                    color: g.inkSecondary,
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      '${d.title.isEmpty ? '…' : d.title}  ·  ${_meta(d, now)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (preview.length > 4)
            Text(
              '+${preview.length - 4} more',
              style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
            ),
        ],
        if (_captured.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          Divider(height: 1, thickness: 1, color: g.line),
          const SizedBox(height: AppSpace.s4),
          for (final (i, c) in _sorted().take(6).indexed) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, indent: 28, color: g.line),
            _CapturedRow(
              key: ValueKey('captured_${c.route}_${c.index}'),
              item: c,
              onUndo: () => _undo(c),
            ),
          ],
          if (_captured.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s4),
              child: Text(
                '+${_captured.length - 6} more saved',
                style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
              ),
            ),
        ],
      ],
    );
    if (!widget.framed) return content;
    return DecoratedBox(
      key: const ValueKey('capture_card'),
      decoration: BoxDecoration(
        color: g.surface,
        borderRadius: AppGeometry.roundedr20,
        border: Border.all(color: g.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: content,
      ),
    );
  }

  /// Newest save first, grouped by destination inside it.
  List<_Captured> _sorted() {
    const order = CaptureTarget.values;
    return [..._captured]..sort((a, b) {
      final byBatch = b.batch.compareTo(a.batch);
      if (byBatch != 0) return byBatch;
      final byTarget = order
          .indexOf(captureTargetOf(a.draft.kind))
          .compareTo(order.indexOf(captureTargetOf(b.draft.kind)));
      return byTarget != 0 ? byTarget : a.index.compareTo(b.index);
    });
  }
}

class _CapturedRow extends StatelessWidget {
  const _CapturedRow({super.key, required this.item, required this.onUndo});
  final _Captured item;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final d = item.draft;
    final title = item.receipt.items.first.title;
    return InkWell(
      onTap: () => context.open(item.route),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(
              captureTargetIcon(captureTargetOf(d.kind)),
              size: 18,
              color: g.inkSecondary,
            ),
            const SizedBox(width: AppSpace.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.body.copyWith(color: g.ink),
                  ),
                  Text(
                    _meta(d, DateTime.now()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AscentButton.ghost(
              key: ValueKey('captured_undo_${item.route}_${item.index}'),
              label: 'Undo',
              compact: true,
              onPressed: onUndo,
            ),
          ],
        ),
      ),
    );
  }
}
