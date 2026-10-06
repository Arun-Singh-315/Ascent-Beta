part of '../app_database.dart';

@DriftAccessor(tables: [
  HabitTable,
  HabitCompletionTable,
])
class HabitDao extends DatabaseAccessor<AppDatabase> with _$HabitDaoMixin {
  HabitDao(super.db);

  Stream<List<Habit>> watchAllHabits() {
    return (select(habitTable)..orderBy([(h) => OrderingTerm.asc(h.createdAt)])).watch();
  }

  Future<int> insertHabit(HabitTableCompanion entry) {
    return into(habitTable).insert(entry);
  }

  Future<bool> updateHabit(HabitTableCompanion entry) {
    return update(habitTable).replace(entry);
  }

  Future<int> deleteHabit(int id) async {
    await (delete(habitCompletionTable)..where((c) => c.habitId.equals(id))).go();
    return (delete(habitTable)..where((h) => h.id.equals(id))).go();
  }

  /// Watch set of habit IDs completed today.
  Stream<Set<int>> watchTodayCompletedHabitIds() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return (select(habitCompletionTable)
          ..where((c) =>
              c.date.isBiggerOrEqualValue(startOfDay) &
              c.date.isSmallerOrEqualValue(endOfDay)))
        .watch()
        .map((list) => list.map((c) => c.habitId).toSet());
  }

  /// Toggle today's completion for a habit.
  Future<bool> toggleHabitToday(int habitId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final existing = await (select(habitCompletionTable)
          ..where((c) =>
              c.habitId.equals(habitId) &
              c.date.isBiggerOrEqualValue(startOfDay) &
              c.date.isSmallerOrEqualValue(endOfDay)))
        .getSingleOrNull();

    if (existing != null) {
      await (delete(habitCompletionTable)..where((c) => c.id.equals(existing.id))).go();
      return false;
    } else {
      await into(habitCompletionTable).insert(
        HabitCompletionTableCompanion.insert(
          habitId: habitId,
          date: startOfDay,
        ),
      );
      return true;
    }
  }

  /// Insert a completion record directly (used in seeding and tests).
  Future<int> insertCompletion(HabitCompletionTableCompanion companion) =>
      into(habitCompletionTable).insert(companion);

  /// Calculate current streak for a single habit.
  Future<int> getStreak(int habitId) async {
    final completions = await (select(habitCompletionTable)
          ..where((c) => c.habitId.equals(habitId))
          ..orderBy([(c) => OrderingTerm.desc(c.date)]))
        .get();

    return _computeStreak(completions);
  }

  /// Batch-compute streak for ALL habits in a single DB query.
  /// Returns a map of habitId → streak length.
  /// Use this in list views to avoid N database queries per list item.
  Future<Map<int, int>> getAllStreaks() async {
    // One query for all completions, sorted by habit + date desc
    final allCompletions = await (select(habitCompletionTable)
          ..orderBy([(c) => OrderingTerm.asc(c.habitId), (c) => OrderingTerm.desc(c.date)]))
        .get();

    // Group by habitId
    final Map<int, List<HabitCompletion>> byHabit = {};
    for (final c in allCompletions) {
      byHabit.putIfAbsent(c.habitId, () => []).add(c);
    }

    // Compute streak per habit
    final Map<int, int> result = {};
    for (final entry in byHabit.entries) {
      result[entry.key] = _computeStreak(entry.value);
    }
    return result;
  }

  int _computeStreak(List<HabitCompletion> completions) {
    if (completions.isEmpty) return 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final dates = completions
        .map((c) => DateTime(c.date.year, c.date.month, c.date.day))
        .toSet();

    // Must have completed today or yesterday to have active streak
    DateTime checkDate;
    if (dates.contains(today)) {
      checkDate = today;
    } else if (dates.contains(yesterday)) {
      checkDate = yesterday;
    } else {
      return 0;
    }

    int streak = 0;
    while (dates.contains(checkDate)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }
}
