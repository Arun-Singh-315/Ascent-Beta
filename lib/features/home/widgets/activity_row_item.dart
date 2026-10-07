import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
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
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: g.line, width: 1.0)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                          color: isDone ? g.clay : g.inkMuted,
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

            // ── 2. TASK TITLE & SUBTITLE ──────────────────────────────────
            Expanded(
              child: InkWell(
                onTap: () async {
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
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          _subtitleText(activity),
                          style: AscentTextStyles.homeSecondary.copyWith(
                            color: g.inkMuted,
                          ),
                        ),
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

            // ── 3. 44dp CIRCULAR START / ACTION BUTTON ───────────────────
            SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
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
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: g.claySoft,
                    ),
                    child: Center(
                      child: Icon(
                        isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                        color: g.clay,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleText(TodayActivityItem act) {
    if (act.kind == ActivityKind.todo) {
      if (act.priority != null && act.priority!.isNotEmpty) {
        return act.priority![0].toUpperCase() + act.priority!.substring(1);
      }
      return 'Medium';
    }
    if (act.kind == ActivityKind.duration) {
      if (act.elapsedSecondsToday > 0) {
        return '${act.elapsedSecondsToday ~/ 60}m tracked / ${act.targetMinutes ?? 30}m';
      }
      return '${act.targetMinutes ?? 30}m target';
    }
    return 'Flexible focus';
  }
}
