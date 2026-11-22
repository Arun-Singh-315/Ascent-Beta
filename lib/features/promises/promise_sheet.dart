import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/promises/promise_providers.dart';
import '../../core/promises/promise_service.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/ascent_switch_row.dart';
import 'promise_copy.dart';
import 'widgets/home_promise_card.dart';
import 'widgets/promise_dots.dart';

/// Opens the promise sheet: new when [editing] is null, else edit.
Future<void> showPromiseSheet(
  BuildContext context, {
  PromiseView? editing,
  String initial = '',
}) => showAscentSheet<void>(
  context: context,
  builder: (_) => PromiseSheet(editing: editing, initial: initial),
);

/// Opens one promise's detail: its days, numbers and actions.
Future<void> showPromiseDetail(BuildContext context, String id) =>
    showAscentSheet<void>(
      context: context,
      builder: (_) => PromiseDetailSheet(id: id),
    );

String _timeLabel(BuildContext context, int minute) => MaterialLocalizations.of(
  context,
).formatTimeOfDay(TimeOfDay(hour: minute ~/ 60, minute: minute % 60));

/// "I promise to ___ for 21 days." One field; everything else has a default.
class PromiseSheet extends ConsumerStatefulWidget {
  const PromiseSheet({super.key, this.editing, this.initial = ''});
  final PromiseView? editing;
  final String initial;

  @override
  ConsumerState<PromiseSheet> createState() => _PromiseSheetState();
}

class _PromiseSheetState extends ConsumerState<PromiseSheet> {
  late final TextEditingController _title;
  late final TextEditingController _why;
  int? _length = 21;
  int? _nudge;
  bool _showWhy = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.editing?.promise;
    _title = TextEditingController(text: p?.title ?? widget.initial);
    _why = TextEditingController(text: p?.why ?? '');
    _showWhy = (p?.why ?? '').isNotEmpty;
    if (p != null) {
      _length = p.lengthDays;
      _nudge = p.nudgeMinute;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _why.dispose();
    super.dispose();
  }

  Future<void> _toggleNudge(bool on) async {
    if (!on) {
      setState(() => _nudge = null);
      return;
    }
    // Ask for notifications only now, when the nudge is wanted (§1.3).
    var allowed = true;
    try {
      allowed = await NotificationService.instance.requestPermissions();
    } catch (_) {}
    if (!mounted) return;
    setState(() => _nudge = 21 * 60);
    if (!allowed) {
      AscentSnackBar.show(
        context,
        message:
            'Notifications are off, so the nudge stays quiet. '
            'You can still check in from Home.',
      );
    }
  }

  Future<void> _pickNudge() async {
    final current = _nudge ?? 21 * 60;
    final t = await showTimePicker(
      context: context,
      helpText: 'Nudge me at',
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (t != null && mounted) setState(() => _nudge = t.hour * 60 + t.minute);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Write what you promise, e.g. Walk 20 minutes.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final service = ref.read(promiseServiceProvider);
    try {
      if (_isEdit) {
        await service.edit(
          widget.editing!.id,
          title: _title.text,
          why: Value(_why.text),
          lengthDays: Value(_length),
          nudgeMinute: Value(_nudge),
        );
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final id = await service.create(
        title: _title.text,
        lengthDays: _length,
        nudgeMinute: _nudge,
        why: _why.text,
      );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      final root = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      if (root.mounted) {
        AscentSnackBar.undo(
          root,
          message: 'Promise made. Day 1 starts today.',
          onUndo: () => service.delete(id),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final gold = promiseTint(context);
    final grace = (_length ?? 7) ~/ 7;
    return SingleChildScrollView(
      primary: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AscentButton.ghost(
                key: const ValueKey('promise_cancel'),
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  _isEdit ? 'Edit promise' : 'New promise',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.cardTitle.copyWith(color: g.ink),
                ),
              ),
              AscentButton.ghost(
                key: const ValueKey('promise_save'),
                label: _isEdit ? 'Save' : 'Promise',
                loading: _saving,
                onPressed: _save,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'I promise to',
            style: AscentTextStyles.caption.copyWith(color: gold),
          ),
          const SizedBox(height: AppSpace.s8),
          AppTextField(
            key: const ValueKey('promise_title'),
            controller: _title,
            autofocus: !_isEdit,
            hintText: 'e.g. Walk 20 minutes',
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            // Rebuild so the starters hide once typing begins.
            onChanged: (_) => setState(() => _error = null),
          ),
          if (!_isEdit && _title.text.isEmpty) ...[
            const SizedBox(height: AppSpace.s8),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final s in promiseStarters)
                  AppChip(
                    label: s,
                    onTap: () => setState(() {
                      _title.text = s;
                      _title.selection = TextSelection.collapsed(
                        offset: s.length,
                      );
                    }),
                  ),
              ],
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              _error!,
              style: AscentTextStyles.caption.copyWith(color: g.errorInk),
            ),
          ],
          const SizedBox(height: AppSpace.s20),
          Text('For', style: AscentTextStyles.caption.copyWith(color: g.ink)),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final l in promiseLengths)
                AppChip(
                  key: ValueKey('promise_length_${l ?? 0}'),
                  label: promiseLengthLabel(l),
                  isSelected: _length == l,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _length = l);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            _length == null
                ? 'No end date. One grace day each week forgives an off day.'
                : 'Includes ${grace < 1 ? 1 : grace} grace '
                      '${grace > 1 ? 'days' : 'day'} for off days, so one '
                      'slip never breaks your streak.',
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
          const SizedBox(height: AppSpace.s16),
          AscentSwitchRow(
            key: const ValueKey('promise_nudge'),
            title: 'Evening nudge',
            helper: _nudge == null
                ? 'A gentle reminder to check in'
                : 'Every day at ${_timeLabel(context, _nudge!)}',
            value: _nudge != null,
            onChanged: _toggleNudge,
          ),
          if (_nudge != null)
            Align(
              alignment: Alignment.centerLeft,
              child: AscentButton.ghost(
                key: const ValueKey('promise_nudge_time'),
                label: 'Change time',
                compact: true,
                onPressed: _pickNudge,
              ),
            ),
          const SizedBox(height: AppSpace.s8),
          if (_showWhy)
            AppTextField(
              key: const ValueKey('promise_why'),
              controller: _why,
              hintText: 'Why it matters, e.g. I want calmer evenings',
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: AscentButton.ghost(
                key: const ValueKey('promise_add_why'),
                label: 'Add why it matters',
                icon: Icons.add_rounded,
                compact: true,
                onPressed: () => setState(() => _showWhy = true),
              ),
            ),
        ],
      ),
    );
  }
}

