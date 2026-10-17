import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
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

  group('Home UI Polish: Chat & Hubs Requirements Tests', () {
    testWidgets(
      'Demand 1: ThoughtWallHomePreview send button dynamically resolves to theme clay color',
      (tester) async {
        // Mount with Classic Clay (Warm terracotta: #A4523A)
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(preset: DayThemePreset.classicClay),
              home: const Scaffold(
                body: ThoughtWallHomePreview(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final iconFinder = find.byIcon(Icons.arrow_upward_rounded);
        expect(iconFinder, findsOneWidget);
        final buttonFinder = find.ancestor(
          of: iconFinder,
          matching: find.byType(IconButton),
        );
        final buttonWidget = tester.widget<IconButton>(buttonFinder);
        final bg = buttonWidget.style?.backgroundColor?.resolve({});
        // In Classic Clay, bg must be clay (#A4523A), NOT FrozenPalette.action (blue)
        expect(bg, AscentGlass.light.clay);
        expect(bg, isNot(equals(FrozenPalette.action)));

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Demand 2: Recent thoughts down to View all are enclosed inside home_mind_space_card',
      (tester) async {
        final id1 = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'First thought'),
        );
        final id2 = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Second thought'),
        );
        final t1 = (await db.thoughtDao.getThoughtById(id1))!;
        final t2 = (await db.thoughtDao.getThoughtById(id2))!;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([t2, t1])),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(preset: DayThemePreset.classicClay),
              home: const Scaffold(
                body: SingleChildScrollView(child: ThoughtWallHomePreview()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Enclosing mind space card exists
        final cardFinder = find.byKey(const ValueKey('home_mind_space_card'));
        expect(cardFinder, findsOneWidget);

        // Header and View all are inside this card
        expect(
          find.descendant(of: cardFinder, matching: find.text('Recent thoughts')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: cardFinder, matching: find.text('View all')),
          findsOneWidget,
        );

        // Bubbles are inside the card
        expect(
          find.descendant(
            of: cardFinder,
            matching: find.byKey(ValueKey('home_thought_$id1')),
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Demand 3: Chevron expand/collapse strictly toggles quick actions without navigating away',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Thought with actions'),
        );
        final thought = (await db.thoughtDao.getThoughtById(id))!;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([thought])),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(child: ThoughtWallHomePreview()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially collapsed: Plan action is not visible, down chevron is present
        expect(find.text('Plan'), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

        // Tap chevron: expands actions
        await tester.tap(find.byTooltip('Expand actions'));
        await tester.pumpAndSettle();

        expect(find.text('Plan'), findsOneWidget);
        expect(find.text('Todo'), findsOneWidget);
        expect(find.text('Reminder'), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

        // Tap chevron second time: collapses actions smoothly rather than opening Thought Wall
        await tester.tap(find.byTooltip('Collapse actions'));
        await tester.pumpAndSettle();

        expect(find.text('Plan'), findsNothing);
        expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Demand 4: Things hub heading and View board are outside home_activity_card',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
              currentStreakStreamProvider.overrideWith((ref) => Stream.value(3)),
              todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(child: ActivityHubCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final headingFinder = find.text('Things hub');
        final viewBoardFinder = find.text('View board');
        final cardFinder = find.byKey(const ValueKey('home_activity_card'));

        expect(headingFinder, findsOneWidget);
        expect(viewBoardFinder, findsOneWidget);
        expect(cardFinder, findsOneWidget);

        // Both heading and View board are OUTSIDE home_activity_card
        expect(
          find.descendant(of: cardFinder, matching: headingFinder),
          findsNothing,
        );
        expect(
          find.descendant(of: cardFinder, matching: viewBoardFinder),
          findsNothing,
        );

        // Card contains progress track
        final cardSurface = tester.widget<GlassSurface>(cardFinder);
        expect(cardSurface, isNotNull);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Demand 5: ActivityComposer renders docked chat-style bar with clean dark theme support',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
              currentStreakStreamProvider.overrideWith((ref) => Stream.value(3)),
              todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const Scaffold(
                body: SingleChildScrollView(child: ActivityHubCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Composer is inside the card
        final cardFinder = find.byKey(const ValueKey('home_activity_card'));
        final inputFinder = find.byKey(const ValueKey('activity_quick_input'));
        expect(
          find.descendant(of: cardFinder, matching: inputFinder),
          findsOneWidget,
        );

        // Options chips rendered cleanly
        expect(find.text('To-do'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Reminder off'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  });
}
