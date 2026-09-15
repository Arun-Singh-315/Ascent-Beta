part of '../app_database.dart';

@DriftAccessor(tables: [DsaLogTable])
class DsaDao extends DatabaseAccessor<AppDatabase> with _$DsaDaoMixin {
  DsaDao(super.db);

  // ---------------------------------------------------------------------------
  // Watch helpers
  // ---------------------------------------------------------------------------

  /// Stream of all DSA logs, most recently solved first.
  Stream<List<DsaLog>> watchAllLogs() =>
      (select(dsaLogTable)
            ..orderBy([(l) => OrderingTerm.desc(l.dateSolved)]))
          .watch();

  /// Stream of logs filtered by [topic] (stores [DsaTopic.name]).
  Stream<List<DsaLog>> watchLogsByTopic(DsaTopic topic) =>
      (select(dsaLogTable)
            ..where((l) => l.topic.equals(topic.name))
            ..orderBy([(l) => OrderingTerm.desc(l.dateSolved)]))
          .watch();

  /// Stream of logs marked for revisit.
  Stream<List<DsaLog>> watchNeedsRevisit() =>
      (select(dsaLogTable)
            ..where((l) => l.revisitFlag.equals(true))
            ..orderBy([(l) => OrderingTerm.desc(l.dateSolved)]))
          .watch();

  // ---------------------------------------------------------------------------
  // Single-fetch queries
  // ---------------------------------------------------------------------------

  /// Returns a map of topic → count of solved problems for that topic.
  Future<Map<DsaTopic, int>> getSolvedCountByTopic() async {
    final count = dsaLogTable.id.count();
    final topicCol = dsaLogTable.topic;
    final query = selectOnly(dsaLogTable)
      ..addColumns([topicCol, count])
      ..groupBy([topicCol]);

    final rows = await query.get();
    return {
      for (final row in rows)
        DsaTopic.values.firstWhere(
          (t) => t.name == row.read(topicCol),
          orElse: () => DsaTopic.other,
        ): row.read(count) ?? 0,
    };
  }

  /// Number of problems solved in the current ISO week (Mon–Sun).
  Future<int> getSolvedCountThisWeek() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final cutoff = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final count = dsaLogTable.id.count();
    final query = selectOnly(dsaLogTable)
      ..addColumns([count])
      ..where(dsaLogTable.dateSolved.isBiggerOrEqualValue(cutoff));

    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Total number of problems solved across all time.
  Future<int> getTotalSolvedCount() async {
    final count = dsaLogTable.id.count();
    final query = selectOnly(dsaLogTable)..addColumns([count]);
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new log entry and returns the generated id.
  Future<int> insertLog(DsaLogTableCompanion companion) =>
      into(dsaLogTable).insert(companion);

  /// Updates the log identified by [companion.id].
  /// Returns true if exactly one row was affected.
  Future<bool> updateLog(DsaLogTableCompanion companion) async {
    final affected = await (update(dsaLogTable)
          ..where((l) => l.id.equals(companion.id.value)))
        .write(companion);
    return affected == 1;
  }

  /// Deletes the log with [id].  Returns the number of deleted rows.
  Future<int> deleteLog(int id) =>
      (delete(dsaLogTable)..where((l) => l.id.equals(id))).go();

  /// Toggles the [revisitFlag] on the log with [id].
  Future<void> toggleRevisit(int id) async {
    final log = await (select(dsaLogTable)..where((l) => l.id.equals(id)))
        .getSingleOrNull();
    if (log == null) return;
    await (update(dsaLogTable)..where((l) => l.id.equals(id))).write(
      DsaLogTableCompanion(revisitFlag: Value(!log.revisitFlag)),
    );
  }
}
