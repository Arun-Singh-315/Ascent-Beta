part of '../app_database.dart';

@DriftAccessor(tables: [UpcomingInterviewTable])
class UpcomingInterviewDao extends DatabaseAccessor<AppDatabase>
    with _$UpcomingInterviewDaoMixin {
  UpcomingInterviewDao(super.db);

  /// Watch all upcoming interviews ordered by interviewDate ascending.
  Stream<List<UpcomingInterview>> watchUpcomingInterviews() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return (select(upcomingInterviewTable)
          ..where((i) => i.interviewDate.isBiggerOrEqualValue(startOfToday))
          ..orderBy([(i) => OrderingTerm.asc(i.interviewDate)]))
        .watch();
  }

  /// Watch the nearest upcoming interview (today or in future).
  Stream<UpcomingInterview?> watchNextInterview() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return (select(upcomingInterviewTable)
          ..where((i) => i.interviewDate.isBiggerOrEqualValue(startOfToday))
          ..orderBy([(i) => OrderingTerm.asc(i.interviewDate)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Get the nearest upcoming interview asynchronously.
  Future<UpcomingInterview?> getNextInterview() {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    return (select(upcomingInterviewTable)
          ..where((i) => i.interviewDate.isBiggerOrEqualValue(startOfToday))
          ..orderBy([(i) => OrderingTerm.asc(i.interviewDate)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Insert a new upcoming interview.
  Future<int> insertInterview(UpcomingInterviewTableCompanion interview) {
    return into(upcomingInterviewTable).insert(interview);
  }

  /// Update an existing upcoming interview.
  Future<bool> updateInterview(UpcomingInterviewTableCompanion interview) {
    return update(upcomingInterviewTable).replace(interview);
  }

  /// Delete interview by id.
  Future<int> deleteInterview(int id) {
    return (delete(upcomingInterviewTable)..where((i) => i.id.equals(id))).go();
  }

  /// Clear all upcoming interviews.
  Future<int> clearAll() {
    return delete(upcomingInterviewTable).go();
  }
}
