part of '../app_database.dart';

@DriftAccessor(tables: [ApplicationTable, ApplicationStatusHistoryTable])
class ApplicationDao extends DatabaseAccessor<AppDatabase>
    with _$ApplicationDaoMixin {
  ApplicationDao(super.db);

  // ---------------------------------------------------------------------------
  // Watch helpers
  // ---------------------------------------------------------------------------

  /// Stream of all applications, most recently updated first.
  Stream<List<ApplicationRow>> watchAllApplications() =>
      (select(applicationTable)
            ..orderBy([(a) => OrderingTerm.desc(a.updatedAt)]))
          .watch();

  /// Stream of applications in a specific [stage] (for Kanban columns).
  Stream<List<ApplicationRow>> watchApplicationsByStage(
    ApplicationStage stage,
  ) =>
      (select(applicationTable)
            ..where((a) => a.currentStage.equals(stage.name))
            ..orderBy([(a) => OrderingTerm.desc(a.updatedAt)]))
          .watch();

  /// Stream of applications where [nextActionDate] falls within [days] days
  /// from now, ordered soonest first.
  Stream<List<ApplicationRow>> watchApplicationsWithUpcomingActions(
    int days,
  ) {
    final now = DateTime.now();
    final windowEnd = now.add(Duration(days: days));
    return (select(applicationTable)
          ..where(
            (a) =>
                a.nextActionDate.isBiggerOrEqualValue(now) &
                a.nextActionDate.isSmallerThanValue(windowEnd),
          )
          ..orderBy([(a) => OrderingTerm.asc(a.nextActionDate)]))
        .watch();
  }

  /// Stream of status history for [applicationId], newest first.
  Stream<List<ApplicationStatusHistory>> watchStatusHistory(
    int applicationId,
  ) =>
      (select(applicationStatusHistoryTable)
            ..where((h) => h.applicationId.equals(applicationId))
            ..orderBy([
              (h) => OrderingTerm.desc(h.occurredAt),
              (h) => OrderingTerm.desc(h.id),
            ]))
          .watch();

  // ---------------------------------------------------------------------------
  // Single-fetch queries
  // ---------------------------------------------------------------------------

  /// Returns the application with [id], or null.
  Future<ApplicationRow?> getApplicationById(int id) =>
      (select(applicationTable)..where((a) => a.id.equals(id)))
          .getSingleOrNull();

  /// Stream of the application with [id], or null.
  Stream<ApplicationRow?> watchApplicationById(int id) =>
      (select(applicationTable)..where((a) => a.id.equals(id)))
          .watchSingleOrNull();

  /// Returns a map of stage → count for the funnel / Sankey chart on
  /// the Report Card screen.
  Future<Map<ApplicationStage, int>> getApplicationCountByStage() async {
    final count = applicationTable.id.count();
    final stage = applicationTable.currentStage;
    final query = selectOnly(applicationTable)
      ..addColumns([stage, count])
      ..groupBy([stage]);

    final rows = await query.get();
    return {
      for (final row in rows)
        ApplicationStage.values.firstWhere(
          (s) => s.name == row.read(stage),
          orElse: () => ApplicationStage.wishlist,
        ): row.read(count) ?? 0,
    };
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new application and records the initial status history entry.
  /// Returns the generated application id.
  Future<int> insertApplication(ApplicationTableCompanion companion) async {
    return transaction(() async {
      final id = await into(applicationTable).insert(companion);
      final initialStage = companion.currentStage.present
          ? companion.currentStage.value
          : 'wishlist';
      await into(applicationStatusHistoryTable).insert(
        ApplicationStatusHistoryTableCompanion(
          applicationId: Value(id),
          stage: Value(initialStage),
          occurredAt: Value(DateTime.now()),
        ),
      );
      return id;
    });
  }

  /// Partially updates an existing application row.
  /// Returns true if exactly one row was affected.
  Future<bool> updateApplication(ApplicationTableCompanion companion) async {
    final rowsAffected = await (update(applicationTable)
          ..where((a) => a.id.equals(companion.id.value)))
        .write(companion);
    return rowsAffected == 1;
  }

  /// Moves the application to [newStage], updating [currentStage] and
  /// [updatedAt], and appending a new [ApplicationStatusHistoryTable] row.
  Future<void> moveToStage(
    int id,
    ApplicationStage newStage, {
    String? notes,
  }) async {
    await transaction(() async {
      final now = DateTime.now();
      await (update(applicationTable)..where((a) => a.id.equals(id))).write(
        ApplicationTableCompanion(
          currentStage: Value(newStage.name),
          updatedAt: Value(now),
          lastInteractedAt: Value(now),
        ),
      );
      await into(applicationStatusHistoryTable).insert(
        ApplicationStatusHistoryTableCompanion(
          applicationId: Value(id),
          stage: Value(newStage.name),
          notes: Value(notes),
          occurredAt: Value(now),
        ),
      );
    });
  }

  /// Appends a new status journey event for [id] in [applicationStatusHistoryTable]
  /// and updates the application's [currentStage] to match atomically.
  Future<void> recordStatusChange(
    int id,
    ApplicationStage stage, {
    String? notes,
    DateTime? occurredAt,
  }) async {
    final eventTime = occurredAt ?? DateTime.now();
    await transaction(() async {
      await (update(applicationTable)..where((a) => a.id.equals(id))).write(
        ApplicationTableCompanion(
          currentStage: Value(stage.name),
          updatedAt: Value(eventTime),
          lastInteractedAt: Value(eventTime),
        ),
      );
      await into(applicationStatusHistoryTable).insert(
        ApplicationStatusHistoryTableCompanion(
          applicationId: Value(id),
          stage: Value(stage.name),
          notes: Value(notes),
          occurredAt: Value(eventTime),
        ),
      );
    });
  }

  /// Deletes the application and its associated status history rows.
  Future<int> deleteApplication(int id) async {
    return transaction(() async {
      await (delete(applicationStatusHistoryTable)
            ..where((h) => h.applicationId.equals(id)))
          .go();
      return (delete(applicationTable)..where((a) => a.id.equals(id))).go();
    });
  }
}
