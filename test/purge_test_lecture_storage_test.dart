import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_catalog.dart';
import 'package:ascent/core/learning_hub/default_course_data.dart';
import 'support/returning_user_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Purge test lecture 38 and 90min test items from storage', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({
        ...returningUserGuidePrefs,
        'ascent_active_lecture_id': 38,
      });
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await db.close();
    });

    test('isTargetTestLecture correctly identifies test lecture 38 and 90min test variants', () {
      expect(
        isTargetTestLecture(const Lecture(
          id: 38,
          moduleId: 4,
          moduleTitle: 'Test Module',
          title: 'test )(',
          durationSeconds: 5400, // 90 min
        )),
        isTrue,
      );

      expect(
        isTargetTestLecture(const Lecture(
          id: 38,
          moduleId: 4,
          moduleTitle: 'Test Module',
          title: 'Lecture 38 Test',
          durationSeconds: 1200,
        )),
        isTrue,
      );

      expect(
        isTargetTestLecture(const Lecture(
          id: 99,
          moduleId: 4,
          moduleTitle: 'Test Module',
          title: 'test )(',
          durationSeconds: 5400,
        )),
        isTrue,
      );

      // Real course lectures are never flagged
      final springCourse = buildDefaultSpringBootCourse();
      for (final module in springCourse.modules) {
        for (final lecture in module.lectures) {
          expect(isTargetTestLecture(lecture), isFalse, reason: 'Flagged real lecture ${lecture.id}: ${lecture.title}');
        }
      }

      final javaCourse = buildCompleteJava2026Course();
      for (final module in javaCourse.modules) {
        for (final lecture in module.lectures) {
          expect(isTargetTestLecture(lecture), isFalse, reason: 'Flagged real lecture ${lecture.id}: ${lecture.title}');
        }
      }
    });

    test('LearningCatalog.loadOrImport purges test lecture 38 and linked 90min task/session from SQLite storage', () async {
      final baseCourse = buildDefaultSpringBootCourse();
      // Inject test lecture 38 into module 4
      final testLecture = const Lecture(
        id: 38,
        moduleId: 4,
        moduleTitle: 'Foundations',
        title: 'lecture 38 test )(',
        durationSeconds: 5400, // 90min
      );

      final contaminatedModules = baseCourse.modules.map((m) {
        if (m.id == 4) {
          return m.copyWith(lectures: [...m.lectures, testLecture]);
        }
        return m;
      }).toList();

      final contaminatedCourse = baseCourse.copyWith(modules: contaminatedModules);

      // Pre-populate SQLite CourseTable with contaminated course
      await db.courseDao.upsertCourse(
        CourseTableCompanion.insert(
          id: contaminatedCourse.id,
          title: contaminatedCourse.title,
          description: drift.Value(contaminatedCourse.description),
          author: drift.Value(contaminatedCourse.author),
          modulesJson: jsonEncode(contaminatedCourse.modules.map((m) => m.toJson()).toList()),
        ),
      );

      // Create a test task linked to lecture 38 with 90 min duration
      final taskId = await db.into(db.taskTable).insert(
        TaskTableCompanion.insert(
          title: 'lecture 38 test )(',
          learningCourseId: drift.Value(contaminatedCourse.id),
          learningLectureId: const drift.Value(38),
          estimatedMinutes: const drift.Value(90),
        ),
      );

      // Create a session linked to the test task
      await db.into(db.timeSessionTable).insert(
        TimeSessionTableCompanion.insert(
          label: 'lecture 38 test )(',
          categoryId: 1,
          linkedTaskId: drift.Value(taskId),
          learningCourseId: drift.Value(contaminatedCourse.id),
          learningLectureId: const drift.Value(38),
          startedAt: DateTime.now(),
          durationSeconds: const drift.Value(5400),
        ),
      );

      // Pre-condition check: lecture 38 exists in DB
      final dbEntriesBefore = await db.courseDao.getAllCourses();
      expect(dbEntriesBefore.first.modulesJson.contains('lecture 38 test )('), isTrue);

      final tasksBefore = await db.select(db.taskTable).get();
      expect(tasksBefore.any((t) => t.learningLectureId == 38), isTrue);

      // Execute loadOrImport
      final catalog = LearningCatalog(db, prefs);
      final cleanedCourses = await catalog.loadOrImport([contaminatedCourse]);

      // Assert lecture 38 is gone from returned courses
      final returnedLectures = cleanedCourses.expand((c) => c.modules).expand((m) => m.lectures).toList();
      expect(returnedLectures.any((l) => l.id == 38), isFalse);
      expect(returnedLectures.any((l) => l.title.contains('test )(')), isFalse);

      // Assert lecture 38 is purged from SQLite CourseTable storage
      final dbEntriesAfter = await db.courseDao.getAllCourses();
      expect(dbEntriesAfter.first.modulesJson.contains('lecture 38'), isFalse);
      expect(dbEntriesAfter.first.modulesJson.contains('test )('), isFalse);

      // Assert task and session are purged from SQLite storage
      final tasksAfter = await db.select(db.taskTable).get();
      expect(tasksAfter.any((t) => t.learningLectureId == 38 || t.title.contains('test )(')), isFalse);

      final sessionsAfter = await db.select(db.timeSessionTable).get();
      expect(sessionsAfter.any((s) => s.learningLectureId == 38 || s.label.contains('test )(')), isFalse);
    });
  });
}
