import 'package:ascent/app/app_navigation.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/home_content_transition.dart';
import 'widgets/home_reveal.dart';
import '../../core/providers/local_day_provider.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../../shared/widgets/empty_state.dart';
import '../../app/theme/surface_tokens.dart';

import 'package:flutter/rendering.dart'
    show RenderSliverMultiBoxAdaptor, SliverMultiBoxAdaptorParentData;
import 'package:flutter/material.dart';
import '../capture/capture_card.dart';
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
import 'v7/home_header_v7.dart';
import 'widgets/home_now_card.dart';
import 'widgets/home_feed_cards.dart';
import 'home_customization_sheet.dart';
import '../../shared/widgets/ascent_backdrop.dart';
import 'widgets/home_feed_entrance.dart';
import '../vault/widgets/vault_home_preview.dart';
import 'widgets/planning_notification_handler.dart';
import 'widgets/welcome_back_banner.dart';
import '../promises/widgets/home_promise_card.dart';
import '../travel/home_travel_card.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;

/// A focused daily workspace with distinct places for action, thought and life.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.notificationUri});
  final Uri? notificationUri;

  // Home uses the app's one theme. It used to wrap itself in a second,
  // separately animated theme, which made day/night switches flicker.
  @override
  Widget build(BuildContext context) =>
      _HomeContent(notificationUri: notificationUri);
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

  /// Sections the compact bar's tabs jump to, in order.
  static const _tabNames = ['Now', 'Things', 'Thoughts', 'Life'];
  final _sectionKeys = List.generate(_tabNames.length, (_) => GlobalKey());
  final _sectionTops = List<double?>.filled(_tabNames.length, null);
  final _tab = ValueNotifier<int>(0);

  /// Height of the compact bar below the top inset, so a jump lands the
  /// section just under it.
  static const _barHeight = 150.0;

  void _updateCompactHeader() {
    final render = _headerKey.currentContext?.findRenderObject();
    if (render is RenderBox && render.hasSize) {
      _expandedHeaderHeight = render.size.height;
    }
    if (!_homeScroll.hasClients) return;
    final start = (_expandedHeaderHeight - 120).clamp(0.0, double.infinity);
    final value = ((_homeScroll.offset - start) / 80).clamp(0.0, 1.0);
    if (_headerCollapse.value != value) _headerCollapse.value = value;
    // Scroll-spy: the last section whose top has passed under the bar.
    // Children laid out by this scroll only get their real offsets after
    // the frame, so look once more then.
    if (!_spyAgainScheduled) {
      _spyAgainScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _spyAgainScheduled = false;
        if (mounted) _spy();
      });
    }
    _spy();
  }

  bool _spyAgainScheduled = false;

  /// Tops are remembered because the list drops boxes far off-screen.
  void _spy() {
    if (!_homeScroll.hasClients) return;
    final offset = _homeScroll.offset;
    for (final (i, key) in _sectionKeys.indexed) {
      final top = _scrollTop(key);
      if (top != null) _sectionTops[i] = top;
    }
    var current = 0;
    for (final (i, top) in _sectionTops.indexed) {
      if (top != null && top - offset <= _barHeight + 24) current = i;
    }
    if (_tab.value != current) _tab.value = current;
  }

  /// A section's top in scroll coordinates (the list's own layout offset,
  /// which stays right for sections scrolled away), or null before it has
  /// ever been laid out.
  double? _scrollTop(GlobalKey key) {
    RenderObject? node = key.currentContext?.findRenderObject();
    while (node != null && node.parent is! RenderSliverMultiBoxAdaptor) {
      node = node.parent;
    }
    final data = node?.parentData;
    return data is SliverMultiBoxAdaptorParentData ? data.layoutOffset : null;
  }

  void _jumpTo(int i) {
    if (!_homeScroll.hasClients) return;
    final top = _scrollTop(_sectionKeys[i]) ?? _sectionTops[i];
    // Not measured yet (never scrolled to): head for the end; the spy
    // measures it on the way.
    final target = (top == null ? double.infinity : top - _barHeight + 8).clamp(
      0.0,
      _homeScroll.position.maxScrollExtent,
    );
    _homeScroll.animateTo(
      target,
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 1 : 380,
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
    _tab.dispose();
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
                        child: CupertinoActivityIndicator(
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
                          // Masthead and the navy summary panel.
                          KeyedSubtree(
                            key: _headerKey,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  HomeMasthead(name: profile?.name ?? ''),
                                  const HomeSummaryPanel(),
                                ],
                              ),
                            ),
                          ),

                          // Capture first: open the app, write, Enter.
                          const Padding(
                            padding: EdgeInsets.fromLTRB(
                              AppSpace.s16,
                              AppSpace.s12,
                              AppSpace.s16,
                              0,
                            ),
                            child: CaptureCard(),
                          ),

                          const SizedBox(height: 8),

                          // 2. Now card: the single "what should I do now?"
                          // answer (CLAUDE.md §5.1).
                          KeyedSubtree(
                            key: _sectionKeys[0],
                            child: const HomeFeedEntrance(
                              index: 0,
                              child: HomeNowCard(),
                            ),
                          ),

                          // Hero feed (CLAUDE.md §5.1): Things and Mind are
                          // live summaries with inline input; Life tiles
                          // follow. Each feature appears once.
                          // Promises sit right under Now: one daily answer
                          // that keeps your word to yourself in view.
                          if (layout.visible.contains('promises') &&
                              ref
                                  .watch(unlockedFeaturesProvider)
                                  .contains(AscentFeature.things))
                            const HomeFeedEntrance(
                              index: 1,
                              child: HomePromiseCard(),
                            ),
                          // Travel shows only while a trip is on or a recent
                          // visit is waiting for its bill or photos.
                          const HomeFeedEntrance(
                            index: 1,
                            child: HomeTravelCard(),
                          ),
                          KeyedSubtree(
                            key: _sectionKeys[1],
                            child: const HomeFeedEntrance(
                              index: 1,
                              child: HomeThingsCard(),
                            ),
                          ),
                          KeyedSubtree(
                            key: _sectionKeys[2],
                            child: const HomeFeedEntrance(
                              index: 2,
                              child: HomeMindCard(),
                            ),
                          ),
                          // The week at a glance: reminders, to-dos and
                          // thoughts by day.
                          const HomeFeedEntrance(
                            index: 3,
                            child: HomeCalendar(),
                          ),
                          KeyedSubtree(
                            key: _sectionKeys[3],
                            child: const HomeFeedEntrance(
                              index: 4,
                              child: HomeLifeTiles(),
                            ),
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
                            child: ValueListenableBuilder<int>(
                              valueListenable: _tab,
                              builder: (context, tab, _) => HomeCompactBar(
                                tabs: _tabNames,
                                current: tab,
                                onTab: _jumpTo,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // The live pill: next thing's countdown or a running timer.
              if (profileAsync.value != null)
                const Positioned(
                  top: 8,
                  left: 0,
                  right: 0,
                  child: Center(child: HomeLivePill()),
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
