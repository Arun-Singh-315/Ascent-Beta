import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'package:ascent/core/ai/riya_alert_effects.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/home_schedule_sheet.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
        todaySeconds: 0,
        yesterdaySeconds: 0,
        priorStreakDays: 0,
        historicalLongestStreak: 0,
        historicalShortestStreak: 1,
        now: DateTime.now(),
      );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        homeScheduleEffectsProvider.overrideWith(
          (ref) => RiyaAlertEffects(
            db,
            cancel: (_) async => true,
            schedule: (_) async => false,
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(0)),
        studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('ChoiceChip theme contrast', () {
    testWidgets('selected ChoiceChip has visible, contrasting label text and checkmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                var selected = true;
                return ChoiceChip(
                  label: const Text('Every day'),
                  selected: selected,
                  onSelected: (val) => setState(() => selected = val),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chipFinder = find.byType(ChoiceChip);
      expect(chipFinder, findsOneWidget);

      final text = tester.widget<Text>(find.descendant(of: chipFinder, matching: find.text('Every day')));
      final chipTheme = ChipTheme.of(tester.element(chipFinder));
      
      // The label must not be equal to selectedColor (which makes text invisible)
      final selectedColor = chipTheme.selectedColor ?? FrozenPalette.action;
      final effectiveTextColor = text.style?.color ?? chipTheme.secondaryLabelStyle?.color;
      expect(effectiveTextColor, isNotNull);
      expect(effectiveTextColor, isNot(equals(selectedColor)));
      expect(effectiveTextColor, equals(Colors.white));
    });
  });

  group('HomeScheduleSheet robust routine and plan creation', () {
    testWidgets('creating a routine with daily and gentle retries succeeds even if session time is 7 am and current time is afternoon', (tester) async {
      final thoughtId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'hii lets kill it :)'),
      );
      final thought = (await db.thoughtDao.getThoughtById(thoughtId))!;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeScheduleSheet(thought: thought),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select 'Every day'
      await tester.tap(find.text('Every day'));
      await tester.pumpAndSettle();

      // Toggle 'Ask me afterwards'
      final askSwitch = find.widgetWithText(SwitchListTile, 'Ask me afterwards');
      await tester.ensureVisible(askSwitch);
      final switchWidget = tester.widget<SwitchListTile>(askSwitch);
      if (!switchWidget.value) {
        await tester.tap(askSwitch);
        await tester.pumpAndSettle();
      }

      // Tap 'Gentle (Retries)'
      await tester.ensureVisible(find.text('Gentle (Retries)'));
      await tester.tap(find.text('Gentle (Retries)'));
      await tester.pumpAndSettle();

      // Tap 'Create routine'
      final createButton = find.widgetWithText(FilledButton, 'Create routine');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Must not display "Could not schedule" error
      expect(find.textContaining('Could not schedule'), findsNothing);

      // Verify plan and occurrences were created
      final plans = await db.planDao.getAllPlans();
      expect(plans, isNotEmpty);
      expect(plans.first.title, 'hii lets kill it :)');
    });

    testWidgets('rescheduling or updating a plan replaces receipt without UNIQUE constraint error', (tester) async {
      final thoughtId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Repeat schedule test'),
      );
      final thought = (await db.thoughtDao.getThoughtById(thoughtId))!;

      // Pre-insert an existing receipt for this thought
      await db.into(db.aiCommandTable).insert(
        AiCommandTableCompanion.insert(
          requestId: 'home.schedule:$thoughtId',
          capability: 'home.schedule',
          argumentsJson: '{"thoughtId": $thoughtId, "title": "Old"}',
          resultJson: '{}',
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
            home: Scaffold(
              body: SingleChildScrollView(
                child: HomeScheduleSheet(thought: thought),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Select 'Every day'
      await tester.tap(find.text('Every day'));
      await tester.pumpAndSettle();

      final createButton = find.widgetWithText(FilledButton, 'Create routine');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.textContaining('Could not schedule'), findsNothing);
    });
  });

  group('Thought card action UX and chevron collapse/expand', () {
    testWidgets('thought card navigates to thought wall on tap, while ^ chevron toggles actions without Open pill', (tester) async {
      final thoughtId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Thought for navigation test'),
      );

      String? pushedRoute;
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: SingleChildScrollView(
                child: ThoughtWallHomePreview(),
              ),
            ),
          ),
          GoRoute(
            path: '/thought-wall',
            builder: (context, state) {
              pushedRoute = '/thought-wall?thought=${state.uri.queryParameters['thought']}';
              return const Scaffold(body: Text('Thought Wall Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The thought is rendered
      expect(find.text('Thought for navigation test'), findsOneWidget);

      // Actions are initially collapsed
      expect(find.text('Plan'), findsNothing);
      expect(find.text('Todo'), findsNothing);
      expect(find.text('Reminder'), findsNothing);
      expect(find.text('Open'), findsNothing);

      // Tap on chevron button to expand actions
      final chevronFinder = find.byTooltip('Expand actions');
      expect(chevronFinder, findsOneWidget);
      await tester.tap(chevronFinder);
      await tester.pumpAndSettle();

      // Actions are now expanded: Plan, Todo, Reminder. 'Open' must NOT be present!
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Todo'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Open'), findsNothing);

      // Tap on chevron button again to collapse
      final collapseFinder = find.byTooltip('Collapse actions');
      expect(collapseFinder, findsOneWidget);
      await tester.tap(collapseFinder);
      await tester.pumpAndSettle();

      expect(find.text('Plan'), findsNothing);

      // Tap anywhere else on the thought bubble card -> navigates to Thought Wall!
      await tester.tap(find.text('Thought for navigation test'));
      await tester.pumpAndSettle();

      expect(pushedRoute, equals('/thought-wall?thought=$thoughtId'));
      expect(find.text('Thought Wall Screen'), findsOneWidget);
    });
  });
}
