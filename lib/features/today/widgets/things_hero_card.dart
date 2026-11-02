import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/glass_surface.dart';

/// "Next Up" Hero card highlighting the single next best action in Things hub.
/// Prioritizes: running/paused session -> overdue/high priority -> due within 1h -> next task.
class ThingsHeroCard extends ConsumerWidget {
  const ThingsHeroCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  final TodayActivityItem activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;
    final isLecture = activity.sourceType == 'lecture';
    final isTimed = activity.kind == ActivityKind.duration ||
        (activity.targetMinutes != null && activity.targetMinutes! > 0) ||
        isLecture;

    final (badgeLabel, badgeColor, badgeIcon) = _resolveHeroBadge(activity, g);

    String durationText = '';
    if (activity.targetMinutes != null && activity.targetMinutes! > 0) {
      durationText = '${activity.targetMinutes} min';
    } else if (activity.scheduledTime != null) {
      durationText = DateFormat('h:mm a').format(activity.scheduledTime!);
    } else if (activity.sourceType == 'medicine') {
      durationText = 'Scheduled';
    } else {
      durationText = 'To-do';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassSurface(
        key: ValueKey('hero_card_${activity.id}'),
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(14),
        customBorder: Border.all(
          color: isRunning
              ? SharedControlColors.actionBlue.withValues(alpha: 0.45)
              : g.line,
          width: 1.2,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: badgeColor.withValues(alpha: 0.28),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(badgeIcon, size: 12, color: badgeColor),
                        const SizedBox(width: 4),
                        Text(
                          badgeLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (durationText.isNotEmpty)
                    Text(
                      durationText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: g.inkMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                activity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: g.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if (activity.notes != null && activity.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  activity.notes!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: g.inkMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.primary(
                      key: ValueKey('hero_start_btn_${activity.id}'),
                      expanded: true,
                      compact: true,
                      label: isRunning
                          ? 'Pause'
                          : isPaused
                          ? 'Resume'
                          : isTimed
                          ? 'Start'
                          : 'Complete',
                      icon: isRunning
                          ? Icons.pause_rounded
                          : isPaused
                          ? Icons.play_arrow_rounded
                          : isTimed
                          ? Icons.play_arrow_rounded
                          : Icons.check_rounded,
                      onPressed: () => _handleHeroAction(context, ref),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, IconData) _resolveHeroBadge(
    TodayActivityItem a,
    dynamic g,
  ) {
    if (a.status == TodayActivityStatus.inProgress) {
      return ('In progress', SharedControlColors.actionBlue, Icons.timer_rounded);
    }
    if (a.status == TodayActivityStatus.paused) {
      return ('Paused', g.clay as Color, Icons.pause_circle_rounded);
    }
    if (a.isOverdue) {
      return ('Overdue', SharedControlColors.dueRed, Icons.warning_amber_rounded);
    }
    if (a.priority == 'high') {
      return ('High priority', SharedControlColors.dueRed, Icons.flag_rounded);
    }
    if (a.scheduledTime != null &&
        a.scheduledTime!.difference(DateTime.now()) <= const Duration(hours: 1)) {
      return ('Due soon', g.clay as Color, Icons.schedule_rounded);
    }
    return ('Next up', SharedControlColors.actionBlue, Icons.arrow_forward_rounded);
  }

  Future<void> _handleHeroAction(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;
    final isLecture = activity.sourceType == 'lecture';
    final isTimed = activity.kind == ActivityKind.duration ||
        (activity.targetMinutes != null && activity.targetMinutes! > 0) ||
        isLecture;

    if (isLecture) {
      final notifier = ref.read(learningHubProvider.notifier);
      notifier.togglePlayPause();
      context.push('/learning');
      return;
    }

    if (isTimed) {
      final tracker = ref.read(timeTrackingProvider.notifier);
      if (isRunning) {
        tracker.pauseSession();
      } else if (isPaused) {
        tracker.resumeSession();
      } else {
        await tracker.switchToTask(
          title: activity.title,
          taskId: activity.linkedTaskId,
          sourceType: activity.sourceType,
          autoStart: true,
        );
        if (context.mounted) {
          context.push('/focus');
        }
      }
    } else {
      // Direct completion toggle for to-dos
      if (activity.linkedTaskId != null) {
        final db = ref.read(databaseProvider);
        await db.taskDao.markComplete(activity.linkedTaskId!);
      }
    }
  }
}
