part of '../app_database.dart';

@DriftAccessor(tables: [ResumeTable])
class ResumeDao extends DatabaseAccessor<AppDatabase> with _$ResumeDaoMixin {
  ResumeDao(super.db);

  /// Stream of all resumes, newest first.
  Stream<List<Resume>> watchAllResumes() => (select(resumeTable)
        ..orderBy([(r) => OrderingTerm.desc(r.uploadedAt)]))
      .watch();

  /// Get all resumes.
  Future<List<Resume>> getAllResumes() => (select(resumeTable)
        ..orderBy([(r) => OrderingTerm.desc(r.uploadedAt)]))
      .get();

  /// Get resume by id.
  Future<Resume?> getResumeById(int id) =>
      (select(resumeTable)..where((r) => r.id.equals(id))).getSingleOrNull();

  /// Insert a new resume version.
  Future<int> insertResume(ResumeTableCompanion companion) =>
      into(resumeTable).insert(companion);

  /// Update resume details (e.g. notes or company tailoring).
  Future<bool> updateResume(ResumeTableCompanion companion) async {
    final rowsAffected = await (update(resumeTable)
          ..where((r) => r.id.equals(companion.id.value)))
        .write(companion);
    return rowsAffected == 1;
  }

  /// Delete a resume entry.
  Future<int> deleteResume(int id) =>
      (delete(resumeTable)..where((r) => r.id.equals(id))).go();
}
