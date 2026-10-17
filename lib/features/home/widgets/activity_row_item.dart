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
class ActivityRowItem extends ConsumerWidget {
  final TodayActivityItem activity;

  const ActivityRowItem({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isDone = activity.status == TodayActivityStatus.done;
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;
    final isTimed =
        activity.kind == ActivityKind.duration ||
        (activity.targetMinutes != null && activity.targetMinutes! > 0) ||
        activity.sourceType == 'lecture';
    final dueCheckIn = activity.linkedTaskId != null
        ? ref.watch(dueCheckInForTaskProvider(activity.linkedTaskId!)).value
        : null;

    return Dismissible(
      key: ValueKey(activity.id),
      direction: isDone ? DismissDirection.none : DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        if (activity.linkedTaskId != null) {
          final taskDao = ref.read(taskDaoProvider);
          final protection =
              await taskDao.getTaskProtection(activity.linkedTaskId!);
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
        final taskDao = ref.read(taskDaoProvider);
        Task? taskBackup;
        if (activity.linkedTaskId != null) {
          taskBackup = await taskDao.getTaskById(activity.linkedTaskId!);
        }
        await deleteTodayActivity(ref, activity);
        if (context.mounted) {
          final isLecture = activity.sourceType == 'lecture';
          AscentSnackBar.undo(
            context,
            message: isLecture
                ? 'Removed from today\'s activities'
                : 'Activity "${activity.title}" deleted',
            onUndo: () async {
              HapticFeedback.lightImpact();
              if (taskBackup != null) {
                await taskDao.insertTask(taskBackup.toCompanion(true));
              }
              await ref
                  .read(dismissedTodayActivityIdsProvider.notifier)
                  .unDismissActivityId(activity.id);
            },
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
        constraints: const BoxConstraints(minHeight: 64),
        margin: (isRunning || isPaused)
            ? const EdgeInsets.symmetric(vertical: AppSpace.s4)
            : EdgeInsets.zero,
        decoration: AppCard.decoration(
          context,
          night: BoxDecoration(
            color: isRunning
                ? (context.isDark
                      ? AppPalette.white.withValues(alpha: 0.22)
                      : g.fill)
                : (isPaused
                      ? (context.isDark
                            ? AppPalette.white.withValues(alpha: 0.12)
                            : g.fill.withValues(alpha: 0.7))
                      : AppPalette.transparent),
            borderRadius: (isRunning || isPaused)
                ? AppGeometry.roundedr12
                : BorderRadius.zero,
            border: isRunning
                ? Border.all(
                    color: g.clay.withValues(alpha: 0.35),
                    width: AppBorderScale.w1point0,
                  )
                : (isPaused
                      ? Border.all(
                          color: g.clay.withValues(alpha: 0.18),
                          width: AppBorderScale.w1point0,
                        )
                      : Border(
                          bottom: BorderSide(
                            color: g.line,
                            width: AppBorderScale.w1point0,
                          ),
                        )),
          ),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: (isRunning || isPaused) ? AppSpace.s12 : AppSpace.s0,
          vertical: AppSpace.s10,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
            // ── 1. CIRCULAR CHECK TARGET (44dp hit area, 28dp visual circle) ────
            SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: AppPalette.transparent,
                child: AppTapArea(
                  onTap: () async {
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
                      await ref
                          .read(taskDaoProvider)
                          .toggleTaskCompletion(activity.linkedTaskId!, true);
                    }
                  },
                  borderRadius: AppGeometry.roundedr22,
                  child: Center(
                    child: AppTag(
                      width: 26,
                      height: 26,
                      nightDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDone ? g.clay : AppPalette.transparent,
                        border: Border.all(
                          color: isDone
                              ? g.clay
                              : (isRunning ? g.clay : g.inkMuted),
                          width: AppBorderScale.w1point75,
                        ),
                      ),
                      child: isDone
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppPalette.white,
                            )
                          : (isTimed
                                ? Icon(
                                    Icons.timer_outlined,
                                    size: 13,
                                    color: isRunning ? g.clay : g.inkMuted,
                                  )
                                : null),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // ── 2. TASK TITLE & SUBTITLE / RUNNING TIMER ──────────────────
            Expanded(
              child: AppTapArea(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (isDone) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Completed activities are sealed and cannot be edited.',
                        ),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  if (isRunning || isPaused) {
                    context.push('/focus');
                    return;
                  }
                  if (activity.sourceType == 'lecture') {
                    if (!_selectLecture(ref, activity)) return;
                    LectureFocusPlayerSheet.show(context);
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
                    const SizedBox(height: 3),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isRunning) ...[
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
                              color: AppPalette.orange.shade400,
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
            if (isDone) ...[
              // Completed activities are immutable and cannot be edited
              const SizedBox(width: 8),
            ] else if (activity.kind == ActivityKind.todo) ...[
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
                        ref.read(timeTrackingProvider.notifier).pauseSession();
                      } else if (isPaused) {
                        ref.read(timeTrackingProvider.notifier).resumeSession();
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
                            Theme.of(context).brightness == Brightness.light &&
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
                  await ref.read(homeCaptureServiceProvider).answer(
                        dueCheckIn.reminderId,
                        dueCheckIn.scheduledAt,
                        'done',
                      );
                }
                try {
                  await ReminderAlertSync.device(ref.read(databaseProvider))
                      .sync(onlyPending: true);
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
                            onTap: () =>
                                Navigator.pop(ctx, Duration(minutes: minutes)),
                          ),
                      ],
                    ),
                  ),
                );
                if (delay != null && context.mounted) {
                  if (dueCheckIn.isRoutine) {
                    await ref.read(planServiceProvider).answerCheckIn(
                          dueCheckIn.occurrenceId!,
                          'later',
                          delay: delay,
                        );
                  } else {
                    await ref.read(homeCaptureServiceProvider).answer(
                          dueCheckIn.reminderId,
                          dueCheckIn.scheduledAt,
                          'later',
                          delay: delay,
                        );
                  }
                  try {
                    await ReminderAlertSync.device(ref.read(databaseProvider))
                        .sync(onlyPending: true);
                  } catch (_) {}
                  if (context.mounted) {
                    AscentSnackBar.show(
                      context,
                      message: 'Check-in moved by ${delay.inMinutes} minutes.',
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
                      .answerCheckIn(dueCheckIn.occurrenceId!, 'skip_this_time');
                } else {
                  await ref.read(homeCaptureServiceProvider).answer(
                        dueCheckIn.reminderId,
                        dueCheckIn.scheduledAt,
                        'skip',
                      );
                }
                try {
                  await ReminderAlertSync.device(ref.read(databaseProvider))
                      .sync(onlyPending: true);
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
                      .answerCheckIn(dueCheckIn.occurrenceId!, 'skip_check_in');
                } else {
                  await ref.read(homeCaptureServiceProvider).answer(
                        dueCheckIn.reminderId,
                        dueCheckIn.scheduledAt,
                        'skip',
                      );
                }
                try {
                  await ReminderAlertSync.device(ref.read(databaseProvider))
                      .sync(onlyPending: true);
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
                            foregroundColor: AppPalette.white,
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
