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
    SharedPreferences.setMockInitialValues({'weather_city': 'Mumbai, India'});
    prefs = await SharedPreferences.getInstance();
  });

  group('Dynamic HomeHeader Data & Atmospheric Canvas Tests', () {
    testWidgets(
      'Header strictly renders dynamic profile name and role from database without hardcoded fallbacks',
      (tester) async {
        final now = DateTime(2026, 11, 17, 9, 30);
        final dynamicProfile = UserProfile(
          id: 42,
          name: 'Kavita',
          targetRole: 'VP of Product Design',
          targetCompanies: '["Figma", "Apple"]',
          weeklyHoursAvailable: 15,
          preferredStudyWindow: 'Morning',
          skillSelfRatings: '{}',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          dateOfBirth: DateTime(1994, 10, 24), // Scorpio / Vrishchika
          onboardingComplete: true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayFestivalProvider.overrideWith((ref) => null),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(10),
              ),
              homeWeatherProvider.overrideWith(
                (ref) => Future.value({
                  'current': {'temperature_2m': 29.0, 'weather_code': 0},
                }),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: HomeHeader(profile: dynamicProfile, now: now),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify dynamic name
        expect(find.text('Kavita'), findsOneWidget);
        expect(find.text('Arun'), findsNothing);

        // Verify role clutter and hardcoded job titles are cleanly omitted
        expect(find.text('VP of Product Design'), findsNothing);
        expect(find.text('Staff Software Engineer'), findsNothing);
        expect(find.text('Profile'), findsNothing);

        // Verify dynamic city from SharedPreferences
        expect(find.textContaining('Mumbai'), findsOneWidget);
        expect(find.textContaining('Bhopal'), findsNothing);

        // Verify dynamic Vedic Rashi for Scorpio (Vrishchika)
        expect(find.textContaining('Vrishchika'), findsOneWidget);
        expect(find.textContaining('Scorpio'), findsOneWidget);
        expect(find.textContaining('Mithuna'), findsNothing);
      },
    );

    testWidgets('Header omits role cleanly when user has no targetRole set', (
      tester,
    ) async {
      final now = DateTime(2026, 11, 17, 9, 30);
      final profileWithoutRole = UserProfile(
        id: 7,
        name: 'Sameer',
        targetRole: '', // No role configured
        targetCompanies: '[]',
        weeklyHoursAvailable: 10,
        preferredStudyWindow: 'Evening',
        skillSelfRatings: '{}',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        dateOfBirth: DateTime(1998, 3, 25), // Aries / Mesha
        onboardingComplete: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayFestivalProvider.overrideWith((ref) => null),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(5)),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: HomeHeader(profile: profileWithoutRole, now: now),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sameer'), findsOneWidget);
      expect(find.text('Staff Software Engineer'), findsNothing);
      expect(find.text('Inner Peace'), findsNothing);
    });

    testWidgets(
      'Header dynamically adapts atmosphere for Rain weather and time of day',
      (tester) async {
        // 1. Rainy afternoon (14:00, weather code 61: Rain)
        final rainyAfternoon = DateTime(2026, 11, 17, 14, 0);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayFestivalProvider.overrideWith((ref) => null),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(0),
              ),
              homeWeatherProvider.overrideWith(
                (ref) => Future.value({
                  'current': {
                    'temperature_2m': 21.0,
                    'weather_code': 61, // Rain
                  },
                }),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: Scaffold(
                body: HomeHeader(profile: null, now: rainyAfternoon),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify afternoon greeting
        expect(find.text('Good afternoon,'), findsOneWidget);
        expect(find.text('Peak hours'), findsOneWidget);

        // Verify rain condition is communicated
        expect(find.textContaining('Rain'), findsOneWidget);
        expect(find.textContaining('21°'), findsOneWidget);

        // Atmospheric canvas is present
        expect(
          find.byKey(const ValueKey('home_atmospheric_canvas')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Header dynamically adapts atmosphere for Night and Evening', (
      tester,
    ) async {
      // Evening (18:30)
      final evening = DateTime(2026, 11, 17, 18, 30);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayFestivalProvider.overrideWith((ref) => null),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(0)),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(body: HomeHeader(profile: null, now: evening)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Good evening,'), findsOneWidget);
      expect(find.text('Golden hour'), findsOneWidget);

      // Night (23:15)
      final night = DateTime(2026, 11, 17, 23, 15);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayFestivalProvider.overrideWith((ref) => null),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(0)),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: Scaffold(body: HomeHeader(profile: null, now: night)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Good night,'), findsOneWidget);
      expect(find.text('Quiet hours'), findsOneWidget);
    });

    testWidgets(
      'Dynamic header with rain animation is overflow immune at 320px with 2.0x scale',
      (tester) async {
        final now = DateTime(2026, 11, 17, 8, 30);
        final profile = UserProfile(
          id: 1,
          name: 'Devangana Sharma',
          targetRole:
              'Lead Quantitative Researcher & Machine Learning Engineer',
          targetCompanies: '["Jane Street", "Two Sigma"]',
          weeklyHoursAvailable: 25,
          preferredStudyWindow: 'Morning',
          skillSelfRatings: '{}',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          dateOfBirth: DateTime(1997, 7, 15), // Cancer / Karka
          onboardingComplete: true,
        );

        tester.view.physicalSize = const Size(320 * 2, 950 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayFestivalProvider.overrideWith((ref) => null),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(18),
              ),
              homeWeatherProvider.overrideWith(
                (ref) => Future.value({
                  'current': {
                    'temperature_2m': 19.5,
                    'weather_code': 63, // Moderate Rain
                  },
                }),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 950),
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
        expect(
          find.byKey(const ValueKey('home_atmospheric_canvas')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('home_profile_button')),
          findsOneWidget,
        );
      },
    );
  });
}
