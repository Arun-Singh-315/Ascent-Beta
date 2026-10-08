part of '../app_database.dart';

@DriftAccessor(tables: [CourseTable])
class CourseDao extends DatabaseAccessor<AppDatabase> with _$CourseDaoMixin {
  CourseDao(super.db);

  Stream<List<CourseEntry>> watchAllCourses() =>
      (select(courseTable)..orderBy([(c) => OrderingTerm.asc(c.createdAt)])).watch();

  Future<List<CourseEntry>> getAllCourses() =>
      (select(courseTable)..orderBy([(c) => OrderingTerm.asc(c.createdAt)])).get();

  Future<CourseEntry?> getCourseById(String id) =>
      (select(courseTable)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<void> upsertCourse(CourseTableCompanion course) =>
      into(courseTable).insertOnConflictUpdate(course);

  Future<int> deleteCourse(String id) =>
      (delete(courseTable)..where((c) => c.id.equals(id))).go();
}
