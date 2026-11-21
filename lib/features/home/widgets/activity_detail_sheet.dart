import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_actions.dart';
import 'package:ascent/features/study_plan/lecture_focus_player_sheet.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'package:ascent/features/today/add_lecture_activity_sheet.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:ascent/shared/widgets/ascent_sheet.dart';
import 'package:ascent/shared/widgets/ascent_snack_bar.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

void showActivityDetailDialog(
  BuildContext context,
  WidgetRef ref,
  TodayActivityItem activity,
) {
  final g = context.glass;
  final isDone = activity.status == TodayActivityStatus.done;
  showAscentSheet<void>(
    context: context,
    builder: (ctx) => SingleChildScrollView(
      key: const ValueKey('activity_detail_sheet'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
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
              if (activity.isDailyStanding) ...[
                const SizedBox(width: 8),
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
                    'Daily Standing',
                    style: AppTypography.inter12W600111(color: g.clay),
                  ),
                ),
              ],
              if ((!isDone || activity.isDailyStanding) &&
                  activity.linkedTaskId != null)
                IconButton(
                  tooltip: 'Edit activity',
                  icon: Icon(Icons.edit_outlined, size: 20, color: g.inkMuted),
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
              Icon(Icons.info_outline_rounded, size: 14, color: g.inkMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  formatActivitySubtitleText(activity),
                  style: AppTypography.inter13Regular6(color: g.inkMuted),
                ),
              ),
            ],
          ),
          if (activity.createdAt != null || activity.completedAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: g.fill.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.25
                      : 0.45,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: g.line.withValues(alpha: 0.5),
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (activity.createdAt != null)
                    Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 14,
                          color: g.inkMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Created: ${DateFormat('EEE, MMM d, y · h:mm a').format(activity.createdAt!)}',
                            style: TextStyle(
                              color: g.inkMuted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (activity.completedAt != null) ...[
                    if (activity.createdAt != null) const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: context.doneInk,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Finished: ${DateFormat('EEE, MMM d, y · h:mm a').format(activity.completedAt!)}',
                            style: TextStyle(
                              color: context.doneInk,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (!isDone &&
              activity.linkedTaskId != null &&
              activity.sourceType != 'lecture') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (activity.kind == ActivityKind.todo)
                  TextButton.icon(
                    icon: Icon(Icons.timer_outlined, size: 16, color: g.clay),
                    label: Text(
                      'Switch to 25m Focus Timer',
                      style: TextStyle(
                        color: g.clay,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await ref
                          .read(taskDaoProvider)
                          .updateTask(
                            TaskTableCompanion(
                              id: Value(activity.linkedTaskId!),
                              estimatedMinutes: const Value(25),
                              updatedAt: Value(DateTime.now()),
                            ),
                          );
                      if (context.mounted) {
                        AscentSnackBar.show(
                          context,
                          message: 'Switched to 25m Focus Timer',
                        );
                      }
                    },
                  )
                else if (activity.kind == ActivityKind.duration)
                  TextButton.icon(
                    icon: Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: g.clay,
                    ),
                    label: Text(
                      'Switch to To-do Checklist',
                      style: TextStyle(
                        color: g.clay,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await ref
                          .read(taskDaoProvider)
                          .updateTask(
                            TaskTableCompanion(
                              id: Value(activity.linkedTaskId!),
                              estimatedMinutes: const Value(null),
                              updatedAt: Value(DateTime.now()),
                            ),
                          );
                      if (context.mounted) {
                        AscentSnackBar.show(
                          context,
                          message: 'Switched to To-do checklist',
                        );
                      }
                    },
                  ),
              ],
            ),
          ],
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
                  await AddLectureActivitySheet.sendTask(context, ref, task);
                }
              },
            ),
          TextButton.icon(
            icon: const Icon(Icons.history_rounded, size: 18),
            label: const Text('History'),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push(
                Uri(
                  path: '/history',
                  queryParameters: {
                    'module': activity.linkedTaskId != null ? 'tasks' : 'focus',
                    'entity':
                        '${activity.linkedTaskId ?? activity.linkedSessionId}',
                  },
                ).toString(),
              );
            },
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
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
              if (!isDone)
                activity.isScheduledInFuture
                    ? FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(ctx).pop();
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
                        },
                        icon: const Icon(Icons.schedule_rounded, size: 14),
                        label: Text(
                          'Scheduled · ${activity.scheduledTime != null ? DateFormat('h:mm a').format(activity.scheduledTime!) : ''}',
                        ),
                        style: context.surfaces.buttonStyle(
                          FilledButton.styleFrom(
                            backgroundColor: g.ink.withValues(alpha: 0.10),
                            foregroundColor: g.ink,
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
                      )
                    : FilledButton(
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
                              if (!selectActivityLecture(ref, activity)) return;
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
                            await completeActivityWithUndo(
                              context,
                              ref,
                              activity,
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
}
