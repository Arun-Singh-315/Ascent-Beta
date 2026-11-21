import '../../../shared/widgets/ascent_press_feedback.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import 'activity_timer_progress.dart';
import 'activity_actions.dart';
import 'activity_detail_sheet.dart';

export 'activity_actions.dart';
export 'activity_detail_sheet.dart';
import '../../../shared/widgets/ascent_button.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/ascent_star_button.dart';
import '../../../app/theme/shared_control_tokens.dart';
import 'package:drift/drift.dart' show Value;
import '../../../shared/widgets/glass_chip.dart';
import '../../../shared/utils/action_text.dart';
import '../../plans/planning_providers.dart';
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
import '../../today/add_activity_sheet.dart';
import '../../plans/widgets/plan_protection_dialog.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/undo_snackbar.dart';

bool _removesFromTodayOnly(TodayActivityItem activity) =>
    activity.sourceType == 'lecture' || activity.linkedTaskId == null;

/// Redesigned task row matching Ascent Home Redesign:
/// - 44dp hit area circular checkbox
/// - 17/24 headline font
/// - Clean subtitle / priority tag
/// - 44dp circular start button (one-tap focus/timer start)
/// - Clean hairline divider
class ActivityRowItem extends ConsumerStatefulWidget {
  final TodayActivityItem activity;

  final bool compact;
  final VoidCallback? onViewCompleted;
  final bool ground;
  final bool hubStyle;
  final bool featured;
  const ActivityRowItem({
    super.key,
    required this.activity,
    this.compact = false,
    this.onViewCompleted,
    this.ground = false,
    this.hubStyle = false,
    this.featured = false,
  });

  @override
  ConsumerState<ActivityRowItem> createState() => _ActivityRowItemState();
}

class _ActivityRowItemState extends ConsumerState<ActivityRowItem> {
  bool _removed = false;
  bool _timerActionBusy = false;
  bool _completing = false;
  TodayActivityItem get activity => widget.activity;

  void _openActivityLecture(
    BuildContext context,
    WidgetRef ref,
    TodayActivityItem activity,
  ) =>
      openActivityLecture(context, ref, activity);

  bool _selectLecture(WidgetRef ref, TodayActivityItem activity) =>
      selectActivityLecture(ref, activity);

  void _showActivityDetailDialog(
    BuildContext context,
    WidgetRef ref,
    TodayActivityItem activity,
  ) =>
      showActivityDetailDialog(context, ref, activity);

