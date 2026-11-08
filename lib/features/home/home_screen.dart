import '../../core/providers/local_day_provider.dart';
import 'widgets/home_first_moment.dart';
import 'widgets/home_promise_section.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../../shared/widgets/empty_state.dart';
import '../../app/theme/surface_tokens.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/home_layout_provider.dart';
import '../money/add_transaction_sheet.dart';
import 'daily_checkin_card.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/streak/study_streak_provider.dart';
import 'widgets/activity_hub_card.dart';
import 'widgets/day_one_tutorial_card.dart';
import 'widgets/daily_welcome_dialog.dart';
import '../../core/services/daily_welcome_service.dart';
import '../../core/providers/daily_briefing_provider.dart';
import 'widgets/home_day_design.dart';
import 'widgets/home_life_shelf.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shortcut_panel.dart';
import 'widgets/home_theme.dart';
import 'widgets/learning_hub_card.dart';
import '../vault/widgets/vault_home_preview.dart';
import 'widgets/smart_catch_up_banner.dart';
import 'widgets/streak_celebration_dialog.dart';
import 'widgets/thought_wall_home_preview.dart';
import 'widgets/planning_notification_handler.dart';
import 'widgets/welcome_back_banner.dart';
import '../challenge/integration/challenge_proof_sync.dart';

/// A focused daily workspace with distinct places for action, thought and life.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.notificationUri});
  final Uri? notificationUri;

  @override
  Widget build(BuildContext context) => Theme(
    data: HomeTheme.from(Theme.of(context)),
    child: _HomeContent(notificationUri: notificationUri),
  );
}

class _HomeContent extends ConsumerStatefulWidget {
  const _HomeContent({this.notificationUri});
  final Uri? notificationUri;

  @override
  ConsumerState<_HomeContent> createState() => _HomeScreenState();
}

/// The welcome-back greeting is shown once per app launch, not on every visit
/// to the Home tab.
bool _welcomeBackShownThisLaunch = false;

