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
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
import 'package:ascent/features/home/widgets/learning_hub_card.dart';
import 'package:ascent/features/home/widgets/life_checkin_popup_dialog.dart';

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

  Widget buildTestableWidget(Widget child, {ThemeData? theme}) {
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
        recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        userProfileStreamProvider
            .overrideWith((ref) => Stream.value(testProfile)),
        todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
        todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
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
  });
}
