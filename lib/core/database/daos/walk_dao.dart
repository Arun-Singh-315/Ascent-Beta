part of '../app_database.dart';

@DriftAccessor(tables: [
  WalkSessionTable,
  DailyActivityGoalTable,
])
class WalkDao extends DatabaseAccessor<AppDatabase> with _$WalkDaoMixin {
  WalkDao(super.db);

  /// Watch all completed walks sorted by start time desc.
  Stream<List<WalkSession>> watchCompletedWalks() {
    return (select(walkSessionTable)
          ..where((w) => w.isCompleted.equals(true))
          ..orderBy([(w) => OrderingTerm.desc(w.startTime)]))
        .watch();
  }

  /// Watch today's total distance in meters.
  Stream<double> watchTodayDistance() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final distanceSum = walkSessionTable.distanceMeters.sum();
    final query = selectOnly(walkSessionTable)
      ..addColumns([distanceSum])
      ..where(walkSessionTable.isCompleted.equals(true) &
          walkSessionTable.startTime.isBiggerOrEqualValue(startOfDay) &
          walkSessionTable.startTime.isSmallerOrEqualValue(endOfDay));

    return query.watchSingle().map((row) => row.read(distanceSum) ?? 0.0);
  }

  /// Watch this week's total distance in meters (from Monday).
  Stream<double> watchWeekDistance() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeek = DateTime(monday.year, monday.month, monday.day);

    final distanceSum = walkSessionTable.distanceMeters.sum();
    final query = selectOnly(walkSessionTable)
      ..addColumns([distanceSum])
      ..where(walkSessionTable.isCompleted.equals(true) &
          walkSessionTable.startTime.isBiggerOrEqualValue(startOfWeek));

    return query.watchSingle().map((row) => row.read(distanceSum) ?? 0.0);
  }

  /// Get walk session by id.
  Future<WalkSession?> getWalkById(int id) {
    return (select(walkSessionTable)..where((w) => w.id.equals(id))).getSingleOrNull();
  }

  /// Insert walk session.
  Future<int> insertWalk(WalkSessionTableCompanion entry) {
    return into(walkSessionTable).insert(entry);
  }

  /// Update walk session.
  Future<bool> updateWalk(WalkSessionTableCompanion entry) {
    return update(walkSessionTable).replace(entry);
  }

  /// Delete walk session.
  Future<int> deleteWalk(int id) {
    return (delete(walkSessionTable)..where((w) => w.id.equals(id))).go();
  }

  // ── Daily Goals ────────────────────────────────────────────────────────────

  Stream<DailyActivityGoal> watchActivityGoal() {
    return (select(dailyActivityGoalTable)..limit(1))
        .watchSingleOrNull()
        .map((goal) => goal ?? DailyActivityGoal(
              id: 1,
              targetDistanceMeters: 5000.0,
              targetWalkMinutes: 45,
              updatedAt: DateTime(2026, 1, 1),
            ));
  }

  Future<void> setActivityGoal(double targetDistanceMeters, int targetWalkMinutes) async {
    final existing = await (select(dailyActivityGoalTable)..limit(1)).getSingleOrNull();
    if (existing == null) {
      await into(dailyActivityGoalTable).insert(
        DailyActivityGoalTableCompanion.insert(
          targetDistanceMeters: Value(targetDistanceMeters),
          targetWalkMinutes: Value(targetWalkMinutes),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await update(dailyActivityGoalTable).replace(
        DailyActivityGoalTableCompanion(
          id: Value(existing.id),
          targetDistanceMeters: Value(targetDistanceMeters),
          targetWalkMinutes: Value(targetWalkMinutes),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
