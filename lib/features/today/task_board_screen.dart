import 'package:drift/drift.dart' show Value;
import '../../shared/widgets/ascent_star_button.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/utils/action_text.dart';
import 'add_lecture_activity_sheet.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
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
  const TaskBoardScreen({super.key, this.initialTaskId});
  final int? initialTaskId;

  @override
  ConsumerState<TaskBoardScreen> createState() => _TaskBoardScreenState();
}

class _TaskBoardScreenState extends ConsumerState<TaskBoardScreen> {
  String _priorityFilter = 'All';
  _TaskBoardTab _selectedTab = _TaskBoardTab.today;

  @override
  void initState() {
    super.initState();
    _scheduleTarget();
  }

  @override
  void didUpdateWidget(covariant TaskBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTaskId != widget.initialTaskId) _scheduleTarget();
  }

  void _scheduleTarget() {
    final id = widget.initialTaskId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final db = ref.read(databaseProvider);
      final task = await db.taskDao.getTaskById(id);
      if (!mounted || widget.initialTaskId != id) return;
      if (task == null) {
        AscentSnackBar.error(
          context,
          message: 'This task is no longer available.',
        );
        return;
      }
      final children = await (db.select(
        db.taskTable,
      )..where((t) => t.parentTaskId.equals(id))).get();
      if (mounted && widget.initialTaskId == id) {
        _TaskItemTile._showTaskDetailDialog(context, ref, task, children);
      }
    });
  }

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
          tooltip: 'Filter starred activities',
          initialValue: _priorityFilter,
          onSelected: (val) => setState(() => _priorityFilter = val),
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'All', child: Text('All activities')),
            const PopupMenuItem(value: 'starred', child: Text('Starred')),
            const PopupMenuItem(value: 'unstarred', child: Text('Unstarred')),
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
              padding: const EdgeInsets.all(AppSpace.s20),
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
                ((_priorityFilter == 'starred') != (t.priority == 'high'))) {
              continue;
            }

            if (t.actualCompletedDate != null) {
              completedTasks.add(t);
              continue;
            }

            if (t.plannedDate == null) {
              upcomingTasks.add(t);
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
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s18,
                  AppSpace.s8,
                  AppSpace.s18,
                  AppSpace.s12,
                ),
                child: AscentSegmentedControl<_TaskBoardTab>(
                  segments: const [
                    AscentSegment(value: _TaskBoardTab.today, label: 'Today'),
                    AscentSegment(value: _TaskBoardTab.others, label: 'Others'),
                    AscentSegment(
                      value: _TaskBoardTab.completed,
                      label: 'Completed',
                    ),
                  ],
                  selected: _selectedTab,
                  onChanged: (value) => setState(() => _selectedTab = value),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.s18,
                    AppSpace.s0,
                    AppSpace.s18,
                    AppSpace.s90,
                  ),
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
                            horizontal: AppSpace.s16,
                            vertical: AppSpace.s14,
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
                            horizontal: AppSpace.s16,
                            vertical: AppSpace.s14,
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
                            horizontal: AppSpace.s16,
                            vertical: AppSpace.s14,
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
          style: AscentTextStyles.displaySmall
              .copyWith(color: context.textPrimary)
              .merge(AppTypeRoles.typeRole10),
        ),
        const SizedBox(width: 8),
        AppTag(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s7,
            vertical: AppSpace.s2,
          ),
          nightDecoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: AppGeometry.roundedr10,
          ),
          child: Text(
            '$count',
            style: AscentTextStyles.statSmall
                .copyWith(color: color)
                .merge(AppTypeRoles.typeRole14),
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
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
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
                  padding: EdgeInsets.only(top: AppSpace.s8),
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
    final matchingReminder = reminders
        .where(
          (r) =>
              r.isActive &&
              (r.linkedTaskId == task.id ||
                  (r.linkedTaskId == null &&
                      r.title.trim().toLowerCase() ==
                          task.title.trim().toLowerCase())),
        )
        .firstOrNull;
    final hasReminder = matchingReminder != null;
    DateTime? scheduledTime;
    if (matchingReminder != null) {
      scheduledTime = matchingReminder.scheduledAt;
    } else if (task.plannedDate != null &&
        (task.plannedDate!.hour != 0 || task.plannedDate!.minute != 0)) {
      scheduledTime = task.plannedDate;
    }
    final isScheduledInFuture =
        !isDone &&
        scheduledTime != null &&
        DateTime.now().isBefore(scheduledTime);

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
      background: AppCard(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpace.s20),
        nightDecoration: BoxDecoration(
          color: context.accentPrimary.withValues(alpha: 0.2),
          borderRadius: AppGeometry.roundedr16,
        ),
        child: Icon(
          Icons.check_circle_rounded,
          color: context.accentPrimary,
          size: 28,
        ),
      ),
      // Swipe Left: Delete
      secondaryBackground: AppCard(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.s20),
        nightDecoration: BoxDecoration(
          color: context.stateDanger.withValues(alpha: 0.2),
          borderRadius: AppGeometry.roundedr16,
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
          if (isScheduledInFuture) {
            final timeStr = DateFormat('h:mm a').format(scheduledTime!);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Scheduled for $timeStr. You can complete it once that time arrives.',
                  ),
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            return false;
          }
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
              borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr20),
            ),
            builder: (ctx) => SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s20),
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
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: AscentCard(
          onTap: () {
            HapticFeedback.lightImpact();
            _showTaskDetailDialog(context, ref, task, subTasks);
          },
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s14,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Checkbox button
                  AppTapArea(
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
                      if (isScheduledInFuture) {
                        HapticFeedback.lightImpact();
                        final timeStr = DateFormat(
                          'h:mm a',
                        ).format(scheduledTime!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Scheduled for $timeStr. You can complete it once that time arrives.',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      final taskDao = ref.read(taskDaoProvider);
                      await taskDao.markComplete(task.id);
                    },
                    borderRadius: AppGeometry.roundedr12,
                    child: AppTag(
                      width: 26,
                      height: 26,
                      nightDecoration: BoxDecoration(
                        color: isDone
                            ? context.accentPrimary
                            : AppPalette.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDone
                              ? context.accentPrimary
                              : context.divider,
                          width: AppBorderScale.w1point8,
                        ),
                      ),
                      child: isDone
                          ? Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: context.textOnPrimary,
                            )
                          : (isScheduledInFuture
                                ? Icon(
                                    Icons.schedule_rounded,
                                    size: 13,
                                    color: context.textMuted,
                                  )
                                : null),
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
                                style: AscentTextStyles.bodyMedium
                                    .copyWith(
                                      color: isDone
                                          ? context.textMuted
                                          : context.textPrimary,
                                      decoration: isDone
                                          ? TextDecoration.lineThrough
                                          : null,
                                    )
                                    .merge(AppTypeRoles.typeRole15),
                              ),
                            ),
                            if (subTasks.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              AppTag(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.s8,
                                  vertical: AppSpace.s2,
                                ),
                                nightDecoration: BoxDecoration(
                                  color: context.accentPrimary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: AppGeometry.roundedr8,
                                ),
                                child: Text(
                                  '$completedSubTasks/${subTasks.length} sub-tasks',
                                  style: AscentTextStyles.captionMedium
                                      .copyWith(
                                        color: context.accentPrimaryBright,
                                      )
                                      .merge(AppTypeRoles.typeRole9),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (actionSupportingText(task.title, task.notes) !=
                            null) ...[
                          const SizedBox(height: 2),
                          Text(
                            actionSupportingText(task.title, task.notes)!,
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
                                  style:
                                      AppStateTypography.stateType3(
                                        state0:
                                            status ==
                                            TaskComputedStatus.lagging,
                                      ).copyWith(
                                        color:
                                            status == TaskComputedStatus.lagging
                                            ? context.stateDanger
                                            : context.textMuted,
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
                                  style: AppTypeRoles.typeRole16.copyWith(
                                    color: context.accentPrimary,
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
                    AppTapArea(
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
                      borderRadius: AppGeometry.roundedr18,
                      child: AppTag(
                        width: 34,
                        height: 34,
                        nightDecoration: BoxDecoration(
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
                AppDivider(
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
                    padding: const EdgeInsets.only(
                      left: AppSpace.s36,
                      top: AppSpace.s4,
                      bottom: AppSpace.s4,
                    ),
                    child: Row(
                      children: [
                        AppTapArea(
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
                          borderRadius: AppGeometry.roundedr6,
                          child: AppTag(
                            width: 20,
                            height: 20,
                            nightDecoration: BoxDecoration(
                              color: isSubDone
                                  ? context.accentPrimary
                                  : AppPalette.transparent,
                              borderRadius: AppGeometry.roundedr5,
                              border: Border.all(
                                color: isSubDone
                                    ? context.accentPrimary
                                    : context.divider,
                                width: AppBorderScale.w1point5,
                              ),
                            ),
                            child: isSubDone
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: AppPalette.white,
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
                  padding: const EdgeInsets.only(
                    left: AppSpace.s36,
                    top: AppSpace.s6,
                  ),
                  child: AppTapArea(
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
                          style: AscentTextStyles.labelSmall
                              .copyWith(color: context.accentPrimary)
                              .merge(AppTypeRoles.typeRole8),
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

  static void _showTaskDetailDialog(
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
          backgroundColor: AppPalette.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s24,
            vertical: AppSpace.s24,
          ),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpace.s22),
            nightDecoration: BoxDecoration(
              color: ctx.bgSurfaceElevated,
              borderRadius: AppGeometry.roundedr24,
              border: Border.all(color: g.line, width: AppBorderScale.w1),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      AscentStarButton(
                        selected: task.priority == 'high',
                        onChanged: isDone
                            ? null
                            : (value) async {
                                final saved = await ref
                                    .read(taskDaoProvider)
                                    .updateTask(
                                      TaskTableCompanion(
                                        id: Value(task.id),
                                        priority: Value(value ? 'high' : 'low'),
                                        updatedAt: Value(DateTime.now()),
                                      ),
                                    );
                                if (!saved) {
                                  throw StateError('Could not save star');
                                }
                              },
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
                    style: AppTypography.plusJakartaSans18W6004(
                      color: g.ink,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (actionSupportingText(task.title, task.notes) != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      actionSupportingText(task.title, task.notes)!,
                      style: AppTypography.inter14Regular5(color: g.inkMuted),
                    ),
                  ],
                  if (task.linkedThoughtId != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 14,
                          color: g.clay,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'From a thought',
                          style: AppTypography.inter11W7003(color: g.clay),
                        ),
                      ],
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
                        Expanded(
                          child: Text(
                            DateFormat(
                              'EEEE, MMM d, y',
                            ).format(task.plannedDate!),
                            style: AppTypography.inter13Regular6(
                              color: g.inkMuted,
                            ),
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
                        style: context.surfaces.buttonStyle(
                          TextButton.styleFrom(
                            foregroundColor: g.inkMuted,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s16,
                              vertical: AppSpace.s10,
                            ),
                          ),
                          filled: false,
                          icon: false,
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      if (!isDone &&
                          isTimeBound &&
                          subTasks.isEmpty &&
                          task.learningCourseId == null)
                        TextButton.icon(
                          icon: const Icon(Icons.school_outlined),
                          label: const Text('Send to lecture'),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            AddLectureActivitySheet.sendTask(
                              context,
                              ref,
                              task,
                            );
                          },
                        ),
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
                          style: context.surfaces.buttonStyle(
                            FilledButton.styleFrom(
                              backgroundColor: g.clay,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s18,
                                vertical: AppSpace.s10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppGeometry.roundedr14,
                              ),
                            ),
                            filled: true,
                            icon: false,
                          ),
                          child: const Text('Mark Done'),
                        )
                      else
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: context.surfaces.buttonStyle(
                            FilledButton.styleFrom(
                              backgroundColor: g.claySoft,
                              foregroundColor: g.clay,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s18,
                                vertical: AppSpace.s10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: AppGeometry.roundedr14,
                              ),
                            ),
                            filled: true,
                            icon: false,
                          ),
                          child: const Text('Done'),
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
  }
}
