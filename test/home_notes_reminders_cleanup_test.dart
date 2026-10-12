import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

import 'package:ascent/app/router.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';

import 'package:ascent/core/auth/auth_provider.dart';

class FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() {
    return const TimeTrackingState();
  }
}

class FakeAuthNotifier extends AuthNotifier {
  final bool _isAuth;
  FakeAuthNotifier([this._isAuth = true]);

  @override
  AuthState build() => AuthState(isAuthenticated: _isAuth, username: 'arn');
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
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'ascent_new_day_shown': todayStr,
      'ascent_last_hydration_prompt_time':
          DateTime.now().millisecondsSinceEpoch,
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestableWidget(
    Widget child, {
    List<TodayActivityItem>? customActivities,
    UserProfile? customProfile,
    bool hasProfile = true,
    bool isAuthenticated = true,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(() => FakeAuthNotifier(isAuthenticated)),
        timeTrackingProvider.overrideWith(() => FakeTimeTrackingNotifier()),
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
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(
            hasProfile ? (customProfile ?? _testUserProfile) : null,
          ),
        ),
        todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
        todayActivitiesProvider.overrideWith(
          (ref) => Stream.value(customActivities ?? []),
        ),
      ],
      child: MaterialApp(theme: AscentTheme.dark(), home: child),
    );
  }

  group('Navigation & Routing Structure Verification', () {
    test(
      'Router has Reminders on shell Tab 1 and TaskBoard on /today route',
      () {
        bool hasRoute(List<RouteBase> routes, String target) {
          for (final r in routes) {
            if (r is GoRoute && r.path == target) return true;
            if (r is StatefulShellRoute) {
              for (final branch in r.branches) {
                if (hasRoute(branch.routes, target)) return true;
              }
            }
            if (r.routes.isNotEmpty && hasRoute(r.routes, target)) return true;
          }
          return false;
        }

        final routes = ascentRouter.configuration.routes;
        // Reminders route is present in shell
        expect(hasRoute(routes, AscentRoutes.reminders), isTrue);
        // Study / Task board route is present as parent route
        expect(hasRoute(routes, AscentRoutes.today), isTrue);
        // Deprecated /notes route is completely removed
        expect(hasRoute(routes, '/notes'), isFalse);
      },
    );

    testWidgets('MainScaffold tabs reflect Reminders in Tab 1', (tester) async {
      // Find shell branch definition
      final shellRoute =
          ascentRouter.configuration.routes.firstWhere(
                (r) => r is StatefulShellRoute,
              )
              as StatefulShellRoute;
      expect(shellRoute.branches.length, 4);
      // Branch 1 contains /reminders
      final branch1 = shellRoute.branches[1];
      expect(
        branch1.routes.any(
          (r) => r is GoRoute && r.path == AscentRoutes.reminders,
        ),
        isTrue,
      );
    });
  });

  group('Inline Running Activity vs Duplicate Banner Verification', () {
    testWidgets(
      'Running activity item displays minimal inline timer and pause icon',
      (tester) async {
        const runningItem = TodayActivityItem(
          id: 'task_1',
          title: 'Spring Boot Architecture Review',
          sourceType: 'task',
          status: TodayActivityStatus.inProgress,
          elapsedSecondsToday: 184, // 3:04
          targetMinutes: 30,
          categoryTag: 'Task',
          kind: ActivityKind.duration,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            const Scaffold(body: ActivityRowItem(activity: runningItem)),
          ),
        );
        await tester.pumpAndSettle();

        // Heading and inline running timer are displayed
        expect(find.text('Spring Boot Architecture Review'), findsOneWidget);
        expect(find.text('03:04 / 30m'), findsOneWidget);
        // Shows pause icon
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      },
    );

    testWidgets('Not-started activity item displays target and play arrow', (
      tester,
    ) async {
      const normalItem = TodayActivityItem(
        id: 'task_2',
        title: 'DSA Sliding Window Practice',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        targetMinutes: 45,
        categoryTag: 'Task',
        kind: ActivityKind.duration,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          const Scaffold(body: ActivityRowItem(activity: normalItem)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('DSA Sliding Window Practice'), findsOneWidget);
      expect(find.text('45m target'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets(
      'ActivityHubCard does not render duplicate floating player banner',
      (tester) async {
        const activeItem = TodayActivityItem(
          id: 'task_99',
          title: 'Deep System Design Study',
          sourceType: 'task',
          status: TodayActivityStatus.inProgress,
          elapsedSecondsToday: 65,
          targetMinutes: 25,
          categoryTag: 'Task',
          kind: ActivityKind.duration,
        );

        await tester.pumpWidget(
          buildTestableWidget(
            const Scaffold(
              body: SingleChildScrollView(child: ActivityHubCard()),
            ),
            customActivities: [activeItem],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // The activity item itself is visible in the list
        expect(find.text('Deep System Design Study'), findsOneWidget);
        // Running timer is formatted inline
        expect(find.text('01:05 / 25m'), findsOneWidget);
        // Only ONE play/pause button exists (inline on the row, not duplicated in a banner)
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
        expect(find.byIcon(Icons.pause_circle_outline_rounded), findsNothing);
      },
    );
  });

  group('Mind Space as Unified Notes & Home Cleanup Verification', () {
    testWidgets(
      'HomeScreen has no TopReminderAlertBanner or SecondaryToolsSection',
      (tester) async {
        await tester.pumpWidget(buildTestableWidget(const HomeScreen()));
        await tester.pump();

        // Neither legacy section appears
        expect(find.text('Notes & reminders'), findsNothing);
        expect(find.text('UPCOMING REMINDER'), findsNothing);

        // Flush 350ms post-frame timer in _HomeScreenState
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );

    test(
      'Mind Space (ThoughtDao) persists notes & reflections cleanly',
      () async {
        final id = await db.thoughtDao.insertThought(
          const ThoughtTableCompanion(
            content: drift.Value(
              'Streamlining notes directly into Mind Space prevents fragmentation.',
            ),
            mood: drift.Value('win'),
          ),
        );

        final thoughts = await db.thoughtDao.watchAllThoughts().first;
        expect(thoughts.any((t) => t.id == id), isTrue);
        expect(thoughts.first.content, contains('Mind Space'));
      },
    );

    testWidgets(
      'DayOneTutorialCard renders cleanly with theme button styling without layout crash',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const Scaffold(
                body: DayOneTutorialCard(userName: 'Test User'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Add First Activity 🚀'), findsOneWidget);
        expect(find.text('Got it! 👍'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'HomeScreen renders cleanly in both Light and Dark mode without layout assertion errors',
      (tester) async {
        for (final theme in [AscentTheme.light(), AscentTheme.dark()]) {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                sharedPreferencesProvider.overrideWithValue(prefs),
                authProvider.overrideWith(() => FakeAuthNotifier()),
                timeTrackingProvider.overrideWith(
                  () => FakeTimeTrackingNotifier(),
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
                todayFocusTaskProvider.overrideWith(
                  (ref) => Future.value(null),
                ),
                todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
              ],
              child: MaterialApp(theme: theme, home: const HomeScreen()),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(Duration.zero);
        }
      },
    );

    testWidgets(
      'HomeScreen compulsory blockage redirects un-onboarded user to /onboarding',
      (tester) async {
        // Missing profile
        await tester.pumpWidget(
          buildTestableWidget(const HomeScreen(), hasProfile: false),
        );
        // First frame might be loading or stream dispatch
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Should never render "Learner" and must show blockage indicator
        expect(find.text('Learner'), findsNothing);
        expect(
          find.byKey(const ValueKey('blockage_profile_indicator')),
          findsOneWidget,
        );

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Home remains a local profile screen without a fake account-login guard',
      (tester) async {
        await tester.pumpWidget(
          buildTestableWidget(const HomeScreen(), isAuthenticated: false),
        );
        await tester.pump();

        // Local profile access is not guarded by the unused fake credential provider.
        expect(find.text('Learner'), findsNothing);
        expect(
          find.byKey(const ValueKey('blockage_auth_indicator')),
          findsNothing,
        );

        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );
  });
}
