import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/default_course_data.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Lightweight Hydration Architecture Tests', () {
    test('WaterDao supports daily goal configuration and logs correctly', () async {
      final waterDao = db.waterDao;

      // Initial default goal is 2500 mL
      final defaultGoal = await waterDao.watchDailyWaterGoal().first;
      expect(defaultGoal, 2500);

      // Set new goal to 3000 mL
      await waterDao.setDailyWaterGoal(3000);
      final updatedGoal = await waterDao.watchDailyWaterGoal().first;
      expect(updatedGoal, 3000);

      // Log 500 mL of water
      await waterDao.addWater(500);
      final totalWater = await waterDao.watchTodayWaterMl().first;
      expect(totalWater, 500);

      // Verify logs
      final logs = await waterDao.watchTodayWaterLogs().first;
      expect(logs.length, 1);
      expect(logs.first.amountMl, 500);

      // Delete log
      await waterDao.deleteWater(logs.first.id);
      final emptyLogs = await waterDao.watchTodayWaterLogs().first;
      expect(emptyLogs, isEmpty);
    });
  });

  group('Learning Hub Hero Model Tests', () {
    test('Spring Boot course initializes with 4 modules and 37 lectures', () {
      final defaultCourse = buildDefaultSpringBootCourse();
      final state = LearningHubState(
        course: defaultCourse,
        activeLectureId: 1,
      );
      final course = state.course;

      expect(course.title, 'Spring Boot Mastery: From Basics to Production');
      expect(course.modules.length, 4);
      expect(course.totalLectures, 37);
      expect(course.completedLectures, 0);
      expect(course.progressPercent, 0);
    });
  });

  group('Back Navigation Double-Tap Logic Tests', () {
    test('Double-tap within 2000ms triggers exit confirmation', () {
      DateTime? lastBackPress;
      bool shouldExit = false;

      void onBackPress(DateTime now) {
        if (lastBackPress == null || now.difference(lastBackPress!) > const Duration(seconds: 2)) {
          lastBackPress = now;
          shouldExit = false;
        } else {
          shouldExit = true;
        }
      }

      final t0 = DateTime(2026, 10, 6, 12, 0, 0);
      onBackPress(t0);
      expect(shouldExit, isFalse);

      // Pressing 1 second later -> should allow exit
      final t1 = t0.add(const Duration(seconds: 1));
      onBackPress(t1);
      expect(shouldExit, isTrue);

      // Pressing 3 seconds later -> should NOT exit (reset timer)
      final t2 = t1.add(const Duration(seconds: 3));
      onBackPress(t2);
      expect(shouldExit, isFalse);
    });
  });
}
