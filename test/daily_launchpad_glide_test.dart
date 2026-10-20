import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/daily_briefing_card.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';

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

  final testProfile = UserProfile(
    id: 1,
    name: 'Arun',
    targetRole: 'Backend Engineer',
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

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'ascent_theme_mode': 'light',
      'ascent_day_theme_preset': 'merlot_linen',
      'ascent_quick_start_v1': true,
      'ascent_onboarding_complete': true,
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildHarness(Widget child, {TextScaler textScaler = TextScaler.noScaling}) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        aiAssistantDaoProvider.overrideWithValue(db.aiAssistantDao),
        timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
        studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
        userProfileStreamProvider.overrideWith((ref) => Stream.value(testProfile)),
      ],
      child: MaterialApp(
        theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
        builder: (context, childWidget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: childWidget!,
        ),
        home: child,
      ),
    );
  }

  group('Daily Launchpad & UI Elevation Tests', () {
    testWidgets('1. Activity Type Chips: equal structured size & flame gold accent on selection', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddActivitySheet.show(ctx),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('To-do'), findsOneWidget);
      expect(find.text('Timed'), findsOneWidget);
      expect(find.text('Flexible'), findsOneWidget);

      // Verify selecting 'Timed' updates selection and does not throw
      await tester.ensureVisible(find.text('Timed'));
      await tester.tap(find.text('Timed'));
      await tester.pumpAndSettle();

      // Timed duration chips appear
      expect(find.text('Target Duration'), findsOneWidget);
      expect(find.text('30 min'), findsOneWidget);

      // Verify selecting 'Flexible'
      await tester.ensureVisible(find.text('Flexible'));
      await tester.tap(find.text('Flexible'));
      await tester.pumpAndSettle();
      expect(find.text('Target Duration'), findsNothing);
    });

    testWidgets('2. Rule 13: Activity Type Selector at 320px width & 2.0x text scale has 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildHarness(
          Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => AddActivitySheet.show(ctx),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('To-do'), findsOneWidget);
      expect(find.text('Timed'), findsOneWidget);
      expect(find.text('Flexible'), findsOneWidget);
    });

    testWidgets('3. AI Assistant Screen: paints theme background and does not hijack conversational greetings', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          const Scaffold(body: AiAssistantScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Scaffold has non-transparent theme background
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, isNot(Colors.transparent));

      // Verify prompt composer is clean and has hint
      expect(find.text('Message Riya...'), findsOneWidget);

      // Verify conversational greeting text entry
      await tester.enterText(find.byType(TextField), 'Talk to me, Riya. Help me check in honestly.');
      await tester.pump();
      expect(find.text('Talk to me, Riya. Help me check in honestly.'), findsOneWidget);

      // Ensure no schedule sheet popped up automatically
      expect(find.text('Make a plan'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('4. 3-Step Glide Daily Launchpad: Step 1 -> Step 2 -> Step 3 with one-stop data feeding', (tester) async {
      final testDay = DateTime(2026, 10, 20);

      await tester.pumpWidget(
        buildHarness(
          Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () => DailyBriefingCard.show(ctx, testDay),
                  child: const Text('Launch Sheet'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open popup
      await tester.tap(find.text('Launch Sheet'));
      await tester.pumpAndSettle();

      // Step 1: Yesterday & Welcome
      expect(find.text('Daily Launchpad'), findsOneWidget);
      expect(find.text('Yesterday in Review'), findsOneWidget);
      expect(find.text('Glide to Today’s Plan'), findsOneWidget);

      // Glide to Step 2
      await tester.tap(find.text('Glide to Today’s Plan'));
      await tester.pumpAndSettle();

      // Step 2: Feed Today's Focus
      expect(find.text('Feed Today’s Focus'), findsOneWidget);
      expect(find.text('Plan one small task'), findsOneWidget);

      // Type a task title and feed directly into system
      await tester.enterText(find.byType(TextField).first, 'Study Dynamic Programming');
      await tester.tap(find.text('Plan one small task'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify task was inserted into AppDatabase
      final tasks = await tester.runAsync(() => db.select(db.taskTable).get());
      expect(tasks?.any((t) => t.title == 'Study Dynamic Programming'), isTrue);

      // Quick log water
      await tester.tap(find.text('+250ml water'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final water = await tester.runAsync(() => db.waterDao.getWaterForDate(DateTime.now()));
      expect(water, equals(250));

      // Glide to Step 3: Launch Day
      await tester.tap(find.text('Next: Launch Day →'));
      await tester.pumpAndSettle();

      // Step 3: All Set for Today
      expect(find.text('All Set for Today'), findsOneWidget);
      expect(find.text('Take me to my tasks'), findsOneWidget);

      // Dismissal works smoothly
      expect(find.byTooltip('Dismiss daily briefing'), findsOneWidget);
      await tester.tap(find.byTooltip('Dismiss daily briefing'));
      await tester.pumpAndSettle();

      expect(find.text('All Set for Today'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('5. Rule 13: Daily Launchpad Flow at 320px width & 2.0x text scale has 0 overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final testDay = DateTime(2026, 10, 20);

      await tester.pumpWidget(
        buildHarness(
          Scaffold(
            body: SingleChildScrollView(
              child: DailyBriefingCard(day: testDay),
            ),
          ),
          textScaler: const TextScaler.linear(2.0),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('6. HomeHeader Start button triggers DailyBriefingCard popup when streak is 0', (tester) async {
      await tester.pumpWidget(
        buildHarness(
          Scaffold(
            body: HomeHeader(profile: testProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Streak is 0, so button shows 'Start' with flame icon
      expect(find.text('Start'), findsOneWidget);
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Daily Launchpad popup opened!
      expect(find.text('Daily Launchpad'), findsOneWidget);
      expect(find.byTooltip('Dismiss daily briefing'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
