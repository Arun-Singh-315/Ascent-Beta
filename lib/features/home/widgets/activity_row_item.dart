import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';
import '../../today/add_activity_sheet.dart';

/// Redesigned task row matching Ascent Home Redesign:
/// - 44dp hit area circular checkbox
/// - 17/24 headline font
/// - Clean subtitle / priority tag
/// - 44dp circular start button (one-tap focus/timer start)
/// - Clean hairline divider
class ActivityRowItem extends ConsumerWidget {
  final TodayActivityItem activity;

  const ActivityRowItem({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
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
        padding: const EdgeInsets.only(right: 16),
        color: context.stateDanger.withValues(alpha: 0.15),
        child: Icon(Icons.delete_outline_rounded, color: context.stateDanger, size: 22),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 64),
        margin: (isRunning || isPaused)
            ? const EdgeInsets.symmetric(vertical: 4)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: isRunning
              ? g.claySoft.withValues(alpha: 0.35)
              : (isPaused ? g.claySoft.withValues(alpha: 0.18) : Colors.transparent),
          borderRadius: (isRunning || isPaused)
              ? BorderRadius.circular(12)
              : BorderRadius.zero,
          border: isRunning
              ? Border.all(color: g.clay.withValues(alpha: 0.35), width: 1.0)
              : (isPaused
                  ? Border.all(color: g.clay.withValues(alpha: 0.18), width: 1.0)
                  : Border(bottom: BorderSide(color: g.line, width: 1.0))),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: (isRunning || isPaused) ? 12 : 0,
          vertical: 10,
        ),
        child: Row(
          children: [
            // ── 1. CIRCULAR CHECK TARGET (44dp hit area, 28dp visual circle) ────
            SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    if (activity.sourceType == 'lecture') {
                      final learningState = ref.read(learningHubProvider);
                      ref.read(learningHubProvider.notifier).markLectureCompleted(
                            learningState.activeLectureId,
                            completed: !isDone,
                          );
                      return;
                    }
                    if (activity.linkedTaskId != null) {
                      await ref.read(taskDaoProvider).toggleTaskCompletion(
                            activity.linkedTaskId!,
                            !isDone,
                          );
                    }
                  },
                  borderRadius: BorderRadius.circular(22),
                  child: Center(
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? g.clay : Colors.transparent,
                        border: Border.all(
                          color: isDone ? g.clay : (isRunning ? g.clay : g.inkMuted),
                          width: 1.75,
                        ),
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── 2. TASK TITLE & SUBTITLE / RUNNING TIMER ──────────────────
            Expanded(
              child: InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (isRunning || isPaused) {
                    context.push('/focus');
                    return;
                  }
                  if (activity.sourceType == 'lecture') {
                    LectureFocusPlayerSheet.show(context);
                    return;
                  }
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      activity.title,
                      style: AscentTextStyles.homeHeadline.copyWith(
                        color: isDone ? g.inkMuted : g.ink,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (isRunning) ...[
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: g.clay,
                            ),
                          ),
                          Text(
                            _runningTimerText(activity),
                            style: GoogleFonts.jetBrainsMono(
                              color: g.clay,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ] else if (isPaused) ...[
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.orange.shade400,
                            ),
                          ),
                          Text(
                            'Paused • ${_runningTimerText(activity)}',
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.orange.shade400,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ] else ...[
                          Text(
                            _subtitleText(activity),
                            style: AscentTextStyles.homeSecondary.copyWith(
                              color: g.inkMuted,
                            ),
                          ),
                        ],
                        if (activity.isOverdue) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• Overdue',
                            style: AscentTextStyles.homeSecondary.copyWith(
                              color: context.stateDanger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── 3. RIGHT ACTION: EDIT FOR TODO, PLAY/PAUSE FOR TIMED ACTIVITIES ───
            if (activity.kind == ActivityKind.todo) ...[
              SizedBox(
                width: 44,
                height: 44,
                child: IconButton(
                  tooltip: 'Edit activity',
                  icon: Icon(Icons.edit_outlined, size: 18, color: g.inkMuted),
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
              ),
            ] else ...[
              SizedBox(
                width: 44,
                height: 44,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      if (activity.sourceType == 'lecture') {
                        ref.read(learningHubProvider.notifier).togglePlayPause();
                        return;
                      }
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
                      }
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRunning ? g.clay : g.claySoft,
                      ),
                      child: Center(
                        child: Icon(
                          isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 20,
                          color: isRunning ? Colors.white : g.clay,
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

  String _runningTimerText(TodayActivityItem act) {
    final elapsed = act.elapsedSecondsToday;
    final m = elapsed ~/ 60;
    final s = elapsed % 60;
    final timeStr = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    if (act.targetMinutes != null && act.targetMinutes! > 0) {
      return '$timeStr / ${act.targetMinutes}m';
    }
    return '$timeStr tracked';
  }

  String _subtitleText(TodayActivityItem act) {
    if (act.kind == ActivityKind.todo) {
      final p = (act.priority != null && act.priority!.isNotEmpty)
          ? act.priority![0].toUpperCase() + act.priority!.substring(1)
          : 'Medium';
      return '$p • To-do';
    }
    if (act.kind == ActivityKind.duration) {
      final targetMins = act.targetMinutes ?? 30;
      if (act.elapsedSecondsToday > 0) {
        final m = act.elapsedSecondsToday ~/ 60;
        final s = act.elapsedSecondsToday % 60;
        final timeStr = '$m:${s.toString().padLeft(2, '0')}';
        return '$timeStr tracked / ${targetMins}m';
      }
      return '${targetMins}m target';
    }
    return 'Flexible focus';
  }
}
