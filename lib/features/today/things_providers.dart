import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/local_day_provider.dart';
import 'models/things_sections.dart';

/// How far ahead the Upcoming segment looks.
const upcomingWindowDays = 30;

/// Pending things planned after today, within [upcomingWindowDays].
///
/// Plans materialise one task per future occurrence, so only each plan's next
/// occurrence is shown (and nothing from paused, ended or skipped occurrences);
/// otherwise a daily routine would fill the whole list.
final upcomingThingsProvider = StreamProvider<List<TodayActivityItem>>((
  ref,
) async* {
  ref.watch(localDayProvider);
  final taskDao = ref.watch(taskDaoProvider);
  final planDao = ref.watch(planDaoProvider);
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);

  await for (final tasks in taskDao.watchUpcomingTasks(
    upcomingWindowDays + 1,
  )) {
    final seenPlans = <String>{};
    final items = <TodayActivityItem>[];
    for (final task in tasks) {
      final planned = task.plannedDate;
      if (planned == null ||
          planned.isBefore(tomorrow) ||
          task.isDailyStanding ||
          task.learningCourseId != null) {
        continue;
      }
      if (!await _keepPlanTask(planDao, task, seenPlans)) continue;
      items.add(upcomingItemFromTask(task));
    }
    yield items;
  }
});

/// Tasks arrive sorted by planned date, so the first one seen per plan is its
/// next occurrence.
Future<bool> _keepPlanTask(
  PlanDao planDao,
  Task task,
  Set<String> seenPlans,
) async {
  final occurrence = await planDao.getOccurrenceByTaskId(task.id);
  if (occurrence == null) return true;
  if (occurrence.outcome == 'skipped') return false;
  if (!seenPlans.add(occurrence.planId)) return false;
  final plan = await planDao.getPlanById(occurrence.planId);
  return plan == null || (plan.status != 'paused' && plan.status != 'ended');
}
