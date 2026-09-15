part of '../app_database.dart';

@DriftAccessor(tables: [StudyPhaseTable, TaskTable])
class StudyPhaseDao extends DatabaseAccessor<AppDatabase>
    with _$StudyPhaseDaoMixin {
  StudyPhaseDao(super.db);

  /// Stream of all phases, ordered by orderIndex asc.
  Stream<List<StudyPhase>> watchAllPhases() => (select(studyPhaseTable)
        ..orderBy([(p) => OrderingTerm.asc(p.orderIndex)]))
      .watch();

  /// Single-fetch of all phases.
  Future<List<StudyPhase>> getAllPhases() => (select(studyPhaseTable)
        ..orderBy([(p) => OrderingTerm.asc(p.orderIndex)]))
      .get();

  /// Single-fetch phase by id.
  Future<StudyPhase?> getPhaseById(int id) =>
      (select(studyPhaseTable)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  /// Insert a new study phase.
  Future<int> insertPhase(StudyPhaseTableCompanion companion) =>
      into(studyPhaseTable).insert(companion);

  /// Update an existing study phase.
  Future<bool> updatePhase(StudyPhaseTableCompanion companion) async {
    final rowsAffected = await (update(studyPhaseTable)
          ..where((p) => p.id.equals(companion.id.value)))
        .write(companion);
    return rowsAffected == 1;
  }

  /// Delete a phase.
  Future<int> deletePhase(int id) =>
      (delete(studyPhaseTable)..where((p) => p.id.equals(id))).go();
}
