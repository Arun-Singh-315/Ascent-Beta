import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../today/add_activity_sheet.dart';

class ActivityRowItem extends ConsumerWidget {
  final TodayActivityItem activity;

  const ActivityRowItem({super.key, required this.activity});

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = activity.status == TodayActivityStatus.done;
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;

    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        await deleteTodayActivity(ref, activity);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activity "${activity.title}" deleted'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: context.stateDanger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline_rounded, color: context.stateDanger, size: 20),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            // 1. Completion Checkbox (or duration indicator)
            if (activity.kind == ActivityKind.todo)
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (activity.linkedTaskId != null) {
                    await ref.read(taskDaoProvider).toggleTaskCompletion(
                          activity.linkedTaskId!,
                          !isDone,
                        );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isDone ? context.accentSecondary : context.divider,
                    size: 22,
                  ),
                ),
              )
            else
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (activity.linkedTaskId != null) {
                    await ref.read(taskDaoProvider).toggleTaskCompletion(
                          activity.linkedTaskId!,
                          !isDone,
                        );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : (activity.kind == ActivityKind.duration
                            ? Icons.timer_outlined
                            : Icons.all_inclusive_rounded),
                    color: isDone
                        ? context.accentSecondary
                        : (isRunning ? context.accentSecondary : context.textMuted),
                    size: 22,
                  ),
                ),
              ),

            const SizedBox(width: 8),

            // 2. Activity Info (Title, Subtitle/Duration/Tags)
            Expanded(
              child: InkWell(
                onLongPress: () async {
                  HapticFeedback.lightImpact();
                  Task? task;
                  if (activity.linkedTaskId != null) {
                    task = await ref.read(taskDaoProvider).getTaskById(activity.linkedTaskId!);
                  }
                  if (context.mounted) {
                    AddActivitySheet.show(
                      context,
                      existingTask: task,
                      initialTitle: activity.title,
                      initialKind: activity.kind,
                      initialDurationMinutes: activity.targetMinutes,
                    );
                  }
                },
                onTap: () async {
                  if (activity.kind == ActivityKind.todo) {
                    // Open task editor
                    Task? task;
                    if (activity.linkedTaskId != null) {
                      task = await ref.read(taskDaoProvider).getTaskById(activity.linkedTaskId!);
                    }
                    if (context.mounted) {
                      AddActivitySheet.show(
                        context,
                        existingTask: task,
                        initialTitle: activity.title,
                        initialKind: activity.kind,
                        initialDurationMinutes: activity.targetMinutes,
                      );
                    }
                  } else {
                    // Duration or flexible: start or open focus
                    await ref.read(timeTrackingProvider.notifier).switchToTask(
                          title: activity.title,
                          taskId: activity.linkedTaskId,
                          sourceType: activity.sourceType,
                          autoStart: !isRunning,
                        );
                    if (context.mounted) {
                      context.push('/focus');
                    }
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDone ? context.textMuted : context.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Type Tag / Priority Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: context.bgBase,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            activity.kind == ActivityKind.todo
                                ? (activity.priority != null ? activity.priority!.toUpperCase() : 'TASK')
                                : (activity.kind == ActivityKind.duration
                                    ? '${activity.targetMinutes ?? 30} MIN'
                                    : 'FLEXIBLE'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: activity.priority == 'high'
                                  ? context.stateDanger
                                  : context.textMuted,
                            ),
                          ),
                        ),

                        if (activity.isOverdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: context.stateDanger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'OVERDUE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: context.stateDanger,
                              ),
                            ),
                          ),
                        ],

                        if (activity.kind == ActivityKind.duration && activity.targetMinutes != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            activity.elapsedSecondsToday > 0
                                ? '${activity.elapsedSecondsToday ~/ 60}m tracked'
                                : '${activity.targetMinutes}m target',
                            style: TextStyle(fontSize: 10, color: context.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            IconButton(
              icon: Icon(Icons.edit_outlined, size: 15, color: context.textMuted),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: 'Edit activity',
              onPressed: () async {
                HapticFeedback.lightImpact();
                Task? task;
                if (activity.linkedTaskId != null) {
                  task = await ref.read(taskDaoProvider).getTaskById(activity.linkedTaskId!);
                }
                if (context.mounted) {
                  AddActivitySheet.show(
                    context,
                    existingTask: task,
                    initialTitle: activity.title,
                    initialKind: activity.kind,
                    initialDurationMinutes: activity.targetMinutes,
                  );
                }
              },
            ),
            const SizedBox(width: 4),

            // 3. Right Action: Play / Pause / Start for Timed & Flexible
            if (activity.kind != ActivityKind.todo)
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (isRunning) {
                    ref.read(timeTrackingProvider.notifier).pauseSession();
                  } else if (isPaused) {
                    ref.read(timeTrackingProvider.notifier).resumeSession();
                  } else {
                    await ref.read(timeTrackingProvider.notifier).switchToTask(
                          title: activity.title,
                          taskId: activity.linkedTaskId,
                          sourceType: activity.sourceType,
                          autoStart: true,
                        );
                    if (context.mounted) {
                      context.push('/focus');
                    }
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? context.accentSecondary.withValues(alpha: 0.15)
                        : (isPaused
                            ? Colors.orange.withValues(alpha: 0.15)
                            : context.bgBase),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRunning
                          ? context.accentSecondary.withValues(alpha: 0.4)
                          : context.divider,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRunning
                            ? Icons.pause_rounded
                            : (isPaused ? Icons.play_arrow_rounded : Icons.play_arrow_rounded),
                        size: 14,
                        color: isRunning
                            ? context.accentSecondary
                            : (isPaused ? Colors.orange : context.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activity.elapsedSecondsToday > 0
                            ? _formatTime(activity.elapsedSecondsToday)
                            : (activity.kind == ActivityKind.duration ? 'Start' : 'Track'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isRunning
                              ? context.accentSecondary
                              : (isPaused ? Colors.orange : context.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
