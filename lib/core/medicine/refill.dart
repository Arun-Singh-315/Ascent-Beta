import 'dart:convert';

import '../database/app_database.dart';

/// Where a medicine's stock stands. Null when stock is not tracked.
class RefillInfo {
  const RefillInfo({
    required this.left,
    required this.daysLeft,
    required this.runsOut,
    required this.low,
    required this.coversCourse,
  });

  /// Units on hand (tablets, ml…).
  final int left;

  /// Whole days the stock lasts at the current schedule.
  final int daysLeft;
  final DateTime runsOut;

  /// Running out within 3 days while the course still needs more.
  final bool low;

  /// Enough is left for the rest of the course.
  final bool coversCourse;
}

RefillInfo? refillInfo(Medicine m, DateTime now) {
  final left = m.stockCount;
  if (left == null) return null;
  var perDay = 1;
  try {
    perDay = (jsonDecode(m.scheduledTimes) as List).length;
  } catch (_) {}
  final usePerDoseDay = (perDay * m.unitsPerDose).clamp(1, 1000);
  // Weekly (every 7 days) stock lasts 7 days per dose day.
  final daysLeft = (left ~/ usePerDoseDay) * m.everyDays.clamp(1, 366);
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(m.startDate.year, m.startDate.month, m.startDate.day);
  final end = start.add(Duration(days: m.durationDays - 1));
  final courseDaysLeft = end.isBefore(today)
      ? 0
      : end.difference(today).inDays + 1;
  final coversCourse = daysLeft >= courseDaysLeft;
  return RefillInfo(
    left: left,
    daysLeft: daysLeft,
    runsOut: today.add(Duration(days: daysLeft)),
    low: !coversCourse && daysLeft <= 3,
    coversCourse: coversCourse,
  );
}
