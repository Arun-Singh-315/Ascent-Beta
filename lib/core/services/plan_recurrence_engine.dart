/// Model for a calculated check-in attempt.
class CheckInAttemptTiming {
  const CheckInAttemptTiming({required this.attemptIndex, required this.time});
  final int attemptIndex;
  final DateTime time;
}

/// Explicit recurrence engine for calendar dates, start times, check-in attempts, and close times.
class PlanRecurrenceEngine {
  /// Format a DateTime to 'YYYY-MM-DD'.
  static String formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Parse 'YYYY-MM-DD' into a local DateTime at midnight.
  static DateTime parseDate(String s) {
    final parts = s.split('-');
    if (parts.length != 3) {
      throw ArgumentError('Invalid date format (expected YYYY-MM-DD): $s');
    }
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final d = int.parse(parts[2]);
    return DateTime(y, m, d);
  }

  /// Calculates the list of eligible calendar date strings ('YYYY-MM-DD')
  /// from [startDate] to [endDate] inclusive according to [recurrenceRule].
  static List<String> calculateEligibleDates({
    required String startDate,
    required String endDate,
    required String recurrenceRule,
    List<int>? customDays,
  }) {
    final start = parseDate(startDate);
    final end = parseDate(endDate);

    if (start.isAfter(end)) {
      throw ArgumentError('startDate ($startDate) cannot be after endDate ($endDate).');
    }

    if (recurrenceRule == 'once') {
      return [startDate];
    }

    final dates = <String>[];
    var current = start;

    while (!current.isAfter(end)) {
      final dateStr = formatDate(current);
      final weekday = current.weekday; // 1 = Monday, 7 = Sunday

      if (recurrenceRule == 'daily') {
        dates.add(dateStr);
      } else if (recurrenceRule == 'weekdays') {
        if (weekday >= DateTime.monday && weekday <= DateTime.friday) {
          dates.add(dateStr);
        }
      } else if (recurrenceRule == 'custom_days') {
        if (customDays != null && customDays.contains(weekday)) {
          dates.add(dateStr);
        }
      }

      // Increment by 1 day using calendar addition
      current = DateTime(current.year, current.month, current.day + 1);
    }

    return dates;
  }

  /// Calculates a [DateTime] for a given date string ('YYYY-MM-DD') and local time ('HH:mm').
  static DateTime calculateStartTime({
    required String dateStr,
    required String localTime,
  }) {
    final date = parseDate(dateStr);
    final timeParts = localTime.split(':');
    if (timeParts.length != 2) {
      throw ArgumentError('Invalid localTime format (expected HH:mm): $localTime');
    }
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// Calculates scheduled check-in timings for a session.
  ///
  /// Initial check-in is scheduled at `startTime + expectedDuration + buffer (10m)`.
  /// If [policy] == 'off', returns empty list.
  /// If [policy] == 'once', returns 1 attempt.
  /// If [policy] == 'gentle', returns 3 attempts:
  ///   - attempt 0: initial check-in
  ///   - attempt 1: initial check-in + 30 minutes
  ///   - attempt 2: initial check-in + 90 minutes
  static List<CheckInAttemptTiming> calculateCheckInTimes({
    required DateTime startTime,
    required String policy,
    int? expectedDurationMinutes,
  }) {
    if (policy == 'off') return const [];

    final duration = expectedDurationMinutes != null && expectedDurationMinutes > 0
        ? expectedDurationMinutes
        : 30;
    // Initial check-in is start + duration + 10 min buffer
    final initialCheckIn = startTime.add(Duration(minutes: duration + 10));

    if (policy == 'once') {
      return [
        CheckInAttemptTiming(attemptIndex: 0, time: initialCheckIn),
      ];
    }

    if (policy == 'gentle') {
      return [
        CheckInAttemptTiming(attemptIndex: 0, time: initialCheckIn),
        CheckInAttemptTiming(
          attemptIndex: 1,
          time: initialCheckIn.add(const Duration(minutes: 30)),
        ),
        CheckInAttemptTiming(
          attemptIndex: 2,
          time: initialCheckIn.add(const Duration(minutes: 90)),
        ),
      ];
    }

    return [
      CheckInAttemptTiming(attemptIndex: 0, time: initialCheckIn),
    ];
  }

  /// Calculates the closing cutoff time for a session.
  ///
  /// Defaults to 2 hours after the last check-in time (or 4 hours after start time if no check-in),
  /// but capped at the end of the calendar day (23:59:59) or before the next morning.
  static DateTime calculateCloseTime({
    required DateTime startTime,
    DateTime? lastCheckInTime,
  }) {
    final base = lastCheckInTime ?? startTime.add(const Duration(hours: 4));
    final target = base.add(const Duration(hours: 2));

    // Do not exceed 23:59:59 of that day unless session started late in the evening
    final endOfDay = DateTime(startTime.year, startTime.month, startTime.day, 23, 59, 59);
    if (target.isAfter(endOfDay) && startTime.hour < 20) {
      return endOfDay;
    }
    return target;
  }
}
