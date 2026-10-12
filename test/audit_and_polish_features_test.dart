import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/features/book_reader/kindle_book_reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Kindle Reader Themes & Model Verification Tests', () {
    test('Kindle themes define soothing, high-contrast book palettes', () {
      expect(KindleTheme.sepia.label, 'Warm Sepia');
      expect(KindleTheme.sepia.bg.toARGB32(), 0xFFFBF0D9);
      expect(KindleTheme.dark.label, 'Dark OLED');
      expect(KindleTheme.light.label, 'Crisp Day');
      expect(KindleTheme.sage.label, 'Forest Sage');
    });

    test(
      'Course model correctly calculates duration and progress for catalog',
      () {
        final module1 = CourseModule(
          id: 1,
          title: 'Module 1',
          lectures: const [
            Lecture(
              id: 1,
              moduleId: 1,
              moduleTitle: 'Module 1',
              title: 'Intro',
              durationSeconds: 1800,
              isCompleted: true,
            ),
            Lecture(
              id: 2,
              moduleId: 1,
              moduleTitle: 'Module 1',
              title: 'Setup',
              durationSeconds: 2700,
              isCompleted: false,
            ),
          ],
        );
        final course = Course(
          id: 'c1',
          title: 'Spring Boot Mastery',
          author: 'Arun',
          modules: [module1],
        );

        expect(course.totalLectures, 2);
        expect(course.completedLectures, 1);
        expect(course.totalDurationSeconds, 1800 + 2700);
        expect((course.totalDurationSeconds / 3600), closeTo(1.25, 0.01));
        expect(course.progressPercent, 50);
      },
    );
  });
}