/// One promise in full: the hero (with today's answer), the numbers, every
/// day, the reason, and edit / release / delete.
class PromiseDetailSheet extends ConsumerWidget {
  const PromiseDetailSheet({super.key, required this.id});
  final String id;

  Future<void> _more(BuildContext context, WidgetRef ref, PromiseView v) async {
    final service = ref.read(promiseServiceProvider);
    final action = await showAscentActionMenu<String>(
      context: context,
      title: v.title,
      actions: [
        const AscentAction('edit', 'Edit', Icons.edit_outlined),
        if (v.isActive)
          const AscentAction('release', 'Release promise', Icons.flag_outlined)
        else ...[
          const AscentAction('renew', 'Promise again', Icons.replay_rounded),
          const AscentAction('reopen', 'Continue it', Icons.play_arrow_rounded),
        ],
        const AscentAction(
          'delete',
          'Delete',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;
    switch (action) {
      case 'edit':
        await showPromiseSheet(context, editing: v);
      case 'release':
        await service.release(v.id);
        if (context.mounted) {
          AscentSnackBar.undo(
            context,
            message: 'Promise released. It moves to Past.',
            onUndo: () => service.reopen(v.id),
          );
        }
      case 'renew':
        await service.renew(v.id);
        if (context.mounted) Navigator.of(context).pop();
      case 'reopen':
        await service.reopen(v.id);
      case 'delete':
        HapticFeedback.mediumImpact();
        final at = await service.delete(v.id);
        if (!context.mounted) return;
        final root = Navigator.of(context, rootNavigator: true).context;
        Navigator.of(context).pop();
        if (root.mounted) {
          AscentSnackBar.undo(
            root,
            message: 'Promise deleted',
            onUndo: () => service.restore(v.id, at),
          );
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final all = ref.watch(promisesProvider).value ?? const [];
    final v = all.where((p) => p.id == id).firstOrNull;
    if (v == null) return const SizedBox(height: 120);
    final p = v.progress;
    final status = switch (v.promise.status) {
      'done' => 'Finished',
      'released' => 'Released',
      _ => null,
    };
    return SingleChildScrollView(
      primary: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s20,
        0,
        AppSpace.s20,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (status != null)
                Text(
                  status,
                  style: AscentTextStyles.caption.copyWith(
                    color: g.inkSecondary,
                  ),
                ),
              const Spacer(),
              AscentButton.icon(
                key: const ValueKey('promise_more'),
                icon: Icons.more_horiz_rounded,
                tooltip: 'More',
                semanticLabel: 'More actions',
                onPressed: () => _more(context, ref, v),
              ),
            ],
          ),
          if (v.isActive || v.promise.status == 'done')
            PromiseHero(view: v, linkToDetail: false)
          else
            Text(
              v.title,
              style: AscentTextStyles.pageTitle.copyWith(color: g.ink),
            ),
          const SizedBox(height: AppSpace.s24),
          Row(
            children: [
              _Stat(value: '${p.kept}', label: 'Kept'),
              _Stat(value: '${p.best}', label: 'Best streak'),
              _Stat(
                value: '${p.graceLeft}',
                label: p.graceLeft == 1 ? 'Grace day left' : 'Grace days left',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s24),
          Text(
            'Every day',
            style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
          ),
          const SizedBox(height: AppSpace.s12),
          PromiseDots(progress: p, wrap: true, size: 18),
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s16,
            runSpacing: AppSpace.s8,
            children: const [
              _Legend(mark: DayMark.kept, label: 'Kept'),
              _Legend(mark: DayMark.grace, label: 'Grace day'),
              _Legend(mark: DayMark.missed, label: 'Missed'),
              _Legend(mark: DayMark.open, label: 'To answer'),
            ],
          ),
          if ((v.promise.why ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpace.s24),
            Text(
              'Why it matters',
              style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
            ),
            const SizedBox(height: AppSpace.s8),
            Text(
              v.promise.why!,
              style: AscentTextStyles.body.copyWith(color: g.inkSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AscentTextStyles.tabular(
              AscentTextStyles.pageTitle,
            ).copyWith(color: g.ink),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.mark, required this.label});
  final DayMark mark;
  final String label;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PromiseDots(
          progress: PromiseProgress(
            dayNumber: 2,
            length: 1,
            kept: 0,
            missed: 0,
            graceAllowance: 0,
            graceUsed: 0,
            streak: 0,
            best: 0,
            today: null,
            yesterdayOpen: false,
            finished: false,
            days: [mark],
          ),
          size: 10,
          wrap: true,
        ),
        const SizedBox(width: AppSpace.s4),
        Text(
          label,
          style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
        ),
      ],
    );
  }
}
