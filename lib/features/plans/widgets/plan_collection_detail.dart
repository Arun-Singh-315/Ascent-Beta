import 'package:flutter/services.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../shared/widgets/app_surfaces.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../core/services/plan_collection_service.dart';
import '../planning_providers.dart';
import 'plan_collection_editor.dart';

Future<void> showPlanCollectionDetail(BuildContext context, String id) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlanCollectionDetail(id: id),
    );

class PlanCollectionDetail extends ConsumerStatefulWidget {
  const PlanCollectionDetail({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PlanCollectionDetail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<PlanCollectionDetail> {
  String _filter = 'All';
  String? _error;
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      try {
        final r = await ref
            .read(planningAlertSyncProvider)
            .sync(onlyPending: true)
            .timeout(const Duration(seconds: 8));
        if (!r.complete && mounted) {
          setState(
            () => _error =
                'Saved · alerts need attention. Check notification permissions, then retry alerts.',
          );
        }
      } catch (_) {
        if (mounted) {
          setState(
            () => _error =
                'Saved · alerts need attention. Retry alerts when permissions are available.',
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> _rename(PlanCollectionView plan) async {
    final name = TextEditingController(text: plan.title),
        notes = TextEditingController(text: plan.description);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit plan'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                maxLength: 300,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: notes,
                maxLines: 3,
                maxLength: 20000,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await _run(
        () => ref
            .read(planCollectionServiceProvider)
            .rename(plan.id, name.text, notes.text),
      );
    }
    // Dialog animations may still hold the fields until the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      notes.dispose();
    });
  }

  Future<void> _action(
    PlanItemView item,
    String action,
    List<PlanItemView> all,
  ) async {
    final service = ref.read(planCollectionServiceProvider);
    if (action == 'history' && item.definitionId != null) {
      final history = await ref
          .read(databaseProvider)
          .planDao
          .getOccurrencesForPlan(item.definitionId!);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (ctx) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Session history',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close history',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: history.length,
                  itemBuilder: (_, n) {
                    final o = history[history.length - 1 - n];
                    return ListTile(
                      title: Text(
                        DateFormat(
                          'EEE, d MMM · h:mm a',
                        ).format(o.scheduledStartTime),
                      ),
                      subtitle: Text(
                        o.outcome == 'done'
                            ? 'Completed'
                            : o.outcome == 'skipped'
                            ? 'Skipped'
                            : o.outcome == 'not_confirmed'
                            ? 'Not confirmed'
                            : 'Scheduled',
                      ),
                      leading: Icon(
                        o.outcome == 'done' ? Icons.task_alt : Icons.schedule,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    if (action == 'skip' && item.occurrenceId != null) {
      await _run(() async {
        await ref.read(planServiceProvider).skipOccurrence(item.occurrenceId!);
      });
      return;
    }
    if (action == 'focus' && item.taskId != null) {
      await _run(
        () => ref
            .read(timeTrackingProvider.notifier)
            .switchToTask(
              title: item.title,
              taskId: item.taskId,
              autoStart: true,
            ),
      );
      return;
    }
    if (action == 'edit') {
      await showPlanCollectionEditor(
        context,
        collectionId: item.collectionId,
        editing: item,
      );
      return;
    }
    if (action == 'delete') {
      if (await _confirm(
            'Delete item?',
            'This removes the item and cancels its alerts. Completed focus history is retained.',
          ) &&
          mounted) {
        await _run(() => service.deleteItem(item));
      }
    } else if (action == 'duplicate') {
      await _run(
        () => service
            .save(
              title: 'Copy',
              requestId: planningId(),
              collectionId: item.collectionId,
              items: [
                PlanItemDraft(
                  title: item.title,
                  notes: item.notes,
                  minutes: item.minutes,
                ),
              ],
            )
            .then((_) {}),
      );
    } else if (action == 'up') {
      final ids = all.map((i) => i.id).toList();
      final n = ids.indexOf(item.id);
      if (n > 0) {
        ids.removeAt(n);
        ids.insert(n - 1, item.id);
        await _run(() => service.reorder(item.collectionId, ids));
      }
    } else if (action == 'move') {
      final choices = (ref.read(planCollectionsProvider).value ?? [])
          .where((c) => c.id != item.collectionId && c.status == 'active')
          .toList();
      final id = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Move to plan'),
          children: [
            if (choices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(AppSpace.s16),
                child: Text('Create another active plan first.'),
              ),
            for (final c in choices)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, c.id),
                child: Text(c.title),
              ),
          ],
        ),
      );
      if (id != null && mounted) await _run(() => service.move(item.id, id));
    }
  }

  Future<void> _planAction(PlanCollectionView plan, String action) async {
    final service = ref.read(planCollectionServiceProvider);
    if (action == 'edit') {
      await _rename(plan);
      return;
    }
    if (action == 'status') {
      await _run(
        () => service.setStatus(
          plan.id,
          plan.status == 'active' ? 'paused' : 'active',
        ),
      );
      return;
    }
    if (action == 'archive') {
      await _run(() => service.setStatus(plan.id, 'archived'));
      return;
    }
    if (action == 'retry') {
      await _run(() async {
        await ref.read(planningRequestPermissionsProvider)();
      });
      return;
    }
    if (action == 'delete' &&
        await _confirm(
          'Delete plan?',
          'All items and their alerts will be removed. The original note stays saved.',
        ) &&
        mounted) {
      var deleted = false;
      await _run(() async {
        await service.deleteCollection(plan.id);
        deleted = true;
      });
      if (deleted && mounted) {
        Navigator.pop(context);
      }
    }
  }

  bool _notesExpanded = false;

  Widget _buildMetricBadge({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s8,
        vertical: AppSpace.s4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppGeometry.roundedr8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: AppSpace.s4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemTag({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.s6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppGeometry.roundedr6,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = ref.watch(planCollectionsProvider);
    final plan = plans.value?.where((c) => c.id == widget.id).firstOrNull;
    final items = ref.watch(planItemsProvider(widget.id));
    final g = context.glass;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: AppSpace.s12, bottom: AppSpace.s4),
                decoration: BoxDecoration(
                  color: g.inkMuted.withValues(alpha: 0.3),
                  borderRadius: AppGeometry.roundedr4,
                ),
              ),
            ),
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s8,
              ),
              child: Row(
                children: [
                  if (plan != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s10,
                        vertical: AppSpace.s4,
                      ),
                      decoration: BoxDecoration(
                        color: plan.status == 'active'
                            ? g.clay.withValues(alpha: 0.15)
                            : g.inkMuted.withValues(alpha: 0.15),
                        borderRadius: AppGeometry.roundedr8,
                        border: Border.all(
                          color: plan.status == 'active'
                              ? g.clay.withValues(alpha: 0.3)
                              : g.edge,
                        ),
                      ),
                      child: Text(
                        plan.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: plan.status == 'active' ? g.clay : g.inkMuted,
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (plan != null)
                    PopupMenuButton<String>(
                      tooltip: 'Plan actions',
                      icon: Icon(Icons.more_horiz_rounded, color: g.ink),
                      enabled: !_busy,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppGeometry.roundedr16,
                      ),
                      onSelected: (a) => _planAction(plan, a),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit plan'),
                        ),
                        PopupMenuItem(
                          value: 'status',
                          child: Text(
                            plan.status == 'active' ? 'Pause' : 'Resume',
                          ),
                        ),
                        if (plan.status != 'archived')
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive'),
                          ),
                        const PopupMenuItem(
                          value: 'retry',
                          child: Text('Permissions & retry alerts'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete plan'),
                        ),
                      ],
                    ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: g.ink),
                  ),
                ],
              ),
            ),
            if (plan == null)
              Expanded(
                child: Center(
                  child: plans.isLoading
                      ? const CircularProgressIndicator()
                      : const Text('This plan is no longer available.'),
                ),
              )
            else ...[
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Plan Title
                            Text(
                              plan.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: g.ink,
                                  ),
                            ),
                            const SizedBox(height: AppSpace.s12),
                            // Stats and Progress Card
                            Container(
                              padding: const EdgeInsets.all(AppSpace.s12),
                              decoration: BoxDecoration(
                                color: g.fill,
                                borderRadius: AppGeometry.roundedr16,
                                border: Border.all(color: g.edge),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Progress',
                                        style: TextStyle(
                                          color: g.inkMuted,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        '${plan.total == 0 ? 0 : ((plan.done / plan.total) * 100).round()}%',
                                        style: TextStyle(
                                          color: g.clay,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpace.s6),
                                  ClipRRect(
                                    borderRadius: AppGeometry.roundedr8,
                                    child: LinearProgressIndicator(
                                      value: plan.total == 0
                                          ? 0
                                          : plan.done / plan.total,
                                      backgroundColor:
                                          g.line.withValues(alpha: 0.3),
                                      color: g.clay,
                                      minHeight: 6,
                                    ),
                                  ),
                                  // Done / remaining counts live in the filter tabs below,
                                  // so only problems are called out here.
                                  if (plan.overdue > 0 || plan.skipped > 0) ...[
                                    const SizedBox(height: AppSpace.s10),
                                    Wrap(
                                      spacing: AppSpace.s6,
                                      runSpacing: AppSpace.s6,
                                      children: [
                                        if (plan.overdue > 0)
                                          _buildMetricBadge(
                                            icon: Icons.warning_amber_rounded,
                                            label: '${plan.overdue} overdue',
                                            color: context.stateDanger,
                                            background: context.stateDanger
                                                .withValues(alpha: 0.12),
                                          ),
                                        if (plan.skipped > 0)
                                          _buildMetricBadge(
                                            icon: Icons.skip_next_rounded,
                                            label: '${plan.skipped} skipped',
                                            color: g.inkMuted,
                                            background: g.fill,
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            // Expandable Notes
                            if (plan.description.isNotEmpty) ...[
                              const SizedBox(height: AppSpace.s10),
                              AppTapArea(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(
                                    () => _notesExpanded = !_notesExpanded,
                                  );
                                },
                                borderRadius: AppGeometry.roundedr12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s12,
                                    vertical: AppSpace.s10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: g.fill,
                                    borderRadius: AppGeometry.roundedr12,
                                    border: Border.all(color: g.edge),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.notes_rounded,
                                            size: 16,
                                            color: g.clay,
                                          ),
                                          const SizedBox(width: AppSpace.s8),
                                          Expanded(
                                            child: Text(
                                              'Plan notes',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: g.ink,
                                                  ),
                                            ),
                                          ),
                                          Icon(
                                            _notesExpanded
                                                ? Icons.keyboard_arrow_up_rounded
                                                : Icons
                                                    .keyboard_arrow_down_rounded,
                                            size: 20,
                                            color: g.inkMuted,
                                          ),
                                        ],
                                      ),
                                      if (_notesExpanded) ...[
                                        const SizedBox(height: AppSpace.s8),
                                        SelectableText(
                                          plan.description,
                                          style: TextStyle(
                                            color: g.inkSecondary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: AppSpace.s12),
                            // Segmented Filter Tabs
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: g.fill,
                                borderRadius: AppGeometry.roundedr12,
                                border: Border.all(color: g.edge),
                              ),
                              child: Row(
                                children: [
                                  for (final f in ['All', 'Remaining', 'Done'])
                                    Expanded(
                                      child: AppTapArea(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() => _filter = f);
                                        },
                                        borderRadius: AppGeometry.roundedr8,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 180,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppSpace.s8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _filter == f
                                                ? g.clay
                                                : Colors.transparent,
                                            borderRadius: AppGeometry.roundedr8,
                                          ),
                                          alignment: Alignment.center,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              // A count appears only when above zero.
                                              f == 'All'
                                                  ? (plan.total > 0
                                                        ? 'All (${plan.total})'
                                                        : 'All')
                                                  : f == 'Remaining'
                                                  ? (plan.remaining > 0
                                                        ? 'Remaining (${plan.remaining})'
                                                        : 'Remaining')
                                                  : (plan.done > 0
                                                        ? 'Done (${plan.done})'
                                                        : 'Done'),
                                              style: TextStyle(
                                                color: _filter == f
                                                    ? Colors.white
                                                    : g.inkSecondary,
                                                fontWeight: _filter == f
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Contextual Action Buttons
                            if ((items.value?.any(
                                      (i) => !i.done && i.at == null,
                                    ) ??
                                    false) ||
                                plan.pendingAlerts > 0) ...[
                              const SizedBox(height: AppSpace.s10),
                              Wrap(
                                spacing: AppSpace.s8,
                                runSpacing: AppSpace.s8,
                                children: [
                                  if (items.value?.any(
                                        (i) => !i.done && i.at == null,
                                      ) ??
                                      false)
                                    OutlinedButton.icon(
                                      onPressed: _busy ||
                                              plan.status != 'active'
                                          ? null
                                          : () => showPlanCollectionEditor(
                                              context,
                                              collectionId: plan.id,
                                              scheduling: items.value!
                                                  .where(
                                                    (i) =>
                                                        !i.done && i.at == null,
                                                  )
                                                  .toList(),
                                            ),
                                      icon: const Icon(
                                        Icons.schedule_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Schedule remaining'),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: g.clay.withValues(alpha: 0.5),
                                        ),
                                        foregroundColor: g.clay,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpace.s12,
                                          vertical: AppSpace.s8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: AppGeometry.roundedr12,
                                        ),
                                      ),
                                    ),
                                  if (plan.pendingAlerts > 0)
                                    OutlinedButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _planAction(plan, 'retry'),
                                      icon: const Icon(
                                        Icons.sync_problem_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Retry alerts'),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: context.stateWarning
                                              .withValues(alpha: 0.5),
                                        ),
                                        foregroundColor: context.stateWarning,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpace.s12,
                                          vertical: AppSpace.s8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: AppGeometry.roundedr12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                            if (plan.status != 'active') ...[
                              const SizedBox(height: AppSpace.s8),
                              Container(
                                padding: const EdgeInsets.all(AppSpace.s8),
                                decoration: BoxDecoration(
                                  color: context.stateWarning
                                      .withValues(alpha: 0.12),
                                  borderRadius: AppGeometry.roundedr8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.pause_circle_outline_rounded,
                                      size: 16,
                                      color: context.stateWarning,
                                    ),
                                    const SizedBox(width: AppSpace.s8),
                                    Expanded(
                                      child: Text(
                                        'This plan is ${plan.status}. Future alerts are stopped.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.stateWarning,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: AppSpace.s8),
                              Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpace.s12),
                    ),
                    items.when(
                      loading: () => const SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpace.s24),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ),
                      error: (e, _) => SliverToBoxAdapter(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.s24),
                            child: Text('Could not load items: $e'),
                          ),
                        ),
                      ),
                      data: (all) {
                        final shown = all
                            .where(
                              (i) =>
                                  _filter == 'All' ||
                                  (_filter == 'Done'
                                      ? i.done
                                      : !i.done && !i.skipped),
                            )
                            .toList();
                        if (shown.isEmpty) {
                          return SliverToBoxAdapter(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpace.s32),
                                child: Text(
                                  'No items in this view.',
                                  style: TextStyle(color: g.inkMuted),
                                ),
                              ),
                            ),
                          );
                        }
                        return SliverList.builder(
                          itemCount: shown.length,
                          itemBuilder: (context, n) {
                            final item = shown[n];
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s16,
                                vertical: AppSpace.s4,
                              ),
                              child: Card(
                                elevation: 0,
                                color: g.fill,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppGeometry.roundedr16,
                                  side: BorderSide(color: g.edge),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s8,
                                    vertical: AppSpace.s6,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 44,
                                        height: 44,
                                        child: Checkbox(
                                          value: item.done,
                                          activeColor: g.clay,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          onChanged: _busy ||
                                                  item.done ||
                                                  plan.status != 'active'
                                              ? null
                                              : (v) => _run(
                                                  () => ref
                                                      .read(
                                                        planCollectionServiceProvider,
                                                      )
                                                      .complete(item, true),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpace.s4),
                                      Expanded(
                                        child: InkWell(
                                          borderRadius: AppGeometry.roundedr12,
                                          onTap: (item.done &&
                                                      !item.recurring) ||
                                                  _busy
                                              ? null
                                              : () => _action(
                                                  item,
                                                  'edit',
                                                  all,
                                                ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: AppSpace.s8,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: item.done
                                                            ? g.inkMuted
                                                            : g.ink,
                                                        decoration: item.done
                                                            ? TextDecoration
                                                                .lineThrough
                                                            : null,
                                                      ),
                                                ),
                                                const SizedBox(
                                                  height: AppSpace.s4,
                                                ),
                                                Wrap(
                                                  spacing: AppSpace.s6,
                                                  runSpacing: AppSpace.s4,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: [
                                                    if (item.done)
                                                      _buildItemTag(
                                                        icon: Icons
                                                            .check_circle_outline_rounded,
                                                        label: 'Completed',
                                                        color: g.clay,
                                                      )
                                                    else if (item.skipped)
                                                      _buildItemTag(
                                                        icon: Icons
                                                            .skip_next_rounded,
                                                        label: 'Skipped',
                                                        color: g.inkMuted,
                                                      )
                                                    else if (item.at == null)
                                                      _buildItemTag(
                                                        icon: Icons
                                                            .hourglass_empty_rounded,
                                                        label: 'Not scheduled',
                                                        color: g.inkMuted,
                                                      )
                                                    else
                                                      _buildItemTag(
                                                        icon: Icons
                                                            .access_time_rounded,
                                                        label: DateFormat(
                                                          'EEE, d MMM · h:mm a',
                                                        ).format(item.at!),
                                                        color: g.inkSecondary,
                                                      ),
                                                    if (item.at != null &&
                                                        !item.done) ...[
                                                      if (item.alert != 'none')
                                                        _buildItemTag(
                                                          icon: item.alert ==
                                                                  'alarm'
                                                              ? Icons
                                                                  .alarm_rounded
                                                              : Icons
                                                                  .notifications_active_rounded,
                                                          label: item.alert,
                                                          color: g.clay,
                                                        ),
                                                      if (item.recurring)
                                                        _buildItemTag(
                                                          icon: Icons
                                                              .repeat_rounded,
                                                          label:
                                                              item.recurrence,
                                                          color: g.inkSecondary,
                                                        ),
                                                      if (item.alertPending)
                                                        _buildItemTag(
                                                          icon: Icons
                                                              .warning_amber_rounded,
                                                          label:
                                                              'Alert pending',
                                                          color: context
                                                              .stateWarning,
                                                        ),
                                                    ],
                                                    if (item.minutes != null)
                                                      _buildItemTag(
                                                        icon: Icons
                                                            .timer_outlined,
                                                        label:
                                                            '${item.minutes}m focus',
                                                        color: g.clay,
                                                      ),
                                                  ],
                                                ),
                                                if (item.notes.isNotEmpty) ...[
                                                  const SizedBox(
                                                    height: AppSpace.s6,
                                                  ),
                                                  Text(
                                                    item.notes,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: g.inkMuted,
                                                      height: 1.3,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert_rounded,
                                          color: g.inkMuted,
                                          size: 20,
                                        ),
                                        tooltip: 'Item options',
                                        enabled: !_busy,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: AppGeometry.roundedr16,
                                        ),
                                        onSelected: (a) =>
                                            _action(item, a, all),
                                        itemBuilder: (_) => [
                                          if (item.definitionId != null)
                                            const PopupMenuItem(
                                              value: 'history',
                                              child: Text('Session history'),
                                            ),
                                          if (item.minutes != null &&
                                              !item.done &&
                                              plan.status == 'active')
                                            const PopupMenuItem(
                                              value: 'focus',
                                              child:
                                                  Text('Start / resume focus'),
                                            ),
                                          if (item.occurrenceId != null &&
                                              !item.done &&
                                              plan.status == 'active')
                                            const PopupMenuItem(
                                              value: 'skip',
                                              child: Text('Skip this session'),
                                            ),
                                          if (!item.done || item.recurring)
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit details'),
                                            ),
                                          const PopupMenuItem(
                                            value: 'duplicate',
                                            child: Text(
                                              'Duplicate without schedule',
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'move',
                                            child: Text('Move to another plan'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'up',
                                            child: Text('Move up'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete item'),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16,
                    vertical: AppSpace.s12,
                  ),
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: g.clay,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr16,
                        ),
                        elevation: 0,
                      ),
                      onPressed: _busy || plan.status != 'active'
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              showPlanCollectionEditor(
                                context,
                                collectionId: plan.id,
                              );
                            },
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'Add items',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

