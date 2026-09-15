part of '../app_database.dart';

/// Data class returned by [SeriesDao.watchSeriesWithTaskCounts].
class SeriesWithTaskCounts {
  final Series series;
  final int completedCount;
  final int totalCount;

  const SeriesWithTaskCounts({
    required this.series,
    required this.completedCount,
    required this.totalCount,
  });
}

@DriftAccessor(tables: [SeriesTable, TaskTable])
class SeriesDao extends DatabaseAccessor<AppDatabase> with _$SeriesDaoMixin {
  SeriesDao(super.db);

  // ---------------------------------------------------------------------------
  // Watch helpers
  // ---------------------------------------------------------------------------

  /// Stream of all series rows, ordered by createdAt asc.
  Stream<List<Series>> watchAllSeries() =>
      (select(seriesTable)
            ..orderBy([(s) => OrderingTerm.asc(s.createdAt)]))
          .watch();

  /// Stream of series joined with per-series task counts.
  /// Used by the Report Card screen to show progress bars.
  Stream<List<SeriesWithTaskCounts>> watchSeriesWithTaskCounts() {
    // Use a custom SQL query for the aggregation.
    final query = customSelect(
      '''
      SELECT
        s.*,
        COUNT(t.id) AS total_count,
        SUM(CASE WHEN t.actual_completed_date IS NOT NULL THEN 1 ELSE 0 END)
          AS completed_count
      FROM series s
      LEFT JOIN tasks t ON t.series_id = s.id
      GROUP BY s.id
      ORDER BY s.created_at ASC
      ''',
      readsFrom: {seriesTable, taskTable},
    );

    return query.watch().map((rows) {
      return rows.map((row) {
        // Map the raw SQL row back to the generated Series data class.
        final series = Series(
          id: row.read<int>('id'),
          title: row.read<String>('title'),
          totalItems: row.readNullable<int>('total_items'),
          pacingRule: row.read<String>('pacing_rule'),
          fixedIntervalDays: row.readNullable<int>('fixed_interval_days'),
          endDate: row.readNullable<DateTime>('end_date'),
          linkedPhaseId: row.readNullable<int>('linked_phase_id'),
          createdAt: row.read<DateTime>('created_at'),
          updatedAt: row.read<DateTime>('updated_at'),
        );

        return SeriesWithTaskCounts(
          series: series,
          completedCount: row.read<int>('completed_count'),
          totalCount: row.read<int>('total_count'),
        );
      }).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Single-fetch queries
  // ---------------------------------------------------------------------------

  /// Returns the series with [id], or null.
  Future<Series?> getSeriesById(int id) =>
      (select(seriesTable)..where((s) => s.id.equals(id))).getSingleOrNull();

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new series and returns the generated id.
  Future<int> insertSeries(SeriesTableCompanion companion) =>
      into(seriesTable).insert(companion);

  /// Updates the series identified by [companion.id].
  /// Returns true if exactly one row was affected.
  Future<bool> updateSeries(SeriesTableCompanion companion) async {
    final affected = await (update(seriesTable)
          ..where((s) => s.id.equals(companion.id.value)))
        .write(companion);
    return affected == 1;
  }

  /// Deletes the series with [id].
  ///
  /// Tasks that belong to this series are NOT deleted — their [seriesId]
  /// column is set to NULL so they become standalone to-dos.
  Future<int> deleteSeries(int id) async {
    return transaction(() async {
      // Detach tasks from the series.
      await (update(taskTable)..where((t) => t.seriesId.equals(id))).write(
        const TaskTableCompanion(seriesId: Value(null)),
      );
      return (delete(seriesTable)..where((s) => s.id.equals(id))).go();
    });
  }
}
