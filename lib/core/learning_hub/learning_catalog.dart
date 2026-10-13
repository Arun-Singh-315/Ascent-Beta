import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/app_database.dart';
import 'learning_hub_models.dart';

const learningCatalogPreferenceKey = 'ascent_learning_hub_courses_v3';
const _catalogIdentity = 'learning.catalog.initialized.v1';

/// SQLite owns the catalog after the one-time import. Preferences are a cache.
/// The marker also distinguishes an intentionally empty catalog from no import.
class LearningCatalog {
  LearningCatalog(this.db, this.preferences);
  final AppDatabase db;
  final SharedPreferences preferences;

  Future<List<Course>> loadOrImport(List<Course> legacy) => db.transaction(
    () async {
      final marker = await (db.select(
        db.aiCommandTable,
      )..where((r) => r.requestId.equals(_catalogIdentity))).getSingleOrNull();
      final entries = await db.courseDao.getAllCourses();
      if (marker == null &&
          (entries.isEmpty ||
              preferences.getString(learningCatalogPreferenceKey) != null)) {
        await _replace(legacy);
        return legacy;
      }
      if (marker == null) {
        await db
            .into(db.aiCommandTable)
            .insert(
              AiCommandTableCompanion.insert(
                requestId: _catalogIdentity,
                capability: 'learning.catalog',
                argumentsJson: '{}',
                resultJson: '{}',
              ),
            );
      }
      return entries
          .map(
            (entry) => Course.fromJson({
              'id': entry.id,
              'title': entry.title,
              'description': entry.description,
              'author': entry.author,
              'category': entry.category,
              'sourceUrl': entry.sourceUrl,
              'targetCompletionDate': entry.targetCompletionDate
                  ?.toIso8601String(),
              'daysLeft': entry.daysLeft,
              'targetMinutesPerDay': entry.targetMinutesPerDay,
              'modules': jsonDecode(entry.modulesJson),
              'createdAt': entry.createdAt.toIso8601String(),
            }),
          )
          .toList();
    },
  );

  Future<void> saveCourses(List<Course> courses) =>
      db.transaction(() => _replace(courses));

  Future<void> cache(List<Course> courses) async {
    try {
      await preferences.setString(
        learningCatalogPreferenceKey,
        jsonEncode(courses.map((c) => c.toJson()).toList()),
      );
    } catch (_) {}
  }

  Future<void> saveJson(String json) async {
    final courses = (jsonDecode(json) as List)
        .map((c) => Course.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList();
    await db.transaction(() => _replace(courses));
    // A cache failure must not undo or misreport the committed domain write.
    try {
      await preferences.setString(learningCatalogPreferenceKey, json);
    } catch (_) {}
  }

  Future<void> _replace(List<Course> courses) async {
    final ids = courses.map((c) => c.id).toSet();
    if (ids.length != courses.length) {
      throw ArgumentError('Course IDs must be unique');
    }
    for (final course in courses) {
      final lectureIds = course.modules
          .expand((m) => m.lectures)
          .map((l) => l.id)
          .toList();
      if (lectureIds.toSet().length != lectureIds.length ||
          course.modules.map((m) => m.id).toSet().length !=
              course.modules.length) {
        throw ArgumentError(
          'Module and lecture IDs must be unique within a course',
        );
      }
      await db.courseDao.upsertCourse(
        CourseTableCompanion.insert(
          id: course.id,
          title: course.title,
          description: Value(course.description),
          author: Value(course.author),
          category: Value(course.category),
          sourceUrl: Value(course.sourceUrl),
          targetCompletionDate: Value(course.targetCompletionDate),
          daysLeft: Value(course.daysLeft),
          targetMinutesPerDay: Value(course.targetMinutesPerDay),
          modulesJson: jsonEncode(
            course.modules.map((m) => m.toJson()).toList(),
          ),
          createdAt: Value(course.createdAt),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
    final linked = await (db.select(
      db.taskTable,
    )..where((t) => t.learningCourseId.isNotNull())).get();
    for (final task in linked) {
      final course = courses
          .where((c) => c.id == task.learningCourseId)
          .firstOrNull;
      if (course == null ||
          !course.modules
              .expand((m) => m.lectures)
              .any((l) => l.id == task.learningLectureId)) {
        await (db.update(
          db.taskTable,
        )..where((t) => t.id.equals(task.id))).write(
          const TaskTableCompanion(
            learningCourseId: Value(null),
            learningLectureId: Value(null),
          ),
        );
      } else {
        await db.taskDao.completeTaskForLecture(task.id);
      }
    }
    await (db.delete(db.courseTable)..where((c) => c.id.isNotIn(ids))).go();
    await db
        .into(db.aiCommandTable)
        .insertOnConflictUpdate(
          AiCommandTableCompanion.insert(
            requestId: _catalogIdentity,
            capability: 'learning.catalog',
            argumentsJson: '{}',
            resultJson: '{}',
          ),
        );
  }
}
