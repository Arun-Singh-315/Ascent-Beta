import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  Future<void> setup({
    int seconds = 0,
    int threshold = 100,
    bool failSave = false,
  }) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final course = Course(
      id: 'qa',
      title: 'QA',
      modules: [
        CourseModule(
          id: 1,
          title: 'Module',
          lectures: [
            Lecture(
              id: 1,
              moduleId: 1,
              moduleTitle: 'Module',
              title: 'First',
              durationSeconds: 100,
              studySeconds: seconds,
              completionThresholdPercent: threshold,
            ),
            const Lecture(
              id: 2,
              moduleId: 1,
              moduleTitle: 'Module',
              title: 'Next',
              durationSeconds: 100,
            ),
          ],
        ),
      ],
    );
    SharedPreferences.setMockInitialValues({
      'ascent_learning_hub_courses_v3': jsonEncode([course.toJson()]),
      'ascent_learning_hub_active_course_v3': 'qa',
      'ascent_learning_hub_active_lecture_id_v3': 1,
    });
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (failSave)
          learningCourseSaveProvider.overrideWithValue(
            (_) async => throw StateError('Disk failure'),
          ),
      ],
    );
    await container.read(learningHubProvider.notifier).ready;
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });
  test(
    'Direct completion rejects ineligible and missing lectures without advancing',
    () async {
      await setup(seconds: 99);
      final notifier = container.read(learningHubProvider.notifier);
      expect(await notifier.markLectureCompleted(1), isFalse);
      expect(await notifier.markLectureCompleted(999), isFalse);
      expect(container.read(learningHubProvider).activeLectureId, 1);
      expect(
        container.read(learningHubProvider).activeLecture.isCompleted,
        isFalse,
      );
    },
  );
  test(
    'Eligible completion persists and is sticky; failed saves do not advance',
    () async {
      await setup(seconds: 50, threshold: 50);
      final notifier = container.read(learningHubProvider.notifier);
      expect(await notifier.markLectureCompleted(1), isTrue);
      expect(container.read(learningHubProvider).activeLectureId, 2);
      expect(await notifier.markLectureCompleted(1, completed: false), isFalse);
      expect(
        container
            .read(learningHubProvider)
            .course
            .modules
            .first
            .lectures
            .first
            .isCompleted,
        isTrue,
      );
    },
  );
  test(
    'Persistence failure leaves completion and selected lecture unchanged',
    () async {
      await setup(seconds: 100, failSave: true);
      expect(
        await container
            .read(learningHubProvider.notifier)
            .markLectureCompleted(1),
        isFalse,
      );
      expect(container.read(learningHubProvider).activeLectureId, 1);
      expect(
        container.read(learningHubProvider).activeLecture.isCompleted,
        isFalse,
      );
    },
  );
  test('Lecture editor cannot forge completion or engagement', () async {
    await setup();
    final notifier = container.read(learningHubProvider.notifier);
    final lecture = container.read(learningHubProvider).activeLecture;
    await notifier.updateLecture(
      'qa',
      lecture.copyWith(
        isCompleted: true,
        elapsedSeconds: 100,
        studySeconds: 100,
      ),
    );
    expect(
      container.read(learningHubProvider).activeLecture.isCompleted,
      isFalse,
    );
    expect(container.read(learningHubProvider).activeLecture.studySeconds, 0);
  });
}
