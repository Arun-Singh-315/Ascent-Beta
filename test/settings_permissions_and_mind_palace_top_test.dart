import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/returning_user_guides.dart';


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
      ...returningUserGuidePrefs,
      'ascent_day_one_tutorial_v2_dismissed': true,
      'ascent_onboarding_completed_v1': true,
      'ascent_quick_start_v1': true,
      'ascent_daily_briefing_seen_v1': DateTime.now().toIso8601String(),
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp({
    Widget? home,
    double width = 390,
    double height = 844,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
        studyStreakProvider.overrideWith(() => _FakeStudyStreakNotifier()),
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(_testUserProfile),
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
        allRemindersProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(textScale),
          ),
          child: home ?? const HomeScreen(),
        ),
      ),
    );
  }

  group('Mind Palace Position & Home Order Verification', () {
    testWidgets(
      'Mind Palace (ThoughtWallHomePreview) is positioned at top of Home feed above ActivityHubCard',
      (tester) async {
        await tester.pumpWidget(buildApp(home: const HomeScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Both Mind Palace preview and Activity Hub are rendered on Home
        expect(find.byType(ThoughtWallHomePreview), findsOneWidget);
        expect(find.byType(ActivityHubCard), findsOneWidget);

        // Verify vertical order: ThoughtWallHomePreview is above ActivityHubCard
        final mindPalaceTop = tester.getTopLeft(find.byType(ThoughtWallHomePreview)).dy;
        final activityHubTop = tester.getTopLeft(find.byType(ActivityHubCard)).dy;

        expect(
          mindPalaceTop,
          lessThan(activityHubTop),
          reason: 'Mind Palace must be positioned at the top of the Home feed above Activity Hub',
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });

  group('Settings Permissions & System Access Verification', () {
    testWidgets(
      'SettingsScreen displays Permissions & System Access section with direct service shortcuts',
      (tester) async {
        await tester.pumpWidget(buildApp(home: const SettingsScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Scroll to Permissions & System Access section
        await tester.drag(find.byType(ListView), const Offset(0, -350));
        await tester.pump();

        // Check Section header
        expect(find.text('App Permissions & System Access'), findsOneWidget);

        // Check Permissions Items
        expect(find.text('Notifications & Alerts'), findsOneWidget);
        expect(find.text('Exact Alarms & Ringing'), findsOneWidget);
        expect(find.text('GPS Walk Tracking'), findsOneWidget);

        // Check Direct Shortcuts
        expect(find.text('Open Phone App Settings'), findsWidgets);
        expect(find.text('Location Settings'), findsWidgets);

        // Scroll button into view and tap
        final openSettingsBtn = find.widgetWithText(AscentButton, 'Open Phone App Settings').first;
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pump();
        await tester.tap(openSettingsBtn, warnIfMissed: false);
        await tester.pump();
      },
    );

    testWidgets(
      'SettingsScreen renders without overflow at 320px width with 2.0x text scale',
      (tester) async {
        await tester.pumpWidget(
          buildApp(
            home: const SettingsScreen(),
            width: 320,
            height: 600,
            textScale: 2.0,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Scroll through the entire settings screen to guarantee zero RenderFlex overflow
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(0, -500));
        await tester.pump();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
