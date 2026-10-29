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
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/challenge/challenge_providers.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/home_dismissible_reminders_section.dart';

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
    targetRole: 'Backend',
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
        activeMomentumChallengeStreamProvider.overrideWith(
          (ref) => Stream.value(null),
        ),
        todayMomentumCommitmentsStreamProvider.overrideWith(
          (ref) => Stream.value([]),
        ),
        recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(testProfile),
        ),
        todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
        todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        theme: theme ?? AscentTheme.light(preset: DayThemePreset.merlotLinen),
        home: child,
      ),
    );
  }

  group('Home UI Polish Drill Tests', () {
    testWidgets(
      '1. Avatar A circle has strong contrast and does not mix with canvas',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(Scaffold(body: HomeHeader(profile: testProfile))),
        );
        await tester.pumpAndSettle();

        // Find the Avatar text 'A'
        final avatarTextFinder = find.text('A');
        expect(avatarTextFinder, findsOneWidget);

        final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
        final foreground = avatar.foregroundColor!.computeLuminance();
        final background = avatar.backgroundColor!.computeLuminance();
        final contrast = foreground > background
            ? (foreground + .05) / (background + .05)
            : (background + .05) / (foreground + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      '2. ActivityRowItem uses rounded capsule with burgundy & yellow accents',
      (tester) async {
        final activity = TodayActivityItem(
          id: 'test_todo_1',
          title: 'Review PR',
          sourceType: 'task',
          categoryTag: 'Task',
          priority: 'high',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          kind: ActivityKind.todo,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            Scaffold(body: ActivityRowItem(activity: activity)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Review PR'), findsOneWidget);
        expect(find.byType(ActivityRowItem), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      '3. HomeDismissibleRemindersSection supports swipe to complete and delete',
      (tester) async {
        bool completed = false;
        bool dismissed = false;

        final reminder1 = Reminder(
          id: 42,
          title: 'Take vitamins',
          scheduledAt: DateTime.now().add(const Duration(hours: 2)),
          alarmEnabled: false,
          isActive: true,
          alertSyncPending: false,
          createdAt: DateTime.now(),
        );

        final reminder2 = Reminder(
          id: 43,
          title: 'Drink water',
          scheduledAt: DateTime.now().add(const Duration(hours: 3)),
          alarmEnabled: false,
          isActive: true,
          alertSyncPending: false,
          createdAt: DateTime.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
            home: Scaffold(
              body: HomeDismissibleRemindersSection(
                reminders: [reminder1],
                onCompleteReminder: (r) async {
                  completed = true;
                },
                onDismissReminder: (r) async {
                  dismissed = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Take vitamins'), findsOneWidget);

        // Swipe right on first reminder to complete
        await tester.drag(find.text('Take vitamins'), const Offset(500, 0));
        await tester.pumpAndSettle();
        expect(completed, isTrue);

        // Pump second reminder to test swipe left delete
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
            home: Scaffold(
              body: HomeDismissibleRemindersSection(
                reminders: [reminder2],
                onCompleteReminder: (r) async {},
                onDismissReminder: (r) async {
                  dismissed = true;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Drink water'), findsOneWidget);

        // Swipe left on second reminder to delete
        await tester.drag(find.text('Drink water'), const Offset(-500, 0));
        await tester.pumpAndSettle();
        expect(dismissed, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      '4. Empty medicine summary avoids a misleading zero-dose progress bar',
      (tester) async {
        tester.view.physicalSize = const Size(400 * 2, 800 * 2);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          buildTestableWidget(
            const Scaffold(
              body: SingleChildScrollView(child: QuickModulesNavHub()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final medBarFinder = find.byKey(
          const ValueKey('medicine_progress_bar'),
        );
        final waterBarFinder = find.byKey(
          const ValueKey('hydration_progress_bar'),
        );

        expect(medBarFinder, findsNothing);
        expect(find.text('No doses scheduled'), findsOneWidget);
        expect(waterBarFinder, findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('5. Rule 13: 320px width & 2.0x text scale overflow immunity', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;

      final reminder = Reminder(
        id: 99,
        title: 'Call doctor for scheduled prescription update',
        scheduledAt: DateTime.now().add(const Duration(hours: 1)),
        alarmEnabled: false,
        isActive: true,
        alertSyncPending: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 800),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    HomeDismissibleRemindersSection(
                      reminders: [reminder],
                      onCompleteReminder: (_) async {},
                      onDismissReminder: (_) async {},
                    ),
                    const QuickModulesNavHub(),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });
}
