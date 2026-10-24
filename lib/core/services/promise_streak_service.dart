import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/database_provider.dart';

class PromiseStreakInfo {
  const PromiseStreakInfo({
    required this.currentStreak,
    required this.isPendingToday,
    this.bestStreak = 0,
  });

  final int currentStreak;
  final bool isPendingToday;
  final int bestStreak;
}

class PromiseStreakService {
  PromiseStreakService(this._db);

  final AppDatabase _db;

  static String getMotivationCopy(int streak) {
    if (streak == 0) {
      return 'Bhai, let’s start strong on this!';
    } else if (streak < 3) {
      return '🌱 Day $streak: Every big discipline starts with day 1.';
    } else if (streak < 7) {
      return '🔥 $streak-day streak: Building real integrity, keep pushing!';
    } else if (streak < 21) {
      return '🏆 $streak-day streak: Man of your word! This is becoming second nature.';
    } else {
      return '⚡ $streak-day streak: Unbreakable will! Iron discipline unlocked.';
    }
  }

  Future<PromiseStreakInfo> calculateStreak(
    Thought thought, {
    DateTime? referenceDate,
  }) async {
    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    final normalized = thought.content.trim().toLowerCase();

    // Fetch all promises with matching normalized content
    final allPromises = await (_db.select(_db.thoughtTable)
          ..where((t) => t.mood.equals('promise')))
        .get();

    final matches = allPromises
        .where((t) => t.content.trim().toLowerCase() == normalized)
        .toList();

    // Check if completed today
    final isCompletedToday = matches.any(
      (t) =>
          t.isCompleted &&
          t.createdAt.year == today.year &&
          t.createdAt.month == today.month &&
          t.createdAt.day == today.day,
    );

    // Count consecutive past days
    var consecutivePastDays = 0;
    var checkDate = today.subtract(const Duration(days: 1));

    while (true) {
      final keptOnDay = matches.any(
        (t) =>
            t.isCompleted &&
            t.createdAt.year == checkDate.year &&
            t.createdAt.month == checkDate.month &&
            t.createdAt.day == checkDate.day,
      );

      if (keptOnDay) {
        consecutivePastDays++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    final currentStreak = isCompletedToday
        ? consecutivePastDays + 1
        : consecutivePastDays;

    return PromiseStreakInfo(
      currentStreak: currentStreak,
      isPendingToday: !isCompletedToday,
      bestStreak: currentStreak,
    );
  }
}

final promiseStreakServiceProvider = Provider<PromiseStreakService>((ref) {
  return PromiseStreakService(ref.watch(databaseProvider));
});
