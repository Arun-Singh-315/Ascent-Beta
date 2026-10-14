import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/insight_engine/series_engine.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/undo_snackbar.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import 'package:go_router/go_router.dart';
import 'add_activity_sheet.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../study_plan/lecture_focus_player_sheet.dart';

enum _TaskBoardTab { today, others, completed }

class TaskBoardScreen extends ConsumerStatefulWidget {
  const TaskBoardScreen({super.key});

  @override
  ConsumerState<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends ConsumerState<TaskBoardScreen> {
  String _priorityFilter = 'All';
  _TaskBoardTab _selectedTab = _TaskBoardTab.today;

  void _openAddTaskSheet(
    BuildContext context, {
    int? parentTaskId,
    int? prefilledApplicationId,
  }) {
    AddActivitySheet.show(
      context,
      parentTaskId: parentTaskId,
      prefilledApplicationId: prefilledApplicationId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskDao = ref.watch(taskDaoProvider);

    final g = context.glass;

    return AscentScaffold(
      title: 'Tasks & Today',
      subtitle: 'Actionable to-dos & study tasks',
      actions: [
        PopupMenuButton<String>(
          icon: Icon(
            Icons.filter_list_rounded,
            color: _priorityFilter != 'All' ? g.clay : g.inkMuted,
          ),
          tooltip: 'Filter by priority',
          initialValue: _priorityFilter,
          onSelected: (val) => setState(() => _priorityFilter = val),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'All', child: Text('All Priorities')),
            const PopupMenuItem(value: 'high', child: Text('High Priority')),
            const PopupMenuItem(
              value: 'medium',
              child: Text('Medium Priority'),
            ),
            const PopupMenuItem(value: 'low', child: Text('Low Priority')),
          ],
        ),
      ],
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

            final plannedDay = DateTime(
              t.plannedDate!.year,
              t.plannedDate!.month,
              t.plannedDate!.day,
            );
            if (plannedDay.isBefore(today)) {
              overdueTasks.add(t);
            } else if (plannedDay.isAtSameMomentAs(today)) {
              todayTasks.add(t);
            } else {
              upcomingTasks.add(t);
            }
          }

          final hasActiveTasks =
              overdueTasks.isNotEmpty ||
              todayTasks.isNotEmpty ||
              upcomingTasks.isNotEmpty;

          // §7: Clean empty state for new users
          if (!hasActiveTasks && completedTasks.isEmpty) {
            return EmptyState(
              icon: Icons.landscape_rounded,
              title: 'Your slate is clean',
              subtitle:
                  'Add your first prep task for today, or link one to an active application.',
              actionLabel: 'Add Task',
              onAction: () => _openAddTaskSheet(context),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: g.fill,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: g.line, width: 1),
                  ),
                  child: Row(
                    children: [
                      _buildTabSegment(
                        'Today',
                        _TaskBoardTab.today,
                        todayTasks.length + overdueTasks.length,
                        g,
                      ),
                      _buildTabSegment(
                        'Others',
                        _TaskBoardTab.others,
                        upcomingTasks.length,
                        g,
                      ),
                      _buildTabSegment(
                        'Completed',
                        _TaskBoardTab.completed,
                        completedTasks.length,
                        g,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 90),
                  children: [
                    if (_selectedTab == _TaskBoardTab.today) ...[
                      // Overdue Group
                      if (overdueTasks.isNotEmpty) ...[
                        _SectionHeader(
                          title: 'Overdue',
                          count: overdueTasks.length,
                          color: context.stateDanger,
                        ),
                        const SizedBox(height: 8),
                        ...overdueTasks.map(
                          (t) => _TaskItemTile(
                            task: t,
                            subTasks: subTasksByParent[t.id] ?? [],
                            onAddSubTask: () =>
                                _openAddTaskSheet(context, parentTaskId: t.id),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Today Group
                      _SectionHeader(
                        title: 'Today',
                        count: todayTasks.length,
                        color: context.accentPrimary,
                      ),
                      const SizedBox(height: 8),
                      if (todayTasks.isEmpty && overdueTasks.isEmpty)
                        AscentCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          color: context.bgSurfaceElevated,
                          child: Text(
                            'No tasks scheduled for today. Great time to catch up or relax!',
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: context.textMuted,
                            ),
                          ),
                        )
                      else
                        ...todayTasks.map(
                          (t) => _TaskItemTile(
                            task: t,
                            subTasks: subTasksByParent[t.id] ?? [],
                            onAddSubTask: () =>
                                _openAddTaskSheet(context, parentTaskId: t.id),
                          ),
                        ),
                    ] else if (_selectedTab == _TaskBoardTab.others) ...[
                      // Upcoming Group
                      _SectionHeader(
                        title: 'Upcoming & Backlog',
                        count: upcomingTasks.length,
                        color: context.accentInfo,
                      ),
                      const SizedBox(height: 8),
                      if (upcomingTasks.isEmpty)
                        AscentCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          color: context.bgSurfaceElevated,
                          child: Text(
                            'No upcoming tasks in queue. Tap + to plan future tasks.',
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: context.textMuted,
                            ),
                          ),
                        )
                      else
                        ...upcomingTasks.map(
                          (t) => _TaskItemTile(
                            task: t,
                            subTasks: subTasksByParent[t.id] ?? [],
                            onAddSubTask: () =>
                                _openAddTaskSheet(context, parentTaskId: t.id),
                          ),
                        ),
                    ] else ...[
                      // Completed Group
                      _SectionHeader(
                        title: 'Completed',
                        count: completedTasks.length,
                        color: context.textMuted,
                      ),
                      const SizedBox(height: 8),
                      if (completedTasks.isEmpty)
                        AscentCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          color: context.bgSurfaceElevated,
                          child: Text(
                            'No completed tasks yet. Finish a task to see it here!',
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: context.textMuted,
                            ),
                          ),
                        )
                      else
                        ...completedTasks.map(
                          (t) => _TaskItemTile(
                            task: t,
                            subTasks: subTasksByParent[t.id] ?? [],
                            isCompletedView: true,
                            onAddSubTask: () =>
                                _openAddTaskSheet(context, parentTaskId: t.id),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabSegment(
    String label,
    _TaskBoardTab tab,
    int count,
    AscentGlass g,
  ) {
    final isSelected = _selectedTab == tab;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTab = tab);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? g.clay : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : g.inkMuted,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : g.claySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : g.clay,
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
    if (task.learningCourseId != null && task.learningLectureId != null) {
      final hub = ref.watch(learningHubProvider);
      final course = hub.courses
          .where((c) => c.id == task.learningCourseId)
          .firstOrNull;
      final lecture = course?.modules
          .expand((m) => m.lectures)
          .where((l) => l.id == task.learningLectureId)
          .firstOrNull;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AscentCard(
          onTap: lecture == null
              ? null
              : () async {
                  HapticFeedback.selectionClick();
                  final notifier = ref.read(learningHubProvider.notifier);
                  await notifier.ready;
                  if (ref.read(learningHubProvider).activeCourseId !=
                      course!.id) {
                    notifier.switchCourse(course.id);
                  }
                  notifier.selectLecture(lecture.id, autoPlay: false);
                  if (context.mounted) LectureFocusPlayerSheet.show(context);
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lecture?.title ?? task.title,
                style: AscentTextStyles.homeHeadline.copyWith(
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lecture == null
                    ? 'Linked lecture unavailable. Open Learning to review.'
                    : 'Lecture · ${course!.title} · ${lecture.isCompleted ? 'Completed' : '${lecture.studyProgressPercent}% study time · ${lecture.completionThresholdPercent}% required'}',
                style: AscentTextStyles.bodySmall.copyWith(
                  color: context.textSecondary,
                ),
              ),
              if (lecture != null)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Open lecture'),
                ),
            ],
          ),
        ),
      );
    }
    final isDone = task.actualCompletedDate != null;
    final isTimeBound =
        task.estimatedMinutes != null && task.estimatedMinutes! > 0;

    final status = SeriesEngine.computeTaskStatus(
      plannedDate: task.plannedDate,
      actualCompletedDate: task.actualCompletedDate,
    );

    final reminders = ref.watch(allRemindersProvider).value ?? [];
    final hasReminder = reminders.any(
      (r) =>
          r.isActive &&
          (r.linkedTaskId == task.id ||
              (r.linkedTaskId == null &&
                  r.title.trim().toLowerCase() ==
                      task.title.trim().toLowerCase())),
    );

    final completedSubTasks = subTasks
        .where((s) => s.actualCompletedDate != null)
        .length;

    return Dismissible(
      key: ValueKey('task_${task.id}'),
      direction: (isCompletedView || isDone)
          ? DismissDirection.none
          : (isTimeBound
                ? DismissDirection.endToStart
                : DismissDirection.horizontal),
      // Swipe Right: Complete
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        decoration: BoxDecoration(
          color: context.accentPrimary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.check_circle_rounded,
          color: context.accentPrimary,
          size: 28,
        ),
      ),
      // Swipe Left: Delete
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: context.stateDanger.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          Icons.delete_outline_rounded,
          color: context.stateDanger,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        final taskDao = ref.read(taskDaoProvider);

        if (direction == DismissDirection.startToEnd) {
          final completed = await taskDao.markComplete(task.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  completed
                      ? 'Task marked complete!'
                      : 'Timed activities complete after their focus target is reached.',
                ),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
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
                      style: AscentTextStyles.displaySmall.copyWith(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"${task.title}" will be removed.',
                      textAlign: TextAlign.center,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: context.textMuted,
                      ),
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

          final visibility = ref.read(
            dismissedTodayActivityIdsProvider.notifier,
          );
          await deleteTaskAndCleanCascade(ref, task.id, taskTitle: task.title);
          if (context.mounted) {
            showUndoSnackbar(
              context,
              message: 'Task deleted',
              onUndo: () async {
                bool restored = false;
                try {
                  restored = await taskDao.restoreDeletedTask(task.id);
                  if (!restored) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'This undo is no longer available. Newer records were kept.',
                          ),
                        ),
                      );
                    }
                    return;
                  }
                  await visibility.unDismissActivityId('task_${task.id}');
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          restored
                              ? 'Task restored. Its visibility could not be refreshed.'
                              : 'Could not restore the task.',
                        ),
                      ),
                    );
                  }
                }
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
            HapticFeedback.lightImpact();
            _showTaskDetailDialog(context, ref, task, subTasks);
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
                      if (isDone) {
                        // Once completed, it cannot be undone or brought back to active (one way only).
                        return;
                      }
                      if (isTimeBound) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Timed activities complete after their focus target is reached.',
                            ),
                          ),
                        );
                        return;
                      }
                      final taskDao = ref.read(taskDaoProvider);
                      await taskDao.markComplete(task.id);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: isDone
                            ? context.accentPrimary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? context.accentPrimary
                              : context.divider,
                          width: 1.8,
                        ),
                      ),
                      child: isDone
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: context.textOnPrimary,
                            )
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
                                  color: isDone
                                      ? context.textMuted
                                      : context.textPrimary,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (subTasks.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.accentPrimary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$completedSubTasks/${subTasks.length} sub-tasks',
                                  style: AscentTextStyles.captionMedium
                                      .copyWith(
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
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: context.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (task.plannedDate != null || isDone) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (task.plannedDate != null) ...[
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
                                    fontWeight:
                                        status == TaskComputedStatus.lagging
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ],
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.stateDanger,
                                  ),
                                ),
                              ],
                              if (hasReminder) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.alarm_rounded,
                                  size: 13,
                                  color: isDone
                                      ? context.textMuted
                                      : context.accentPrimary,
                                ),
                              ],
                              if (isDone) ...[
                                if (task.plannedDate != null)
                                  const SizedBox(width: 8),
                                Text(
                                  task.actualCompletedDate != null
                                      ? '✓ Done ${DateFormat('h:mm a').format(task.actualCompletedDate!)}'
                                      : '✓ Completed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.accentPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!isDone &&
                      task.estimatedMinutes != null &&
                      task.estimatedMinutes! > 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                        await ref
                            .read(timeTrackingProvider.notifier)
                            .switchToTask(
                              title: task.title,
                              taskId: task.id,
                              sourceType: 'task',
                              autoStart: true,
                            );
                        if (context.mounted) {
                          context.push('/focus');
                        }
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.accentPrimary.withValues(alpha: 0.12),
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: context.accentPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                  if (!isDone) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Edit task',
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: context.textMuted,
                      ),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        AddActivitySheet.show(context, existingTask: task);
                      },
                    ),
                  ],
                ],
              ),
              // §7: Sub-entries rendered as an indented checklist
              if (subTasks.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(
                  color: context.divider.withValues(alpha: 0.5),
                  height: 1,
                ),
                const SizedBox(height: 6),
                ...subTasks.map((sub) {
                  if (sub.learningCourseId != null &&
                      sub.learningLectureId != null) {
                    return _TaskItemTile(task: sub, onAddSubTask: () {});
                  }
                  final isSubDone = sub.actualCompletedDate != null;
                  return Padding(
                    padding: const EdgeInsets.only(left: 36, top: 4, bottom: 4),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () async {
                            final dao = ref.read(taskDaoProvider);
                            if (isSubDone) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Completed tasks stay sealed.'),
                                ),
                              );
                            } else {
                              final completed = await dao.markComplete(sub.id);
                              if (!completed && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Timed activities complete after their focus target is reached.',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSubDone
                                  ? context.accentPrimary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSubDone
                                    ? context.accentPrimary
                                    : context.divider,
                                width: 1.5,
                              ),
                            ),
                            child: isSubDone
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sub.title,
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: isSubDone
                                  ? context.textMuted
                                  : context.textPrimary,
                              decoration: isSubDone
                                  ? TextDecoration.lineThrough
                                  : null,
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
                        Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: context.accentPrimary,
                        ),
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

  void _showTaskDetailDialog(
    BuildContext context,
    WidgetRef ref,
    Task task,
    List<Task> subTasks,
  ) {
    final isTimeBound =
        task.estimatedMinutes != null && task.estimatedMinutes! > 0;
    final isDone = task.actualCompletedDate != null;
    final g = context.glass;
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: ctx.bgSurfaceElevated,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: g.line, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: g.claySoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.priority.toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: g.clay,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!isDone)
                      IconButton(
                        tooltip: 'Edit task',
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: g.inkMuted,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          AddActivitySheet.show(context, existingTask: task);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  task.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: g.ink,
                    height: 1.35,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (task.notes != null && task.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    task.notes!,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: g.inkMuted,
                      height: 1.4,
                    ),
                  ),
                ],
                if (task.plannedDate != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: g.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('EEEE, MMM d, y').format(task.plannedDate!),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: g.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: g.inkMuted,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    if (!isDone && isTimeBound)
                      FilledButton.icon(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await ref
                              .read(timeTrackingProvider.notifier)
                              .switchToTask(
                                title: task.title,
                                taskId: task.id,
                                sourceType: 'task',
                                autoStart: true,
                              );
                          if (context.mounted) context.push('/focus');
                        },
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Open timer'),
                      )
                    else if (!isDone)
                      FilledButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final completed = await ref
                              .read(taskDaoProvider)
                              .markComplete(task.id);
                          if (completed) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                          } else if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Timed activities complete after their focus target is reached.',
                                ),
                              ),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: g.clay,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Mark Done'),
                      )
                    else
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: FilledButton.styleFrom(
                          backgroundColor: g.claySoft,
                          foregroundColor: g.clay,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Done'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
