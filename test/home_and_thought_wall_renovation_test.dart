import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/festival_service.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/home_weather.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/shared/widgets/thought_excerpt.dart';
import 'package:drift/drift.dart' show Value;
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
    testWidgets('Header festival chip uses celebration icon distinct from weather', (tester) async {
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
    });

    testWidgets('Header chips use Wrap layout and have zero horizontal scrollview', (tester) async {
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
            (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
          ),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('Home Thought Wall Preview & Bubble Expansion Tests', () {
    testWidgets('Renders latest thought in tactile glass bubble with category and timestamp', (tester) async {
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'A positive spark for today.',
          category: const Value('spark'),
          mood: const Value('spark'),
          createdAt: Value(DateTime.now()),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(compact: true),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      final bubble = find.byKey(const ValueKey('home_latest_thought_bubble'));
      expect(bubble, findsOneWidget);
      expect(find.text('#spark'), findsOneWidget);
      expect(find.text('A positive spark for today.'), findsOneWidget);
      expect(find.byTooltip('Thought actions'), findsOneWidget);

      // Verify quick chips use Wrap with zero horizontal scrolling
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home_mind_space_card')),
          matching: find.byWidgetPredicate(
            (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
          ),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('Tapping "Show more" expands bubble inline without popup dialog', (tester) async {
      final longContent = List.generate(8, (i) => 'Line ${i + 1}: Continuous reflection and mindful presence.').join('\n');
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: longContent,
          createdAt: Value(DateTime.now()),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            homeWeatherProvider.overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(compact: true),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      // Verify collapsed initial state has maxLines: 4 and shows "Show more" button
      final textBefore = tester.widget<Text>(find.byKey(const ValueKey('home_latest_thought_text')));
      expect(textBefore.maxLines, 4);

      final expandToggle = find.byKey(const ValueKey('home_thought_expand_toggle'));
      expect(expandToggle, findsOneWidget);
      expect(find.text('Show more'), findsOneWidget);

      // Tap "Show more"
      await tester.tap(expandToggle);
      await settle(tester);

      // Verify no dialog or popup was opened
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      // Verify expanded inline state
      final textAfter = tester.widget<Text>(find.byKey(const ValueKey('home_latest_thought_text')));
      expect(textAfter.maxLines, isNull);
      expect(find.text('Show less'), findsOneWidget);

      // Tap "Show less" to collapse back
      await tester.tap(expandToggle);
      await settle(tester);

      final textCollapsedAgain = tester.widget<Text>(find.byKey(const ValueKey('home_latest_thought_text')));
      expect(textCollapsedAgain.maxLines, 4);
      expect(find.text('Show more'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });

  group('Thought Wall Screen Renovated Atmosphere & Bubbles Tests', () {
    testWidgets('Mindspace bubbles render with balanced margins and inline expansion', (tester) async {
      tester.view.physicalSize = const Size(400 * 2, 1000 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final longThought = List.generate(10, (i) => 'Mindspace line $i: deep learning and creative synthesis.').join('\n');
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: longThought,
          createdAt: Value(DateTime.now()),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const ThoughtWallScreen(),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Mindspace'), findsOneWidget);

      // Find ThoughtExcerpt inside ThoughtCardBubble
      expect(find.byType(ThoughtExcerpt), findsOneWidget);
      final showMore = find.text('Show more');
      expect(showMore, findsOneWidget);

      // Tap "Show more" inside Mindspace wall
      await tester.tap(showMore);
      await settle(tester);

      // Expanded inline: shows "Show less" with zero popups
      expect(find.text('Show less'), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('320px width & 2.0x accessibility text scale immunity', (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Accessibility test thought for high zoom viewports.',
          createdAt: Value(DateTime.now()),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
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
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    HomeHeader(profile: null, now: DateTime(2026, 11, 16)),
                    const ThoughtWallHomePreview(compact: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);

      // Assert zero RenderFlex overflows
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
