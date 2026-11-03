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
import '../../money/add_transaction_sheet.dart';
import '../models/things_intelligence.dart';

/// "The Compass Card" — Intelligent Hero card highlighting the single next best action.
/// Never just reflects text: auto-synthesizes category blueprints, micro-steps, and contextual actions.
class ThingsHeroCard extends ConsumerStatefulWidget {
  const ThingsHeroCard({
    super.key,
    required this.activity,
    this.onTap,
  });

  final TodayActivityItem activity;
  final VoidCallback? onTap;

  @override
  ConsumerState<ThingsHeroCard> createState() => _ThingsHeroCardState();
}

class _ThingsHeroCardState extends ConsumerState<ThingsHeroCard> {
  bool _isUnpacked = false;
  final Set<int> _checkedSteps = {};

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final g = context.glass;
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;
    final isLecture = activity.sourceType == 'lecture';
    final isTimed = activity.kind == ActivityKind.duration ||
        (activity.targetMinutes != null && activity.targetMinutes! > 0) ||
        isLecture;

    final (badgeLabel, badgeColor, badgeIcon) = _resolveHeroBadge(activity, g);
    final enrichment = ThingsEnrichmentEngine.analyze(activity);

    String durationText = '';
    if (activity.targetMinutes != null && activity.targetMinutes! > 0) {
      durationText = '${activity.targetMinutes} min';
    } else if (activity.scheduledTime != null) {
      durationText = DateFormat('h:mm a').format(activity.scheduledTime!);
    } else if (activity.sourceType == 'medicine') {
      durationText = 'Scheduled';
    } else {
      durationText = '${enrichment.suggestedMinutes}m estimated';
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
              : enrichment.categoryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Badges Row (Wrap-safe for 320px width & 2.0x text scale)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 240),
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
                        Flexible(
                          child: Text(
                            badgeLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Intelligent Category Pill
                  Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: enrichment.categoryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: enrichment.categoryColor.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          enrichment.categoryIcon,
                          size: 11,
                          color: enrichment.categoryColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            enrichment.categoryLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: enrichment.categoryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
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

              // 2. Task Title
              Text(
                activity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: g.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
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

              // 3. Unpack Blueprint Toggle / Intelligent Micro-Steps
              const SizedBox(height: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _isUnpacked = !_isUnpacked);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Icon(
                        _isUnpacked
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.auto_awesome_rounded,
                        size: 14,
                        color: enrichment.categoryColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _isUnpacked
                              ? 'Hide Blueprint'
                              : 'Unpack 3 Micro-Steps with Riya',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: enrichment.categoryColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (_isUnpacked) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: enrichment.categoryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: enrichment.categoryColor.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < enrichment.microSteps.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (_checkedSteps.contains(i)) {
                                _checkedSteps.remove(i);
                              } else {
                                _checkedSteps.add(i);
                              }
                            });
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _checkedSteps.contains(i)
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                size: 16,
                                color: _checkedSteps.contains(i)
                                    ? enrichment.categoryColor
                                    : g.inkMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  enrichment.microSteps[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.3,
                                    color: _checkedSteps.contains(i)
                                        ? g.inkMuted
                                        : g.ink,
                                    decoration: _checkedSteps.contains(i)
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // 4. Action Buttons Row
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
                  if (enrichment.actionChips.any((c) => c.type == ThingsActionType.moneyLog)) ...[
                    const SizedBox(width: 8),
                    Container(
                      height: 38,
                      decoration: BoxDecoration(
                        color: g.fill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: g.line,
                          width: 0.8,
                        ),
                      ),
                      child: TextButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          AddTransactionSheet.show(context);
                        },
                        icon: const Icon(Icons.receipt_long_rounded, size: 15),
                        label: const Text('Log Money'),
                        style: TextButton.styleFrom(
                          foregroundColor: enrichment.categoryColor,
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
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
    final activity = widget.activity;
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
