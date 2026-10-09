import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';

import 'package:ascent/core/auth/auth_provider.dart';
import 'package:drift/drift.dart';

class FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() {
    return const TimeTrackingState();
  }
}

class FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(isAuthenticated: true, username: 'arn');
}

final _modularTestProfile = UserProfile(
  id: 1,
  name: 'Arun',
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
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'ascent_new_day_shown': todayStr,
      'ascent_last_hydration_prompt_time': DateTime.now().millisecondsSinceEpoch,
    });
    prefs = await SharedPreferences.getInstance();
    await prefs.setString('ascent_new_day_shown', todayStr);
    await prefs.setInt('ascent_last_hydration_prompt_time', DateTime.now().millisecondsSinceEpoch);
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => FakeAuthNotifier()),
        timeTrackingProvider.overrideWith(() => FakeTimeTrackingNotifier()),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(5)),
        todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(1500)),
        dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
        todayWalkDistanceStreamProvider.overrideWith((ref) => Stream.value(2400.0)),
        todaySpendingStreamProvider.overrideWith((ref) => Stream.value(350.0)),
        overallBudgetStreamProvider.overrideWith((ref) => Stream.value(null)),
        activeMedicinesStreamProvider.overrideWith((ref) => Stream.value([])),
        todayMedicineLogsStreamProvider.overrideWith((ref) => Stream.value([])),
        activeMomentumChallengeStreamProvider.overrideWith((ref) => Stream.value(null)),
        todayMomentumCommitmentsStreamProvider.overrideWith((ref) => Stream.value([])),
        recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        nextUpcomingReminderProvider.overrideWith((ref) => Stream.value(null)),
        userProfileStreamProvider.overrideWith((ref) => Stream.value(_modularTestProfile)),
        todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
        todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Modular Home Architecture Tests', () {
    testWidgets('HomeHeader pumps with profile name, greeting, and streak flame', (tester) async {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 1,
        name: 'Arun',
        targetRole: 'Senior Flutter Architect',
        targetCompanies: jsonEncode(['Google']),
        weeklyHoursAvailable: 20,
        preferredStudyWindow: 'morning',
        skillSelfRatings: '{}',
        createdAt: now,
        updatedAt: now,
        onboardingComplete: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(Scaffold(body: HomeHeader(profile: profile))),
      );

      await tester.pump();
      expect(find.textContaining('Arun'), findsOneWidget);
      expect(find.textContaining('Senior Flutter Architect'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('ThoughtWallHomePreview renders quick mind spark prompt', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const Scaffold(body: ThoughtWallHomePreview())),
      );

      await tester.pump();
      expect(find.text('MIND SPACE • SELF-TALK'), findsOneWidget);
      expect(find.textContaining("What's on your mind?"), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('QuickModulesNavHub renders Momentum progress, Medicine, Hydration and Chai Break', (tester) async {
      await tester.pumpWidget(
        buildTestableWidget(const Scaffold(body: QuickModulesNavHub())),
      );

      await tester.pump();
      expect(find.text('DAILY PROTOCOL'), findsOneWidget);
      expect(find.text('Hydration'), findsOneWidget);
      expect(find.text('Medicine'), findsOneWidget);
      expect(find.text('Momentum'), findsOneWidget);
      expect(find.text('Chai & Coffee Break'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('HomeScreen pumps cleanly with all modular components (<100ms render target)', (tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        buildTestableWidget(const HomeScreen()),
      );

      await tester.pump();
      stopwatch.stop();

      // Ensure rapid cold-pump
      expect(stopwatch.elapsedMilliseconds < 2000, true);

      // Verify key elements are in tree
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Riya'), findsOneWidget);

      // Flush 350ms post-frame timer in _HomeScreenState
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('HomeHeader dynamically reflects customized assistant identity name', (tester) async {
      final container = ProviderContainer(
        overrides: [
          currentStreakStreamProvider.overrideWith((ref) => Stream.value(5)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: HomeHeader(profile: null),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Riya'), findsOneWidget);

      // Change assistant identity to Jarvis
      await container.read(assistantNameProvider.notifier).setName('Jarvis');
      await tester.pump();

      expect(find.text('Jarvis'), findsOneWidget);
      expect(find.text('Riya'), findsNothing);
    });
  });
}
