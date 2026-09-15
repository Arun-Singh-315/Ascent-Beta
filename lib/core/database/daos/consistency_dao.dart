part of '../app_database.dart';

@DriftAccessor(tables: [ConsistencyLogTable])
class ConsistencyDao extends DatabaseAccessor<AppDatabase>
    with _$ConsistencyDaoMixin {
  ConsistencyDao(super.db);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Normalises a [DateTime] to midnight UTC so it can be used as a date key.
  static DateTime _midnight(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day);

  // ---------------------------------------------------------------------------
  // Watch helpers
  // ---------------------------------------------------------------------------

  /// Stream of all log entries for [year]/[month], used by the calendar heatmap.
  Stream<List<ConsistencyLog>> watchMonthLogs(int year, int month) {
    final start = DateTime.utc(year, month, 1);
    final end = DateTime.utc(year, month + 1, 1);
    return (select(consistencyLogTable)
          ..where(
            (l) =>
                l.date.isBiggerOrEqualValue(start) &
                l.date.isSmallerThanValue(end),
          )
          ..orderBy([(l) => OrderingTerm.asc(l.date)]))
        .watch();
  }

  /// Stream emitting the current consecutive-present streak count.
  /// The streak resets on the first absent or missing day going backwards
  /// from today.
  Stream<int> watchCurrentStreak() =>
      (select(consistencyLogTable)
            ..orderBy([(l) => OrderingTerm.desc(l.date)]))
          .watch()
          .map(_computeCurrentStreak);

  static int _computeCurrentStreak(List<ConsistencyLog> logs) {
    if (logs.isEmpty) return 0;
    final today = _midnight(DateTime.now());
    int streak = 0;
    DateTime expected = today;
    for (final log in logs) {
      final logDate = _midnight(log.date);
      if (logDate != expected) break;
      if (!log.present) break;
      streak++;
      expected = expected.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Stream of logs for the last [days] days (including today), ordered
  /// most-recent first.
  Stream<List<ConsistencyLog>> watchRecentLogs(int days) {
    final cutoff = _midnight(DateTime.now()).subtract(Duration(days: days - 1));
    return (select(consistencyLogTable)
          ..where((l) => l.date.isBiggerOrEqualValue(cutoff))
          ..orderBy([(l) => OrderingTerm.desc(l.date)]))
        .watch();
  }

  /// Stream of all consistency logs, most recent first.
  Stream<List<ConsistencyLog>> watchAllLogs() {
    return (select(consistencyLogTable)
          ..orderBy([(l) => OrderingTerm.desc(l.date)]))
        .watch();
  }


  // ---------------------------------------------------------------------------
  // Single-fetch queries
  // ---------------------------------------------------------------------------

  /// Returns the log entry for [date], or null if none exists.
  Future<ConsistencyLog?> getLogForDate(DateTime date) {
    final d = _midnight(date);
    return (select(consistencyLogTable)..where((l) => l.date.equals(d)))
        .getSingleOrNull();
  }

  /// Convenience wrapper — returns today's log entry, or null.
  Future<ConsistencyLog?> getTodayLog() => getLogForDate(DateTime.now());

  /// Returns the longest ever streak of consecutive present days.
  Future<int> getLongestStreak() async {
    final logs = await (select(consistencyLogTable)
          ..orderBy([(l) => OrderingTerm.asc(l.date)]))
        .get();

    int longest = 0;
    int current = 0;
    DateTime? previous;

    for (final log in logs) {
      final logDate = _midnight(log.date);
      if (!log.present) {
        current = 0;
      } else if (previous == null) {
        current = 1;
      } else {
        final diff = logDate.difference(previous).inDays;
        current = (diff == 1) ? current + 1 : 1;
      }
      if (current > longest) longest = current;
      previous = logDate;
    }
    return longest;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts or updates the log entry for [date].
  /// Uses INSERT OR REPLACE semantics via the unique constraint on [date].
  Future<void> logDay(
    DateTime date,
    bool present, {
    String? note,
    double? hoursStudied,
  }) async {
    final d = _midnight(date);
    await into(consistencyLogTable).insertOnConflictUpdate(
      ConsistencyLogTableCompanion.insert(
        date: d,
        present: present,
        note: Value(note),
        hoursStudied: Value(hoursStudied),
      ),
    );
  }
}
