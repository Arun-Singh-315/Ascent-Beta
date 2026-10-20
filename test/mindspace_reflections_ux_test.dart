import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/streak/study_streak_models.dart';
import 'package:ascent/features/home/widgets/study_streak_meter_card.dart';

void main() {
  group('Mind Space Reflections & UX Enhancement Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'Completing a linked task crosses out and completes the corresponding thought',
      () async {
        // 1. Insert a thought
        final thoughtId = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Read chapter 3 of distributed systems',
            mood: const drift.Value('idea'),
          ),
        );

        var thought = await db.thoughtDao.getThoughtById(thoughtId);
        expect(thought, isNotNull);
        expect(thought!.isCompleted, isFalse);

        // 2. Insert a task with linked thought_id in notes
        final taskId = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Read chapter 3 of distributed systems',
            notes: drift.Value(
              'thought_id:$thoughtId • Converted from Thought Wall',
            ),
            plannedDate: drift.Value(DateTime.now()),
          ),
        );

        // 3. Mark task complete
        await db.taskDao.markComplete(taskId);

        // 4. Verify thought is now marked complete
        thought = await db.thoughtDao.getThoughtById(thoughtId);
        expect(thought!.isCompleted, isTrue);

        // 5. Mark task incomplete
        await db.taskDao.markIncomplete(taskId);

        // 6. Completion is intentionally locked once recorded.
        thought = await db.thoughtDao.getThoughtById(thoughtId);
        expect(thought!.isCompleted, isTrue);
      },
    );

    test(
      'Matching text without an explicit link never completes an unrelated thought',
      () async {
        final thoughtId = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Finish sprint retrospectives',
            mood: const drift.Value('thought'),
          ),
        );

        final taskId = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Finish sprint retrospectives',
            plannedDate: drift.Value(DateTime.now()),
          ),
        );

        await db.taskDao.markComplete(taskId);

        final thought = await db.thoughtDao.getThoughtById(thoughtId);
        expect(thought!.isCompleted, isFalse);
      },
    );

    test(
      'WaterDao past 7 days history calculates daily totals and trend accurately',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Add water logs across different dates
        await db.waterDao.addWaterForDate(
          500,
          today.subtract(const Duration(days: 2)),
        );
        await db.waterDao.addWaterForDate(
          750,
          today.subtract(const Duration(days: 1)),
        );
        await db.waterDao.addWaterForDate(1000, today);

        final history = await db.waterDao.getPast7DaysHistory();
        expect(history.length, equals(7));

        final day2Ago = history.firstWhere(
          (h) => h.date.day == today.subtract(const Duration(days: 2)).day,
        );
        expect(day2Ago.totalMl, equals(500));

        final day1Ago = history.firstWhere(
          (h) => h.date.day == today.subtract(const Duration(days: 1)).day,
        );
        expect(day1Ago.totalMl, equals(750));

        final todayItem = history.firstWhere((h) => h.date.day == today.day);
        expect(todayItem.totalMl, equals(1000));
      },
    );

    testWidgets(
      'StudyStreakMeterCard offers a fresh start after a previous streak',
      (tester) async {
        final streakStatus = StudyStreakStatus(
          todaySeconds: 900,
          targetSeconds: 7200,
          displayStreakDays: 0,
          longestStreakDays: 5,
          shortestStreakDays: 1,
          isTodaySecured: false,
          isRescueMode: false,
          isUrgent: false,
          isRescuedToday: false,
          yesterdayDeficitSeconds: 0,
          hoursRemainingInDay: 12,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: const [AscentGlass.dark],
            ),
            home: Scaffold(body: StudyStreakMeterCard(status: streakStatus)),
          ),
        );

        expect(find.text('A fresh start'), findsOneWidget);
        expect(find.textContaining('Study for 120 minutes'), findsNothing);
      },
    );
  });
}
