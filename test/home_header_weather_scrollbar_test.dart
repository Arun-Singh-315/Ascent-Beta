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
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'weather_city': 'Bengaluru, India',
    });
  });

  UserProfile createTestProfile({String name = 'Arun'}) {
    return UserProfile(
      id: 1,
      name: name,
      targetRole: 'Engineering',
      targetCompanies: 'Google',
      weeklyHoursAvailable: 20,
      preferredStudyWindow: 'Morning',
      skillSelfRatings: '{}',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      dateOfBirth: DateTime(1998, 11, 10), // Scorpio
      onboardingComplete: true,
    );
  }

  group('HomeHeader Layout & Weather Design Tests', () {

    testWidgets(
      'Header chips use Wrap and have zero horizontal scrolling with all chips populated',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime(2026, 11, 15);
        final profile = createTestProfile();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayFestivalProvider.overrideWith(
                (ref) => const FestivalEvent(
                  id: 'diwali',
                  name: 'Diwali',
                  greeting: 'Happy Diwali',
                  thought: 'May light triumph over darkness.',
                  riyaWish: 'Happy Diwali',
                  month: 11,
                  day: 15,
                ),
              ),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(7),
              ),
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

        // All chips are rendered
        expect(
          find.byKey(const ValueKey('home_festival_banner')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('home_rashi')), findsOneWidget);
        expect(find.byKey(const ValueKey('home_streak_chip')), findsOneWidget);

        // Header chips must NOT be inside a horizontal scrollview
        final horizontalScrollables = find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        );
        expect(horizontalScrollables, findsNothing);

        // Chips are contained in a Wrap widget
        expect(find.byType(Wrap), findsWidgets);
      },
    );

    testWidgets(
      'Header is immune to overflow at 320px width with 2.0x accessibility text scale',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime(2026, 11, 15);
        final profile = createTestProfile(name: 'Arun Singh Visen');

        tester.view.physicalSize = const Size(320 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayFestivalProvider.overrideWith(
                (ref) => const FestivalEvent(
                  id: 'diwali',
                  name: 'Diwali',
                  greeting: 'Happy Diwali',
                  thought: 'May light triumph over darkness.',
                  riyaWish: 'Happy Diwali',
                  month: 11,
                  day: 15,
                ),
              ),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(12),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 844),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: Scaffold(
                  body: HomeHeader(profile: profile, now: now),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Zero exceptions and zero RenderFlex overflow
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('WeatherForecastSheet Scrollbar & Navigation Tests', () {
    testWidgets(
      'WeatherForecastSheet features a persistent side scrollbar and close button',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              homeWeatherProvider.overrideWith(
                (ref) async => {
                  'current': {
                    'temperature_2m': 21.0,
                    'apparent_temperature': 21.6,
                    'relative_humidity_2m': 65,
                    'weather_code': 3,
                    'wind_speed_10m': 5.8,
                  },
                  'daily': {
                    'time': ['2026-11-15', '2026-11-16', '2026-11-17'],
                    'temperature_2m_min': [19.0, 19.6, 19.2],
                    'temperature_2m_max': [27.0, 29.2, 29.7],
                    'precipitation_probability_max': [0, 0, 0],
                  },
                },
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(body: WeatherForecastSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify visible side scrollbar exists and wraps content
        expect(find.byType(Scrollbar), findsOneWidget);
        final scrollbar = tester.widget<Scrollbar>(find.byType(Scrollbar));
        expect(scrollbar.thumbVisibility, isTrue);

        // 2. Verify close button exists
        expect(
          find.byKey(const ValueKey('close_weather_sheet')),
          findsOneWidget,
        );

        // 3. Verify city name and weather title
        expect(find.text('Weather & Forecast'), findsOneWidget);
        expect(find.text('Bengaluru, India'), findsOneWidget);
        expect(find.text('Choose your city'), findsOneWidget);

        // 4. Tap close button pops
        await tester.tap(find.byKey(const ValueKey('close_weather_sheet')));
        await tester.pumpAndSettle();
      },
    );
  });
}
