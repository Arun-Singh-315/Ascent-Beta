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

  /// Get total water intake for a specific date in mL.
  Future<int> getWaterForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final amountSum = waterLogTable.amountMl.sum();
    final query = selectOnly(waterLogTable)
      ..addColumns([amountSum])
      ..where(waterLogTable.date.isBiggerOrEqualValue(startOfDay) &
          waterLogTable.date.isSmallerOrEqualValue(endOfDay));

    final row = await query.getSingleOrNull();
    return row?.read(amountSum) ?? 0;
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

  /// Add water log for a specific date (useful for backfill and testing).
  Future<int> addWaterForDate(int amountMl, DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return into(waterLogTable).insert(
      WaterLogTableCompanion.insert(
        amountMl: amountMl,
        timestamp: Value(date),
        date: dateOnly,
      ),
    );
  }

  /// Get past 7 days hydration records (including today).
  Future<List<DailyHydrationRecord>> getPast7DaysHistory() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final goal = await (select(waterGoalTable)..limit(1)).getSingleOrNull();
    final goalMl = goal?.targetMl ?? 2500;

    final records = <DailyHydrationRecord>[];
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final ml = await getWaterForDate(date);
      records.add(DailyHydrationRecord(
        date: date,
        totalMl: ml,
        goalMl: goalMl,
      ));
    }
    return records;
  }

  /// Watch past 7 days hydration history stream.
  Stream<List<DailyHydrationRecord>> watchPast7DaysHistory() {
    return select(waterLogTable).watch().asyncMap((_) => getPast7DaysHistory());
  }
}

class DailyHydrationRecord {
  final DateTime date;
  final int totalMl;
  final int goalMl;

  const DailyHydrationRecord({
    required this.date,
    required this.totalMl,
    this.goalMl = 2500,
  });

  bool get isGoalMet => totalMl >= goalMl;
  double get progress => goalMl > 0 ? (totalMl / goalMl).clamp(0.0, 1.5) : 0.0;
}
