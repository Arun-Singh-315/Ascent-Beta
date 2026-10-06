import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/insight_engine/series_engine.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/undo_snackbar.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/settings_provider.dart';

class TaskBoardScreen extends ConsumerStatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  ConsumerState<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends ConsumerState<TaskBoardScreen> {
  String _priorityFilter = 'All';

  void _openAddTaskSheet(
    BuildContext context, {
    int? parentTaskId,
    int? prefilledApplicationId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddTaskSheet(
        parentTaskId: parentTaskId,
        prefilledApplicationId: prefilledApplicationId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskDao = ref.watch(taskDaoProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        title: Text(
          'Tasks & Today',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        backgroundColor: context.bgBase,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list_rounded,
              color: _priorityFilter != 'All' ? context.accentPrimary : context.textPrimary,
            ),
            tooltip: 'Filter by priority',
            initialValue: _priorityFilter,
            onSelected: (val) => setState(() => _priorityFilter = val),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Priorities')),
              const PopupMenuItem(value: 'high', child: Text('High Priority')),
              const PopupMenuItem(value: 'medium', child: Text('Medium Priority')),
              const PopupMenuItem(value: 'low', child: Text('Low Priority')),
            ],
          ),
        ],
      ),
      floatingActionButton: AscentButton.fab(
        icon: Icons.add_rounded,
        onPressed: () => _openAddTaskSheet(context),
      ),
      body: StreamBuilder<List<Task>>(
        stream: taskDao.watchAllTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SkeletonShimmer(height: 72),
                  const SizedBox(height: 12),
                  SkeletonShimmer(height: 72),
                  const SizedBox(height: 12),
                  SkeletonShimmer(height: 72),
                ],
              ),
            );
          }

          final allTasks = snapshot.data ?? [];
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // §7: Partition tasks into top-level and sub-tasks
          final subTasksByParent = <int, List<Task>>{};
          final topLevelTasks = <Task>[];

          for (final t in allTasks) {
            if (t.parentTaskId != null) {
              subTasksByParent.putIfAbsent(t.parentTaskId!, () => []).add(t);
            } else {
              topLevelTasks.add(t);
            }
          }

          final overdueTasks = <Task>[];
          final todayTasks = <Task>[];
          final upcomingTasks = <Task>[];
          final completedTasks = <Task>[];

          for (final t in topLevelTasks) {
            if (_priorityFilter != 'All' &&
                t.priority.toLowerCase() != _priorityFilter.toLowerCase()) {
              continue;
            }

            if (t.actualCompletedDate != null) {
              completedTasks.add(t);
              continue;
            }

            if (t.plannedDate == null) {
              todayTasks.add(t);
              continue;
            }

            final plannedDay = DateTime(t.plannedDate!.year, t.plannedDate!.month, t.plannedDate!.day);
            if (plannedDay.isBefore(today)) {
              overdueTasks.add(t);
            } else if (plannedDay.isAtSameMomentAs(today)) {
              todayTasks.add(t);
            } else {
              upcomingTasks.add(t);
            }
          }

          final hasActiveTasks = overdueTasks.isNotEmpty || todayTasks.isNotEmpty || upcomingTasks.isNotEmpty;

          // §7: Clean empty state for new users
          if (!hasActiveTasks && completedTasks.isEmpty) {
            return EmptyState(
              icon: Icons.landscape_rounded,
              title: 'Your slate is clean',
              subtitle: 'Add your first prep task for today, or link one to an active application.',
              actionLabel: 'Add Task',
              onAction: () => _openAddTaskSheet(context),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
            children: [
              // JARVIS Task Orchestrator & Priority Coach
              _JarvisTaskCoachCard(
                overdueCount: overdueTasks.length,
                todayCount: todayTasks.length,
                completedCount: completedTasks.length,
              ),

              // Overdue Group
              if (overdueTasks.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Overdue',
                  count: overdueTasks.length,
                  color: context.stateDanger,
                ),
                const SizedBox(height: 8),
                ...overdueTasks.map((t) => _TaskItemTile(
                      task: t,
                      subTasks: subTasksByParent[t.id] ?? [],
                      onAddSubTask: () => _openAddTaskSheet(context, parentTaskId: t.id),
                    )),
                const SizedBox(height: 18),
              ],

              // Today Group
              _SectionHeader(
                title: 'Today',
                count: todayTasks.length,
                color: context.accentPrimary,
              ),
              const SizedBox(height: 8),
              if (todayTasks.isEmpty)
                AscentCard(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  color: context.bgSurfaceElevated,
                  child: Text(
                    'No tasks scheduled for today. Great time to catch up or relax!',
                    style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                  ),
                )
              else
                ...todayTasks.map((t) => _TaskItemTile(
                      task: t,
                      subTasks: subTasksByParent[t.id] ?? [],
                      onAddSubTask: () => _openAddTaskSheet(context, parentTaskId: t.id),
                    )),

              const SizedBox(height: 18),

              // Upcoming Group
              if (upcomingTasks.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Upcoming',
                  count: upcomingTasks.length,
                  color: context.accentInfo,
                ),
                const SizedBox(height: 8),
                ...upcomingTasks.map((t) => _TaskItemTile(
                      task: t,
                      subTasks: subTasksByParent[t.id] ?? [],
                      onAddSubTask: () => _openAddTaskSheet(context, parentTaskId: t.id),
                    )),
                const SizedBox(height: 18),
              ],

              // Completed Group (Collapsed/subtle)
              if (completedTasks.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Completed Recently',
                  count: completedTasks.length,
                  color: context.textMuted,
                ),
                const SizedBox(height: 8),
                ...completedTasks.take(5).map((t) => _TaskItemTile(
                      task: t,
                      subTasks: subTasksByParent[t.id] ?? [],
                      isCompletedView: true,
                      onAddSubTask: () => _openAddTaskSheet(context, parentTaskId: t.id),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AscentTextStyles.displaySmall.copyWith(
            fontSize: 16,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: AscentTextStyles.statSmall.copyWith(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskItemTile extends ConsumerWidget {
  final Task task;
  final List<Task> subTasks;
  final bool isCompletedView;
  final VoidCallback onAddSubTask;

  const _TaskItemTile({
    required this.task,
    this.subTasks = const [],
    this.isCompletedView = false,
    required this.onAddSubTask,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = task.actualCompletedDate != null;

    final status = SeriesEngine.computeTaskStatus(
      plannedDate: task.plannedDate,
      actualCompletedDate: task.actualCompletedDate,
    );

    final completedSubTasks =
        subTasks.where((s) => s.actualCompletedDate != null).length;

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: isCompletedView
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      // Swipe Right: Complete
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: context.accentPrimary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.check_circle_rounded, color: context.accentPrimary, size: 28),
      ),
      // Swipe Left: Delete
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: context.stateDanger.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline_rounded, color: context.stateDanger, size: 28),
      ),
      confirmDismiss: (direction) async {
        final taskDao = ref.read(taskDaoProvider);

        if (direction == DismissDirection.startToEnd) {
          await taskDao.markComplete(task.id);
          if (context.mounted) {
            showUndoSnackbar(
              context,
              message: 'Task marked complete!',
              onUndo: () async {
                await taskDao.updateTask(
                  TaskTableCompanion(
                    id: drift.Value(task.id),
                    actualCompletedDate: const drift.Value(null),
                  ),
                );
              },
            );
          }
          return false;
        } else {
          final confirmed = await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: context.bgSurface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Delete Task?',
                      style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${task.title}" will be removed.',
                      textAlign: TextAlign.center,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: AscentButton.outlined(
                            label: 'Cancel',
                            compact: true,
                            onPressed: () => Navigator.pop(ctx, false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AscentButton.destructive(
                            label: 'Delete',
                            onPressed: () => Navigator.pop(ctx, true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );

          if (confirmed != true) return false;

          await taskDao.deleteTask(task.id);
          if (context.mounted) {
            showUndoSnackbar(
              context,
              message: 'Task deleted',
              onUndo: () async {
                await taskDao.insertTask(
                  TaskTableCompanion.insert(
                    title: task.title,
                    notes: drift.Value(task.notes),
                    plannedDate: drift.Value(task.plannedDate),
                    priority: drift.Value(task.priority),
                    seriesId: drift.Value(task.seriesId),
                    linkedPhaseId: drift.Value(task.linkedPhaseId),
                    parentTaskId: drift.Value(task.parentTaskId),
                    linkedApplicationId: drift.Value(task.linkedApplicationId),
                  ),
                );
              },
            );
          }
          return true;
        }
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AscentCard(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: context.bgSurface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              builder: (ctx) => AddTaskSheet(existingTask: task),
            );
          },
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Checkbox button
                  InkWell(
                    onTap: () async {
                      final taskDao = ref.read(taskDaoProvider);
                      if (isDone) {
                        await taskDao.updateTask(
                          TaskTableCompanion(
                            id: drift.Value(task.id),
                            actualCompletedDate: const drift.Value(null),
                          ),
                        );
                      } else {
                        await taskDao.markComplete(task.id);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDone ? context.accentPrimary : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone ? context.accentPrimary : context.divider,
                          width: 1.8,
                        ),
                      ),
                      child: isDone
                          ? Icon(Icons.check_rounded, size: 18, color: context.textOnPrimary)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: AscentTextStyles.bodyMedium.copyWith(
                                  color: isDone ? context.textMuted : context.textPrimary,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (subTasks.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: context.accentPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$completedSubTasks/${subTasks.length} sub-tasks',
                                  style: AscentTextStyles.captionMedium.copyWith(
                                    color: context.accentPrimaryBright,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (task.notes != null && task.notes!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            task.notes!,
                            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (task.plannedDate != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 13,
                                color: status == TaskComputedStatus.lagging
                                    ? context.stateDanger
                                    : context.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('MMM d').format(task.plannedDate!),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: status == TaskComputedStatus.lagging
                                      ? context.stateDanger
                                      : context.textMuted,
                                  fontWeight: status == TaskComputedStatus.lagging
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                              if (task.priority == 'high') ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: context.stateDanger,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'High',
                                  style: TextStyle(fontSize: 11, color: context.stateDanger),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              // §7: Sub-entries rendered as an indented checklist
              if (subTasks.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: context.divider.withValues(alpha: 0.5), height: 1),
                const SizedBox(height: 6),
                ...subTasks.map((sub) {
                  final isSubDone = sub.actualCompletedDate != null;
                  return Padding(
                    padding: const EdgeInsets.only(left: 36, top: 4, bottom: 4),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            final dao = ref.read(taskDaoProvider);
                            if (isSubDone) {
                              await dao.updateTask(TaskTableCompanion(
                                id: drift.Value(sub.id),
                                actualCompletedDate: const drift.Value(null),
                              ));
                            } else {
                              await dao.markComplete(sub.id);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSubDone ? context.accentPrimary : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSubDone ? context.accentPrimary : context.divider,
                                width: 1.5,
                              ),
                            ),
                            child: isSubDone
                                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sub.title,
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: isSubDone ? context.textMuted : context.textPrimary,
                              decoration: isSubDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              // Inline "Add sub-task" button on parent card
              if (!isCompletedView) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 36, top: 6),
                  child: InkWell(
                    onTap: onAddSubTask,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: context.accentPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Add sub-task',
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: context.accentPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Task Bottom Sheet (§7 Simplified with 3 fields + optional Advanced)
// ---------------------------------------------------------------------------

class AddTaskSheet extends ConsumerStatefulWidget {
  final Task? existingTask;
  final int? parentTaskId;
  final int? prefilledApplicationId;
  final String? initialTitle;

  const AddTaskSheet({
    super.key,
    this.existingTask,
    this.parentTaskId,
    this.prefilledApplicationId,
    this.initialTitle,
  });

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _priority = 'medium';
  int? _selectedApplicationId;
  int? _selectedSeriesId;
  int? _selectedPhaseId;
  bool _startSessionNow = false;

  @override
  void initState() {
    super.initState();
    _selectedApplicationId = widget.prefilledApplicationId;
    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }

    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      _notesController.text = t.notes ?? '';
      _selectedDate = t.plannedDate ?? DateTime.now();
      _priority = t.priority;
      _selectedSeriesId = t.seriesId;
      _selectedPhaseId = t.linkedPhaseId;
      _selectedApplicationId = t.linkedApplicationId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  DateTime _getWeekend() {
    final now = DateTime.now();
    final daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
    return now.add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final appsAsync = ref.watch(applicationDaoProvider).watchAllApplications();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekend = _getWeekend();

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingTask != null
                      ? 'Edit Task'
                      : (widget.parentTaskId != null ? 'New Sub-Task' : 'New Task'),
                  style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 1. Title (Required, autofocus)
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: widget.parentTaskId != null
                    ? 'Sub-task description (e.g. Solve 2 LeetCode mediums)'
                    : 'What needs to be done? (e.g. Review System Design)',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 14),

            // 2. Planned Date (Defaults to today, quick chips)
            Text(
              'Planned Date: ${DateFormat('EEE, MMM d').format(_selectedDate)}',
              style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: _isSameDay(_selectedDate, today),
                  selectedColor: context.accentPrimary.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _selectedDate = today),
                ),
                ChoiceChip(
                  label: const Text('Tomorrow'),
                  selected: _isSameDay(_selectedDate, tomorrow),
                  selectedColor: context.accentPrimary.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _selectedDate = tomorrow),
                ),
                ChoiceChip(
                  label: const Text('This Weekend'),
                  selected: _isSameDay(_selectedDate, weekend),
                  selectedColor: context.accentPrimary.withValues(alpha: 0.2),
                  onSelected: (_) => setState(() => _selectedDate = weekend),
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: const Text('Pick date'),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 7)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 3. Optional: Link to Application
            StreamBuilder<List<ApplicationRow>>(
              stream: appsAsync,
              builder: (context, snapshot) {
                final apps = snapshot.data ?? [];
                if (apps.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Link to Application (Optional)',
                      style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedApplicationId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: context.bgBase,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      hint: Text('None (General task)', style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted)),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None (General task)'),
                        ),
                        ...apps.map((a) => DropdownMenuItem<int?>(
                              value: a.id,
                              child: Text('${a.company} — ${a.role}', overflow: TextOverflow.ellipsis),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedApplicationId = val),
                    ),
                    const SizedBox(height: 14),
                  ],
                );
              },
            ),

            // Toggle: Start session for this task now
            if (widget.existingTask == null) ...[
              Container(
                decoration: BoxDecoration(
                  color: context.accentPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.accentPrimary.withValues(alpha: 0.2)),
                ),
                child: SwitchListTile(
                  title: Text(
                    'Start session for this task now',
                    style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                  ),
                  subtitle: Text(
                    'Immediately begins live focus tracking',
                    style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                  ),
                  value: _startSessionNow,
                  activeThumbColor: context.accentPrimary,
                  onChanged: (val) => setState(() => _startSessionNow = val),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Collapsible Advanced Options
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Advanced options',
                  style: AscentTextStyles.labelMedium.copyWith(color: context.textMuted),
                ),
                children: [
                  TextField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Notes or reference link (optional)',
                      hintStyle: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      filled: true,
                      fillColor: context.bgBase,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Priority:', style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted)),
                      const SizedBox(width: 12),
                      ...['low', 'medium', 'high'].map((p) {
                        final isSelected = _priority == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(p.toUpperCase()),
                            selected: isSelected,
                            selectedColor: p == 'high'
                                ? context.stateDanger.withValues(alpha: 0.2)
                                : context.accentPrimary.withValues(alpha: 0.2),
                            side: BorderSide(
                              color: isSelected ? context.accentPrimary : context.divider,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? context.textPrimary : context.textMuted,
                            ),
                            onSelected: (_) => setState(() => _priority = p),
                          ),
                        );
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: AscentButton.outlined(
                    label: 'Cancel',
                    compact: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentButton.primary(
                    label: widget.existingTask != null ? 'Save Changes' : 'Add Task',
                    compact: true,
                    onPressed: () async {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) return;

                      final taskDao = ref.read(taskDaoProvider);
                      if (widget.existingTask != null) {
                        await taskDao.updateTask(
                          TaskTableCompanion(
                            id: drift.Value(widget.existingTask!.id),
                            title: drift.Value(title),
                            notes: drift.Value(
                                _notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
                            plannedDate: drift.Value(_selectedDate),
                            priority: drift.Value(_priority),
                            seriesId: drift.Value(_selectedSeriesId),
                            linkedPhaseId: drift.Value(_selectedPhaseId),
                            linkedApplicationId: drift.Value(_selectedApplicationId),
                            lastInteractedAt: drift.Value(DateTime.now()),
                          ),
                        );
                      } else {
                        final newTaskId = await taskDao.insertTask(
                          TaskTableCompanion.insert(
                            title: title,
                            notes: drift.Value(
                                _notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
                            plannedDate: drift.Value(_selectedDate),
                            priority: drift.Value(_priority),
                            seriesId: drift.Value(_selectedSeriesId),
                            linkedPhaseId: drift.Value(_selectedPhaseId),
                            parentTaskId: drift.Value(widget.parentTaskId),
                            linkedApplicationId: drift.Value(_selectedApplicationId),
                            lastInteractedAt: drift.Value(DateTime.now()),
                          ),
                        );

                        if (_startSessionNow && context.mounted) {
                          await ref.read(timeTrackingProvider.notifier).startSession(
                            label: title,
                            categoryId: 1,
                            activityType: 'study',
                            linkedTaskId: newTaskId,
                          );
                        }
                      }

                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JarvisTaskCoachCard extends ConsumerWidget {
  final int overdueCount;
  final int todayCount;
  final int completedCount;

  const _JarvisTaskCoachCard({
    required this.overdueCount,
    required this.todayCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantName = ref.watch(assistantNameProvider);
    String message;
    if (overdueCount > 0) {
      message = 'Attention: You have $overdueCount overdue items. Let\'s resolve them first to restore momentum.';
    } else if (todayCount > 0) {
      message = 'All systems nominal. You have $todayCount priority items today. Ready when you are.';
    } else {
      message = 'Your slate is completely clear for today. You can plan new milestones or rest.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF0096C7).withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0096C7).withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                  ),
                ),
                child: const Icon(Icons.blur_on_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                '${assistantName.toUpperCase()} TASK ORCHESTRATOR',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: const Color(0xFF00B4D8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.push('/ai-assistant'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 12, color: context.accentPrimary),
                      const SizedBox(width: 4),
                      Text(
                        'Plan with AI',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: context.accentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AscentTextStyles.bodySmall.copyWith(
              color: context.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
