import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_weather.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'weather_city': 'Bengaluru, India',
    });
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
