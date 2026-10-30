import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/shared/widgets/ascent_dialog.dart';
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

  group('Dark Night Mode Glass Theme & Exception Handling Tests', () {
    test(
      'Requirement 1: HomeTheme.from configures dark glass tokens and blur: 0 for performance',
      () {
        final parentDark = AscentTheme.dark();
        final homeDark = HomeTheme.from(parentDark);

        expect(homeDark.brightness, equals(Brightness.dark));

        final glass = homeDark.extension<AscentGlass>();
        expect(glass, isNotNull);
        // Dark glass fill should have proper translucent opacity (> 0.06)
        expect(glass!.fill.a, greaterThan(0.06));
        // Edge should be crisp and defined (> 0.12)
        expect(glass.edge.a, greaterThan(0.12));

        final surfaces = homeDark.extension<AppSurfaces>();
        expect(surfaces, isNotNull);
        // Rule 2: Home screen blur must be 0 to guarantee <100ms render
        expect(surfaces!.blur, equals(0.0));
        // Card fill and border in dark surfaces should match glass tokens
        expect(surfaces.cardFill, equals(glass.fill));
        expect(surfaces.cardBorderColor, equals(glass.edge));
      },
    );

    testWidgets(
      'Requirement 2: Home activity and mind space cards use dark glass surfaces',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Dark mode glass note'),
        );
        final thought = (await db.thoughtDao.getThoughtById(id))!;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              latestHomeThoughtProvider.overrideWith(
                (ref) => Stream.value(thought),
              ),
              todayActivitiesProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(3),
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
                      children: [ThoughtWallHomePreview(), ActivityHubCard()],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Mind Space card is rendered
        final mindSpaceFinder = find.byKey(
          const ValueKey('home_mind_space_card'),
        );
        expect(mindSpaceFinder, findsOneWidget);
        final mindSpaceGlass = tester.widget<GlassSurface>(mindSpaceFinder);
        expect(mindSpaceGlass.enableBlur, isFalse);

        // Verify Things Hub card is rendered
        final activityCardFinder = find.byKey(
          const ValueKey('home_activity_card'),
        );
        expect(activityCardFinder, findsOneWidget);
        final activityGlass = tester.widget<GlassSurface>(activityCardFinder);
        expect(activityGlass.enableBlur, isFalse);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Requirement 3: Nested thought bubbles use a subtle tint and outline in dark mode',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Night thought contrast'),
        );
        final thought = (await db.thoughtDao.getThoughtById(id))!;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              latestHomeThoughtProvider.overrideWith(
                (ref) => Stream.value(thought),
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
                    child: ThoughtWallHomePreview(compact: true),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final bubbleFinder = find.byKey(
          const ValueKey('home_latest_thought_bubble'),
        );
        expect(bubbleFinder, findsOneWidget);

        final bubble = tester.widget<Material>(
          find
              .ancestor(of: bubbleFinder, matching: find.byType(Material))
              .first,
        );
        expect(bubble.color!.a, lessThan(.15));
        final excerpt = tester.widget<Text>(
          find.byKey(const ValueKey('home_latest_thought_text')),
        );
        expect(excerpt.maxLines, 2);
        expect(excerpt.overflow, TextOverflow.ellipsis);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Requirement 4 (Exception): Docked ActivityComposer has distinct dock container in dark mode',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(
                () => _FakeTimeTrackingNotifier(),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: Theme(
                data: HomeTheme.from(AscentTheme.dark()),
                child: const Scaffold(body: ActivityComposer()),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final inputFinder = find.byKey(const ValueKey('activity_quick_input'));
        expect(inputFinder, findsOneWidget);

        final textField = tester.widget<TextField>(inputFinder);
        final g = tester.element(inputFinder).glass;

        // Text and hint must be legible
        expect(textField.style?.color, equals(g.ink));
        expect(textField.decoration?.hintStyle?.color, equals(g.inkMuted));

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Requirement 5 (Exception): AscentDialog has high opacity backdrop in dark mode to prevent bleed-through blunder',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.dark(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      AscentDialog.confirm(
                        context: context,
                        title: 'Delete Activity?',
                        content: 'Are you sure you want to proceed?',
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.tap(find.text('Show Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Delete Activity?'), findsOneWidget);

        final fill = find.descendant(
          of: find.byType(AscentDialog),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color != null,
          ),
        );
        expect(fill, findsWidgets);
        final panel = tester.widget<Container>(fill.first);
        expect(
          (panel.decoration as BoxDecoration).color!.a,
          greaterThanOrEqualTo(.90),
        );
      },
    );
  });
}