class _HomeScreenState extends ConsumerState<_HomeContent>
    with WidgetsBindingObserver {
  int? _welcomeBackDays;
  bool _heavierModulesReady = false;
  bool _entryDialogsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final daysAway = ref.read(daysSinceLastOpenProvider);
    if (!_welcomeBackShownThisLaunch && daysAway >= 3 && daysAway < 999) {
      _welcomeBackShownThisLaunch = true;
      _welcomeBackDays = daysAway;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _heavierModulesReady = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Future.delayed(const Duration(milliseconds: 350));
        if (!mounted) return;
        final preferences = ref.read(sharedPreferencesProvider);
        final notice = preferences.getString('ascent_restore_notice_v1');
        if (notice != null) {
          preferences.remove('ascent_restore_notice_v1');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(notice),
              duration: const Duration(seconds: 8),
            ),
          );
        }

        if (!mounted) return;
        final profile = await ref
            .read(userProfileStreamProvider.future)
            .onError((_, _) => null);
        if (!mounted || !canEnterWorkspace(profile, preferences)) return;

        final tutorialDismissed =
            (preferences.getBool(DayOneTutorialDialog.prefKey) ?? false);
        if (!tutorialDismissed && mounted) {
          // First login: the one-time guide is today's welcome, so the daily
          // one waits for tomorrow instead of stacking on top of it.
          preferences.setBool(DayOneTutorialDialog.prefKey, true);
          await preferences.setString(
            'ascent_first_home_day_v1',
            briefingDay(DateTime.now()).toIso8601String(),
          );
          await markDailyWelcomeSeen(preferences, DateTime.now());
          if (!mounted) return;
          // First capture lives in Home, with no blocking welcome overlay.
          return;
        }

        // Every other day: one daily welcome on the first open, never again that
        // day, and never when Home was opened for a specific destination.
        final uri = widget.notificationUri;
        final homeOnly = uri == null || uri.path == '/home';
        final now = DateTime.now();
        if (!mounted ||
            !homeOnly ||
            !shouldShowDailyWelcome(
              prefs: preferences,
              now: now,
              autoOpen: ref.read(dailyBriefingAutoOpenProvider),
            )) {
          return;
        }
        await markDailyWelcomeSeen(preferences, now);
        if (!mounted) return;
        await DailyWelcomeDialog.show(
          context,
          day: briefingDay(now),
          name: profile?.name ?? '',
        );
      } finally {
        if (mounted) setState(() => _entryDialogsReady = true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    final profileAsync = ref.watch(userProfileStreamProvider);
    final layout = ref.watch(homeLayoutProvider);
    ref.watch(localHourProvider);
    ref.watch(challengeProofSyncProvider);

    // Listen for celebratory streak unlocked event
    ref.listen<StudyStreakStatus?>(streakCelebrationEventProvider, (
      prev,
      next,
    ) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          StreakCelebrationDialog.show(context, next);
          ref.read(streakCelebrationEventProvider.notifier).clear();
        });
      }
    });

    return Scaffold(
      backgroundColor: g.bg,
      body: SafeArea(
        child: HomeDayBackground(
          child: Stack(
            children: [
              Positioned.fill(
                child: profileAsync.when(
                  loading: () => const _HomeLoadingView(),
                  error: (err, _) {
                    debugPrint('Home profile load failed: $err');
                    return EmptyState(
                      icon: Icons.cloud_off_rounded,
                      title: "Couldn't load your Home",
                      subtitle:
                          'Something went wrong while loading. Please try again.',
                      actionLabel: 'Try again',
                      onAction: () => ref.invalidate(userProfileStreamProvider),
                    );
                  },
                  data: (profile) {
                    final isValidProfile = canEnterWorkspace(
                      profile,
                      ref.read(sharedPreferencesProvider),
                    );

                    if (!isValidProfile) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        final router = GoRouter.maybeOf(context);
                        if (router != null) {
                          router.go('/onboarding');
                        }
                      });
                      return const Center(
                        child: CircularProgressIndicator(
                          key: ValueKey('blockage_profile_indicator'),
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(userProfileStreamProvider);
                        ref.invalidate(todayFocusTaskProvider);
                        ref.invalidate(currentStreakStreamProvider);
                        ref.invalidate(learningHubProvider);
                        ref.invalidate(nextUpcomingInterviewProvider);
                        ref.invalidate(recentThoughtsStreamProvider);
                        ref.invalidate(latestHomeThoughtProvider);
                        ref.invalidate(todayActivitiesProvider);
                        ref.invalidate(activeMomentumChallengeStreamProvider);
                        ref.invalidate(todayMomentumCommitmentsStreamProvider);
                        ref.invalidate(studyStreakProvider);
                        ref.invalidate(allRemindersProvider);
                        ref.invalidate(dismissedTodayReminderIdsProvider);
                      },
                      color: g.clay,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: AppSpace.s96,
                        ),
                        children: [
                          HomeHeader(profile: profile),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            child: HomeShortcutPanel(
                              shortcuts: layout.shortcuts,
                              showReminders: layout.visible.contains(
                                'reminders',
                              ),
                            ),
                          ),
                          if (ref.watch(firstMomentPendingProvider))
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: HomeFirstMoment(),
                            ),
                          if (!ref.watch(firstMomentPendingProvider) &&
                              layout.visible.contains('mind'))
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: ThoughtWallHomePreview(
                                previewLimit: 1,
                                compact: true,
                              ),
                            ),
                          if (!ref.watch(firstMomentPendingProvider) &&
                              layout.visible.contains('today'))
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                              child: ActivityHubCard(
                                previewLimit: layout.compact.contains('today')
                                    ? 2
                                    : 3,
                              ),
                            ),
                          PlanningNotificationHandler(
                            uri: widget.notificationUri,
                          ),
                          ..._buildContextualModules(context, layout).map(
                            (module) => Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: module,
                            ),
                          ),
                          if (layout.visible.contains('life') &&
                              layout.tools.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: HomeLifeShelf(),
                            ),
                          if (_entryDialogsReady &&
                              ref
                                      .read(sharedPreferencesProvider)
                                      .getString('ascent_first_home_day_v1') !=
                                  ref.watch(localDayProvider).toIso8601String())
                            const SmartCatchUpBanner(),
                          if (layout.visible.isEmpty)
                            EmptyState(
                              icon: Icons.dashboard_customize_outlined,
                              title: 'Make this space yours',
                              subtitle: 'Choose what belongs on your Home.',
                              actionLabel: 'Open tools',
                              onAction: () => context.push('/more'),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Return-user greeting: floats at the top for a few seconds and
              // never pushes the Dayboard down, positioned below header controls.
              if (_welcomeBackDays != null)
                Positioned(
                  top: 96,
                  left: AppSpace.s24,
                  right: AppSpace.s24,
                  child: WelcomeBackBanner(
                    days: _welcomeBackDays!,
                    visibleFor: const Duration(seconds: 3),
                    onDismissed: () {
                      if (mounted) setState(() => _welcomeBackDays = null);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildContextualModules(
    BuildContext context,
    HomeLayout layout,
  ) {
    final modules = <Widget>[];
    Widget spaced(Widget child) =>
        Padding(padding: const EdgeInsets.only(bottom: 28), child: child);
    if (!_heavierModulesReady) return modules;
    if (layout.visible.contains('learning')) {
      modules.add(spaced(const LearningHubCard()));
    }
    if (layout.visible.contains('promises')) {
      modules.add(spaced(const HomePromiseSection()));
    }
    if (layout.visible.contains('checkin') &&
        ref.watch(localHourProvider) >= 17) {
      modules.add(spaced(const DailyCheckInCard()));
    }
    if (layout.visible.contains('vault') &&
        !layout.shortcuts.contains('vault')) {
      modules.add(spaced(const VaultHomePreview()));
    }
    if (layout.visible.contains('money')) {
      modules.add(
        spaced(
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text('Quick expense'),
            trailing: const Icon(Icons.add_rounded),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const AddTransactionSheet(),
            ),
          ),
        ),
      );
    }
    return modules;
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s24),
      children: [
        SkeletonShimmer.card(height: 50),
        const SizedBox(height: 20),
        SkeletonShimmer.card(height: 120),
        const SizedBox(height: 20),
        SkeletonShimmer.card(height: 72),
        const SizedBox(height: 24),
        SkeletonShimmer.card(height: 180),
        const SizedBox(height: 24),
        SkeletonShimmer.card(height: 90),
      ],
    );
  }
}
