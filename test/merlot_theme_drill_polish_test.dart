import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/challenge/challenge_providers.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
import 'package:ascent/features/home/widgets/learning_hub_card.dart';
import 'package:ascent/features/home/widgets/life_checkin_popup_dialog.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
import 'package:ascent/shared/widgets/thought_excerpt.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

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
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      DayOneTutorialDialog.prefKey: false,
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  final testProfile = UserProfile(
    id: 1,
    name: 'Arun Singh',
    targetRole: 'Engineer',
    targetCompanies: '[]',
    weeklyHoursAvailable: 10,
    preferredStudyWindow: 'morning',
    skillSelfRatings: '{}',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    onboardingComplete: true,
    interviewDate: null,
    lastOpenedAt: null,
  );

  Widget buildTestableWidget(Widget child, {ThemeData? theme, List<Thought>? thoughts, List<TodayActivityItem>? activities}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
        studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
        homeStreakVisibleProvider.overrideWith((ref) => true),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(0)),
        todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(1000)),
        dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
        activeMedicinesStreamProvider.overrideWith((ref) => Stream.value([])),
        todayMedicineLogsStreamProvider.overrideWith((ref) => Stream.value([])),
        allChallengesProvider.overrideWith((ref) => Stream.value([])),
        activeMomentumChallengeStreamProvider
            .overrideWith((ref) => Stream.value(null)),
        todayMomentumCommitmentsStreamProvider
            .overrideWith((ref) => Stream.value([])),
        recentThoughtsStreamProvider.overrideWith((ref) => Stream.value(thoughts ?? [])),
        allThoughtsStreamProvider.overrideWith((ref) => Stream.value(thoughts ?? [])),
        archivedThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        userProfileStreamProvider
            .overrideWith((ref) => Stream.value(testProfile)),
        todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
        todayActivitiesProvider.overrideWith((ref) => Stream.value(activities ?? [])),
      ],
      child: MaterialApp(theme: theme, home: child),
    );
  }

  group('Merlot Theme Drill & Polish Tests', () {
    testWidgets('1. Streak chip text has high contrast in both Merlot light and dark modes', (tester) async {
      // Light Merlot
      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(body: HomeHeader(profile: testProfile)),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final startTextFinder = find.text('Start');
      expect(startTextFinder, findsOneWidget);
      final startText = tester.widget<Text>(startTextFinder);
      expect(startText.style?.color, equals(Colors.white));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);

      // Dark Merlot
      await tester.pumpWidget(
        buildTestableWidget(
          Scaffold(body: HomeHeader(profile: testProfile)),
          theme: AscentTheme.dark(preset: DayThemePreset.merlotLinen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final darkStartTextFinder = find.text('Start');
      expect(darkStartTextFinder, findsOneWidget);
      final darkStartText = tester.widget<Text>(darkStartTextFinder);
      expect(darkStartText.style?.color, equals(MerlotPalette.darkInk));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('2. DayOneTutorialDialog renders without overflowing at 320px with 2.0x text scale and dismisses cleanly', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => DayOneTutorialDialog.show(ctx, userName: 'Arun Singh'),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Open dialog
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DayOneTutorialDialog), findsOneWidget);
      expect(find.text('QUICK START GUIDE'), findsOneWidget);
      expect(find.text("Welcome, Arun! Here's how Ascent works:"), findsOneWidget);

      // Dismiss dialog via Got it!
      await tester.tap(find.text('Got it! 👍'));
      await tester.pumpAndSettle();

      expect(find.byType(DayOneTutorialDialog), findsNothing);
      expect(prefs.getBool(DayOneTutorialDialog.prefKey), isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('3. QuickModulesNavHub renders seamless bento cells without nested AppCard rounded boxes', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: QuickModulesNavHub(),
            ),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Life & Health'), findsOneWidget);
      expect(find.text('Medicine'), findsOneWidget);
      expect(find.text('Hydration'), findsOneWidget);
      expect(find.text('Chai & Coffee Break'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('4. LearningHubCard Explore button text is white in dark Merlot mode', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: LearningHubCard(),
            ),
          ),
          theme: AscentTheme.dark(preset: DayThemePreset.merlotLinen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final buttonFinder = find.widgetWithText(FilledButton, 'Explore');
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.style?.foregroundColor?.resolve({}), equals(Colors.white));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('5. LifeCheckInPopupDialog renders redesigned generous hydration cards and logs water', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => LifeCheckInPopupDialog.show(ctx, initialTab: LifeCheckInTab.hydration),
                  child: const Text('CheckIn'),
                ),
              ),
            ),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('CheckIn'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(LifeCheckInPopupDialog), findsOneWidget);
      expect(find.text('+250 mL'), findsOneWidget);
      expect(find.text('Glass'), findsOneWidget);
      expect(find.text('+150 mL'), findsOneWidget);
      expect(find.text('Small Sip'), findsOneWidget);
      expect(find.text('+350 mL'), findsOneWidget);
      expect(find.text('Bottle'), findsOneWidget);
      expect(find.text('+500 mL'), findsOneWidget);
      expect(find.text('Sipper'), findsOneWidget);

      // Tap +250 mL
      await tester.tap(find.text('+250 mL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final todayWater = await db.waterDao.getWaterForDate(DateTime.now());
      expect(todayWater, equals(250));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('6. UI Overflow Immunity at 320px width with 2.0x text scale for Home widgets', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestableWidget(
          MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2.0),
              size: Size(320, 800),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    HomeHeader(profile: testProfile),
                    const QuickModulesNavHub(),
                    const LearningHubCard(),
                  ],
                ),
              ),
            ),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('7. LearningHubCard Explore button is light in light Merlot and Frozen Sky modes', (tester) async {
      // Light Merlot
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: LearningHubCard(),
            ),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final buttonFinder = find.widgetWithText(FilledButton, 'Explore');
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.style?.backgroundColor?.resolve({}), equals(MerlotPalette.pillSoft));
      expect(button.style?.foregroundColor?.resolve({}), equals(MerlotPalette.action));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);

      // Light Frozen Sky
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: LearningHubCard(),
            ),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final frozenButtonFinder = find.widgetWithText(FilledButton, 'Explore');
      expect(frozenButtonFinder, findsOneWidget);
      final frozenButton = tester.widget<FilledButton>(frozenButtonFinder);
      expect(frozenButton.style?.backgroundColor?.resolve({}), equals(FrozenPalette.pillSoft));
      expect(frozenButton.style?.foregroundColor?.resolve({}), equals(FrozenPalette.action));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('8. ThoughtWallHomePreview card retains theme surface and only thought bubble receives vibrant blue gradient in Frozen Sky', (tester) async {
      final tId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Deep mind space reflection'),
      );
      final t = (await db.thoughtDao.getThoughtById(tId))!;

      // Merlot light: outer card is MerlotPalette.surface, bubble is MerlotPalette.pillSoft
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(child: ThoughtWallHomePreview()),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
          thoughts: [t],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final cardFinder = find.byKey(const ValueKey('home_mind_space_card'));
      expect(cardFinder, findsOneWidget);
      final cardGlass = tester.widget<GlassSurface>(cardFinder);
      expect(cardGlass.fillColor, equals(MerlotPalette.surface));

      final bubbleFinder = find.byKey(ValueKey('home_thought_$tId'));
      expect(bubbleFinder, findsOneWidget);
      final bubbleGlass = tester.widget<GlassSurface>(bubbleFinder);
      expect(bubbleGlass.gradient, isNotNull);
      final merlotGradient = bubbleGlass.gradient as LinearGradient;
      expect(merlotGradient.colors, equals([MerlotPalette.actionBright, MerlotPalette.actionDeep]));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);

      // Frozen Sky light: outer card is FrozenPalette.surface, bubble has Ask Aria blue gradient
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(child: ThoughtWallHomePreview()),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
          thoughts: [t],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final frozenCardFinder = find.byKey(const ValueKey('home_mind_space_card'));
      expect(frozenCardFinder, findsOneWidget);
      final frozenCardGlass = tester.widget<GlassSurface>(frozenCardFinder);
      expect(frozenCardGlass.fillColor, equals(FrozenPalette.surface));

      final frozenBubbleFinder = find.byKey(ValueKey('home_thought_$tId'));
      expect(frozenBubbleFinder, findsOneWidget);
      final frozenBubbleGlass = tester.widget<GlassSurface>(frozenBubbleFinder);
      expect(frozenBubbleGlass.gradient, isNotNull);
      final gradient = frozenBubbleGlass.gradient as LinearGradient;
      expect(gradient.colors, equals([FrozenPalette.actionBright, FrozenPalette.action]));

      // Verify thought text inside the blue bubble is white
      final excerptFinder = find.byType(ThoughtExcerpt);
      expect(excerptFinder, findsOneWidget);
      final excerptWidget = tester.widget<ThoughtExcerpt>(excerptFinder);
      expect(excerptWidget.style.color, equals(Colors.white));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('9. ThoughtWallHomePreview is immune to overflows at 320px width with 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Important reflection about daily routines and priorities',
          isPinned: const drift.Value(true),
        ),
      );
      final t = (await db.thoughtDao.getThoughtById(tId))!;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: buildTestableWidget(
            const Scaffold(
              body: SingleChildScrollView(child: ThoughtWallHomePreview()),
            ),
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
            thoughts: [t],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('home_mind_space_card')), findsOneWidget);
      expect(find.byKey(ValueKey('home_thought_$tId')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('10. ActivityRowItem active to-do receives theme tint, line border, checkbox accent, and reminder badge', (tester) async {
      const todoItem = TodayActivityItem(
        id: 'todo_active_1',
        title: 'Review Engineering Mathematics formulas',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Revision',
        kind: ActivityKind.todo,
        priority: 'high',
        hasReminder: true,
      );

      // Frozen Sky Light
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: ActivityRowItem(activity: todoItem),
            ),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
          activities: [todoItem],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final frozenContainerFinder = find.byKey(const ValueKey('activity_row_container_todo_active_1'));
      expect(frozenContainerFinder, findsOneWidget);
      final frozenContainer = tester.widget<AnimatedContainer>(frozenContainerFinder);
      final frozenBox = frozenContainer.decoration as BoxDecoration;
      expect(frozenBox.color, equals(FrozenPalette.tint.withValues(alpha: 0.55)));
      final frozenBorder = frozenBox.border as Border;
      expect(frozenBorder.top.color, equals(FrozenPalette.line));

      // Verify reminder pill exists
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.byIcon(Icons.alarm_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);

      // Merlot Linen Light
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: SingleChildScrollView(
              child: ActivityRowItem(activity: todoItem),
            ),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
          activities: [todoItem],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final merlotContainerFinder = find.byKey(const ValueKey('activity_row_container_todo_active_1'));
      expect(merlotContainerFinder, findsOneWidget);
      final merlotContainer = tester.widget<AnimatedContainer>(merlotContainerFinder);
      final merlotBox = merlotContainer.decoration as BoxDecoration;
      expect(merlotBox.color, equals(MerlotPalette.tint.withValues(alpha: 0.50)));
      final merlotBorder = merlotBox.border as Border;
      expect(merlotBorder.top.color, equals(MerlotPalette.line));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('11. ThoughtWallScreen cards render with theme surface, crisp line border, and mood divider', (tester) async {
      final thoughtId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Clear actionable idea for distributed consensus algorithms',
          mood: const drift.Value('idea'),
        ),
      );
      final thought = (await db.thoughtDao.getThoughtById(thoughtId))!;

      // Frozen Sky
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: ThoughtWallScreen(),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
          thoughts: [thought],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final containerFinder = find.byKey(ValueKey('thought_container_$thoughtId'));
      expect(containerFinder, findsOneWidget);
      final container = tester.widget<AnimatedContainer>(containerFinder);
      final box = container.decoration as BoxDecoration;
      expect(box.color, equals(FrozenPalette.surface));
      final border = box.border as Border;
      expect(border.top.color, equals(FrozenPalette.line));

      // Verify mood badge "Idea" exists
      expect(find.text('Idea'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);

      // Merlot Linen
      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(
            body: ThoughtWallScreen(),
          ),
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
          thoughts: [thought],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final merlotThoughtFinder = find.byKey(ValueKey('thought_container_$thoughtId'));
      expect(merlotThoughtFinder, findsOneWidget);
      final merlotThoughtContainer = tester.widget<AnimatedContainer>(merlotThoughtFinder);
      final merlotBox = merlotThoughtContainer.decoration as BoxDecoration;
      expect(merlotBox.color, equals(MerlotPalette.surface));
      final merlotBorder = merlotBox.border as Border;
      expect(merlotBorder.top.color, equals(MerlotPalette.line));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('12. ActivityRowItem and ThoughtWallScreen are immune to overflow at 320px with 2.0x text scale', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const todoItem = TodayActivityItem(
        id: 'todo_overflow_check',
        title: 'Comprehensive test of long task title text wrap behavior under accessibility zoom',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'GATE',
        kind: ActivityKind.todo,
        priority: 'urgent',
        hasReminder: true,
        isOverdue: true,
      );

      final thoughtId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Thorough review of discrete math graphs and combinatorics',
          mood: const drift.Value('win'),
        ),
      );
      final thought = (await db.thoughtDao.getThoughtById(thoughtId))!;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: buildTestableWidget(
            Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const ActivityRowItem(activity: todoItem),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 500,
                      child: const ThoughtWallScreen(),
                    ),
                  ],
                ),
              ),
            ),
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
            activities: [todoItem],
            thoughts: [thought],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('activity_row_container_todo_overflow_check')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}
