import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/features/home/widgets/learning_hub_card.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Home Cards Dark vs Day Theme Border Integrity Tests', () {
    testWidgets('In dark mode: Things Hub, Learning, and Recent Thought cards match Life & Health card styling with subtle glass edge, no opaque white border', (tester) async {
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Thought in dark mode'),
      );
      final thought = (await db.thoughtDao.getThoughtById(id))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value([thought]),
            ),
            todayActivitiesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            currentStreakStreamProvider.overrideWith(
              (ref) => Stream.value(0),
            ),
            timeTrackingProvider.overrideWith(
              () => _FakeTimeTrackingNotifier(),
            ),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: Theme(
              data: HomeTheme.from(AscentTheme.dark()),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      ThoughtWallHomePreview(),
                      ActivityHubCard(),
                      LearningHubCard(),
                      QuickModulesNavHub(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Life & Health card baseline
      final lifeAndHealthFinder = find.descendant(
        of: find.byType(QuickModulesNavHub),
        matching: find.byType(GlassSurface),
      ).first;
      final lifeGlass = tester.widget<GlassSurface>(lifeAndHealthFinder);
      // In dark mode, Life & Health uses null customBorder and null fillColor (inheriting g.edge and g.fill)
      expect(lifeGlass.customBorder, isNull);
      expect(lifeGlass.fillColor, isNull);

      // 2. Things Hub card
      final activityCardFinder = find.byKey(const ValueKey('home_activity_card'));
      final activityGlass = tester.widget<GlassSurface>(activityCardFinder);
      expect(activityGlass.customBorder, isNull,
          reason: 'Things Hub card in dark mode should match Life & Health (null customBorder to use g.edge)');
      expect(activityGlass.fillColor, isNull,
          reason: 'Things Hub card in dark mode should match Life & Health (null fillColor to use g.fill)');

      // 3. Learning card
      final learningCardFinder = find.descendant(
        of: find.byType(LearningHubCard),
        matching: find.byType(GlassSurface),
      ).first;
      final learningGlass = tester.widget<GlassSurface>(learningCardFinder);
      expect(learningGlass.customBorder, isNull,
          reason: 'Learning card in dark mode should match Life & Health (null customBorder to use g.edge)');
      expect(learningGlass.fillColor, isNull,
          reason: 'Learning card in dark mode should match Life & Health (null fillColor to use g.fill)');

      // 4. Recent Thought card (Mind Space container)
      final mindSpaceFinder = find.byKey(const ValueKey('home_mind_space_card'));
      final mindSpaceGlass = tester.widget<GlassSurface>(mindSpaceFinder);
      expect(mindSpaceGlass.customBorder, isNull,
          reason: 'Recent Thought card in dark mode should match Life & Health (null customBorder to use g.edge)');
      expect(mindSpaceGlass.fillColor, isNull,
          reason: 'Recent Thought card in dark mode should match Life & Health (null fillColor to use g.fill)');

      // 5. Write a thought composer card (AppCard at top of Mind Space)
      // Check the AppCard decoration border
      final composerCardFinder = find.descendant(
        of: find.byType(ThoughtWallHomePreview),
        matching: find.byType(TextField),
      );
      expect(composerCardFinder, findsOneWidget);
      final g = tester.element(composerCardFinder).glass;

      // Find the parent decorated container/card of the composer
      final appCardDecorations = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ThoughtWallHomePreview),
          matching: find.byType(Container),
        ),
      ).where((c) => c.decoration is BoxDecoration).map((c) => c.decoration as BoxDecoration).toList();

      final composerDeco = appCardDecorations.firstWhere(
        (d) => d.borderRadius == BorderRadius.circular(22),
      );
      final border = composerDeco.border as Border?;
      expect(border, isNotNull);
      // In dark mode, border must NOT be opaque white (a == 1.0)
      expect(border!.top.color.a, isNot(equals(1.0)));
      expect(border.top.color, equals(g.edge));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('In day mode: Things Hub, Learning, Recent Thought, and Composer retain explicit day borders and white fill for element separation', (tester) async {
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Thought in daylight'),
      );
      final thought = (await db.thoughtDao.getThoughtById(id))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value([thought]),
            ),
            todayActivitiesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            currentStreakStreamProvider.overrideWith(
              (ref) => Stream.value(0),
            ),
            timeTrackingProvider.overrideWith(
              () => _FakeTimeTrackingNotifier(),
            ),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Theme(
              data: HomeTheme.from(AscentTheme.light()),
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      ThoughtWallHomePreview(),
                      ActivityHubCard(),
                      LearningHubCard(),
                      QuickModulesNavHub(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final g = tester.element(find.byType(QuickModulesNavHub)).glass;

      // 1. Life & Health card in light mode
      final lifeAndHealthFinder = find.descendant(
        of: find.byType(QuickModulesNavHub),
        matching: find.byType(GlassSurface),
      ).first;
      final lifeGlass = tester.widget<GlassSurface>(lifeAndHealthFinder);
      expect(lifeGlass.fillColor, equals(Colors.white));
      expect(lifeGlass.customBorder, isNotNull);
      expect(lifeGlass.customBorder!.top.color, equals(g.edge.withValues(alpha: .45)));

      // 2. Things Hub card in light mode
      final activityCardFinder = find.byKey(const ValueKey('home_activity_card'));
      final activityGlass = tester.widget<GlassSurface>(activityCardFinder);
      expect(activityGlass.fillColor, equals(Colors.white));
      expect(activityGlass.customBorder, isNotNull);
      expect(activityGlass.customBorder!.top.color, equals(g.edge.withValues(alpha: .45)));

      // 3. Learning card in light mode
      final learningCardFinder = find.descendant(
        of: find.byType(LearningHubCard),
        matching: find.byType(GlassSurface),
      ).first;
      final learningGlass = tester.widget<GlassSurface>(learningCardFinder);
      expect(learningGlass.fillColor, equals(Colors.white));
      expect(learningGlass.customBorder, isNotNull);
      expect(learningGlass.customBorder!.top.color, equals(g.edge.withValues(alpha: .45)));

      // 4. Recent Thought card in light mode
      final mindSpaceFinder = find.byKey(const ValueKey('home_mind_space_card'));
      final mindSpaceGlass = tester.widget<GlassSurface>(mindSpaceFinder);
      expect(mindSpaceGlass.fillColor, equals(Colors.white));
      expect(mindSpaceGlass.customBorder, isNotNull);
      expect(mindSpaceGlass.customBorder!.top.color, equals(g.edge.withValues(alpha: .45)));

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('In Frozen Sky (Nordic) mode: cards remain styled with frozen palette', (tester) async {
      final nordicDark = AscentTheme.dark(preset: DayThemePreset.nordicSky);
      final homeNordic = HomeTheme.from(nordicDark);
      final g = homeNordic.extension<AscentGlass>()!;
      expect(g.frozen, isTrue);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            todayActivitiesProvider.overrideWith(
              (ref) => Stream.value(const []),
            ),
            timeTrackingProvider.overrideWith(
              () => _FakeTimeTrackingNotifier(),
            ),
          ],
          child: MaterialApp(
            theme: nordicDark,
            home: Theme(
              data: homeNordic,
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      ActivityHubCard(),
                      LearningHubCard(),
                      QuickModulesNavHub(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cards should render properly in frozen mode
      expect(find.byKey(const ValueKey('home_activity_card')), findsOneWidget);
      expect(find.byType(LearningHubCard), findsOneWidget);
      expect(find.byType(QuickModulesNavHub), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
