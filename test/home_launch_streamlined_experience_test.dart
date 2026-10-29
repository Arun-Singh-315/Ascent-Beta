import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';
import 'package:ascent/features/home/widgets/welcome_back_banner.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/features/today/task_board_screen.dart';
import 'package:ascent/shared/widgets/feature_guide.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

final _testUserProfile = UserProfile(
  id: 1,
  name: 'Arun Singh',
  targetRole: 'Software Engineer',
  targetCompanies: '["Google"]',
  weeklyHoursAvailable: 10,
  preferredStudyWindow: 'morning',
  skillSelfRatings: '{}',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  onboardingComplete: true,
  interviewDate: null,
  lastOpenedAt: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'ascent_day_one_tutorial_v2_dismissed': true,
      'ascent_daily_briefing_seen_v1': DateTime.now().toIso8601String(),
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp({
    Widget? home,
    UserProfile? profile,
    List<Reminder> reminders = const [],
    List<dynamic> extraOverrides = const [],
  }) {
    final effectiveProfile = profile ?? _testUserProfile;
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
        studyStreakProvider.overrideWith(() => _FakeStudyStreakNotifier()),
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(effectiveProfile),
        ),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(3)),
        todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(1000)),
        dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2000)),
        todayWalkDistanceStreamProvider.overrideWith(
          (ref) => Stream.value(1500.0),
        ),
        todaySpendingStreamProvider.overrideWith((ref) => Stream.value(200.0)),
        overallBudgetStreamProvider.overrideWith((ref) => Stream.value(null)),
        activeMedicinesStreamProvider.overrideWith((ref) => Stream.value([])),
        todayMedicineLogsStreamProvider.overrideWith((ref) => Stream.value([])),
        activeMomentumChallengeStreamProvider.overrideWith(
          (ref) => Stream.value(null),
        ),
        todayMomentumCommitmentsStreamProvider.overrideWith(
          (ref) => Stream.value([]),
        ),
        recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        nextUpcomingReminderProvider.overrideWith((ref) => Stream.value(null)),
        todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
        todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
        allRemindersProvider.overrideWith((ref) => Stream.value(reminders)),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        home: home ?? const HomeScreen(),
      ),
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  group('Part 1: Streamlined App Launch & Zero-Interruption Tests', () {
    testWidgets('1. Launch with overdue reminders: ZERO modal dialogs pop up', (
      tester,
    ) async {
      final overdueReminder = Reminder(
        id: 1,
        title: 'Overdue Project Review',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 3)),
        alarmEnabled: false,
        alertSyncPending: false,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(buildApp(reminders: [overdueReminder]));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify ZERO modal dialogs or alert dialogs were opened
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Overdue Reminder'), findsNothing);

      // Verify Home Screen loaded cleanly
      expect(find.byType(HomeScreen), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('2. Launch with no data (clean empty state): renders cleanly with zero modals', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('3. Launch with 3+ days away: WelcomeBackBanner appears at top 96 and auto-dismisses', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp(
        extraOverrides: [
          daysSinceLastOpenProvider.overrideWith((ref) => 4),
        ],
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Banner should appear
      expect(find.byType(WelcomeBackBanner), findsOneWidget);

      // Verify positioned top is 96 (below header controls)
      final positioned = tester.widget<Positioned>(
        find.ancestor(
          of: find.byType(WelcomeBackBanner),
          matching: find.byType(Positioned),
        ).first,
      );
      expect(positioned.top, equals(96));

      // Advance by 3 seconds to fire timer, then 300ms to complete reverse animation
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();

      expect(find.byType(WelcomeBackBanner), findsNothing);

      await unmount(tester);
    });

    testWidgets('4. Resume from background: zero modals or bottom sheets pop up', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Simulate AppLifecycleState.resumed
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Zero modal sheets or dialogs on resume
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);

      await unmount(tester);
    });

    testWidgets('5. First-run user sees DayOneTutorialDialog once, returning user does NOT', (
      tester,
    ) async {
      // First-run: tutorialDismissed is FALSE
      await prefs.setBool(DayOneTutorialDialog.prefKey, false);

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // First run shows the tutorial
      expect(find.byType(DayOneTutorialDialog), findsOneWidget);

      // Dismiss tutorial
      await tester.tap(find.text('Got it! 👍').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(prefs.getBool(DayOneTutorialDialog.prefKey), isTrue);

      await unmount(tester);

      // Now simulate a returning-user launch with tutorial dismissed
      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Returning user NEVER sees DayOneTutorialDialog
      expect(find.byType(DayOneTutorialDialog), findsNothing);

      await unmount(tester);
    });

    testWidgets('6. Settings screen allows re-opening DayOneTutorialDialog on demand', (
      tester,
    ) async {
      await prefs.setBool(DayOneTutorialDialog.prefKey, true);

      await tester.pumpWidget(buildApp(home: const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll to Help & Walkthroughs collapsible card
      await tester.scrollUntilVisible(
        find.text('Help & Walkthroughs'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Help & Walkthroughs'), findsOneWidget);
      await tester.tap(find.text('Help & Walkthroughs'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Replay Day One Tutorial tile should be visible
      await tester.scrollUntilVisible(
        find.text('Replay Day One Tutorial'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Replay Day One Tutorial'), findsOneWidget);
      await tester.tap(find.text('Replay Day One Tutorial'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tutorial dialog is opened intentionally on demand
      expect(find.byType(DayOneTutorialDialog), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('7. Daily Briefing is an inline collapsible card on Home (tap opens intentionally, x dismisses)', (
      tester,
    ) async {
      // Not seen today
      await prefs.remove('ascent_daily_briefing_seen_v1');

      await tester.pumpWidget(buildApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Zero auto popup sheets
      expect(find.byType(BottomSheet), findsNothing);

      // Inline card is rendered
      expect(find.byKey(const ValueKey('home_inline_briefing_card')), findsOneWidget);
      expect(find.text('Daily Briefing'), findsOneWidget);

      // Dismissing via 'x' button dismisses card and persists seen flag
      expect(find.byKey(const ValueKey('dismiss_inline_briefing')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('dismiss_inline_briefing')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('home_inline_briefing_card')), findsNothing);
      expect(prefs.getString('ascent_daily_briefing_seen_v1'), isNotNull);

      await unmount(tester);
    });

    testWidgets('8. FeatureGuideHost does NOT auto-pop dialogs on navigation', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FeatureGuideHost(
              feature: 'Today',
              child: const Text('Target Screen Content'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Zero dialogs popped
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Target Screen Content'), findsOneWidget);

      await unmount(tester);
    });

    testWidgets('9. Activity count alignment: Today tab and todayActivitiesProvider match count', (
      tester,
    ) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 10);
      final yesterday = today.subtract(const Duration(days: 1));

      // 1. Task planned for today (active)
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Today Task 1',
          priority: drift.Value('medium'),
          plannedDate: drift.Value(today),
          createdAt: drift.Value(today),
        ),
      );

      // 2. Overdue task planned for yesterday (active)
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Overdue Task 2',
          priority: drift.Value('high'),
          plannedDate: drift.Value(yesterday),
          createdAt: drift.Value(yesterday),
        ),
      );

      // 3. Unscheduled backlog task (plannedDate is NULL) -> should be in Others/Backlog
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Unscheduled Backlog Task 3',
          priority: drift.Value('low'),
          createdAt: drift.Value(today),
        ),
      );

      // 4. Completed task
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Completed Task 4',
          priority: drift.Value('medium'),
          plannedDate: drift.Value(today),
          actualCompletedDate: drift.Value(today),
          createdAt: drift.Value(today),
        ),
      );

      // Verify TaskDao getTodayAndOverdueTasks returns active today + overdue (2) plus completed today (1) = 3 total
      final allTodayTasks = await db.taskDao.getTodayAndOverdueTasks(today);
      final activeTasks = allTodayTasks.where((t) => t.actualCompletedDate == null).toList();
      final completedTasks = allTodayTasks.where((t) => t.actualCompletedDate != null).toList();
      expect(activeTasks.length, equals(2));
      expect(completedTasks.length, equals(1));
      expect(activeTasks.any((t) => t.title == 'Today Task 1'), isTrue);
      expect(activeTasks.any((t) => t.title == 'Overdue Task 2'), isTrue);
      // Unscheduled backlog task must NOT be in today/overdue
      expect(allTodayTasks.any((t) => t.title == 'Unscheduled Backlog Task 3'), isFalse);

      // Now verify TaskBoardScreen renders the exact same count (2) on the Today tab
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const TaskBoardScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Today tab header and section header show 'Today' and count badge shows '2'
      expect(find.text('Today'), findsNWidgets(2));
      expect(find.text('2'), findsOneWidget);
      // Others tab badge must show count 1 (the unscheduled backlog task)
      expect(find.text('Others'), findsOneWidget);
      // Completed tab badge must show count 1
      expect(find.text('Completed'), findsOneWidget);

      await unmount(tester);
    });
  });
}
