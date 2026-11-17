import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/festival_service.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/home_weather.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'weather_city': 'Bengaluru, India',
    });
    prefs = await SharedPreferences.getInstance();
  });

  UserProfile createTestProfile({
    String name = 'Arun',
    String role = 'Staff Software Engineer',
    DateTime? dob,
  }) {
    return UserProfile(
      id: 1,
      name: name,
      targetRole: role,
      targetCompanies: '["Google"]',
      weeklyHoursAvailable: 20,
      preferredStudyWindow: 'Morning',
      skillSelfRatings: '{}',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      dateOfBirth: dob ?? DateTime(1996, 6, 5), // Gemini / Mithuna
      onboardingComplete: true,
    );
  }

  group('HomeHeader Premium Redesign & Layout Tests', () {
    testWidgets('Avatar initial is placed on top right alongside day/night toggle', (tester) async {
      final now = DateTime(2026, 11, 17, 10, 0);
      final profile = createTestProfile();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayFestivalProvider.overrideWith((ref) => null),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: HomeHeader(profile: profile, now: now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find avatar button on the right
      final avatarFinder = find.byKey(const ValueKey('home_profile_button'));
      expect(avatarFinder, findsOneWidget);

      // Find Day/Night theme toggle button on top right
      final themeToggleFinder = find.byKey(const ValueKey('home_theme_toggle_btn'));
      expect(themeToggleFinder, findsOneWidget);

      // Verify avatar is horizontally to the right of date
      final dateFinder = find.byKey(const ValueKey('home_date'));
      expect(dateFinder, findsOneWidget);

      final dateOffset = tester.getTopLeft(dateFinder);
      final avatarOffset = tester.getTopLeft(avatarFinder);
      final toggleOffset = tester.getTopLeft(themeToggleFinder);

      // Avatar & Toggle must be to the right of date
      expect(avatarOffset.dx, greaterThan(dateOffset.dx));
      expect(toggleOffset.dx, greaterThan(dateOffset.dx));

      // Name is prominently displayed with clean typography without role clutter
      expect(find.byKey(const ValueKey('home_user_name')), findsOneWidget);
      expect(find.text('Arun'), findsOneWidget);
      expect(find.text('Staff Software Engineer'), findsNothing);
      expect(find.text('Profile'), findsNothing);
    });

    testWidgets('Tapping day/night toggle changes theme mode smoothly', (tester) async {
      final now = DateTime(2026, 11, 17, 10, 0);
      final profile = createTestProfile();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayFestivalProvider.overrideWith((ref) => null),
          currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
          homeWeatherProvider.overrideWith((ref) => Future.value(null)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: HomeHeader(profile: profile, now: now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final themeToggle = find.byKey(const ValueKey('home_theme_toggle_btn'));
      expect(themeToggle, findsOneWidget);

      // Tap theme toggle to switch to dark mode
      await tester.tap(themeToggle);
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });

    testWidgets('Weather and Rashi are combined in atmospheric celestial card', (tester) async {
      final now = DateTime(2026, 11, 17, 10, 0);
      final profile = createTestProfile(dob: DateTime(1996, 6, 5)); // Gemini / Mithuna

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayFestivalProvider.overrideWith((ref) => null),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: HomeHeader(profile: profile, now: now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Atmospheric container exists
      expect(find.byKey(const ValueKey('home_atmospheric_card')), findsOneWidget);

      // Weather widget exists inside atmospheric card
      expect(find.byKey(const ValueKey('home_weather')), findsOneWidget);

      // Vedic Rashi exists inside atmospheric card with symbol and name
      final rashiFinder = find.byKey(const ValueKey('home_rashi'));
      expect(rashiFinder, findsOneWidget);
      expect(find.textContaining('Mithuna'), findsOneWidget);
      expect(find.textContaining('Gemini'), findsOneWidget);
    });

    testWidgets('HomeHeader renders with zero overflow at 320px with 2.0x scale', (tester) async {
      final now = DateTime(2026, 11, 17, 10, 0);
      final profile = createTestProfile(
        name: 'Arun Singh Visen',
        role: 'Principal Systems Architect & Lead Engineer',
      );

      tester.view.physicalSize = const Size(320 * 2, 900 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayFestivalProvider.overrideWith((ref) => const FestivalEvent(
                  id: 'diwali',
                  name: 'Diwali',
                  greeting: 'Happy Diwali',
                  thought: 'May light triumph over darkness.',
                  riyaWish: 'Happy Diwali',
                  month: 11,
                  day: 17,
                )),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(21)),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 900),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: HomeHeader(profile: profile, now: now),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home_profile_button')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_theme_toggle_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_atmospheric_card')), findsOneWidget);
    });

    testWidgets('Ask Assistant card has constrained width and is centered', (tester) async {
      final now = DateTime(2026, 11, 17, 10, 0);
      final profile = createTestProfile();

      tester.view.physicalSize = const Size(400 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayFestivalProvider.overrideWith((ref) => null),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeHeader(profile: profile, now: now),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final heroFinder = find.byKey(const ValueKey('home_assistant_button'));
      expect(heroFinder, findsOneWidget);

      final heroSize = tester.getSize(heroFinder);
      // Max card width should be constrained to 336 on a 400px screen
      expect(heroSize.width, lessThanOrEqualTo(336.0));
      // And centered: left and right margins should be balanced
      final heroTopLeft = tester.getTopLeft(heroFinder);
      final heroCenter = heroTopLeft.dx + heroSize.width / 2;
      expect(heroCenter, closeTo(200.0, 1.0));
    });
  });
}
