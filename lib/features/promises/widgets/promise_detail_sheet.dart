import 'promise_privacy_guard.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import '../../../shared/widgets/ascent_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';
import 'promise_action_button.dart';
import '../../vault/providers/vault_providers.dart';
import '../../../shared/widgets/locked_commitment_tile.dart';
import 'promise_actions.dart';
import 'promise_calendar.dart';
import 'promise_schedule_editor.dart';

class PromiseDetailSheet extends ConsumerStatefulWidget {
  const PromiseDetailSheet({
    super.key,
    required this.promise,
    this.initialAction,
  });
  final String? initialAction;
  final PromiseModel promise;
  static final _open = <int>{};
  static Future<void> show(
    BuildContext context,
    PromiseModel promise, {
    String? initialAction,
  }) async {
    if (!_open.add(promise.id)) return;
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final current = await container
          .read(promiseRepositoryProvider)
          .getPromiseById(promise.id);
      if (current == null || !context.mounted) return;
      if (current.isPrivate &&
          !container.read(unlockedPromiseIdsProvider).contains(current.id)) {
        final authenticated = await container
            .read(vaultSecurityServiceProvider)
            .authenticateBiometrics(reason: 'Unlock private commitment');
        if (!authenticated || !context.mounted) return;
        container.read(unlockedPromiseIdsProvider.notifier).unlock(current.id);
      }
      if (!context.mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) =>
            PromiseDetailSheet(promise: current, initialAction: initialAction),
      );
    } finally {
      _open.remove(promise.id);
    }
  }

  @override
  ConsumerState<PromiseDetailSheet> createState() => _PromiseDetailSheetState();
}

