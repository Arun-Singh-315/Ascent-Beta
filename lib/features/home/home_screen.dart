import 'package:ascent/app/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/home_content_transition.dart';
import 'widgets/home_reveal.dart';
import '../../core/providers/local_day_provider.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../../shared/widgets/empty_state.dart';
import '../../app/theme/surface_tokens.dart';

import 'package:flutter/material.dart';
import 'widgets/home_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/home_layout_provider.dart';
import '../../core/features/feature_registry.dart';
import 'widgets/home_unlock_next_card.dart';
import 'daily_checkin_card.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/streak/study_streak_provider.dart';
import 'widgets/home_header.dart';
import 'widgets/home_now_card.dart';
import 'widgets/home_ask_bar.dart';
import 'widgets/home_feed_cards.dart';
import 'home_customization_sheet.dart';
import '../../shared/widgets/ascent_backdrop.dart';
import 'widgets/home_feed_entrance.dart';
import 'widgets/home_compact_header.dart';
import 'widgets/home_theme.dart';
import '../vault/widgets/vault_home_preview.dart';
import 'widgets/planning_notification_handler.dart';
import 'widgets/welcome_back_banner.dart';
import '../capture/capture_button.dart';

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
      // Home never opens pop-ups on entry (CLAUDE.md §1): no daily welcome,
      // tutorial, catch-up or celebration dialogs. Only a restore notice.
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      final preferences = ref.read(sharedPreferencesProvider);
      final notice = preferences.getString('ascent_restore_notice_v1');
      if (notice != null) {
        preferences.remove('ascent_restore_notice_v1');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice), duration: const Duration(seconds: 8)),
        );
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
    final profileAsync = ref.watch(userProfileStreamProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateCompactHeader();
    });
    final layout = ref.watch(homeLayoutProvider);
    ref.watch(localHourProvider);

    final c = context.c;

    return Scaffold(
      backgroundColor: c.bg,
      extendBody: true,
      floatingActionButton: const CaptureButton.fab(),
      body: SafeArea(
        child: AscentBackdrop(
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
                        ref.invalidate(recentThoughtsStreamProvider);
                        ref.invalidate(latestHomeThoughtProvider);
                        ref.invalidate(todayActivitiesProvider);
                        ref.invalidate(studyStreakProvider);
                        ref.invalidate(allRemindersProvider);
                        ref.invalidate(dismissedTodayReminderIdsProvider);
                      },
                      color: c.accent,
                      child: ListView(
                        key: const ValueKey('home_scroll'),
                        controller: _homeScroll,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: EdgeInsets.zero,
                        children: [
                          // 1. HomeHeader (keeps header spacious by setting includeAssistant: false)
                          HomeHeader(
                            key: _headerKey,
                            profile: profile,
                            includeAssistant: false,
                          ),

                          // Ask Riya, right where the thumb starts.
                          const HomeAskBar(),
                          const SizedBox(height: 8),

                          // 2. Now card: the single "what should I do now?"
                          // answer (CLAUDE.md §5.1).
                          const HomeFeedEntrance(
                            index: 0,
                            child: HomeNowCard(),
                          ),

                          // Hero feed (CLAUDE.md §5.1): Things and Mind are
                          // live summaries with inline input; Life tiles
                          // follow. Each feature appears once.
                          const HomeFeedEntrance(
                            index: 1,
                            child: HomeThingsCard(),
                          ),
                          const HomeFeedEntrance(
                            index: 2,
                            child: HomeMindCard(),
                          ),
                          // The week at a glance: reminders, to-dos and
                          // thoughts by day.
                          const HomeFeedEntrance(
                            index: 3,
                            child: HomeCalendar(),
                          ),
                          const HomeFeedEntrance(
                            index: 4,
                            child: HomeLifeTiles(),
                          ),

                          PlanningNotificationHandler(
                            uri: widget.notificationUri,
                          ),

                          for (final module in _buildContextualModules(
                            context,
                            layout,
                          ))
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: module,
                            ),

                          if (layout.visible.isEmpty)
                            EmptyState(
                              icon: Icons.dashboard_customize_outlined,
                              title: 'Make this space yours',
                              subtitle: 'Choose what belongs on your Home.',
                              actionLabel: 'Open tools',
                              onAction: () => context.open('/you'),
                            ),

                          // Suggests the next feature; comes and goes.
                          const HomeUnlockNextCard(),

                          Center(
                            child: TextButton.icon(
                              key: const ValueKey('home_customize'),
                              onPressed: () => showHomeCustomization(context),
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Customize Home'),
                            ),
                          ),

                          // Scroll bottom padding = bottom nav height (64) + safe-area inset + 16
                          SizedBox(
                            height:
                                64 + MediaQuery.paddingOf(context).bottom + 16,
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

  List<Widget> _buildContextualModules(
    BuildContext context,
    HomeLayout layout,
  ) {
    final modules = <Widget>[];
    Widget spaced(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HomeReveal(child: HomeContentTransition(child: child)),
    );
    if (!_heavierModulesReady) return modules;
    if (layout.visible.contains('checkin') &&
        ref.watch(localHourProvider) >= 17) {
      modules.add(spaced(const DailyCheckInCard()));
    }
    final unlocked = ref.watch(unlockedFeaturesProvider);
    if (layout.visible.contains('vault') &&
        unlocked.contains(AscentFeature.vault) &&
        !layout.shortcuts.contains('vault')) {
      modules.add(spaced(const VaultHomePreview()));
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
