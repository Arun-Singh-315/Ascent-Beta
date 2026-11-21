import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:ascent/features/home/widgets/home_reveal.dart';
import 'package:ascent/features/settings/settings_screen.dart';
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
  name: 'Test User',
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

  group('Home Quick Expense Card Verification', () {
    for (final isDark in [false, true]) {
      final mode = isDark ? 'Dark' : 'Light';




    }


  });

  group('HomeReveal Reduce Motion Verification', () {
    testWidgets('Renders TweenAnimationBuilder when animations are enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: HomeReveal(child: Text('Animated Content')),
          ),
        ),
      );
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    });

    testWidgets('Skips animation entirely when reduce motion is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: HomeReveal(child: Text('Direct Content')),
          ),
        ),
      );
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.text('Direct Content'), findsOneWidget);
    });
  });

  group('Input Hint Verification', () {
    testWidgets('Things ActivityComposer shows an example hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(home: Scaffold(body: ActivityComposer())),
        ),
      );
      await tester.pump();

      expect(find.text('e.g. Gym 7am tomorrow 45m'), findsOneWidget);
    });
  });

  group('Plans Card Home Conditional Verification', () {
  });

  group('Settings Screen Island Removal Verification', () {
    testWidgets('Settings screen contains no Dynamic Island reference or row', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.textContaining('Dynamic Island', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('Island', findRichText: true), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
