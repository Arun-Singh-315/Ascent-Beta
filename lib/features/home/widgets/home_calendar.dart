import 'package:flutter/material.dart';
import '../../../app/theme/home_design.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../shared/widgets/ascent_calendar_day.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/local_day_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import 'home_outline_surface.dart';

/// Home's primary schedule entry. Browsing dates never changes saved records.
class HomeCalendar extends ConsumerStatefulWidget {
  const HomeCalendar({super.key});

  @override
  ConsumerState<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends ConsumerState<HomeCalendar> {
  int _weekOffset = 0;

  void _open(DateTime day) {
    HapticFeedback.selectionClick();
    context.push('/calendar?date=${DateFormat('yyyy-MM-dd').format(day)}');
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(localDayProvider);
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1 + _weekOffset * 7,
    );
    final days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    final reminders = ref.watch(allRemindersProvider);
    final tasks = ref.watch(allTasksStreamProvider);
    final activities = ref.watch(todayActivitiesProvider);
    final g = context.glass;
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;
    final scheduled = <DateTime>{};
    void mark(DateTime date) =>
        scheduled.add(DateTime(date.year, date.month, date.day));
    for (final reminder in reminders.value ?? const <Reminder>[]) {
      if (reminder.isActive) {
        mark(reminder.scheduledAt);
      }
    }
    for (final task in tasks.value ?? const <Task>[]) {
      if (task.actualCompletedDate == null) mark(task.plannedDate ?? today);
    }
    for (final activity in activities.value ?? const <TodayActivityItem>[]) {
      if (activity.status != TodayActivityStatus.done) {
        mark(activity.plannedDate ?? today);
      }
    }
    final unavailable =
        reminders.hasError || tasks.hasError || activities.hasError;
    final loading =
        reminders.isLoading || tasks.isLoading || activities.isLoading;
    bool thisWeek(DateTime date) =>
        !date.isBefore(monday) &&
        date.isBefore(monday.add(const Duration(days: 7)));
    final openTasks = (tasks.value ?? const <Task>[])
        .where((t) => t.actualCompletedDate == null)
        .toList();
    final taskIds = openTasks.map((t) => t.id).toSet();
    final todoCount =
        openTasks.where((t) => thisWeek(t.plannedDate ?? today)).length +
        (activities.value ?? const <TodayActivityItem>[])
            .where(
              (a) =>
                  a.status != TodayActivityStatus.done &&
                  !taskIds.contains(a.linkedTaskId) &&
                  thisWeek(a.plannedDate ?? today),
            )
            .length;
    final reminderCount = (reminders.value ?? const <Reminder>[])
        .where((r) => r.isActive && thisWeek(r.scheduledAt))
        .length;
    final busyDays = days.where(scheduled.contains).length;
    final month = days.first.month == days.last.month
        ? DateFormat.yMMMM().format(days.first)
        : '${DateFormat.MMM().format(days.first)} – ${DateFormat.yMMM().format(days.last)}';

    return HomeOutlineSurface(
      surfaceKey: const ValueKey('home_calendar'),
      frameless: true,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                month,
                style: HomeType.section.copyWith(color: g.ink, fontSize: 16),
              );
              final controls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Previous week',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _weekOffset--);
                    },
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Next week',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _weekOffset++);
                    },
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  IconButton(
                    key: const ValueKey('home_calendar_open'),
                    tooltip: 'Open full calendar',
                    onPressed: () => _open(_weekOffset == 0 ? today : monday),
                    icon: Icon(
                      Icons.open_in_full_rounded,
                      color: g.clay,
                      size: 18,
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    Align(alignment: Alignment.centerRight, child: controls),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  controls,
                ],
              );
            },
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final accessible =
                  constraints.maxWidth < 7 * 44 ||
                  MediaQuery.textScalerOf(context).scale(14) > 21;
              final columns = accessible ? 4 : 7;
              final spacing = accessible ? 4.0 : 0.0;
              final width =
                  (constraints.maxWidth - (columns - 1) * spacing) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: 8,
                children: [
                  for (final day in days)
                    SizedBox(
                      width: width,
                      child: AscentCalendarDay(
                        key: ValueKey(
                          'home_calendar_day_${DateFormat('yyyy-MM-dd').format(day)}',
                        ),
                        date: day,
                        compact: true,
                        today: sameDay(day, today),
                        hasScheduledItems: scheduled.contains(day),
                        weekdayLabel: DateFormat('EEEEE').format(day),
                        onTap: () => _open(day),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            busyDays == 0
                ? 'Your week, at a glance.'
                : '$todoCount ${todoCount == 1 ? 'to-do' : 'to-dos'} · $reminderCount ${reminderCount == 1 ? 'reminder' : 'reminders'} · $busyDays planned days',
            style: HomeType.supporting.copyWith(color: g.inkSecondary),
          ),
          if (_weekOffset != 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: g.ink,
                  minimumSize: const Size(48, 48),
                ),
                onPressed: () => setState(() => _weekOffset = 0),
                child: const Text('Back to today'),
              ),
            )
          else if (unavailable || loading)
            Text(
              unavailable
                  ? 'Some schedule markers could not load. Open calendar to retry.'
                  : 'Loading your schedule…',
              style: HomeType.supporting.copyWith(color: g.inkSecondary),
            ),
        ],
      ),
    );
  }
}