class _PromiseDetailSheetState extends ConsumerState<PromiseDetailSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted ||
          (widget.promise.isPrivate &&
              !ref
                  .read(unlockedPromiseIdsProvider)
                  .contains(widget.promise.id))) {
        return;
      }
      if (widget.initialAction == 'edit') await _edit(widget.promise);
      if (widget.initialAction == 'delete') await _delete(widget.promise);
      if (widget.initialAction == 'pause') {
        await _run(() => ref.read(promiseRepositoryProvider).setPromiseStatus(widget.promise.id,
          widget.promise.isPaused ? PromiseStatus.active : PromiseStatus.paused));
      }
    });
  }

  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy ||
        (widget.promise.isPrivate &&
            !ref.read(unlockedPromiseIdsProvider).contains(widget.promise.id))) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this change. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final live = ref.watch(promiseByIdProvider(widget.promise.id));
    final p = live.value ?? widget.promise;
    final unlocked = ref.watch(unlockedPromiseIdsProvider).contains(p.id);
    if (p.isPrivate && !unlocked) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: LockedCommitmentTile(
            label: 'Private commitment',
            onTap: () async {
              final authenticated = await ref
                  .read(vaultSecurityServiceProvider)
                  .authenticateBiometrics(reason: 'Unlock private commitment');
              if (authenticated && mounted) {
                ref.read(unlockedPromiseIdsProvider.notifier).unlock(p.id);
              }
            },
          ),
        ),
      );
    }
    return GlassSurface(
      radius: 28,
      minimumOpacity: .88,
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .88,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.isCompleted
                          ? 'Promise completed'
                          : p.isPaused
                          ? 'Promise paused'
                          : 'Your promise',
                      style: TextStyle(color: g.inkMuted),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit promise',
                    onPressed: _busy ? null : () => _edit(p),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_busy,
                    onSelected: (value) async {
                      if (value == 'pause') {
                        await _run(
                          () => ref
                              .read(promiseRepositoryProvider)
                              .setPromiseStatus(
                                p.id,
                                p.isPaused
                                    ? PromiseStatus.active
                                    : PromiseStatus.paused,
                              ),
                        );
                      } else if (value == 'finish') {
                        await _run(
                          () => ref
                              .read(promiseRepositoryProvider)
                              .completePromise(p.id),
                        );
                      } else if (value == 'archive') {
                        await _run(
                          () => ref
                              .read(promiseRepositoryProvider)
                              .setPromiseStatus(p.id, PromiseStatus.archived),
                        );
                      } else if (value == 'delete') {
                        await _delete(p);
                      }
                    },
                    itemBuilder: (_) => [
                      if (!p.isCompleted)
                        PopupMenuItem(
                          value: 'pause',
                          child: Text(p.isPaused ? 'Resume' : 'Pause'),
                        ),
                      if (p.isActive && p.schedule?.repeats == true)
                        const PopupMenuItem(
                          value: 'finish',
                          child: Text('Finish this promise'),
                        ),
                      if (p.status != PromiseStatus.archived)
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('Archive · keep history'),
                        ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete permanently'),
                      ),
                    ],
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    p.title,
                    style: TextStyle(
                      color: g.ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (p.schedule != null)
                    Text(
                      '${p.schedule!.summary}${p.schedule!.plannedTime == null ? '' : ' · ${p.schedule!.plannedTime}'}${p.schedule!.endDate == null ? '' : ' · until ${MaterialLocalizations.of(context).formatShortDate(p.schedule!.endDate!)}'}',
                      style: TextStyle(color: g.inkMuted, fontSize: 13),
                    ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: p.progressFraction,
                    backgroundColor: g.track,
                    color: g.clay,
                    borderRadius: BorderRadius.circular(8),
                    minHeight: 5,
                  ),
                  const SizedBox(height: 8),
                  Text(p.progressSummary, style: TextStyle(color: g.inkMuted)),
                  if (p.reminderTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Reminder ${p.reminderTime}${p.isPrivate ? ' · private' : ''}',
                        style: TextStyle(color: g.inkMuted, fontSize: 12),
                      ),
                    ),
                  if (p.reminderIssue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        p.reminderIssue!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: PromiseActionButton(
                      promise: p,
                      isLoading: _busy,
                      onPressed: () =>
                          _run(() => PromiseActions.perform(context, ref, p)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  PromiseCalendar(promise: p),
                  const SizedBox(height: 20),
                  Text(
                    'History',
                    style: TextStyle(
                      color: g.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ref
                      .watch(promiseEventsProvider(p.id))
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => const Text('Could not load history.'),
                        data: (events) => Column(
                          children: [
                            if (events.isEmpty)
                              Text(
                                'Your first step will appear here.',
                                style: TextStyle(color: g.inkMuted),
                              ),
                            for (final event in events.take(20))
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(event.note ?? 'Progress recorded'),
                                subtitle: Text(
                                  '${event.dateKey ?? promiseDateKey(event.occurredAt)} · ${event.amount.toStringAsFixed(event.amount % 1 == 0 ? 0 : 1)} ${p.unit}',
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

  Future<void> _delete(PromiseModel p) async {
    final confirmed = await AscentDialog.confirm(
      context: context,
      title: 'Delete this promise?',
      content:
          'Its progress history will also be removed. This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep promise',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true) {
      await _run(() async {
        await ref.read(promiseRepositoryProvider).deletePromise(p.id);
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _edit(PromiseModel p) async {
    if (await AscentDialog.confirm(
              context: context,
              title: 'Edit this promise?',
              content: 'Your changes will only be applied when you save.',
              confirmLabel: 'Continue editing',
              cancelLabel: 'Keep as is',
              icon: Icons.edit_outlined,
            ) !=
            true ||
        !mounted) {
      return;
    }

    var draft = PromiseProposal(
      title: p.title,
      intention: p.intention,
      category: p.category,
      trackingType: p.trackingType,
      targetValue: p.targetValue,
      unit: p.unit,
      frequencyPerWeek: p.frequencyPerWeek,
      targetDate: p.targetDate,
      schedule:
          p.schedule ?? PromiseSchedule(startDate: promiseDay(DateTime.now())),
      isPrivate: p.isPrivate,
      reminderTime: p.reminderEnabled ? p.reminderTime : null,
      reminderDays: p.reminderDays,
    );
    final title = TextEditingController(text: p.title);
    bool saving = false;
    String? error;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => PromisePrivacyGuard(
          promise: p,
          child: StatefulBuilder(
            builder: (ctx, setLocal) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: GlassSurface(
                radius: 28,
                minimumOpacity: .92,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * .8,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Edit promise',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(ctx),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        TextField(
                          controller: title,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Your promise',
                          ),
                        ),
                        const SizedBox(height: 16),
                        AbsorbPointer(
                          absorbing: saving,
                          child: PromiseScheduleEditor(
                            proposal: draft,
                            allowTrackingType: false,
                            onChanged: (next) => setLocal(() => draft = next),
                          ),
                        ),
                        if (error != null)
                          Text(
                            error!,
                            style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                          ),
                        FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (p.isPrivate &&
                                      !ref
                                          .read(unlockedPromiseIdsProvider)
                                          .contains(p.id)) {
                                    return;
                                  }
                                  setLocal(() => saving = true);
                                  try {
                                    await ref
                                        .read(promiseRepositoryProvider)
                                        .updatePromise(
                                          p.copyWith(
                                            title: title.text,
                                            trackingType: draft.trackingType,
                                            unit: draft.unit,
                                            targetValue: draft.targetValue,
                                            frequencyPerWeek:
                                                draft.frequencyPerWeek,
                                            schedule: draft.schedule,
                                            targetDate: draft.schedule?.endDate,
                                            isPrivate: draft.isPrivate,
                                            reminderTime: draft.reminderTime,
                                            reminderEnabled:
                                                draft.reminderTime != null,
                                            reminderDays: draft.schedule?.days,
                                          ),
                                        );
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  } catch (e) {
                                    if (ctx.mounted) {
                                      setLocal(() {
                                        saving = false;
                                        error = e is ArgumentError
                                            ? e.message.toString()
                                            : 'Could not save. Your changes are still here.';
                                      });
                                    }
                                  }
                                },
                          child: Text(saving ? 'Saving…' : 'Save changes'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } finally {
      title.dispose();
    }
  }
}

Future<void> showPromiseActionMenu(
  BuildContext context,
  PromiseModel promise, {
  bool locked = false,
}) async {
  final action = await showAscentActionMenu<String>(
    context: context,
    title: locked ? 'Private commitment' : promise.title,
    actions: [
      const AscentAction('view', 'View commitment', Icons.open_in_new_rounded),
      if (!locked && promise.isPrivate)
        const AscentAction('lock', 'Lock commitment', Icons.lock_outline_rounded),
      if (!locked)
        const AscentAction('edit', 'Edit commitment', Icons.edit_outlined),
      if (!locked && !promise.isCompleted)
        AscentAction('pause', promise.isPaused ? 'Resume' : 'Pause', Icons.pause_circle_outline_rounded),
      if (!locked)
        const AscentAction(
          'delete',
          'Delete commitment',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
    ],
  );
  if (action == 'lock' && context.mounted) {
    ProviderScope.containerOf(context, listen: false).read(unlockedPromiseIdsProvider.notifier).lock(promise.id);
    return;
  }
  if (action != null && context.mounted) {
    await PromiseDetailSheet.show(context, promise, initialAction: action);
  }
}
