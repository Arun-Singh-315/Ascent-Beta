import '../../promises/providers/promise_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/daily_briefing_provider.dart';
import '../../../core/providers/database_provider.dart';

/// One reactive source for task nudges and the words used in the recap.
final islandTasksProvider = StreamProvider.autoDispose<List<Task>>((ref) {
  final promises = ref.watch(allPromisesStreamProvider);
  final privateIds = ref.watch(privatePromiseIdsProvider);
  return ref
      .watch(taskDaoProvider)
      .watchAllTasks()
      .map(
        (tasks) => tasks
            .where(
              (task) =>
                  task.linkedThoughtId == null ||
                  (promises.hasValue &&
                      !privateIds.contains(task.linkedThoughtId)),
            )
            .toList(),
      );
});

final islandStarredTasksProvider = Provider.autoDispose
    .family<List<Task>, DateTime>((ref, day) {
      return islandStarredTasks(
        ref.watch(islandTasksProvider).value ?? const [],
        day,
      );
    });

List<Task> islandStarredTasks(List<Task> tasks, DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final result = tasks
      .where(
        (task) =>
            task.priority == 'high' &&
            task.actualCompletedDate == null &&
            (task.plannedDate == null || task.plannedDate!.isBefore(tomorrow)),
      )
      .toList();
  result.sort((a, b) {
    final due = (a.plannedDate ?? tomorrow).compareTo(
      b.plannedDate ?? tomorrow,
    );
    return due != 0 ? due : a.id.compareTo(b.id);
  });
  return result;
}

/// Ordinary work keeps the island useful even when nothing is starred.
/// Include unfinished top-level work due today, overdue or still unscheduled.
List<Task> islandPendingTasks(List<Task> tasks, DateTime now) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final pending = tasks
      .where(
        (task) =>
            task.priority != 'high' &&
            task.parentTaskId == null &&
            task.actualCompletedDate == null &&
            (task.plannedDate == null || task.plannedDate!.isBefore(tomorrow)),
      )
      .toList();
  pending.sort((a, b) {
    final due = (a.plannedDate ?? tomorrow).compareTo(
      b.plannedDate ?? tomorrow,
    );
    return due != 0 ? due : a.id.compareTo(b.id);
  });
  return pending;
}

/// Describe actual records without turning the island into a statistics panel.
List<String> islandRecapPoints(
  DailyBriefing briefing,
  List<Task> tasks,
  DateTime now,
) {
  final today = briefingDay(now);
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final completed = tasks
      .where(
        (task) =>
            task.actualCompletedDate != null &&
            !task.actualCompletedDate!.isBefore(yesterday) &&
            task.actualCompletedDate!.isBefore(today),
      )
      .take(2)
      .toList();
  return [
    if (completed.isNotEmpty)
      '• You finished ${completed.map((t) => '“${t.title}”').join(' and ')}.'
    else if (briefing.completedYesterday > 0)
      '• You moved things off your list yesterday.',
    if (briefing.trackedMinutesYesterday > 0)
      '• You recorded time for your activities.',
    if (briefing.nextTask != null)
      '• Next, make a little room for “${briefing.nextTask}”.',
  ];
}
