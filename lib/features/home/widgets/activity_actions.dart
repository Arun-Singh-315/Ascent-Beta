import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_detail_sheet.dart';
import 'package:ascent/features/plans/widgets/plan_protection_dialog.dart';
import 'package:ascent/features/study_plan/lecture_focus_player_sheet.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'package:ascent/shared/widgets/ascent_action_menu.dart';
import 'package:ascent/shared/widgets/ascent_dialog.dart';
import 'package:ascent/shared/widgets/ascent_snack_bar.dart';
import 'package:ascent/shared/widgets/undo_snackbar.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

bool removesActivityFromTodayOnly(TodayActivityItem activity) =>
    activity.sourceType == 'lecture' || activity.linkedTaskId == null;

bool selectActivityLecture(WidgetRef ref, TodayActivityItem activity) {
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

void openActivityLecture(
  BuildContext context,
  WidgetRef ref,
  TodayActivityItem activity,
) {
  if (selectActivityLecture(ref, activity)) {
    LectureFocusPlayerSheet.show(context);
  } else {
    AscentSnackBar.error(
      context,
      message:
          'This lecture is no longer available. Choose another in Learning.',
    );
  }
}

/// Completes a Home activity with an Undo snackbar. Shared with the Now card.
Future<void> completeActivityWithUndo(
  BuildContext context,
  WidgetRef ref,
  TodayActivityItem activity,
) async {
  if (activity.linkedTaskId == null || activity.sourceType == 'lecture') return;

  if (activity.isScheduledInFuture) {
    AscentSnackBar.show(
      context,
      message:
          'You can complete this activity once its scheduled time arrives.',
    );
    return;
  }
  try {
    final dao = ref.read(taskDaoProvider);
    final undo = await dao.completeWithUndo(activity.linkedTaskId!);
    if (!context.mounted) return;
    if (undo == null) {
      AscentSnackBar.show(
        context,
        message:
            'This activity could not be completed. Check its steps and completion requirements.',
      );
    } else {
      AscentSnackBar.applaud(
        context,
        message: 'Activity completed',
        onUndo: () async {
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
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(
        context,
        message: 'Could not complete the activity. Please retry.',
      );
    }
  }
  return;
}

Future<void> showActivityActions(
  BuildContext context,
  WidgetRef ref,
  TodayActivityItem activity,
) async {
  final isDone = activity.status == TodayActivityStatus.done;
  final isLecture = activity.sourceType == 'lecture';
  final action = await showAscentActionMenu<String>(
    context: context,
    title: activity.title,
    actions: [
      const AscentAction('view', 'View details', Icons.open_in_new_rounded),
      if (!isDone &&
          !isLecture &&
          activity.linkedTaskId != null &&
          activity.kind == ActivityKind.todo &&
          (activity.targetMinutes ?? 0) <= 0)
        const AscentAction(
          'done',
          'Mark as done',
          Icons.check_circle_outline_rounded,
        ),
      if (!isDone && activity.linkedTaskId != null && !isLecture)
        AscentAction(
          'star',
          activity.priority == 'high' ? 'Remove star' : 'Mark important',
          activity.priority == 'high'
              ? Icons.star_rounded
              : Icons.star_border_rounded,
        ),
      if (activity.linkedTaskId != null && !isDone && !isLecture)
        const AscentAction(
          'tomorrow',
          'Move to tomorrow',
          Icons.next_plan_outlined,
        ),
      if (!isLecture && activity.linkedTaskId != null && !isDone)
        const AscentAction('edit', 'Edit activity', Icons.edit_outlined),
      AscentAction(
        'delete',
        removesActivityFromTodayOnly(activity)
            ? 'Remove from today'
            : 'Delete activity',
        Icons.delete_outline_rounded,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted || action == null) return;
  if (action == 'view') {
    if (isLecture) {
      openActivityLecture(context, ref, activity);
    } else {
      showActivityDetailDialog(context, ref, activity);
    }
    return;
  }
  if (action == 'done') {
    await completeActivityWithUndo(context, ref, activity);
    return;
  }
  if (action == 'star') {
    try {
      final saved = await ref
          .read(taskDaoProvider)
          .updateTask(
            TaskTableCompanion(
              id: Value(activity.linkedTaskId!),
              priority: Value(activity.priority == 'high' ? 'low' : 'high'),
              updatedAt: Value(DateTime.now()),
            ),
          );
      if (!saved) throw StateError('Could not save star');
    } catch (_) {
      if (context.mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not save the star. Please retry.',
        );
      }
    }
    return;
  }
  try {
    final dao = ref.read(taskDaoProvider);
    if (activity.linkedTaskId != null) {
      final protection = await dao.getTaskProtection(activity.linkedTaskId!);
      if (!context.mounted) return;
      if (protection != null) {
        await showPlanProtectionDialog(
          context,
          ref,
          protection,
          manageOnly: action != 'delete',
        );
        return;
      }
    }
    if (!context.mounted) return;
    if (action == 'tomorrow') {
      final now = DateTime.now();
      final current = activity.scheduledTime ?? activity.plannedDate;
      final tomorrow = DateTime(
        now.year,
        now.month,
        now.day + 1,
        current?.hour ?? 0,
        current?.minute ?? 0,
      );
      final moved = await dao.moveToDay(activity.linkedTaskId!, tomorrow);
      if (!moved) throw StateError('This activity could not be moved');
      if (context.mounted) {
        AscentSnackBar.show(context, message: 'Moved to tomorrow');
      }
    } else if (action == 'edit') {
      final confirmed = await AscentDialog.confirm(
        context: context,
        title: 'Edit this activity?',
        content:
            'Open “${activity.title}” to make changes. Nothing changes until you save.',
        confirmLabel: 'Continue editing',
        cancelLabel: 'Keep as is',
        icon: Icons.edit_outlined,
      );
      if (confirmed != true || !context.mounted) return;
      final task = await dao.getTaskById(activity.linkedTaskId!);
      if (!context.mounted) return;
      if (task == null) {
        AscentSnackBar.error(
          context,
          message: 'This activity is no longer available.',
        );
        return;
      }
      await AddActivitySheet.show(context, existingTask: task);
    } else if (action == 'delete') {
      // Undo-first (CLAUDE.md §1.8): no confirmation, Undo in the snackbar.
      HapticFeedback.mediumImpact();
      final container = ProviderScope.containerOf(context, listen: false);
      final removed = activity;
      await deleteTodayActivity(container, removed);
      if (!context.mounted) return;
      showUndoSnackbar(
        context,
        message: removesActivityFromTodayOnly(removed)
            ? 'Removed “${removed.title}” from today'
            : 'Deleted “${removed.title}”',
        onUndo: () async {
          try {
            if (removed.linkedTaskId != null &&
                removed.sourceType != 'lecture') {
              if (!await dao.restoreDeletedTask(removed.linkedTaskId!)) {
                throw StateError('Restore unavailable');
              }
            }
            await container
                .read(dismissedTodayActivityIdsProvider.notifier)
                .unDismissActivityId(removed.id);
          } catch (_) {
            if (context.mounted) {
              AscentSnackBar.error(
                context,
                message: 'Could not restore this activity.',
              );
            }
          }
        },
      );
    }
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(
        context,
        message: 'Could not delete this activity. Try again.',
      );
    }
  }
}

String formatActivityTimestamp(DateTime dt) {
  final now = DateTime.now();
  final isToday =
      dt.year == now.year && dt.month == now.month && dt.day == now.day;
  final timeStr = DateFormat('h:mm a').format(dt);
  if (isToday) {
    return timeStr;
  }
  final yesterday = now.subtract(const Duration(days: 1));
  final isYesterday =
      dt.year == yesterday.year &&
      dt.month == yesterday.month &&
      dt.day == yesterday.day;
  if (isYesterday) {
    return 'yesterday, $timeStr';
  }
  if (dt.year == now.year) {
    return '${DateFormat('MMM d').format(dt)}, $timeStr';
  }
  return '${DateFormat('MMM d, y').format(dt)}, $timeStr';
}

String formatActivitySubtitleText(TodayActivityItem act) {
  final createdStr = act.createdAt != null
      ? ' · Created ${formatActivityTimestamp(act.createdAt!)}'
      : '';

  if (act.sourceType == 'medicine' || act.categoryTag == 'Medicine') {
    final at = act.plannedDate;
    return 'Medicine${at == null ? '' : ' · ${DateFormat.jm().format(at)}'}$createdStr';
  }
  if (act.sourceType == 'study' || act.categoryTag == 'Study') {
    final at = act.plannedDate;
    return 'Study${at == null ? '' : ' · ${DateFormat.jm().format(at)}'}$createdStr';
  }
  if (act.sourceType == 'meal' || act.categoryTag == 'Meal') {
    final at = act.plannedDate;
    return 'Meal${at == null ? '' : ' · ${DateFormat.jm().format(at)}'}$createdStr';
  }

  if (act.status == TodayActivityStatus.done) {
    if (act.isDailyStanding) {
      if (act.completedAt != null) {
        return '✓ Done for today at ${formatActivityTimestamp(act.completedAt!)} • Resets tomorrow$createdStr';
      }
      return '✓ Done for today • Resets tomorrow$createdStr';
    }
    if (act.completedAt != null) {
      return '✓ Done at ${formatActivityTimestamp(act.completedAt!)}$createdStr';
    }
    return '✓ Completed$createdStr';
  }
  if (act.sourceType == 'lecture') {
    if (act.status == TodayActivityStatus.inProgress) {
      return 'Lecture in progress';
    }
    return 'Lecture$createdStr';
  }
  if (act.kind == ActivityKind.todo && (act.targetMinutes ?? 0) <= 0) {
    final p = (act.priority != null && act.priority!.isNotEmpty)
        ? act.priority![0].toUpperCase() + act.priority!.substring(1)
        : 'Medium';
    if (act.isDailyStanding) {
      return 'Daily • $p to-do$createdStr';
    }
    return '$p • To-do$createdStr';
  }
  if (act.kind == ActivityKind.duration || (act.targetMinutes ?? 0) > 0) {
    final targetMins = act.targetMinutes ?? 30;
    if (act.elapsedSecondsToday > 0) {
      final m = act.elapsedSecondsToday ~/ 60;
      final s = act.elapsedSecondsToday % 60;
      final timeStr = '$m:${s.toString().padLeft(2, '0')}';
      return '$timeStr tracked / ${targetMins}m$createdStr';
    }
    return '${targetMins}m target$createdStr';
  }
  return 'Flexible focus$createdStr';
}
