import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/local_day_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/ascent_calendar_day.dart';

class HomeCalendar extends ConsumerStatefulWidget {
  const HomeCalendar({super.key});

  @override
  ConsumerState<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends ConsumerState<HomeCalendar> {
  int _weekOffset = 0;
  DateTime? _selectedDay;

  void _open(DateTime day) {
    HapticFeedback.selectionClick();
    context.push('/calendar?date=${DateFormat('yyyy-MM-dd').format(day)}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
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

    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    final scheduled = <DateTime>{};
    final reminderDates = <DateTime>{};

    void mark(DateTime date, {bool isReminder = false}) {
      final key = DateTime(date.year, date.month, date.day);
      scheduled.add(key);
      if (isReminder) reminderDates.add(key);
    }

    for (final reminder in reminders.value ?? const <Reminder>[]) {
      if (reminder.isActive) {
        mark(reminder.scheduledAt, isReminder: true);
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

    final month = days.first.month == days.last.month
        ? DateFormat.yMMMM().format(days.first)
        : '${DateFormat.MMM().format(days.first)} – ${DateFormat.yMMM().format(days.last)}';

    return Container(
      key: const ValueKey('home_calendar'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Rd.card),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row: Month on left; two 40px icon buttons on right
          LayoutBuilder(
            builder: (context, constraints) {
              final title = InkWell(
                key: const ValueKey('home_calendar_open'),
                onTap: () => _open(_weekOffset == 0 ? today : monday),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    month,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ),
              );
              final controls = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CalendarNavButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: 'Previous week',
                    onTap: () => setState(() => _weekOffset--),
                  ),
                  const SizedBox(width: 4),
                  _CalendarNavButton(
                    icon: Icons.chevron_right_rounded,
                    tooltip: 'Next week',
                    onTap: () => setState(() => _weekOffset++),
                  ),
                ],
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
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
          const SizedBox(height: 10),

          // 7-day strip
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
                        selected: _selectedDay != null && sameDay(day, _selectedDay!),
                        hasScheduledItems: scheduled.contains(DateTime(day.year, day.month, day.day)),
                        weekdayLabel: DateFormat('EEEEE').format(day),
                        onTap: () {
                          setState(() => _selectedDay = day);
                          _open(day);
                        },
                      ),
                    ),
                ],
              );
            },
          ),

          if (_weekOffset != 0)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: c.accent,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 32),
                  ),
                  onPressed: () => setState(() => _weekOffset = 0),
                  child: const Text('Back to today'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarNavButton extends StatelessWidget {
  const _CalendarNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IconButton(
      tooltip: tooltip,
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      icon: Icon(icon, size: 22, color: c.textSecondary),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
    );
  }
}
