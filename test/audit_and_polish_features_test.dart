import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/auth/auth_provider.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/notes/kindle_book_reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Authentication & Security Tests', () {
    test('AuthProvider succeeds with correct credentials (arn / 1234)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final authNotifier = container.read(authProvider.notifier);
      expect(container.read(authProvider).isAuthenticated, false);

      final success = await authNotifier.login('arn', '1234');
      expect(success, true);
      expect(container.read(authProvider).isAuthenticated, true);
      expect(container.read(authProvider).username, 'arn');
      expect(prefs.getBool('ascent_is_authenticated_v1'), true);
      expect(prefs.getString('ascent_auth_username_v1'), 'arn');

      // Test Logout
      await authNotifier.logout();
      expect(container.read(authProvider).isAuthenticated, false);
      expect(prefs.getBool('ascent_is_authenticated_v1'), false);
    });

    test('AuthProvider rejects incorrect credentials with meaningful result', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final authNotifier = container.read(authProvider.notifier);
      final success = await authNotifier.login('wrong_user', '0000');
      expect(success, false);
      expect(container.read(authProvider).isAuthenticated, false);
    });
  });

  group('Kindle Reader Themes & Model Verification Tests', () {
    test('Kindle themes define soothing, high-contrast book palettes', () {
      expect(KindleTheme.sepia.label, 'Warm Sepia');
      expect(KindleTheme.sepia.bg.toARGB32(), 0xFFFBF0D9);
      expect(KindleTheme.dark.label, 'Dark OLED');
      expect(KindleTheme.light.label, 'Crisp Day');
      expect(KindleTheme.sage.label, 'Forest Sage');
    });

    test('Course model correctly calculates duration and progress for catalog', () {
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
    });
  });
}
