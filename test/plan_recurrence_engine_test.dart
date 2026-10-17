import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/services/plan_recurrence_engine.dart';

void main() {
  group('PlanRecurrenceEngine', () {
    test('Daily recurrence generates all dates from start to end inclusive', () {
      final dates = PlanRecurrenceEngine.calculateEligibleDates(
        startDate: '2026-10-18',
        endDate: '2026-10-31',
        recurrenceRule: 'daily',
      );

      expect(dates.length, 14);
      expect(dates.first, '2026-10-18');
      expect(dates.last, '2026-10-31');
      expect(dates.contains('2026-11-01'), isFalse);
    });

    test('Weekdays recurrence skips Saturdays and Sundays', () {
      // 2026-10-19 is Monday, 2026-10-25 is Sunday
      final dates = PlanRecurrenceEngine.calculateEligibleDates(
        startDate: '2026-10-19',
        endDate: '2026-10-25',
        recurrenceRule: 'weekdays',
      );

      // Mon, Tue, Wed, Thu, Fri = 5 days
      expect(dates.length, 5);
      expect(dates, [
        '2026-10-19',
        '2026-10-20',
        '2026-10-21',
        '2026-10-22',
        '2026-10-23',
      ]);
      expect(dates.contains('2026-10-24'), isFalse); // Saturday
      expect(dates.contains('2026-10-25'), isFalse); // Sunday
    });

    test('Custom days recurrence honors selected weekdays only', () {
      // 2026-10-19 (Mon) to 2026-10-25 (Sun)
      // Pick Monday (1), Wednesday (3), Friday (5)
      final dates = PlanRecurrenceEngine.calculateEligibleDates(
        startDate: '2026-10-19',
        endDate: '2026-10-25',
        recurrenceRule: 'custom_days',
        customDays: [1, 3, 5],
      );

      expect(dates, [
        '2026-10-19', // Mon
        '2026-10-21', // Wed
        '2026-10-23', // Fri
      ]);
    });

    test('Once recurrence generates exactly one date on startDate', () {
      final dates = PlanRecurrenceEngine.calculateEligibleDates(
        startDate: '2026-10-20',
        endDate: '2026-10-25',
        recurrenceRule: 'once',
      );

      expect(dates, ['2026-10-20']);
    });

    test('Handles month and year transitions and leap years', () {
      // 2028 is a leap year; Feb has 29 days
      final leapDates = PlanRecurrenceEngine.calculateEligibleDates(
        startDate: '2028-02-28',
        endDate: '2028-03-01',
        recurrenceRule: 'daily',
      );
      expect(leapDates, ['2028-02-28', '2028-02-29', '2028-03-01']);

      // Year boundary 2026-12-31 to 2027-01-02
      final yearDates = PlanRecurrenceEngine.calculateEligibleDates(
        startDate: '2026-12-31',
        endDate: '2027-01-02',
        recurrenceRule: 'daily',
      );
      expect(yearDates, ['2026-12-31', '2027-01-01', '2027-01-02']);
    });

    test('Rejects invalid date ranges', () {
      expect(
        () => PlanRecurrenceEngine.calculateEligibleDates(
          startDate: '2026-10-25',
          endDate: '2026-10-20',
          recurrenceRule: 'daily',
        ),
        throwsArgumentError,
      );
    });

    test('Calculates scheduledStartTime from date and localTime', () {
      final start = PlanRecurrenceEngine.calculateStartTime(
        dateStr: '2026-10-18',
        localTime: '07:00',
      );

      expect(start.year, 2026);
      expect(start.month, 10);
      expect(start.day, 18);
      expect(start.hour, 7);
      expect(start.minute, 0);
    });

    test('Calculates check-in timings for Once policy', () {
      final start = DateTime(2026, 10, 18, 7, 0);
      final checkIns = PlanRecurrenceEngine.calculateCheckInTimes(
        startTime: start,
        policy: 'once',
        expectedDurationMinutes: 30,
      );

      // 7:00 + 30 min duration + 10 min buffer = 7:40
      expect(checkIns.length, 1);
      expect(checkIns[0].attemptIndex, 0);
      expect(checkIns[0].time, DateTime(2026, 10, 18, 7, 40));
    });

    test('Calculates check-in timings for Gentle policy (first, +30m, +90m)', () {
      final start = DateTime(2026, 10, 18, 7, 0);
      final checkIns = PlanRecurrenceEngine.calculateCheckInTimes(
        startTime: start,
        policy: 'gentle',
        expectedDurationMinutes: 30,
      );

      expect(checkIns.length, 3);
      // Attempt 0: 7:40 am
      expect(checkIns[0].attemptIndex, 0);
      expect(checkIns[0].time, DateTime(2026, 10, 18, 7, 40));

      // Attempt 1: 7:40 + 30m = 8:10 am
      expect(checkIns[1].attemptIndex, 1);
      expect(checkIns[1].time, DateTime(2026, 10, 18, 8, 10));

      // Attempt 2: 7:40 + 90m = 9:10 am
      expect(checkIns[2].attemptIndex, 2);
      expect(checkIns[2].time, DateTime(2026, 10, 18, 9, 10));
    });

    test('Calculates closeTime (cutoff) after last check-in or end of day', () {
      final start = DateTime(2026, 10, 18, 7, 0);
      final close = PlanRecurrenceEngine.calculateCloseTime(
        startTime: start,
        lastCheckInTime: DateTime(2026, 10, 18, 9, 10),
      );

      // Cutoff gives a response window (e.g. 2 hours after last check-in: 11:10 am)
      expect(close.isAfter(DateTime(2026, 10, 18, 9, 10)), isTrue);
      expect(close.day, 18);
    });
  });
}
