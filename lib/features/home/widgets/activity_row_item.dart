import '../../../shared/utils/action_text.dart';
import '../../plans/planning_providers.dart';
import '../../today/add_lecture_activity_sheet.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/merlot_palette.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../core/database/app_database.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';
import '../../today/add_activity_sheet.dart';
import '../../plans/widgets/plan_protection_dialog.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';

/// Redesigned task row matching Ascent Home Redesign:
/// - 44dp hit area circular checkbox
/// - 17/24 headline font
/// - Clean subtitle / priority tag
/// - 44dp circular start button (one-tap focus/timer start)
/// - Clean hairline divider
class ActivityRowItem extends ConsumerStatefulWidget {
  final TodayActivityItem activity;

  const ActivityRowItem({super.key, required this.activity});

  @override
  ConsumerState<ActivityRowItem> createState() => _ActivityRowItemState();
}

class _ActivityRowItemState extends ConsumerState<ActivityRowItem> {
  bool _removed = false;
  TodayActivityItem get activity => widget.activity;

  @override
  void didUpdateWidget(covariant ActivityRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != activity.id) _removed = false;
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();
    final planLabel = activity.linkedTaskId == null
        ? null
        : ref.watch(taskPlanLabelProvider(activity.linkedTaskId!)).value;
    final g = context.glass;
    final isDone = activity.status == TodayActivityStatus.done;
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;
    final isLecture = activity.sourceType == 'lecture';
    final isTimed =
        (activity.kind == ActivityKind.duration ||
            (activity.targetMinutes != null && activity.targetMinutes! > 0)) &&
        !isLecture;
    final dueCheckIn = activity.linkedTaskId != null
        ? ref.watch(dueCheckInForTaskProvider(activity.linkedTaskId!)).value
        : null;

