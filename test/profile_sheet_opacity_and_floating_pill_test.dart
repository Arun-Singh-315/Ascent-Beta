import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/color_tokens.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
import 'package:ascent/features/home/widgets/home_promise_section.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
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
  name: 'Arun singh visen ;)',
  targetRole: 'Backend Engineer',
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

  group('UI/UX Audit: Profile Sheet Opacity & Floating AI Pill Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'ascent_new_day_shown': DateTime.now().toIso8601String().substring(0, 10),
        'ascent_day_one_tutorial_v2_dismissed': true,
        'ascent_daily_briefing_seen_v1': DateTime.now().toIso8601String(),
      });
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'Tapping top A avatar navigates directly to /settings',
      (tester) async {
        String? navigatedRoute;
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (ctx, state) => Scaffold(
                body: HomeHeader(profile: _testUserProfile),
              ),
            ),
            GoRoute(
              path: '/settings',
              builder: (ctx, state) {
                navigatedRoute = '/settings';
                return const Scaffold(body: Text('Settings Screen'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp.router(
              theme: AscentTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find the Avatar Circle "A" and tap it
        expect(find.text('A'), findsOneWidget);
        await tester.tap(find.text('A'));
        await tester.pumpAndSettle();

        // Verifies direct navigation to /settings with no intermediate sheet
        expect(navigatedRoute, equals('/settings'));
        expect(find.text('Settings Screen'), findsOneWidget);
      },
    );

    testWidgets(
      'HomeScreen floating Ask Riya pill has bottom padding >= 70 to clear bottom navigation bar',
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
        expect(scaffold.floatingActionButton, isNotNull);

        final pillFinder = find.byWidget(scaffold.floatingActionButton!);
        expect(find.descendant(of: pillFinder, matching: find.text('Ask Riya')), findsOneWidget);

        // Check that padding has bottom >= 70 to avoid being obscured by bottom nav
        final paddingWidget = tester.widget<Padding>(pillFinder);
        final insets = paddingWidget.padding as EdgeInsets;
        expect(insets.bottom, greaterThanOrEqualTo(70.0));

        // Shortcut panel (Mind, Health, Challenge, Vault) is at top
        expect(find.byType(HomeShortcutPanel), findsOneWidget);

        // Mind Palace (ThoughtWallHomePreview) is right below shortcuts
        expect(find.byType(ThoughtWallHomePreview), findsOneWidget);

        // Scroll down to Life & Health section
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();

        // Life & Health (QuickModulesNavHub) is in the feed
        expect(find.byType(QuickModulesNavHub), findsOneWidget);

        // Promise section is removed from Home
        expect(find.byType(HomePromiseSection), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      },
    );
  });
}
