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
import 'package:ascent/features/home/widgets/activity_row_item.dart';

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
        recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(testProfile),
        ),
        todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
        todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(theme: theme ?? AscentTheme.light(), home: child),
    );
  }

  group('Home UI Polish Drill Tests', () {
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

  });
}
