import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

/// The four Things Hub segments (CLAUDE.md §5.2).
enum ThingsSegment { today, upcoming, anytime, routines }

extension ThingsSegmentLabel on ThingsSegment {
  String get label => switch (this) {
    ThingsSegment.today => 'Today',
    ThingsSegment.upcoming => 'Upcoming',
    ThingsSegment.anytime => 'Anytime',
    ThingsSegment.routines => 'Routines',
  };
}

/// Maps a `?tab=` deep link to a segment. Legacy values keep working:
/// `now` and `done` open Today, `plans` opens Routines.
ThingsSegment thingsSegmentForTab(String? tab) => switch (tab) {
  'upcoming' => ThingsSegment.upcoming,
  'anytime' => ThingsSegment.anytime,
  'routines' || 'plans' => ThingsSegment.routines,
  _ => ThingsSegment.today,
};

/// A to-do with no date or time that isn't a daily routine.
bool isAnytimeThing(TodayActivityItem a) =>
    a.linkedTaskId != null &&
    a.plannedDate == null &&
    a.scheduledTime == null &&
    !a.isDailyStanding &&
    a.sourceType != 'medicine' &&
    a.sourceType != 'lecture';

/// Whether an item belongs to today's plan. Home's Now card, Home's Things
/// card and the Things Today segment all use this one rule; anytime to-dos
/// live in the Anytime segment instead.
bool isOnTodayList(TodayActivityItem a) => !isAnytimeThing(a);

bool _isDone(TodayActivityItem a) => a.status == TodayActivityStatus.done;

DateTime? _when(TodayActivityItem a) => a.scheduledTime ?? a.plannedDate;

/// Timed items first (earliest first), then untimed ones in their original
/// order. Stable, so equal times keep the provider's order.
List<TodayActivityItem> _byTime(Iterable<TodayActivityItem> items) {
  final list = items.toList();
  final index = {for (final (i, a) in list.indexed) a.id: i};
  list.sort((a, b) {
    final at = a.scheduledTime, bt = b.scheduledTime;
    if (at != null && bt != null) {
      final c = at.compareTo(bt);
      if (c != 0) return c;
    } else if (at != null) {
      return -1;
    } else if (bt != null) {
      return 1;
    }
    return index[a.id]!.compareTo(index[b.id]!);
  });
  return list;
}

/// What the Today segment shows.
class ThingsTodayView {
  const ThingsTodayView({
    required this.overdue,
    required this.today,
    required this.completed,
  });

  /// Pending items from earlier days, oldest first.
  final List<TodayActivityItem> overdue;

  /// Pending items for today: timed first, then untimed.
  final List<TodayActivityItem> today;

  /// Everything finished today, most recent first.
  final List<TodayActivityItem> completed;

  /// Overdue items that "Move all to today" can move.
  Iterable<int> get movableOverdueTaskIds => [
    for (final a in overdue)
      if (a.linkedTaskId != null && !a.isDailyStanding) a.linkedTaskId!,
  ];

  bool get isEmpty => overdue.isEmpty && today.isEmpty && completed.isEmpty;
}

ThingsTodayView groupToday(List<TodayActivityItem> items) {
  final pending = items.where((a) => !_isDone(a));
  final overdue = pending.where((a) => a.isOverdue).toList()
    ..sort((a, b) {
      final at = _when(a), bt = _when(b);
      if (at == null || bt == null) return 0;
      return at.compareTo(bt);
    });
  final completed = items.where(_isDone).toList()
    ..sort((a, b) {
      final at = a.completedAt, bt = b.completedAt;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });
  return ThingsTodayView(
    overdue: overdue,
    today: _byTime(pending.where((a) => !a.isOverdue && !isAnytimeThing(a))),
    completed: completed,
  );
}

/// Pending to-dos with no date, in the order they were added.
List<TodayActivityItem> anytimeThings(List<TodayActivityItem> items) =>
    items.where((a) => !_isDone(a) && isAnytimeThing(a)).toList();

/// Daily routines: the to-dos that come back every day.
List<TodayActivityItem> dailyRoutines(List<TodayActivityItem> items) =>
    _byTime(items.where((a) => a.isDailyStanding));

/// Converts a future task into the row model the Things list renders.
TodayActivityItem upcomingItemFromTask(Task task) {
  final planned = task.plannedDate;
  final minutes = task.estimatedMinutes;
  return TodayActivityItem(
    id: 'task_${task.id}',
    title: task.title,
    sourceType: 'task',
    status: TodayActivityStatus.notStarted,
    elapsedSecondsToday: 0,
    linkedTaskId: task.id,
    categoryTag: task.priority == 'high' ? 'High Priority' : 'Task',
    priority: task.priority,
    kind: minutes != null && minutes > 0
        ? ActivityKind.duration
        : minutes == -1
        ? ActivityKind.flexible
        : ActivityKind.todo,
    targetMinutes: minutes != null && minutes > 0 ? minutes : null,
    plannedDate: planned,
    scheduledTime: planned != null && (planned.hour != 0 || planned.minute != 0)
        ? planned
        : null,
    notes: task.notes,
    createdAt: task.createdAt,
  );
}

/// One day in the Upcoming segment.
class UpcomingDay {
  const UpcomingDay(this.day, this.items);
  final DateTime day;
  final List<TodayActivityItem> items;
}

/// Groups future items by calendar day, starting tomorrow.
List<UpcomingDay> groupUpcoming(
  Iterable<TodayActivityItem> items,
  DateTime now,
) {
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  final byDay = <DateTime, List<TodayActivityItem>>{};
  for (final item in items) {
    final when = item.plannedDate;
    if (when == null) continue;
    final day = DateTime(when.year, when.month, when.day);
    if (day.isBefore(tomorrow)) continue;
    byDay.putIfAbsent(day, () => []).add(item);
  }
  final days = byDay.keys.toList()..sort();
  return [for (final d in days) UpcomingDay(d, _byTime(byDay[d]!))];
}

/// "Tomorrow", a weekday within the next week, or "Mon, 30 Nov".
String upcomingDayLabel(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (diff == 1) return 'Tomorrow';
  if (diff > 1 && diff < 7) return DateFormat('EEEE').format(day);
  return DateFormat('EEE, d MMM').format(day);
}

/// Case-insensitive title/notes search used by every segment.
bool matchesThingsQuery(TodayActivityItem a, String query) =>
    query.isEmpty ||
    '${a.title} ${a.notes ?? ''}'.toLowerCase().contains(query);

/// Where a thing sits in the Today board. Lists stay readable with lots of
/// data by grouping: medicine doses together, everything else by the part
/// of the day it is scheduled for.
enum DayPart {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening'),
  anytime('Anytime'),
  medicine('Medicine');

  const DayPart(this.label);
  final String label;
}

DayPart dayPartOf(TodayActivityItem a) {
  if (a.sourceType == 'medicine') return DayPart.medicine;
  final t = a.scheduledTime;
  if (t == null) return DayPart.anytime;
  if (t.hour < 12) return DayPart.morning;
  if (t.hour < 17) return DayPart.afternoon;
  return DayPart.evening;
}

/// [items] split into day parts, in display order, keeping their order
/// within each part. Empty parts are left out.
List<(DayPart, List<TodayActivityItem>)> groupByDayPart(
  Iterable<TodayActivityItem> items,
) {
  final map = <DayPart, List<TodayActivityItem>>{};
  for (final a in items) {
    (map[dayPartOf(a)] ??= []).add(a);
  }
  return [
    for (final p in DayPart.values)
      if (map[p] case final list?) (p, list),
  ];
}
