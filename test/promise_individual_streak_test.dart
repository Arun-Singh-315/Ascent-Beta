import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/promise_streak_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PromiseStreakService streakService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    streakService = PromiseStreakService(db);
  });

  tearDown(() => db.close());

  group('Promise Individual Streak Engine Tests', () {
    test('new promise with zero prior completions has streak 0 if pending, 1 if completed today', () async {
      final today = DateTime(2026, 10, 24, 10);
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Daily morning meditation',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(today),
          isCompleted: const drift.Value(false),
        ),
      );

      final thought = (await db.thoughtDao.getThoughtById(id))!;
      var streak = await streakService.calculateStreak(thought, referenceDate: today);
      expect(streak.currentStreak, equals(0));
      expect(streak.isPendingToday, isTrue);

      // Now complete it today
      await db.thoughtDao.setCompleted(id, true);
      final completedThought = (await db.thoughtDao.getThoughtById(id))!;
      streak = await streakService.calculateStreak(completedThought, referenceDate: today);
      expect(streak.currentStreak, equals(1));
      expect(streak.isPendingToday, isFalse);
    });

    test('multi-day consecutive completion builds individual streak', () async {
      final baseDate = DateTime(2026, 10, 20);

      // Day 1 (Oct 20) - kept
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'No smoking',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(baseDate),
          isCompleted: const drift.Value(true),
        ),
      );

      // Day 2 (Oct 21) - kept
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'No smoking',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(baseDate.add(const Duration(days: 1))),
          isCompleted: const drift.Value(true),
        ),
      );

      // Day 3 (Oct 22) - kept
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'No smoking',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(baseDate.add(const Duration(days: 2))),
          isCompleted: const drift.Value(true),
        ),
      );

      // Day 4 (Oct 23) - today - pending
      final todayId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'No smoking',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(baseDate.add(const Duration(days: 3))),
          isCompleted: const drift.Value(false),
        ),
      );

      final todayThought = (await db.thoughtDao.getThoughtById(todayId))!;
      final todayDate = baseDate.add(const Duration(days: 3));
      final streak = await streakService.calculateStreak(todayThought, referenceDate: todayDate);

      // Prior 3 days kept -> current streak is 3
      expect(streak.currentStreak, equals(3));

      // Once completed today -> streak climbs to 4
      await db.thoughtDao.setCompleted(todayId, true);
      final completedToday = (await db.thoughtDao.getThoughtById(todayId))!;
      final updatedStreak = await streakService.calculateStreak(completedToday, referenceDate: todayDate);
      expect(updatedStreak.currentStreak, equals(4));
    });

    test('breaking one promise does NOT affect streaks of other promises', () async {
      final baseDate = DateTime(2026, 10, 20);

      // 3 days of "Workout" (kept each day)
      for (int i = 0; i < 3; i++) {
        await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Workout 30 min',
            mood: const drift.Value('promise'),
            createdAt: drift.Value(baseDate.add(Duration(days: i))),
            isCompleted: const drift.Value(true),
          ),
        );
      }

      // 3 days of "Read 20 pages" (kept day 1 and 2, but skipped day 3)
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Read 20 pages',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(baseDate),
          isCompleted: const drift.Value(true),
        ),
      );
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Read 20 pages',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(baseDate.add(const Duration(days: 1))),
          isCompleted: const drift.Value(true),
        ),
      );
      // Day 3 (day 2 in 0-indexed) was NOT completed (or slipped)

      final day4Date = baseDate.add(const Duration(days: 3));
      final workoutDay4 = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Workout 30 min',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(day4Date),
          isCompleted: const drift.Value(false),
        ),
      );

      final readDay4 = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Read 20 pages',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(day4Date),
          isCompleted: const drift.Value(false),
        ),
      );

      final workoutThought = (await db.thoughtDao.getThoughtById(workoutDay4))!;
      final readThought = (await db.thoughtDao.getThoughtById(readDay4))!;

      final workoutStreak = await streakService.calculateStreak(workoutThought, referenceDate: day4Date);
      final readStreak = await streakService.calculateStreak(readThought, referenceDate: day4Date);

      // Workout kept its 3-day streak intact
      expect(workoutStreak.currentStreak, equals(3));

      // Read had a gap on day 3, so its streak reset to 0
      expect(readStreak.currentStreak, equals(0));
    });

    test('streak motivation tier returns companion coaching copy', () {
      expect(PromiseStreakService.getMotivationCopy(0), contains('Bhai, let’s start strong'));
      expect(PromiseStreakService.getMotivationCopy(3), contains('Building real integrity'));
      expect(PromiseStreakService.getMotivationCopy(7), contains('Man of your word'));
      expect(PromiseStreakService.getMotivationCopy(21), contains('Unbreakable will'));
    });
  });
}
