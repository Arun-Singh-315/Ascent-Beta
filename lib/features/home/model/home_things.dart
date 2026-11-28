import 'package:flutter/foundation.dart';

import '../../../core/providers/database_provider.dart';
import '../../today/models/things_sections.dart';

/// What Home's Things section shows for today: overdue items from earlier
/// days (as one red line), and today's things (pending and done) split by
/// part of the day.
@immutable
class HomeThingsToday {
  const HomeThingsToday({
    required this.overdue,
    required this.parts,
    required this.done,
    required this.total,
  });

  final List<TodayActivityItem> overdue;
  final List<(DayPart, List<TodayActivityItem>)> parts;
  final int done, total;

  /// Overdue tasks that "Move to today" can move.
  List<int> get movableOverdue => [
    for (final a in overdue)
      if (a.linkedTaskId != null && !a.isDailyStanding) a.linkedTaskId!,
  ];
}

bool _done(TodayActivityItem a) => a.status == TodayActivityStatus.done;

/// Builds [HomeThingsToday] from today's activities. Medicine doses live in
/// Life, and undated to-dos in Anytime, so neither shows here. Pure.
HomeThingsToday buildHomeThingsToday(List<TodayActivityItem> items) {
  final view = groupToday(
    items.where((a) => a.sourceType != 'medicine').toList(),
  );
  final todays = [
    ...view.today,
    ...view.completed.where((a) => !isAnytimeThing(a)),
  ];
  // Keep each part in time order, done or not, so the list reads as a day.
  todays.sort((a, b) {
    final at = a.scheduledTime, bt = b.scheduledTime;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  });
  return HomeThingsToday(
    overdue: view.overdue,
    parts: groupByDayPart(todays),
    done: todays.where(_done).length,
    total: todays.length,
  );
}

/// The part of the day to open first: the current part if it has
/// something left, else the first part with something left, else none.
DayPart? defaultOpenPart(
  List<(DayPart, List<TodayActivityItem>)> parts,
  DateTime now,
) {
  final current = now.hour < 12
      ? DayPart.morning
      : now.hour < 17
      ? DayPart.afternoon
      : DayPart.evening;
  bool pending((DayPart, List<TodayActivityItem>) p) =>
      p.$2.any((a) => !_done(a));
  for (final p in parts) {
    if (p.$1 == current && pending(p)) return p.$1;
  }
  for (final p in parts) {
    if (pending(p)) return p.$1;
  }
  return null;
}