    return Dismissible(
      key: ValueKey(activity.id),
      direction: isDone ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (activity.linkedTaskId != null) {
          final taskDao = ref.read(taskDaoProvider);
          final protection = await taskDao.getTaskProtection(
            activity.linkedTaskId!,
          );
          if (protection != null) {
            HapticFeedback.mediumImpact();
            if (context.mounted) {
              await showPlanProtectionDialog(context, ref, protection);
            }
            return false;
          }
        }
        return true;
      },
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        // Capture dependencies before the row disappears from its parent stream.
        final container = ProviderScope.containerOf(context, listen: false);
        final messenger = ScaffoldMessenger.of(context);
        final removedActivity = activity;
        final taskDao = container.read(taskDaoProvider);
        final dismissed = container.read(
          dismissedTodayActivityIdsProvider.notifier,
        );
        // Never leave a dismissed Dismissible in the tree while awaiting I/O.
        setState(() => _removed = true);
        try {
          await deleteTodayActivity(container, removedActivity);
          if (!messenger.mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                removedActivity.sourceType == 'lecture'
                    ? "Removed from today's activities"
                    : 'Activity "${removedActivity.title}" deleted',
              ),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    if (removedActivity.linkedTaskId != null &&
                        removedActivity.sourceType != 'lecture') {
                      final restored = await taskDao.restoreDeletedTask(
                        removedActivity.linkedTaskId!,
                      );
                      if (!restored) {
                        if (!messenger.mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Could not restore this activity.'),
                          ),
                        );
                        return;
                      }
                    }
                    await dismissed.unDismissActivityId(removedActivity.id);
                    if (mounted) setState(() => _removed = false);
                  } catch (_) {
                    if (!messenger.mounted) return;
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Could not restore this activity.'),
                      ),
                    );
                  }
                },
              ),
            ),
          );
        } catch (_) {
          await dismissed.unDismissActivityId(removedActivity.id);
          if (mounted) setState(() => _removed = false);
          if (!messenger.mounted) return;
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Could not delete this activity. Try again.'),
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.s16),
        color: context.stateDanger.withValues(alpha: 0.15),
        child: Icon(
          Icons.delete_outline_rounded,
          color: context.stateDanger,
          size: 22,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minHeight: 58),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: isRunning
              ? (context.isDark
                    ? (g.merlot
                          ? MerlotPalette.darkAction.withValues(alpha: 0.18)
                          : (g.frozen
                                ? FrozenPalette.darkAction.withValues(
                                    alpha: 0.18,
                                  )
                                : AppPalette.white.withValues(alpha: 0.22)))
                    : (g.merlot
                          ? MerlotPalette.tint
                          : (g.frozen ? FrozenPalette.tint : g.fill)))
              : (isPaused
                    ? (context.isDark
                          ? (g.merlot
                                ? MerlotPalette.darkElevated
                                : (g.frozen
                                      ? FrozenPalette.darkElevated
                                      : AppPalette.white.withValues(
                                          alpha: 0.12,
                                        )))
                          : (g.merlot
                                ? MerlotPalette.pillSoft
                                : (g.frozen
                                      ? FrozenPalette.pillSoft
                                      : const Color(0xFFFAFAFA))))
                    : (context.isDark
                          ? (g.merlot
                                ? MerlotPalette.darkElevated
                                : (g.frozen
                                      ? FrozenPalette.darkElevated
                                      : g.fill))
                          : (g.merlot
                                ? MerlotPalette.pillSoft
                                : (g.frozen
                                      ? FrozenPalette.pillSoft
                                      : const Color(0xFFFAFAFA))))),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isRunning
                ? (g.merlot
                      ? MerlotPalette.action
                      : (g.frozen ? FrozenPalette.action : g.clay))
                : (isPaused
                      ? (g.merlot
                            ? MerlotPalette.antiqueGold
                            : (g.frozen ? FrozenPalette.line : g.line))
                      : (context.isDark
                            ? (g.merlot
                                  ? MerlotPalette.darkLine
                                  : (g.frozen
                                        ? FrozenPalette.darkLine
                                        : g.edge))
                            : (g.merlot
                                  ? MerlotPalette.lineSubtle
                                  : (g.frozen
                                        ? FrozenPalette.lineSubtle
                                        : g.edge.withValues(alpha: 0.35))))),
            width: isRunning ? 1.5 : (g.merlot || g.frozen ? 0.75 : 1),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ── 1. CIRCULAR CHECK TARGET (48dp hit area, 28dp visual circle) ────
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Material(
                    color: AppPalette.transparent,
                    child: AppTapArea(
                      onTap: isLecture
                          ? null
                          : () async {
                              if (isDone) {
                                // Once completed, it cannot be undone or brought to active (one way only).
                                AscentSnackBar.show(
                                  context,
                                  message:
                                      'Completed items are finished and cannot be reopened.',
                                );
                                return;
                              }
                              HapticFeedback.mediumImpact();
                              if (isTimed) {
                                AscentSnackBar.show(
                                  context,
                                  message:
                                      'Timed activities complete automatically when the focus timer ends.',
                                );
                                return;
                              }
                              if (activity.linkedTaskId != null) {
                                final dao = ref.read(taskDaoProvider);
                                try {
                                  await dao.toggleTaskCompletion(
                                    activity.linkedTaskId!,
                                    true,
                                  );
                                  final saved = await dao.getTaskById(
                                    activity.linkedTaskId!,
                                  );
                                  if (context.mounted) {
                                    AscentSnackBar.show(
                                      context,
                                      message:
                                          saved?.actualCompletedDate != null
                                          ? 'Task completed'
                                          : 'Finish the checklist steps before completing this task.',
                                    );
                                  }
                                } catch (_) {
                                  if (context.mounted) {
                                    AscentSnackBar.error(
                                      context,
                                      message:
                                          'Could not complete the task. Please retry.',
                                    );
                                  }
                                }
                              }
                            },
                      borderRadius: AppGeometry.roundedr22,
                      child: Center(
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone
                                ? (g.merlot ? MerlotPalette.action : g.clay)
                                : (g.merlot
                                      ? MerlotPalette.spark.withValues(
                                          alpha: 0.12,
                                        )
                                      : AppPalette.transparent),
                            border: Border.all(
                              color: isDone
                                  ? (g.merlot ? MerlotPalette.action : g.clay)
                                  : (isPaused
                                        ? (g.frozen
                                              ? FrozenPalette.action
                                              : (g.merlot
                                                    ? MerlotPalette.antiqueGold
                                                    : g.clay))
                                        : (isRunning ? g.clay : g.inkMuted)),
                              width: 1.75,
                            ),
                          ),
                          child: isDone
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 16,
                                  color: AppPalette.white,
                                )
                              : (isLecture
                                    ? Icon(
                                        isRunning
                                            ? Icons.headphones_rounded
                                            : Icons.school_outlined,
                                        size: 14,
                                        color: isRunning
                                            ? g.clay
                                            : (isPaused
                                                  ? (g.frozen
                                                        ? FrozenPalette.action
                                                        : (g.merlot
                                                              ? MerlotPalette
                                                                    .antiqueGold
                                                              : g.clay))
                                                  : g.inkMuted),
                                      )
                                    : (isTimed
                                          ? Icon(
                                              Icons.timer_outlined,
                                              size: 13,
                                              color: isRunning
                                                  ? g.clay
                                                  : (isPaused
                                                        ? (g.frozen
                                                              ? FrozenPalette
                                                                    .action
                                                              : (g.merlot
                                                                    ? MerlotPalette
                                                                          .antiqueGold
                                                                    : g.clay))
                                                        : g.inkMuted),
                                            )
                                          : null)),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // ── 2. TASK TITLE & SUBTITLE / RUNNING TIMER ──────────────────
                Expanded(
                  child: AppTapArea(
                    onTap: (isDone || isLecture)
                        ? null
                        : () async {
                            HapticFeedback.lightImpact();
                            if (isRunning || isPaused) {
                              context.push('/focus');
                              return;
                            }
                            _showActivityDetailDialog(context, ref, activity);
                          },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activity.title,
                                style: AscentTextStyles.homeHeadline.copyWith(
                                  color: isDone ? g.inkMuted : g.ink,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (planLabel != null &&
                            !sameActionText(planLabel, activity.title))
                          Text(
                            planLabel,
                            style: AscentTextStyles.homeSecondary.copyWith(
                              color: g.clay,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        const SizedBox(height: 3),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (isLecture) ...[
                              Text(
                                _subtitleText(activity),
                                style: AscentTextStyles.homeSecondary.copyWith(
                                  color: isRunning ? g.clay : g.inkMuted,
                                  fontWeight: isRunning
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ] else if (isRunning) ...[
                              Text(
                                _runningTimerText(activity),
                                style: AppTypography.jetBrainsMono12W600109(
                                  color: g.clay,
                                ),
                              ),
                            ] else if (isPaused) ...[
                              Text(
                                'Paused · ${_runningTimerText(activity)}',
                                style: AppTypography.jetBrainsMono12W500110(
                                  color: g.frozen
                                      ? (context.isDark
                                            ? FrozenPalette.darkSecondaryInk
                                            : FrozenPalette.action)
                                      : (g.merlot
                                            ? (context.isDark
                                                  ? MerlotPalette.darkSpark
                                                  : MerlotPalette.antiqueGold)
                                            : AppPalette.orange.shade400),
                                ),
                              ),
                            ] else ...[
                              if (g.merlot &&
                                  activity.kind == ActivityKind.todo &&
                                  !isDone) ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: const BoxDecoration(
                                    color: MerlotPalette.spark,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              Text(
                                _subtitleText(activity),
                                style: AscentTextStyles.homeSecondary.copyWith(
                                  color:
                                      (g.merlot &&
                                          activity.kind == ActivityKind.todo &&
                                          !isDone)
                                      ? (context.isDark
                                            ? MerlotPalette.darkSecondaryInk
                                            : MerlotPalette.action)
                                      : g.inkMuted,
                                  fontWeight:
                                      (g.merlot &&
                                          activity.kind == ActivityKind.todo &&
                                          !isDone)
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                            if (activity.isOverdue) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• Overdue',
                                style: AscentTextStyles.homeSecondary
                                    .copyWith(color: context.stateDanger)
                                    .merge(AppTypeRoles.typeRole8),
                              ),
                            ],
                            if (activity.hasReminder) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Icons.alarm_rounded,
                                size: 12,
                                color: isDone ? g.inkMuted : g.clay,
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
                if (isDone || isLecture) ...[
                  // Completed and lecture activities have no edit or timer play buttons on the row
                  const SizedBox(width: 8),
                ] else if (activity.kind == ActivityKind.todo) ...[
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      tooltip: 'Edit activity',
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: g.inkMuted,
                      ),
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        Task? task;
                        if (activity.linkedTaskId != null) {
                          task = await ref
                              .read(taskDaoProvider)
                              .getTaskById(activity.linkedTaskId!);
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
                      color: AppPalette.transparent,
                      child: AppTapArea(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          if (activity.sourceType == 'lecture') {
                            if (!_selectLecture(ref, activity)) return;
                            ref
                                .read(learningHubProvider.notifier)
                                .togglePlayPause();
                            return;
                          }
                          if (isRunning) {
                            ref
                                .read(timeTrackingProvider.notifier)
                                .pauseSession();
                          } else if (isPaused) {
                            ref
                                .read(timeTrackingProvider.notifier)
                                .resumeSession();
                          } else {
                            await ref
                                .read(timeTrackingProvider.notifier)
                                .switchToTask(
                                  title: activity.title,
                                  taskId: activity.linkedTaskId,
                                  sourceType: activity.sourceType,
                                  autoStart: true,
                                );
                          }
                        },
                        borderRadius: AppGeometry.roundedr22,
                        child: AppTag(
                          nightDecoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isRunning ? g.clay : g.claySoft,
                            border:
                                Theme.of(context).brightness ==
                                        Brightness.light &&
                                    !isRunning
                                ? Border.all(
                                    color: g.clay.withValues(alpha: .45),
                                    width: 1,
                                  )
                                : null,
                          ),
                          child: Center(
                            child: Icon(
                              isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 26,
                              color: isRunning ? AppPalette.white : g.clay,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (dueCheckIn != null)
              _buildCheckInResponseBar(context, ref, g, dueCheckIn),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInResponseBar(
    BuildContext context,
    WidgetRef ref,
    AscentGlass g,
    DueCheckInItem dueCheckIn,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: g.claySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: g.clay.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, size: 14, color: g.clay),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Did you finish: ${activity.title}?',
                  style: AscentTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: g.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              AppPill.action(
                label: const Text('Done'),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  if (dueCheckIn.isRoutine) {
                    await ref
                        .read(planServiceProvider)
                        .answerCheckIn(dueCheckIn.occurrenceId!, 'done');
                  } else {
                    await ref
                        .read(homeCaptureServiceProvider)
                        .answer(
                          dueCheckIn.reminderId,
                          dueCheckIn.scheduledAt,
                          'done',
                        );
                  }
                  try {
                    await ReminderAlertSync.device(
                      ref.read(databaseProvider),
                    ).sync(onlyPending: true);
                  } catch (_) {}
                  if (context.mounted) {
                    AscentSnackBar.show(
                      context,
                      message: 'Done. Session marked finished.',
                    );
                  }
                },
              ),
              AppPill.action(
                label: const Text('Later'),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final delay = await showModalBottomSheet<Duration>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ListTile(title: Text('Ask me again in…')),
                          for (final minutes in [15, 30, 60])
                            ListTile(
                              title: Text('$minutes minutes'),
                              onTap: () => Navigator.pop(
                                ctx,
                                Duration(minutes: minutes),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                  if (delay != null && context.mounted) {
                    if (dueCheckIn.isRoutine) {
                      await ref
                          .read(planServiceProvider)
                          .answerCheckIn(
                            dueCheckIn.occurrenceId!,
                            'later',
                            delay: delay,
                          );
                    } else {
                      await ref
                          .read(homeCaptureServiceProvider)
                          .answer(
                            dueCheckIn.reminderId,
                            dueCheckIn.scheduledAt,
                            'later',
                            delay: delay,
                          );
                    }
                    try {
                      await ReminderAlertSync.device(
                        ref.read(databaseProvider),
                      ).sync(onlyPending: true);
                    } catch (_) {}
                    if (context.mounted) {
                      AscentSnackBar.show(
                        context,
                        message:
                            'Check-in moved by ${delay.inMinutes} minutes.',
                      );
                    }
                  }
                },
              ),
              AppPill.action(
                label: const Text('Skip this time'),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  if (dueCheckIn.isRoutine) {
                    await ref
                        .read(planServiceProvider)
                        .answerCheckIn(
                          dueCheckIn.occurrenceId!,
                          'skip_this_time',
                        );
                  } else {
                    await ref
                        .read(homeCaptureServiceProvider)
                        .answer(
                          dueCheckIn.reminderId,
                          dueCheckIn.scheduledAt,
                          'skip',
                        );
                  }
                  try {
                    await ReminderAlertSync.device(
                      ref.read(databaseProvider),
                    ).sync(onlyPending: true);
                  } catch (_) {}
                  if (context.mounted) {
                    AscentSnackBar.show(
                      context,
                      message: 'Session skipped. Todo stays unfinished.',
                    );
                  }
                },
              ),
              AppPill.action(
                label: const Text('Skip check-in'),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  if (dueCheckIn.isRoutine) {
                    await ref
                        .read(planServiceProvider)
                        .answerCheckIn(
                          dueCheckIn.occurrenceId!,
                          'skip_check_in',
                        );
                  } else {
                    await ref
                        .read(homeCaptureServiceProvider)
                        .answer(
                          dueCheckIn.reminderId,
                          dueCheckIn.scheduledAt,
                          'skip',
                        );
                  }
                  try {
                    await ReminderAlertSync.device(
                      ref.read(databaseProvider),
                    ).sync(onlyPending: true);
                  } catch (_) {}
                  if (context.mounted) {
                    AscentSnackBar.show(
                      context,
                      message: 'Check-in stopped for this session.',
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _runningTimerText(TodayActivityItem act) {
    final elapsed = act.elapsedSecondsToday;
    final m = elapsed ~/ 60;
    final s = elapsed % 60;
    final timeStr =
        '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    if (act.targetMinutes != null && act.targetMinutes! > 0) {
      return '$timeStr / ${act.targetMinutes}m';
    }
    return '$timeStr tracked';
  }

  String _subtitleText(TodayActivityItem act) {
    if (act.status == TodayActivityStatus.done) {
      if (act.completedAt != null) {
        return '✓ Done at ${DateFormat('h:mm a').format(act.completedAt!)}';
      }
      return '✓ Completed';
    }
    if (act.sourceType == 'lecture') {
      if (act.status == TodayActivityStatus.inProgress) {
        return 'Lecture in progress';
      }
      return 'Lecture';
    }
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

  void _showActivityDetailDialog(
    BuildContext context,
    WidgetRef ref,
    TodayActivityItem activity,
  ) {
    final g = context.glass;
    final isDone = activity.status == TodayActivityStatus.done;
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s10,
                        vertical: AppSpace.s4,
                      ),
                      nightDecoration: BoxDecoration(
                        color: g.claySoft,
                        borderRadius: AppGeometry.roundedr12,
                      ),
                      child: Text(
                        activity.kind == ActivityKind.todo
                            ? 'To-do'
                            : 'Focus Activity',
                        style: AppTypography.inter12W600111(color: g.clay),
                      ),
                    ),
                    const Spacer(),
                    if (!isDone && activity.kind == ActivityKind.todo)
                      IconButton(
                        tooltip: 'Edit activity',
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: g.inkMuted,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          Task? task;
                          if (activity.linkedTaskId != null) {
                            task = await ref
                                .read(taskDaoProvider)
                                .getTaskById(activity.linkedTaskId!);
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
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  activity.title,
                  style: AppTypography.plusJakartaSans18W6004(
                    color: g.ink,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: g.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _subtitleText(activity),
                      style: AppTypography.inter13Regular6(color: g.inkMuted),
                    ),
                  ],
                ),
                if (!isDone &&
                    activity.linkedTaskId != null &&
                    activity.sourceType != 'lecture' &&
                    (activity.targetMinutes ?? 0) > 0)
                  TextButton.icon(
                    icon: const Icon(Icons.school_outlined),
                    label: const Text('Send to lecture'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final task = await ref
                          .read(taskDaoProvider)
                          .getTaskById(activity.linkedTaskId!);
                      if (context.mounted && task != null) {
                        await AddLectureActivitySheet.sendTask(
                          context,
                          ref,
                          task,
                        );
                      }
                    },
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
                    if (!isDone)
                      FilledButton(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          Navigator.of(ctx).pop();
                          final isTimedItem =
                              activity.kind == ActivityKind.duration ||
                              (activity.targetMinutes != null &&
                                  activity.targetMinutes! > 0) ||
                              activity.sourceType == 'lecture';
                          if (isTimedItem) {
                            if (activity.sourceType == 'lecture') {
                              if (!_selectLecture(ref, activity)) return;
                              LectureFocusPlayerSheet.show(context);
                            } else {
                              await ref
                                  .read(timeTrackingProvider.notifier)
                                  .switchToTask(
                                    title: activity.title,
                                    taskId: activity.linkedTaskId,
                                    sourceType: activity.sourceType,
                                    autoStart: true,
                                  );
                            }
                            return;
                          }
                          if (activity.linkedTaskId != null) {
                            await ref
                                .read(taskDaoProvider)
                                .toggleTaskCompletion(
                                  activity.linkedTaskId!,
                                  true,
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
                        child: Text(
                          (activity.kind == ActivityKind.duration ||
                                  (activity.targetMinutes != null &&
                                      activity.targetMinutes! > 0) ||
                                  activity.sourceType == 'lecture')
                              ? 'Start Focus'
                              : 'Mark Done',
                        ),
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
        );
      },
    );
  }
}

bool _selectLecture(WidgetRef ref, TodayActivityItem activity) {
  final courseId = activity.learningCourseId;
  final lectureId = activity.learningLectureId;
  if (courseId == null || lectureId == null) return false;
  final state = ref.read(learningHubProvider);
  if (!state.courses.any(
    (c) =>
        c.id == courseId &&
        c.modules.any((m) => m.lectures.any((l) => l.id == lectureId)),
  )) {
    return false;
  }
  final notifier = ref.read(learningHubProvider.notifier);
  if (state.activeCourseId != courseId) notifier.switchCourse(courseId);
  if (ref.read(learningHubProvider).activeLectureId != lectureId) {
    notifier.selectLecture(lectureId, autoPlay: false);
  }
  return true;
}
