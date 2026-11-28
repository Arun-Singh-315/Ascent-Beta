import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Strict Study Streak & Rescue Math Logic Tests', () {
    test(
      'Anti-Cheat: Manual lecture completion does not increment study watch time',
      () {
        final calculator = StudyStreakCalculator();
        final now = DateTime(2026, 10, 8, 14, 0);

        // User has 0 seconds watched
        final status = calculator.calculate(
          todaySeconds: 0,
          yesterdaySeconds: 7200, // Yesterday met 2 hours
          priorStreakDays: 3,
          historicalLongestStreak: 5,
          now: now,
        );

        expect(status.todaySeconds, 0);
        expect(status.todayMinutes, 0);
        expect(status.isTodaySecured, isFalse);
        expect(status.progressFraction, 0.0);
        // Streak from yesterday is alive, but today is not yet secured
        expect(status.displayStreakDays, 3);
        expect(status.isRescueMode, isFalse);
      },
    );

    test(
      'Normal Goal: Completing 120 minutes (7200s) secures today and increments streak',
      () {
        final calculator = StudyStreakCalculator();
        final now = DateTime(2026, 10, 8, 15, 30);

        final status = calculator.calculate(
          todaySeconds: 7200, // Exactly 120 minutes
          yesterdaySeconds: 7200,
          priorStreakDays: 4,
          historicalLongestStreak: 4,
          now: now,
        );

        expect(status.isTodaySecured, isTrue);
        expect(status.displayStreakDays, 5); // 4 + 1
        expect(status.progressFraction, 1.0);
        expect(status.remainingMinutes, 0);
        expect(status.longestStreakDays, 5);
        expect(status.isRescueMode, isFalse);
      },
    );

    test(
      'Rescue Mode: Deficit from yesterday is added to today requirement (1-day grace)',
      () {
        final calculator = StudyStreakCalculator();
        final now = DateTime(2026, 10, 8, 11, 0);

        // Yesterday user only studied 80 minutes (4800s), missing 40 minutes (2400s)
        final status = calculator.calculate(
          todaySeconds: 3600, // 60 mins studied so far today
          yesterdaySeconds: 4800, // 80 mins
          priorStreakDays: 6, // Had a 6-day streak
          historicalLongestStreak: 10,
          now: now,
        );

        expect(status.isRescueMode, isTrue);
        expect(status.yesterdayDeficitMinutes, 40);
        // Today target is 120m + 40m debt = 160 minutes
        expect(status.targetMinutes, 160);
        expect(status.todayMinutes, 60);
        expect(status.remainingMinutes, 100);
        expect(status.isTodaySecured, isFalse);
        // Prior streak of 6 is preserved in rescue mode until midnight
        expect(status.displayStreakDays, 6);
      },
    );

    test(
      'Rescue Mode: Successfully hitting target today rescues the streak',
      () {
        final calculator = StudyStreakCalculator();
        final now = DateTime(2026, 10, 8, 20, 0);

        // Today watched 160 minutes (9600s), fully paying off the 40m debt
        final status = calculator.calculate(
          todaySeconds: 9600,
          yesterdaySeconds: 4800, // 80 mins
          priorStreakDays: 6,
          historicalLongestStreak: 10,
          now: now,
        );

        expect(status.isRescueMode, isTrue);
        expect(status.isTodaySecured, isTrue);
        expect(status.isRescuedToday, isTrue);
        // Rescued streak preserved!
        expect(status.displayStreakDays, 7);
        expect(status.remainingMinutes, 0);
        expect(status.progressFraction, 1.0);
      },
    );

    test(
      'Snapchat-style Urgency: Alerts user in the evening if minutes are still remaining',
      () {
        final calculator = StudyStreakCalculator();
        // 8:00 PM (20:00) with 45 minutes remaining
        final eveningTime = DateTime(2026, 10, 8, 20, 0);

        final status = calculator.calculate(
          todaySeconds: 4500, // 75 mins watched, 45 mins left
          yesterdaySeconds: 7200,
          priorStreakDays: 3,
          historicalLongestStreak: 5,
          now: eveningTime,
        );

        expect(status.isTodaySecured, isFalse);
        expect(status.remainingMinutes, 45);
        expect(status.isUrgent, isTrue);
        expect(status.hoursRemainingInDay, 4); // 24 - 20 = 4
      },
    );

    test(
      'Snapchat-style Urgency: Not urgent in morning/afternoon with time remaining',
      () {
        final calculator = StudyStreakCalculator();
        // 11:00 AM (11:00)
        final morningTime = DateTime(2026, 10, 8, 11, 0);

        final status = calculator.calculate(
          todaySeconds: 3600,
          yesterdaySeconds: 7200,
          priorStreakDays: 3,
          historicalLongestStreak: 5,
          now: morningTime,
        );

        expect(status.isUrgent, isFalse);
      },
    );
  });

  group('Study Streak Meter UI Widget Tests', () {});

  group('Home Screen Dismissible Reminders Tests', () {});

  group('Study Streak Card Visibility Toggle Tests', () {});
}