  @override
  void didUpdateWidget(covariant ActivityRowItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != activity.id) {
      _removed = false;
      _completing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Swipes (CLAUDE.md §5.2): right = complete, left = reschedule or delete.
  // Both are Undo-first; nothing asks for confirmation.
  // ---------------------------------------------------------------------------

  bool get _canComplete =>
      activity.linkedTaskId != null && activity.sourceType != 'lecture';

  bool get _canReschedule =>
      _canComplete &&
      !activity.isDailyStanding &&
      activity.sourceType != 'medicine';

  Widget _swipeable({
    required Key key,
    required bool enabled,
    required Widget child,
  }) {
    final direction = !enabled
        ? DismissDirection.none
        : _canComplete
        ? DismissDirection.horizontal
        : DismissDirection.endToStart;
    return Dismissible(
      key: key,
      direction: direction,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.35,
      },
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          await completeActivityWithUndo(context, ref, activity);
          return false; // The row updates from the data stream.
        }
        return _onSwipeLeft();
      },
      onDismissed: (_) => _deleteWithUndo(),
      background: _swipeBackground(
        context,
        alignment: Alignment.centerLeft,
        color: context.doneInk,
        icon: Icons.check_circle_rounded,
        label: 'Complete',
      ),
      secondaryBackground: _swipeBackground(
        context,
        alignment: Alignment.centerRight,
        color: context.isDark
            ? SharedControlColors.actionBlueDark
            : SharedControlColors.actionBlue,
        icon: Icons.more_horiz_rounded,
        label: _canReschedule ? 'Move or delete' : 'Remove',
      ),
      child: child,
    );
  }

  /// Returns true only when the row should be dismissed (i.e. deleted).
  Future<bool> _onSwipeLeft() async {
    if (activity.linkedTaskId != null) {
      final protection = await ref
          .read(taskDaoProvider)
          .getTaskProtection(activity.linkedTaskId!);
      if (protection != null) {
        HapticFeedback.mediumImpact();
        if (mounted) await showPlanProtectionDialog(context, ref, protection);
        return false;
      }
    }
    if (!mounted) return false;
    final todayOnly = _removesFromTodayOnly(activity);
    final choice = await showAscentActionMenu<String>(
      context: context,
      title: activity.title,
      actions: [
        if (_canReschedule) ...[
          const AscentAction(
            'tomorrow',
            'Move to tomorrow',
            Icons.next_plan_outlined,
          ),
          const AscentAction('pick', 'Pick a day', Icons.event_outlined),
        ],
        AscentAction(
          'delete',
          todayOnly ? 'Remove from today' : 'Delete',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || choice == null) return false;
    if (choice == 'delete') return true;
    final now = DateTime.now();
    DateTime? day;
    if (choice == 'tomorrow') {
      day = DateTime(now.year, now.month, now.day + 1);
    } else {
      final current = activity.plannedDate;
      final today = DateTime(now.year, now.month, now.day);
      day = await showDatePicker(
        context: context,
        initialDate: current != null && !current.isBefore(today)
            ? current
            : today.add(const Duration(days: 1)),
        firstDate: today,
        lastDate: DateTime(now.year + 2, now.month, now.day),
      );
    }
    if (day != null && mounted) await _rescheduleWithUndo(day);
    return false;
  }

  /// Moves the task (and its reminders) to [day], keeping its time of day.
  Future<void> _rescheduleWithUndo(DateTime day) async {
    final dao = ref.read(taskDaoProvider);
    final id = activity.linkedTaskId!;
    final original = activity.plannedDate;
    final title = activity.title;
    try {
      final moved = await dao.moveToDay(id, day);
      if (!mounted) return;
      if (!moved) {
        AscentSnackBar.show(
          context,
          message: 'This activity could not be moved.',
        );
        return;
      }
      HapticFeedback.lightImpact();
      final now = DateTime.now();
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final when = DateUtils.isSameDay(day, tomorrow)
          ? 'tomorrow'
          : DateFormat('EEE, d MMM').format(day);
      showUndoSnackbar(
        context,
        message: 'Moved “$title” to $when',
        onUndo: () async {
          if (original != null) {
            await dao.moveToDay(id, original);
          } else {
            // It had no date: make it an anytime thing again.
            await dao.updateTask(
              TaskTableCompanion(
                id: Value(id),
                plannedDate: const Value(null),
                updatedAt: Value(DateTime.now()),
              ),
            );
          }
        },
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not move this activity. Please retry.',
        );
      }
    }
  }

  Future<void> _deleteWithUndo() async {
    HapticFeedback.mediumImpact();
    // Capture dependencies before the row disappears from its parent stream.
    final container = ProviderScope.containerOf(context, listen: false);
    final removed = activity;
    final taskDao = container.read(taskDaoProvider);
    final dismissed = container.read(
      dismissedTodayActivityIdsProvider.notifier,
    );
    // Never leave a dismissed Dismissible in the tree while awaiting I/O.
    setState(() => _removed = true);
    try {
      await deleteTodayActivity(container, removed);
      if (!mounted) return;
      showUndoSnackbar(
        context,
        message: _removesFromTodayOnly(removed)
            ? 'Removed “${removed.title}” from today'
            : 'Deleted “${removed.title}”',
        onUndo: () async {
          try {
            if (removed.linkedTaskId != null &&
                removed.sourceType != 'lecture') {
              final restored = await taskDao.restoreDeletedTask(
                removed.linkedTaskId!,
              );
              if (!restored) throw StateError('not restored');
            }
            await dismissed.unDismissActivityId(removed.id);
            if (mounted) setState(() => _removed = false);
          } catch (_) {
            if (mounted) {
              AscentSnackBar.error(
                context,
                message: 'Could not restore this activity.',
              );
            }
          }
        },
      );
    } catch (_) {
      await dismissed.unDismissActivityId(removed.id);
      if (mounted) {
        setState(() => _removed = false);
        AscentSnackBar.error(
          context,
          message: 'Could not delete this activity. Try again.',
        );
      }
    }
  }

  static Widget _swipeBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final leading = alignment == Alignment.centerLeft;
    final content = [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 6),
      Text(label, style: AscentTextStyles.labelMedium.copyWith(color: color)),
    ];
    return Container(
      alignment: alignment,
      padding: EdgeInsets.only(
        left: leading ? AppSpace.s16 : 0,
        right: leading ? 0 : AppSpace.s16,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: context.isDark ? 0.20 : 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: leading ? content : content.reversed.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_removed) return const SizedBox.shrink();
    if (widget.compact) return _compactRow(context);
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: _swipeable(
          key: ValueKey(activity.id),
          enabled: !isDone,
          child: GestureDetector(
            onLongPress: () => showActivityActions(context, ref, activity),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(minHeight: 58),
              margin: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: isDone
                ? g.sage.withValues(alpha: .10)
                : isRunning
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
              color: isDone
                  ? g.sage.withValues(alpha: .5)
                  : isRunning
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
                                if (activity.isScheduledInFuture) {
                                  HapticFeedback.lightImpact();
                                  final timeStr = activity.scheduledTime != null
                                      ? DateFormat(
                                          'h:mm a',
                                        ).format(activity.scheduledTime!)
                                      : 'later';
                                  AscentSnackBar.show(
                                    context,
                                    message:
                                        'Scheduled for $timeStr. You can complete it once that time arrives.',
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
                                            ? (activity.isDailyStanding
                                                  ? 'Completed for today • Resets tomorrow'
                                                  : 'Task completed')
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
                            width: isDone ? 40 : 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: isDone
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: isDone
                                  ? BorderRadius.circular(8)
                                  : null,
                              color: isDone
                                  ? g.sage.withValues(alpha: .12)
                                  : (isRunning
                                        ? g.clay.withValues(alpha: .12)
                                        : (activity.isScheduledInFuture
                                              ? g.ink.withValues(alpha: .04)
                                              : AppPalette.transparent)),
                              border: Border.all(
                                color: isDone
                                    ? g.sage
                                    : (isPaused
                                          ? (g.frozen
                                                ? FrozenPalette.action
                                                : (g.merlot
                                                      ? MerlotPalette
                                                            .antiqueGold
                                                      : g.clay))
                                          : (isRunning
                                                ? g.clay
                                                : (activity.isScheduledInFuture
                                                      ? g.inkMuted
                                                      : g.inkMuted))),
                                width: 1.75,
                              ),
                            ),
                            child: isDone
                                ? Center(
                                    child: Text(
                                      'Done',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: context.doneInk,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  )
                                : activity.isScheduledInFuture
                                ? Center(
                                    child: Icon(
                                      Icons.schedule_rounded,
                                      size: 13,
                                      color: g.inkMuted,
                                    ),
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
                      onTap: isLecture
                          ? () => _openActivityLecture(context, ref, activity)
                          : isDone
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              if (isRunning || isPaused) {
                                context.push('/focus');
                                return;
                              }
                              showActivityDetailDialog(context, ref, activity);
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
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w600,
                                    height: 1.30,
                                    letterSpacing: -0.2,
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
                              style: AscentTextStyles.interfaceSupporting
                                  .copyWith(color: g.clay),
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
                                  style: AscentTextStyles.interfaceSupporting
                                      .copyWith(
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
                                    decoration: BoxDecoration(
                                      color: context.isDark
                                          ? MerlotPalette.darkAction
                                          : MerlotPalette.action,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                                Text(
                                  _subtitleText(activity),
                                  style: AscentTextStyles.interfaceSupporting
                                      .copyWith(
                                        color:
                                            (g.merlot &&
                                                activity.kind ==
                                                    ActivityKind.todo &&
                                                !isDone)
                                            ? (context.isDark
                                                  ? MerlotPalette
                                                        .darkSecondaryInk
                                                  : MerlotPalette.action)
                                            : g.inkMuted,
                                        fontWeight:
                                            (g.merlot &&
                                                activity.kind ==
                                                    ActivityKind.todo &&
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
                                  style: AscentTextStyles.interfaceSupporting
                                      .copyWith(color: context.stateDanger)
                                      .merge(AppTypeRoles.typeRole8),
                                ),
                              ],
                              if (activity.isDailyStanding) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.repeat_rounded,
                                  size: 12,
                                  color: isDone ? g.inkMuted : g.clay,
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
                  if (isLecture) ...[
                    IconButton(
                      tooltip: 'Open lecture',
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _openActivityLecture(context, ref, activity);
                      },
                      icon: Icon(
                        Icons.open_in_new_rounded,
                        color: g.clay,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                  ] else if (isDone) ...[
                    const SizedBox(width: 8),
                  ] else if (activity.kind == ActivityKind.todo &&
                      !isTimed) ...[
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
              if (isTimed &&
                  !isDone &&
                  activity.targetMinutes != null &&
                  activity.targetMinutes! > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: g.track,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: g.line.withValues(alpha: 0.4),
                        width: 0.5,
                      ),
                    ),
                    child: LinearProgressIndicator(
                      key: ValueKey('activity_timer_progress_${activity.id}'),
                      value:
                          (activity.elapsedSecondsToday /
                                  (activity.targetMinutes! * 60))
                              .clamp(0.0, 1.0),
                      minHeight: 5,
                      color: g.clay,
                      backgroundColor: Colors.transparent,
                      semanticsLabel: 'Focus time progress',
                    ),
                  ),
                ),
              ],
              if (dueCheckIn != null)
                _buildCheckInResponseBar(context, ref, g, dueCheckIn),
            ],
          ),
        ),
      ),
        )));
  }

  Future<void> _setStar(bool selected) async {
    final id = activity.linkedTaskId;
    if (id == null || activity.status == TodayActivityStatus.done) return;
    final saved = await ref
        .read(taskDaoProvider)
        .updateTask(
          TaskTableCompanion(
            id: Value(id),
            priority: Value(selected ? 'high' : 'low'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (!saved) throw StateError('Could not save star');
    if (mounted) {
      AscentSnackBar.show(
        context,
        message: selected
            ? 'Marked important · Pinned to top of Today'
            : 'Removed from important',
      );
    }
  }

  Widget _compactRow(BuildContext context) {
    final g = context.glass;
    final accessibleTitle =
        widget.hubStyle && MediaQuery.textScalerOf(context).scale(1) >= 1.45;
    final done = activity.status == TodayActivityStatus.done;
    final visualDone = done || _completing;
    final running = activity.status == TodayActivityStatus.inProgress;
    final paused = activity.status == TodayActivityStatus.paused;
    final lecture = activity.sourceType == 'lecture';
    final timed =
        !lecture &&
        (activity.kind != ActivityKind.todo ||
            (activity.targetMinutes ?? 0) > 0);

    // When it was created is noise on a to-do row (CLAUDE.md §5.2: one meta
    // line of time · duration · category).
    const String? createdLabel = null;
    final String? finishedLabel = (visualDone && activity.completedAt != null)
        ? 'Finished ${_formatActivityTimestamp(activity.completedAt!)}'
        : null;

    final String? timeLabel = (widget.hubStyle && activity.scheduledTime != null)
        ? DateFormat('h:mm a').format(activity.scheduledTime!)
        : (activity.sourceType == 'medicine' && activity.plannedDate != null)
            ? DateFormat('h:mm a').format(activity.plannedDate!)
            : createdLabel;

    final status = visualDone
        ? [
            if (finishedLabel != null) finishedLabel else 'Completed',
            if (finishedLabel == null && timeLabel != null) timeLabel,
          ].join(' · ')
        : [
            if (activity.sourceType == 'medicine') 'Medicine',
            if (lecture) (running ? 'Lecture in progress' : 'Lecture'),
            ?timeLabel,
            if (timed && (activity.targetMinutes ?? 0) > 0)
              '${activity.targetMinutes} min',
          ].join(' · ');

    final actionLabel = done
        ? 'Done'
        : timed
        ? (running
              ? 'Pause'
              : paused
              ? 'Resume'
              : 'Start')
        : 'Done';

    Future<void> completeTask() async {
      final target = activity;
      if (done || _completing) return;
      if (target.isScheduledInFuture) {
        HapticFeedback.lightImpact();
        final timeStr = target.scheduledTime != null
            ? DateFormat('h:mm a').format(target.scheduledTime!)
            : 'later';
        AscentSnackBar.show(
          context,
          message:
              'Scheduled for $timeStr. You can complete it once that time arrives.',
        );
        return;
      }
      if (target.linkedTaskId == null) return;
      final dao = ref.read(taskDaoProvider);
      final animate = !MediaQuery.disableAnimationsOf(context);
      setState(() => _completing = true);
      HapticFeedback.mediumImpact();
      try {
        if (animate) {
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
        final undo = await dao.completeWithUndo(target.linkedTaskId!);
        final task = await dao.getTaskById(target.linkedTaskId!);
        if (task?.actualCompletedDate != null && context.mounted) {
          if (widget.onViewCompleted != null) {
            AscentSnackBar.show(
              context,
              message: 'Task completed',
              icon: Icons.check_circle_rounded,
              actionLabel: 'View completed',
              onAction: () => widget.onViewCompleted?.call(),
            );
          } else {
            AscentSnackBar.applaud(
              context,
              message: target.isDailyStanding
                  ? 'Bravo! Completed for today 👏'
                  : 'Bravo! Task completed! 👏',
              subtitle: target.isDailyStanding
                  ? 'Resets tomorrow to keep your daily rhythm'
                  : 'One step closer to your goals ✨',
              onUndo: undo == null
                  ? null
                  : () async {
                      try {
                        final restored = await dao.undoCompletion(undo);
                        if (!restored && context.mounted) {
                          AscentSnackBar.show(
                            context,
                            message:
                                'This activity has changed. Undo is no longer available.',
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          AscentSnackBar.error(
                            context,
                            message: 'Could not undo. Please retry.',
                          );
                        }
                      }
                    },
            );
          }
        } else if (context.mounted && task?.actualCompletedDate == null) {
          AscentSnackBar.show(
            context,
            message: 'Finish the checklist steps before completing this task.',
          );
        }
      } catch (_) {
        if (context.mounted) {
          AscentSnackBar.error(
            context,
            message: 'Could not complete the task. Please retry.',
          );
        }
      } finally {
        if (mounted) setState(() => _completing = false);
      }
    }

    Widget buildLeadingTarget() {
      Widget content;
      if (lecture) {
        content = Icon(
          Icons.school_outlined,
          size: 20,
          color: running ? SharedControlColors.actionBlue : g.inkMuted,
        );
      } else if (timed) {
        content = Icon(
          running ? Icons.timer_rounded : Icons.timer_outlined,
          size: 20,
          color: running
              ? SharedControlColors.actionBlue
              : (paused ? g.clay : g.inkMuted),
        );
      } else if (activity.isScheduledInFuture) {
        content = Icon(Icons.schedule_rounded, size: 20, color: g.inkMuted);
      } else {
        content = Semantics(
          button: true,
          label: _completing
              ? 'Completing task'
              : (done ? 'Completed' : 'Mark complete'),
          child: InkResponse(
            key: ValueKey('activity_action_${activity.id}'),
            onTap: visualDone ? null : completeTask,
            radius: 18,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutBack,
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: visualDone
                    ? SharedControlColors.actionBlue
                    : Colors.transparent,
                border: Border.all(
                  color: visualDone
                      ? SharedControlColors.actionBlue
                      : (context.isDark
                            ? g.inkMuted.withValues(alpha: 0.6)
                            : g.ink.withValues(alpha: 0.35)),
                  width: 1.6,
                ),
              ),
              child: AnimatedScale(
                scale: visualDone ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.elasticOut,
                child: const Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
      }

      return Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 10),
        child: content,
      );
    }

    final Widget? timedAction = (timed && !done)
        ? (activity.isScheduledInFuture
              ? Semantics(
                  button: true,
                  label:
                      'Scheduled for ${activity.scheduledTime != null ? DateFormat('h:mm a').format(activity.scheduledTime!) : 'later'}',
                  child: InkWell(
                    key: ValueKey('activity_scheduled_${activity.id}'),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final timeStr = activity.scheduledTime != null
                          ? DateFormat('h:mm a').format(activity.scheduledTime!)
                          : 'later';
                      AscentSnackBar.show(
                        context,
                        message:
                            'Scheduled for $timeStr. You can complete it once that time arrives.',
                      );
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: g.ink.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: g.ink.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 12, color: g.clay),
                          const SizedBox(width: 4),
                          Text(
                            widget.hubStyle
                                ? 'Scheduled'
                                : activity.scheduledTime != null
                                ? DateFormat(
                                    'h:mm a',
                                  ).format(activity.scheduledTime!)
                                : '',
                            style: TextStyle(
                              color: g.ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  child: Center(
                    child: OutlinedButton.icon(
                      key: ValueKey('activity_action_${activity.id}'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: running
                            ? SharedControlColors.dueRed.withValues(alpha: 0.12)
                            : SharedControlColors.actionBlue.withValues(
                                alpha: 0.08,
                              ),
                        foregroundColor: running
                            ? SharedControlColors.dueRed
                            : (context.isDark
                                  ? SharedControlColors.actionBlueDark
                                  : SharedControlColors.actionBlue),
                        side: BorderSide(
                          color: (running
                                  ? SharedControlColors.dueRed
                                  : SharedControlColors.actionBlue)
                              .withValues(
                            alpha: context.isDark ? 0.55 : 0.35,
                          ),
                          width: 1.0,
                        ),
                        minimumSize: const Size(0, 26),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        running
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 13,
                      ),
                      label: Text(actionLabel),
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        if (_timerActionBusy) return;
                        setState(() => _timerActionBusy = true);
                        try {
                          if (lecture) {
                            if (_selectLecture(ref, activity)) {
                              ref
                                  .read(learningHubProvider.notifier)
                                  .togglePlayPause();
                            }
                          } else {
                            final tracker =
                                ref.read(timeTrackingProvider.notifier);
                            if (running) {
                              final session = ref
                                  .read(timeTrackingProvider)
                                  .activeSession;
                              final matches = session != null &&
                                  (activity.linkedSessionId != null
                                      ? session.id == activity.linkedSessionId
                                      : activity.linkedTaskId != null &&
                                          session.linkedTaskId ==
                                              activity.linkedTaskId);
                              if (!matches) throw StateError('Timer changed');
                              await tracker.pauseSession();
                            } else {
                              await tracker.switchToTask(
                                title: activity.title,
                                taskId: activity.linkedTaskId,
                                sourceType: activity.sourceType,
                                autoStart: true,
                              );
                            }
                          }
                        } catch (_) {
                          if (context.mounted) {
                            AscentSnackBar.error(
                              context,
                              message:
                                  'Could not update this timer. Please retry.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _timerActionBusy = false);
                        }
                      },
                    ),
                  ),
                ))
        : null;

    final Widget? lectureAction = (lecture && !done)
        ? IconButton(
            key: ValueKey('activity_lecture_open_${activity.id}'),
            tooltip: 'Open in Learning Hub',
            icon: Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: g.clay,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              _openActivityLecture(context, ref, activity);
            },
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          )
        : null;

    final Widget? scheduledBadge = (!timed && activity.isScheduledInFuture)
        ? Semantics(
            button: true,
            label:
                'Scheduled for ${activity.scheduledTime != null ? DateFormat('h:mm a').format(activity.scheduledTime!) : 'later'}',
            child: InkWell(
              key: ValueKey('activity_scheduled_${activity.id}'),
              onTap: () {
                HapticFeedback.lightImpact();
                final timeStr = activity.scheduledTime != null
                    ? DateFormat('h:mm a').format(activity.scheduledTime!)
                    : 'later';
                AscentSnackBar.show(
                  context,
                  message:
                      'Scheduled for $timeStr. You can complete it once that time arrives.',
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 28),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: g.ink.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: g.ink.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule_rounded, size: 12, color: g.clay),
                    const SizedBox(width: 4),
                    Text(
                      activity.scheduledTime != null
                          ? DateFormat('h:mm a').format(activity.scheduledTime!)
                          : '',
                      style: TextStyle(
                        color: g.ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;

    final isStarred = activity.priority == 'high' && !done;
    final softBorderColor = widget.ground
        ? Colors.transparent
        : (isStarred
              ? SharedControlColors.actionBlue.withValues(
                  alpha: context.isDark ? 0.38 : 0.28,
                )
              : g.line.withValues(alpha: context.isDark ? 0.20 : 0.25));
    final cardColor = widget.ground
        ? Colors.transparent
        : (isStarred
              ? (context.isDark
                    ? SharedControlColors.actionBlue.withValues(alpha: 0.08)
                    : SharedControlColors.actionBlue.withValues(alpha: 0.035))
              : (context.isDark
                    ? g.fill.withValues(alpha: 0.18)
                    : Theme.of(context).colorScheme.surface));

    final rowContent = AscentPressFeedback(
      child: Material(
          color: widget.featured
              ? Colors.transparent
              : timed && !done && (running || paused)
              ? SharedControlColors.actionBlue.withValues(
                  alpha: context.isDark ? .09 : .035,
                )
              : cardColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => lecture
                ? _openActivityLecture(context, ref, activity)
                : _showActivityDetailDialog(context, ref, activity),
            onLongPress: () => showActivityActions(context, ref, activity),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: widget.ground
                    ? null
                    : Border.all(color: softBorderColor, width: 0.65),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: widget.ground ? 4 : 12,
                vertical: timed ? 10 : (widget.ground ? 6 : 8.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (!widget.featured) buildLeadingTarget(),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activity.title,
                              key: ValueKey('activity_title_${activity.id}'),
                              maxLines: lecture
                                  ? 1
                                  : (accessibleTitle
                                        ? null
                                        : (widget.featured ? 4 : 2)),
                              overflow: TextOverflow.ellipsis,
                              softWrap: !lecture,
                              style: TextStyle(
                                color: visualDone ? g.inkMuted : g.ink,
                                fontSize: widget.featured
                                    ? 22
                                    : (widget.ground ? 16 : 15),
                                fontWeight: widget.ground
                                    ? (done ? FontWeight.w500 : FontWeight.w600)
                                    : FontWeight.normal,
                                height: 1.35,
                                decoration: visualDone
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (status.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2.5),
                                child: Row(
                                  children: [
                                    Icon(
                                      visualDone
                                          ? Icons.check_circle_outline_rounded
                                          : (activity.scheduledTime != null
                                                ? Icons.schedule_rounded
                                                : Icons.access_time_rounded),
                                      size: 11.5,
                                      color: visualDone
                                          ? context.doneInk
                                          : g.inkMuted,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        status,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: visualDone
                                              ? context.doneInk
                                              : g.inkMuted,
                                          fontSize: 11.5,
                                          fontWeight: visualDone
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (activity.linkedTaskId != null && !done)
                        // On timed tasks, only show star button if marked high-priority to prevent multi-button clustering
                        if (timedAction == null || activity.priority == 'high')
                          AscentStarButton(
                            key: ValueKey('activity_priority_${activity.id}'),
                            selected: activity.priority == 'high',
                            onChanged: _setStar,
                          ),

                      if (scheduledBadge != null && !widget.hubStyle) ...[
                        const SizedBox(width: 6),
                        scheduledBadge,
                      ],
                      if (done && !widget.hubStyle) ...[
                        const SizedBox(width: 6),
                        const Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: GlassChip(
                              label: 'Done',
                              icon: Icons.check_rounded,
                              selected: true,
                              success: true,
                              tooltip: 'Completed',
                            ),
                          ),
                        ),
                      ],
                      if (lectureAction != null) ...[
                        const SizedBox(width: 4),
                        lectureAction,
                      ],
                      InkResponse(
                        radius: 16,
                        onTap: () =>
                            showActivityActions(context, ref, activity),
                        child: Tooltip(
                          message: 'Activity actions',
                          child: SizedBox(
                            width: 32,
                            height: 44,
                            child: Icon(
                              Icons.more_horiz_rounded,
                              size: 18,
                              color: g.inkMuted,
                            ),
                          ),
                        ),
                      ),
                      if (!done && !timed)
                        SizedBox(
                          width: 1,
                          height: 1,
                          child: OverflowBox(
                            minWidth: 48,
                            minHeight: 48,
                            maxWidth: 48,
                            maxHeight: 48,
                            child: Opacity(
                              opacity: 0.001,
                              child: FilledButton(
                                onPressed: completeTask,
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Done'),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (widget.featured &&
                      !timed &&
                      !done &&
                      !activity.isScheduledInFuture) ...[
                    const SizedBox(height: 16),
                    AscentButton.primary(
                      label: 'Mark complete',
                      icon: Icons.check_rounded,
                      loading: _completing,
                      onPressed: completeTask,
                    ),
                  ],
                  // The timer block appears once a timer has started (or on
                  // the featured row). Before that, a due item shows only its
                  // Start button; a future one shows nothing extra.
                  if (timed &&
                      !widget.featured &&
                      !running &&
                      !paused &&
                      activity.elapsedSecondsToday == 0)
                    if (timedAction != null &&
                        !activity.isScheduledInFuture)
                      Padding(
                        padding: const EdgeInsets.only(left: 42, top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: timedAction,
                        ),
                      )
                    else
                      const SizedBox.shrink()
                  else if (timed)
                    Padding(
                      padding: EdgeInsets.only(
                        left: widget.featured ? 0 : 42,
                        top: widget.featured ? 12 : 4,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final progress = ActivityTimerProgress(
                            activity: activity,
                          );
                          if (MediaQuery.textScalerOf(context).scale(14) > 21 ||
                              constraints.maxWidth < 200) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                progress,
                                if (timedAction != null) ...[
                                  const SizedBox(height: 8),
                                  timedAction,
                                ],
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: progress),
                              if (timedAction != null) ...[
                                const SizedBox(width: 14),
                                timedAction,
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: timed ? 4 : (widget.ground ? 0 : 2.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: _swipeable(
          key: ValueKey('activity_dismiss_${activity.id}'),
          enabled: !done && !_completing,
          child: IgnorePointer(
            ignoring: _completing,
            child: AnimatedSlide(
              offset: _completing ? const Offset(0, -.025) : Offset.zero,
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
              ),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _completing ? .55 : 1,
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
                ),
                child: rowContent,
              ),
            ),
          ),
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
                  style: AscentTextStyles.interfaceSupporting.copyWith(
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
                  final minutes = await showAscentActionMenu<int>(
                    context: context,
                    title: 'Ask me again in…',
                    actions: const [
                      AscentAction(15, '15 minutes', Icons.schedule_rounded),
                      AscentAction(30, '30 minutes', Icons.schedule_rounded),
                      AscentAction(60, '1 hour', Icons.schedule_rounded),
                    ],
                  );
                  final delay = minutes == null
                      ? null
                      : Duration(minutes: minutes);
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
}

String _subtitleText(TodayActivityItem act) => formatActivitySubtitleText(act);
String _formatActivityTimestamp(DateTime dt) => formatActivityTimestamp(dt);
