import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';

import '../features/onboarding/onboarding_shell.dart';
import '../features/home/home_screen.dart';
import '../features/today/task_board_screen.dart';
import '../features/pipeline/pipeline_screen.dart';
import '../features/pipeline/card_detail_screen.dart';
import '../features/analytics/analytics_screen.dart';
import '../features/analytics/series_report_card_screen.dart';
import '../features/more/more_screen.dart';
import '../features/study_plan/study_plan_screen.dart';
import '../features/dsa/dsa_screen.dart';
import '../features/interview_prep/interview_prep_screen.dart';
import '../features/consistency/consistency_screen.dart';
import '../features/notes/notes_screen.dart';
import '../features/resume_vault/resume_vault_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/focus/focus_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../shared/widgets/main_scaffold.dart';

// ── Route name constants ─────────────────────────────────────────────────────

class AscentRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const today = '/today';
  static const pipeline = '/pipeline';
  static const pipelineCard = '/pipeline/:id';
  static const analytics = '/analytics';
  static const analyticsSeriesReport = '/analytics/series/:id';
  static const more = '/more';
  static const studyPlan = '/study-plan';
  static const dsa = '/dsa';
  static const interviewPrep = '/interview-prep';
  static const consistency = '/consistency';
  static const notes = '/notes';
  static const resumeVault = '/resume-vault';
  static const settings = '/settings';
  static const focus = '/focus';
  static const reminders = '/reminders';
}

// ── Navigator key ─────────────────────────────────────────────────────────────

/// Root navigator key — used by flutter_local_notifications to navigate
/// when a notification is tapped while the app is open.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');

// ── Router ────────────────────────────────────────────────────────────────────

final ascentRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AscentRoutes.splash,
  debugLogDiagnostics: true,

  routes: [
    // ── Splash (no shell — full screen) ──────────────────────────────────────
    GoRoute(
      path: AscentRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),

    // ── Onboarding (no shell — full screen flow) ──────────────────────────
    GoRoute(
      path: AscentRoutes.onboarding,
      builder: (context, state) => const OnboardingShell(),
    ),

    // ── Main shell (bottom nav + drawer) ──────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainScaffold(shell: shell),
      branches: [
        // Tab 0: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.home,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: HomeScreen(),
              ),
            ),
          ],
        ),

        // Tab 1: Today (Task Board)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.today,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: TaskBoardScreen(),
              ),
            ),
          ],
        ),

        // Tab 2: Pipeline (Kanban)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.pipeline,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: PipelineScreen(),
              ),
              routes: [
                GoRoute(
                  path: ':id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => CardDetailScreen(
                    applicationId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Tab 3: Analytics
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.analytics,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: AnalyticsScreen(),
              ),
              routes: [
                GoRoute(
                  path: 'series/:id',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => SeriesReportCardScreen(
                    seriesId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),

        // Tab 4: More (drawer hub)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.more,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: MoreScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // ── Drawer destinations (pushed over the shell, with back arrow) ──────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.studyPlan,
      builder: (context, state) => const StudyPlanScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.dsa,
      builder: (context, state) => const DsaScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.interviewPrep,
      builder: (context, state) {
        final applicationId = state.uri.queryParameters['applicationId'];
        return InterviewPrepScreen(
          linkedApplicationId: applicationId != null ? int.parse(applicationId) : null,
        );
      },
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.consistency,
      builder: (context, state) => const ConsistencyScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.notes,
      builder: (context, state) => const NotesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.resumeVault,
      builder: (context, state) => const ResumeVaultScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.focus,
      builder: (context, state) => const FocusScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.reminders,
      builder: (context, state) => const RemindersScreen(),
    ),
  ],
);
