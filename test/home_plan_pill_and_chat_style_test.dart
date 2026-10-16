import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
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
        'ascent_new_day_shown': DateTime.now().toIso8601String().substring(0, 10),
      });
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'Thought Wall preview renders 2 messages in left/right chat style with transparent fill',
      (tester) async {
        final thoughts = <Thought>[];
        for (var i = 0; i < 3; i++) {
          final id = await db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(
              content: 'Thought message $i',
            ),
          );
          thoughts.insert(0, (await db.thoughtDao.getThoughtById(id))!);
        }

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value(thoughts),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ThoughtWallHomePreview(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check hint text
        expect(find.text('Capture a thought…'), findsOneWidget);

        // Exactly 2 thoughts rendered (collapsed view)
        final thought0Finder = find.byKey(ValueKey('home_thought_${thoughts[0].id}'));
        final thought1Finder = find.byKey(ValueKey('home_thought_${thoughts[1].id}'));
        final thought2Finder = find.byKey(ValueKey('home_thought_${thoughts[2].id}'));

        expect(thought0Finder, findsOneWidget);
        expect(thought1Finder, findsOneWidget);
        expect(thought2Finder, findsNothing);

        // Verify GlassSurface fill color is transparent
        final glass0 = tester.widget<GlassSurface>(thought0Finder);
        final glass1 = tester.widget<GlassSurface>(thought1Finder);
        expect(glass0.fillColor, Colors.transparent);
        expect(glass1.fillColor, Colors.transparent);

        // Verify left / right asymmetric chat margins
        final padding0 = tester.widget<Padding>(
          find.ancestor(of: thought0Finder, matching: find.byType(Padding)).first,
        );
        final padding1 = tester.widget<Padding>(
          find.ancestor(of: thought1Finder, matching: find.byType(Padding)).first,
        );

        final edge0 = padding0.padding as EdgeInsets;
        final edge1 = padding1.padding as EdgeInsets;

        // Index 0 is left-aligned: left 0, right 36
        expect(edge0.left, 0.0);
        expect(edge0.right, 36.0);

        // Index 1 is right-aligned: left 36, right 0
        expect(edge1.left, 36.0);
        expect(edge1.right, 0.0);
      },
    );

    testWidgets(
      'HomeScreen contains floating Ask Riya pill at bottom right and removes banner from above thoughts',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
              studyStreakProvider.overrideWith(() => _FakeStudyStreakNotifier()),
              currentStreakStreamProvider.overrideWith((ref) => Stream.value(3)),
              todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(1000)),
              dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2000)),
              todayWalkDistanceStreamProvider.overrideWith((ref) => Stream.value(1500.0)),
              todaySpendingStreamProvider.overrideWith((ref) => Stream.value(200.0)),
              overallBudgetStreamProvider.overrideWith((ref) => Stream.value(null)),
              activeMedicinesStreamProvider.overrideWith((ref) => Stream.value([])),
              todayMedicineLogsStreamProvider.overrideWith((ref) => Stream.value([])),
              activeMomentumChallengeStreamProvider.overrideWith((ref) => Stream.value(null)),
              todayMomentumCommitmentsStreamProvider.overrideWith((ref) => Stream.value([])),
              recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
              nextUpcomingReminderProvider.overrideWith((ref) => Stream.value(null)),
              userProfileStreamProvider.overrideWith((ref) => Stream.value(_testUserProfile)),
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
        expect(scaffold.floatingActionButtonLocation, FloatingActionButtonLocation.endFloat);
        expect(scaffold.floatingActionButton, isNotNull);

        // Verify Floating Ask Riya pill exists inside floatingActionButton
        final fabFinder = find.byWidget(scaffold.floatingActionButton!);
        expect(find.descendant(of: fabFinder, matching: find.text('Ask Riya')), findsOneWidget);
        expect(find.descendant(of: fabFinder, matching: find.byIcon(Icons.auto_awesome_rounded)), findsOneWidget);

        // Tear down cleanly
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );
  });
}
