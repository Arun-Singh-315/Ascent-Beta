import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
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

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() {
    return const StudyStreakStatus(
      todaySeconds: 1200,
      targetSeconds: 7200,
      priorStreakDays: 3,
      currentStreakDays: 3,
      displayStreakDays: 3,
    );
  }
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
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Home Assistant Pill & Chat Style Thought Wall Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'ascent_new_day_shown': DateTime.now().toIso8601String().substring(
          0,
          10,
        ),
      });
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });


    testWidgets(
      'HomeScreen keeps Ask Riya in its header without a floating overlay',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(
                () => _FakeTimeTrackingNotifier(),
              ),
              studyStreakProvider.overrideWith(
                () => _FakeStudyStreakNotifier(),
              ),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(3),
              ),
              todayWaterMlStreamProvider.overrideWith(
                (ref) => Stream.value(1000),
              ),
              dailyWaterGoalStreamProvider.overrideWith(
                (ref) => Stream.value(2000),
              ),
              todayWalkDistanceStreamProvider.overrideWith(
                (ref) => Stream.value(1500.0),
              ),
              todaySpendingStreamProvider.overrideWith(
                (ref) => Stream.value(200.0),
              ),
              overallBudgetStreamProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
              activeMedicinesStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              todayMedicineLogsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              activeMomentumChallengeStreamProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
              todayMomentumCommitmentsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              recentThoughtsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              nextUpcomingReminderProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
              userProfileStreamProvider.overrideWith(
                (ref) => Stream.value(_testUserProfile),
              ),
              todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
              todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.floatingActionButton, isNull);
        // Ask Riya sits near the top of the Home feed.
        expect(
          find.byKey(const ValueKey('home_ask_bar')),
          findsOneWidget,
        );
        expect(find.textContaining('Ask Riya'), findsOneWidget);

        // Tear down cleanly
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );
  });
}
