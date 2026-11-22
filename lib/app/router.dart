import '../features/history/history_screen.dart';
import '../features/today/things_hub_screen.dart';
import 'theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';

import '../features/onboarding/onboarding_shell.dart';
import '../features/home/home_screen.dart';
import '../features/today/task_board_screen.dart';
import '../features/you/you_screen.dart';
import 'app_navigation.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/backup_screen.dart';
import '../features/focus/focus_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/money/money_screen.dart';
import '../features/ai_assistant/ai_assistant_screen.dart';
import '../features/medicine/medicine_screen.dart';
import '../features/thought_wall/board/board_logic.dart' show wallCategoryKey;
import '../features/thought_wall/board/board_routes.dart';
import '../features/thought_wall/board/thought_board_screen.dart';
import '../features/thought_wall/board/thought_space_screen.dart';
import '../features/hydration/hydration_screen.dart';
import '../features/plans/plans_screen.dart';
import '../features/plans/screens/plan_creator_screen.dart';
import '../features/plans/screens/plan_detail_screen.dart';
import '../features/today/screens/add_activity_screen.dart';
import '../features/vault/vault_screen.dart';
import '../shared/widgets/main_scaffold.dart';
import '../shared/widgets/feature_guide.dart';
import '../features/promises/promises_screen.dart';
import '../features/travel/travel_screen.dart';
import '../features/travel/trip_screen.dart';

// ── Route name constants ─────────────────────────────────────────────────────

class AscentRoutes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const home = AscentTabs.home;
  static const history = '/history';
  static const things = AscentTabs.things;
  static const vault = '/vault';
  static const today = '/today';
  static const money = '/money';
  static const medicine = '/medicine';
  static const aiAssistant = AscentTabs.assistant;
  static const hydration = '/hydration';
  static const thoughtWall = AscentTabs.mind;

  /// Legacy location of the old More tab; redirects to [you].
  static const more = '/more';
  static const you = AscentTabs.you;
  static const settings = '/settings';
  static const backup = '/backup';
  static const promises = '/promises';
  static const travel = '/travel';
  static const trip = '/travel/trip';
  static const focus = '/focus';
  static const reminders = '/reminders';
  static const calendar = '/calendar';
  static const plans = '/plans';
  static const createPlan = '/create-plan';
  static const addActivity = '/add-activity';
  static const planDetail = '/plan-detail/:id';
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

    GoRoute(
      path: AscentRoutes.calendar,
      builder: (context, state) => RemindersScreen(
        calendarOnly: true,
        openCalendar: true,
        thingsOnly: state.uri.queryParameters['scope'] == 'things',
        initialCalendarDate: DateTime.tryParse(
          state.uri.queryParameters['date'] ?? '',
        ),
      ),
    ),

    // ── Main shell: Home · Things · Assistant · Mind · You (CLAUDE.md §4) ──
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => MainScaffold(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.home,
              pageBuilder: (context, state) => NoTransitionPage(
                child: HomeScreen(notificationUri: state.uri),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.things,
              // A deep link with new parameters starts a fresh hub; returning
              // to the tab keeps the same location and so keeps its state.
              pageBuilder: (context, state) => NoTransitionPage(
                child: ThingsHubScreen(
                  key: ValueKey('things:${state.uri.query}'),
                  initialTab: state.uri.queryParameters['tab'],
                  initialFocusId: state.uri.queryParameters['focus'],
                  initialMode: state.uri.queryParameters['mode'],
                ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.aiAssistant,
              pageBuilder: (context, state) => NoTransitionPage(
                child: Theme(
                  data: AscentTheme.assistant(Theme.of(context)),
                  child: FeatureGuideHost(
                    feature: 'Riya',
                    child: AiAssistantScreen(
                      key: ValueKey('assistant:${state.uri.query}'),
                      initialPrompt: state.uri.queryParameters['prompt'],
                      sourceThoughtId: int.tryParse(
                        state.uri.queryParameters['thought'] ?? '',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.thoughtWall,
              pageBuilder: (context, state) => NoTransitionPage(
                child: ThoughtBoardScreen(
                  key: ValueKey('mind:${state.uri.query}'),
                  initialThoughtId: int.tryParse(
                    state.uri.queryParameters['thought'] ?? '',
                  ),
                ),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AscentRoutes.you,
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: YouScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(path: AscentRoutes.more, redirect: (_, _) => AscentRoutes.you),

    // Reminders live inside Things; the screen opens over the shell.
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.reminders,
      builder: (context, state) => RemindersScreen(
        openCalendar: state.uri.queryParameters['view'] == 'calendar',
        initialCalendarDate: DateTime.tryParse(
          state.uri.queryParameters['date'] ?? '',
        ),
        initialReminderId: int.tryParse(
          state.uri.queryParameters['reminder'] ?? '',
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.vault,
      builder: (context, state) => const VaultScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.history,
      builder: (context, state) => HistoryScreen(
        module: state.uri.queryParameters['module'],
        entity: state.uri.queryParameters['entity'],
      ),
    ),

    // ── Parent destinations (pushed over the shell) ───────────────────────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.medicine,
      builder: (context, state) => const MedicineScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.hydration,
      builder: (context, state) => const HydrationScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: thoughtSpacePath,
      builder: (context, state) => ThoughtSpaceScreen(
        spaceKey: state.uri.queryParameters['key'] ?? wallCategoryKey,
        initialThoughtId: int.tryParse(
          state.uri.queryParameters['thought'] ?? '',
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.plans,
      builder: (context, state) =>
          PlansScreen(initialPlanId: state.uri.queryParameters['id']),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.createPlan,
      builder: (context, state) => const PlanCreatorScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.addActivity,
      builder: (context, state) => const AddActivityScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.planDetail,
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return PlanDetailScreen(collectionId: id);
      },
    ),

    // ── Drawer destinations (pushed over the shell, with back arrow) ──────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.today,
      builder: (context, state) => TaskBoardScreen(
        initialTaskId: int.tryParse(state.uri.queryParameters['task'] ?? ''),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.backup,
      builder: (context, state) => const BackupScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.promises,
      builder: (context, state) => const PromisesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.travel,
      builder: (context, state) => const TravelScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.trip,
      builder: (context, state) => TripScreen(
        id: state.uri.queryParameters['id'] ?? '',
        tab: state.uri.queryParameters['tab'] == 'money'
            ? TripTab.money
            : TripTab.plan,
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.focus,
      builder: (context, state) => const FocusScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: AscentRoutes.money,
      builder: (context, state) => const MoneyScreen(),
    ),
  ],
);
