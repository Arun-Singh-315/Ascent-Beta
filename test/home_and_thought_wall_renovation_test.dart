import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/festival_service.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/home_weather.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('Home Header & Section Visual Lineage Tests', () {
    testWidgets(
      'Header festival chip uses celebration icon distinct from weather',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayFestivalProvider.overrideWithValue(
                const FestivalEvent(
                  id: 'diwali_2026',
                  name: 'Diwali',
                  greeting: 'Happy Diwali!',
                  thought: 'Festival of Lights',
                  riyaWish: 'Happy Diwali!',
                  month: 11,
                  day: 8,
                  emoji: '🪔',
                  accentColor: Color(0xFFE0A94E),
                ),
              ),
              homeWeatherProvider.overrideWith((ref) => Future.value(null)),
            ],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HomeHeader(profile: null, now: DateTime(2026, 11, 16)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final festivalChip = find.byKey(const ValueKey('home_festival_banner'));
        expect(festivalChip, findsOneWidget);
        expect(find.byIcon(Icons.celebration_rounded), findsOneWidget);
        // Ensure no duplicate wb_sunny icon in header chips
        expect(find.byIcon(Icons.wb_sunny_rounded), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Header chips use Wrap layout and have zero horizontal scrollview',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayFestivalProvider.overrideWithValue(
                const FestivalEvent(
                  id: 'new_year_2026',
                  name: 'New Year',
                  greeting: 'Happy New Year!',
                  thought: 'Fresh beginnings',
                  riyaWish: 'Happy New Year!',
                  month: 1,
                  day: 1,
                  emoji: '✨',
                  accentColor: Color(0xFFE0A94E),
                ),
              ),
              homeWeatherProvider.overrideWith((ref) => Future.value(null)),
            ],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HomeHeader(profile: null, now: DateTime(2026, 11, 16)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(Wrap), findsWidgets);
        // Verify no SingleChildScrollView with Axis.horizontal in header
        final headerFinder = find.byKey(const ValueKey('home_day_header'));
        expect(
          find.descendant(
            of: headerFinder,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is SingleChildScrollView &&
                  w.scrollDirection == Axis.horizontal,
            ),
          ),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });

  group('Home Thought Wall Preview & Bubble Expansion Tests', () {
  });

  group('Thought Wall Screen Renovated Atmosphere & Bubbles Tests', () {

  });
}
