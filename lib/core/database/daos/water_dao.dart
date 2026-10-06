part of '../app_database.dart';

@DriftAccessor(tables: [
  WaterLogTable,
  WaterGoalTable,
])
class WaterDao extends DatabaseAccessor<AppDatabase> with _$WaterDaoMixin {
  WaterDao(super.db);

  /// Watch total water intake today in mL.
  Stream<int> watchTodayWaterMl() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final amountSum = waterLogTable.amountMl.sum();
    final query = selectOnly(waterLogTable)
      ..addColumns([amountSum])
      ..where(waterLogTable.date.isBiggerOrEqualValue(startOfDay) &
          waterLogTable.date.isSmallerOrEqualValue(endOfDay));

    return query.watchSingle().map((row) => row.read(amountSum) ?? 0);
  }

  /// Watch individual logs for today (newest first).
  Stream<List<WaterLog>> watchTodayWaterLogs() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return (select(waterLogTable)
          ..where((l) =>
              l.date.isBiggerOrEqualValue(startOfDay) &
              l.date.isSmallerOrEqualValue(endOfDay))
          ..orderBy([(l) => OrderingTerm.desc(l.id)]))
        .watch();
  }

  /// Add a water log (e.g. 250 mL).
  Future<int> addWater(int amountMl) {
    final now = DateTime.now();
    final dateOnly = DateTime(now.year, now.month, now.day);
    return into(waterLogTable).insert(
      WaterLogTableCompanion.insert(
        amountMl: amountMl,
        timestamp: Value(now),
        date: dateOnly,
      ),
    );
  }

  /// Delete a water log entry by ID.
  Future<int> deleteWater(int id) {
    return (delete(waterLogTable)..where((l) => l.id.equals(id))).go();
  }

  /// Watch daily water goal in mL (default 2500 mL).
  Stream<int> watchDailyWaterGoal() {
    return (select(waterGoalTable)..limit(1))
        .watchSingleOrNull()
        .map((goal) => goal?.targetMl ?? 2500);
  }

  /// Update daily water goal.
  Future<void> setDailyWaterGoal(int targetMl) async {
    final existing = await (select(waterGoalTable)..limit(1)).getSingleOrNull();
    if (existing == null) {
      await into(waterGoalTable).insert(
        WaterGoalTableCompanion.insert(
          targetMl: Value(targetMl),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } else {
      await update(waterGoalTable).replace(
        WaterGoalTableCompanion(
          id: Value(existing.id),
          targetMl: Value(targetMl),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
