import '../../app/theme/home_design.dart';
import 'widgets/home_section_heading.dart';
import '../plans/widgets/home_plans_preview.dart';
import 'widgets/home_module_row.dart';
import 'widgets/home_content_transition.dart';
import '../../core/providers/local_day_provider.dart';
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
import 'widgets/home_compact_header.dart';
import 'widgets/home_calendar.dart';
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
  Widget build(BuildContext context) => AnimatedTheme(
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 320,
    ),
    curve: Curves.easeInOutCubic,
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
  final _homeScroll = ScrollController();
  final _headerKey = GlobalKey();
  final _headerCollapse = ValueNotifier<double>(0);
  double _expandedHeaderHeight = 280;

  void _updateCompactHeader() {
    final render = _headerKey.currentContext?.findRenderObject();
    if (render is RenderBox && render.hasSize) {
      _expandedHeaderHeight = render.size.height;
    }
    if (!_homeScroll.hasClients) return;
    final start = (_expandedHeaderHeight - 76).clamp(0.0, double.infinity);
    final value = ((_homeScroll.offset - start) / 64).clamp(0.0, 1.0);
    if (_headerCollapse.value != value) _headerCollapse.value = value;
  }

  void _returnToTop() {
    if (!_homeScroll.hasClients) return;
    _homeScroll.animateTo(
      0,
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 1 : 280,
      ),
      curve: Curves.easeOutCubic,
    );
  }

  int? _welcomeBackDays;
  bool _heavierModulesReady = false;
  bool _entryDialogsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _homeScroll.addListener(_updateCompactHeader);
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
    _homeScroll.removeListener(_updateCompactHeader);
    _homeScroll.dispose();
    _headerCollapse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    final profileAsync = ref.watch(userProfileStreamProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateCompactHeader();
    });
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
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  skipError: true,
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
                        key: const ValueKey('home_scroll'),
                        controller: _homeScroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(
                          left: 0,
                          right: 0,
                          top: 0,
                          bottom: AppSpace.s96,
                        ),
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              MediaQuery.sizeOf(context).width < 360 ? 8 : 12,
                              8,
                              MediaQuery.sizeOf(context).width < 360 ? 8 : 12,
                              0,
                            ),
                            child: _HomeOneCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                          HomeHeader(key: _headerKey, profile: profile),
                          const SizedBox(height: 12),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              MediaQuery.sizeOf(context).width < 360 ? 16 : 20,
                              0,
                              MediaQuery.sizeOf(context).width < 360 ? 16 : 20,
                              16,
                            ),
                            child: HomeShortcutPanel(
                              shortcuts: layout.shortcuts,
                              showReminders: layout.visible.contains(
                                'reminders',
                              ),
                            ),
                          ),
                          Padding(
                            padding: _sectionPadding(context),
                            child: HomeCalendar(),
                          ),
                          if (layout.visible.contains('today'))
                            Padding(
                              padding: _sectionPadding(context),
                              child: ActivityHubCard(
                                previewLimit: layout.compact.contains('today')
                                    ? 3
                                    : 6,
                              ),
                            ),
                          if (layout.visible.contains('mind'))
                            Padding(
                              padding: _sectionPadding(context),
                              child: ThoughtWallHomePreview(
                                previewLimit: 1,
                                compact: true,
                              ),
                            ),
                          if (layout.visible.contains('life') &&
                              layout.tools.isNotEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: HomeLifeShelf(),
                            ),
                          Padding(
                            padding: _sectionPadding(context),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HomeSectionHeading(
                                  title: 'Plans & Routines',
                                  dotColor: HomeDesign.of(context).learningInk,
                                  titleColor: HomeDesign.of(
                                    context,
                                  ).learningInk,
                                  trailing: HomeSectionArrowButton(
                                    tooltip: 'Open all plans',
                                    framed: false,
                                    color: HomeDesign.of(context).learningInk,
                                    onTap: () => context.push('/plans'),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const HomePlansPreview(
                                  key: ValueKey('home_plans_big_card'),
                                ),
                              ],
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
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ValueListenableBuilder<double>(
                  valueListenable: _headerCollapse,
                  builder: (context, value, _) {
                    if (value <= 0 || profileAsync.value == null) {
                      return const SizedBox.shrink();
                    }
                    return IgnorePointer(
                      ignoring: value < .8,
                      child: ExcludeSemantics(
                        excluding: value < .8,
                        child: Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, -8 * (1 - value)),
                            child: HomeCompactHeader(
                              name: profileAsync.value?.name ?? '',
                              onReturnToTop: _returnToTop,
                            ),
                          ),
                        ),
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

  EdgeInsets _sectionPadding(BuildContext context) {
    final margin = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 20.0;
    return EdgeInsets.fromLTRB(margin, 0, margin, 24);
  }

  List<Widget> _buildContextualModules(
    BuildContext context,
    HomeLayout layout,
  ) {
    final modules = <Widget>[];
    Widget spaced(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: HomeContentTransition(child: child),
    );
    if (!_heavierModulesReady) return modules;
    final growthModules = <Widget>[
      if (layout.visible.contains('learning')) const LearningHubCard(),
      if (layout.visible.contains('promises')) const HomePromiseSection(),
    ];
    if (growthModules.isNotEmpty) {
      modules.add(spaced(HomeModuleGroup(children: growthModules)));
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
            onTap: () => AddTransactionSheet.show(context),
          ),
        ),
      );
    }
    return modules;
  }
}

/// One continuous surface for every Home section: a fine outline, no shadow,
/// and sections separated by space and their own coloured outlines.
class _HomeOneCard extends StatelessWidget {
  const _HomeOneCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final design = HomeDesign.of(context);
    return Container(
      key: const ValueKey('home_one_card'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: design.canvas,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: MediaQuery.highContrastOf(context)
              ? design.controlOutline
              : design.separator,
        ),
      ),
      child: child,
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.s24),
      children: [
        SkeletonShimmer.card(
          height: MediaQuery.textScalerOf(context).scale(14) > 21 ? 420 : 260,
        ),
        const SizedBox(height: 20),
        SkeletonShimmer.card(height: 180),
        const SizedBox(height: 20),
        SkeletonShimmer.card(height: 132),
        const SizedBox(height: 24),
        SkeletonShimmer.card(height: 180),
        const SizedBox(height: 24),
        SkeletonShimmer.card(height: 90),
      ],
    );
  }
}
