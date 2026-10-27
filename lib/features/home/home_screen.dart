import 'widgets/home_promise_section.dart';
import '../reminders/reminder_action_ui.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import 'dart:async';

import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/home_layout_provider.dart';
import '../money/add_transaction_sheet.dart';
import 'daily_checkin_card.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/streak/study_streak_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../promises/providers/promise_providers.dart';
import 'widgets/activity_hub_card.dart';
import 'widgets/day_one_tutorial_card.dart';
import 'widgets/daily_briefing_card.dart';
import '../../core/providers/daily_briefing_provider.dart';
import 'widgets/home_atmosphere.dart';
import 'widgets/home_dismissible_reminders_section.dart';
import 'widgets/home_header.dart';
import 'widgets/home_shortcut_panel.dart';
import 'widgets/home_theme.dart';
import 'widgets/learning_hub_card.dart';
import 'widgets/quick_modules_nav_hub.dart';
import 'widgets/streak_celebration_dialog.dart';
import 'widgets/study_streak_meter_card.dart';
import 'widgets/thought_wall_home_preview.dart';
import 'widgets/planning_notification_handler.dart';
import 'widgets/welcome_back_banner.dart';
import '../challenge/integration/challenge_proof_sync.dart';
import '../vault/widgets/vault_home_preview.dart';

/// Redesigned Home Screen according to the Ascent Home Redesign specification:
/// - Clean intentional surface levels.
/// - Clay accent with neutral ink hierarchy.
/// - First screen leads with Today execution.
/// - Stationary ambient atmosphere painter behind smooth scrolling view.
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
  DateTime _briefingDate = briefingDay(DateTime.now());
  Timer? _dayTimer;
  bool _dismissedBriefingToday = false;
  int? _welcomeBackDays;
  bool _heavierModulesReady = false;
  String? _activeShortcutId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayChange();
    final daysAway = ref.read(daysSinceLastOpenProvider);
    if (!_welcomeBackShownThisLaunch && daysAway >= 3 && daysAway < 999) {
      _welcomeBackShownThisLaunch = true;
      _welcomeBackDays = daysAway;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _heavierModulesReady = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

      if (!mounted) return;
      final profile = await ref
          .read(userProfileStreamProvider.future)
          .onError((_, _) => null);
      if (!mounted || !canEnterWorkspace(profile, preferences)) return;

      final tutorialDismissed =
          (preferences.getBool(DayOneTutorialDialog.prefKey) ?? false) ||
          (preferences.getBool('ascent_quick_start_v1') ?? false);
      if (!tutorialDismissed && mounted) {
        preferences.setBool(DayOneTutorialDialog.prefKey, true);
        await DayOneTutorialDialog.show(context, userName: profile?.name ?? '');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshBriefingDay();
    }
  }

  void _refreshBriefingDay() {
    final day = briefingDay(DateTime.now());
    if (mounted && day != _briefingDate) {
      setState(() {
        _briefingDate = day;
        _dismissedBriefingToday = false;
      });
    }
    _scheduleDayChange();
  }

  void _scheduleDayChange() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(tomorrow.difference(now), () {
      _refreshBriefingDay();
    });
  }

  Widget _buildInlineBriefingCard(
    BuildContext context,
    SharedPreferences preferences,
  ) {
    final key = _briefingDate.toIso8601String();
    if (preferences.getString('ascent_daily_briefing_seen_v1') == key ||
        _dismissedBriefingToday) {
      return const SizedBox.shrink();
    }
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('home_inline_briefing_card'),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            DailyBriefingCard.show(context, _briefingDate);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: g.fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: g.line),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: g.clay.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.wb_sunny_outlined, size: 18, color: g.clay),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Daily Briefing',
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to review agenda & launchpad',
                        style: TextStyle(color: g.inkSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('dismiss_inline_briefing'),
                  tooltip: 'Dismiss for today',
                  icon: Icon(Icons.close_rounded, size: 18, color: g.inkMuted),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _dismissedBriefingToday = true);
                    preferences.setString('ascent_daily_briefing_seen_v1', key);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    final profileAsync = ref.watch(userProfileStreamProvider);
    final layout = ref.watch(homeLayoutProvider);
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

    return PopScope(
      canPop: _activeShortcutId == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_activeShortcutId != null) {
          setState(() => _activeShortcutId = null);
        }
      },
      child: Scaffold(
        backgroundColor: g.bg,
        body: SafeArea(
          child: HomeAtmosphereBackground(
            child: Stack(
              children: [
                Positioned.fill(
                  child: profileAsync.when(
                    loading: () => const _HomeLoadingView(),
                    error: (err, _) => Center(
                      child: Text(
                        'Failed to load dashboard: $err',
                        style: TextStyle(color: g.inkMuted),
                      ),
                    ),
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
                          ref.invalidate(todayActivitiesProvider);
                          ref.invalidate(activeMomentumChallengeStreamProvider);
                          ref.invalidate(
                            todayMomentumCommitmentsStreamProvider,
                          );
                          ref.invalidate(studyStreakProvider);
                          ref.invalidate(allRemindersProvider);
                          ref.invalidate(dismissedTodayReminderIdsProvider);
                        },
                        color: g.clay,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(
                            left: AppSpace.s24,
                            right: AppSpace.s24,
                            top: AppSpace.s16,
                            bottom: AppSpace.s96,
                          ),
                          children: [
                            // 1. Top Header (Date caption + Riya gateway + Profile avatar + Greeting + Name)
                            HomeHeader(profile: profile),

                            // Inline Collapsible Daily Briefing Card (if not seen today)
                            _buildInlineBriefingCard(
                              context,
                              ref.read(sharedPreferencesProvider),
                            ),

                            // 2. Dynamic Shortcut Hub (up to four user-customized shortcuts)
                            if (layout.shortcuts.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpace.s16,
                                ),
                                child: HomeShortcutPanel(
                                  shortcuts: layout.shortcuts,
                                  activeShortcutId: _activeShortcutId,
                                  onSelectShortcut: (id) =>
                                      setState(() => _activeShortcutId = id),
                                ),
                              ),

                            // ── SHORTCUT DRILLDOWN / FULL HOME FEED ──
                            if (_activeShortcutId != null) ...[
                              _buildBackToHomeBar(context),
                              _buildSingleShortcutFeature(
                                _activeShortcutId!,
                                layout,
                              ),
                            ] else ...[
                              // Mind Palace / Thought capture stays at the top of the feed
                              if (layout.visible.contains('mind'))
                                const Padding(
                                  padding: EdgeInsets.only(
                                    bottom: AppSpace.s20,
                                  ),
                                  child: ThoughtWallHomePreview(
                                    previewLimit: 1,
                                    compact: true,
                                  ),
                                ),

                              // HERO: Activity Hub
                              if (layout.visible.contains('today'))
                                Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpace.s24,
                                  ),
                                  child: ActivityHubCard(
                                    previewLimit:
                                        layout.compact.contains('today')
                                        ? 2
                                        : 4,
                                  ),
                                ),

                              PlanningNotificationHandler(
                                uri: widget.notificationUri,
                              ),

                              // Contextual & remaining modules (hidden when empty)
                              ..._buildContextualModules(context, layout),

                              if (layout.visible.isEmpty)
                                Column(
                                  children: [
                                    Text(
                                      'Make this space yours',
                                      style: TextStyle(color: g.ink),
                                    ),
                                    TextButton(
                                      onPressed: () => context.push('/more'),
                                      child: const Text('Open tools'),
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Return-user greeting: floats at the top for a few seconds and
                // never pushes the Things hub down, positioned below header controls.
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
      ),
    );
  }

  Widget _buildBackToHomeBar(BuildContext context) {
    final g = context.glass;
    final shortcutLabel = _activeShortcutId != null
        ? (kRegisteredShortcuts[_activeShortcutId]?.label ?? _activeShortcutId!)
        : '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('back_to_home_button'),
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _activeShortcutId = null);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: g.fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: g.edge),
            ),
            child: Row(
              children: [
                Icon(Icons.arrow_back_rounded, size: 18, color: g.clay),
                const SizedBox(width: 8),
                Text(
                  'Back to home',
                  style: TextStyle(
                    color: g.clay,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  shortcutLabel,
                  style: TextStyle(
                    color: g.inkMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleShortcutFeature(String id, HomeLayout layout) {
    switch (id) {
      case 'today':
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpace.s32),
          child: ActivityHubCard(previewLimit: 20),
        );
      case 'thought-wall':
      case 'mind':
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpace.s32),
          child: ThoughtWallHomePreview(previewLimit: 20),
        );
      case 'reminders':
        final reminders = ref.watch(homeVisibleRemindersProvider);
        if (reminders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s24),
              child: Text(
                'No reminders scheduled.',
                style: TextStyle(color: context.glass.inkMuted),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s32),
          child: HomeDismissibleRemindersSection(
            reminders: reminders,
            onAddReminder: () => context.push('/reminders'),
            onViewAll: () => context.push('/reminders'),
            onDismissReminder: (r) =>
                runReminderAction(context, ref, r, ReminderRowAction.delete),
            onCompleteReminder: (r) =>
                runReminderAction(context, ref, r, ReminderRowAction.done),
            onSnoozeReminder: (r) =>
                runReminderAction(context, ref, r, ReminderRowAction.snooze),
          ),
        );
      case 'learning':
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpace.s32),
          child: LearningHubCard(),
        );
      case 'hydration':
      case 'health':
      case 'medicine':
      case 'walk':
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpace.s32),
          child: QuickModulesNavHub(),
        );
      case 'promises':
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpace.s32),
          child: HomePromiseSection(),
        );
      case 'money':
        return _homeSection('money', layout);
      case 'vault':
        return _homeSection('vault', layout);
      case 'checkin':
        return const Padding(
          padding: EdgeInsets.only(bottom: AppSpace.s32),
          child: DailyCheckInCard(),
        );
      default:
        return _homeSection(id, layout);
    }
  }

  List<Widget> _buildContextualModules(
    BuildContext context,
    HomeLayout layout,
  ) {
    final hour = DateTime.now().hour;
    final isMorning = hour < 12;
    final isEvening = hour >= 17;
    final widgets = <Widget>[];

    Widget deferredModule(Widget child) {
      return AnimatedOpacity(
        opacity: _heavierModulesReady ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: child,
      );
    }

    // 1. Morning: Life & Health (Water/Medicine) higher up
    if (isMorning &&
        layout.visible.contains('life') &&
        layout.tools.isNotEmpty) {
      widgets.add(
        deferredModule(
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpace.s24),
            child: QuickModulesNavHub(),
          ),
        ),
      );
    }

    // 2. Active Reminders (hidden when empty)
    if (layout.visible.contains('reminders')) {
      final reminders = ref.watch(homeVisibleRemindersProvider);
      if (reminders.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s32),
            child: HomeDismissibleRemindersSection(
              reminders: reminders,
              onAddReminder: () => context.push('/reminders'),
              onViewAll: () => context.push('/reminders'),
              onDismissReminder: (r) =>
                  runReminderAction(context, ref, r, ReminderRowAction.delete),
              onCompleteReminder: (r) =>
                  runReminderAction(context, ref, r, ReminderRowAction.done),
              onSnoozeReminder: (r) =>
                  runReminderAction(context, ref, r, ReminderRowAction.snooze),
            ),
          ),
        );
      }
    }

    // 3. Learning Hub (hidden when empty/unstarted)
    if (layout.visible.contains('learning')) {
      final learning = ref.watch(learningHubProvider);
      if (learning.hasStartedLearning && learning.courses.isNotEmpty) {
        widgets.add(
          deferredModule(
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.s32),
              child: LearningHubCard(),
            ),
          ),
        );
      }
    }

    // 4. Promises (hidden when empty)
    if (layout.visible.contains('promises')) {
      final promises = ref.watch(activePromisesStreamProvider).value ?? [];
      if (promises.isNotEmpty) {
        widgets.add(
          deferredModule(
            const Padding(
              padding: EdgeInsets.only(bottom: AppSpace.s24),
              child: HomePromiseSection(),
            ),
          ),
        );
      }
    }

    // 5. Evening: Daily Check-In higher up (hidden when empty)
    if (isEvening && layout.visible.contains('checkin')) {
      widgets.add(
        deferredModule(
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpace.s32),
            child: DailyCheckInCard(),
          ),
        ),
      );
    }

    // 6. Afternoon/Non-morning: Life & Health (if visible)
    if (!isMorning &&
        layout.visible.contains('life') &&
        layout.tools.isNotEmpty) {
      widgets.add(
        deferredModule(
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpace.s24),
            child: QuickModulesNavHub(),
          ),
        ),
      );
    }

    // 7. Streak Meter (if visible)
    if (layout.visible.contains('streak') &&
        ref.watch(homeStreakVisibleProvider)) {
      widgets.add(
        deferredModule(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s32),
            child: StudyStreakMeterCard(
              status: ref.watch(studyStreakProvider),
              onTap: () => ref
                  .read(homeLayoutProvider.notifier)
                  .save(
                    layout.copyWith(
                      visible: {...layout.visible}..remove('streak'),
                    ),
                  ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _homeSection(String id, HomeLayout layout) {
    Widget spaced(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s32),
      child: child,
    );
    switch (id) {
      case 'streak':
        if (!ref.watch(homeStreakVisibleProvider)) {
          return const SizedBox.shrink();
        }
        return spaced(
          StudyStreakMeterCard(
            status: ref.watch(studyStreakProvider),
            onTap: () => ref
                .read(homeLayoutProvider.notifier)
                .save(
                  layout.copyWith(
                    visible: {...layout.visible}..remove('streak'),
                  ),
                ),
          ),
        );
      case 'promises':
        return const SizedBox.shrink();
      case 'reminders':
        final reminders = ref.watch(homeVisibleRemindersProvider);
        if (reminders.isEmpty) return const SizedBox.shrink();
        return spaced(
          HomeDismissibleRemindersSection(
            reminders: reminders,
            onAddReminder: () => context.push('/reminders'),
            onViewAll: () => context.push('/reminders'),
            onDismissReminder: (reminder) async {
              await runReminderAction(
                context,
                ref,
                reminder,
                ReminderRowAction.delete,
              );
            },
            onCompleteReminder: (reminder) async {
              await runReminderAction(
                context,
                ref,
                reminder,
                ReminderRowAction.done,
              );
            },
            onSnoozeReminder: (reminder) async {
              await runReminderAction(
                context,
                ref,
                reminder,
                ReminderRowAction.snooze,
              );
            },
          ),
        );
      case 'today':
        return spaced(
          ActivityHubCard(previewLimit: layout.compact.contains(id) ? 2 : 4),
        );
      case 'learning':
        return spaced(const LearningHubCard());
      case 'life':
        if (layout.tools.isEmpty) return const SizedBox.shrink();
        if (layout.tools.length == homeTools.length) {
          return spaced(const QuickModulesNavHub());
        }
        return spaced(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Life & Health',
                style: AppTypeRoles.typeRole1.copyWith(
                  color: context.glass.ink,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: layout.tools
                    .map(
                      (tool) => AppPill.action(
                        label: Text(homeTools[tool]!),
                        onPressed: () => context.push('/$tool'),
                      ),
                    )
                    .toList(),
              ),
              if (layout.tools.contains('hydration'))
                TextButton(
                  onPressed: () async {
                    await ref.read(waterDaoProvider).addWater(250);
                  },
                  child: const Text('Log 250 ml water'),
                ),
            ],
          ),
        );
      case 'money':
        return spaced(
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.payments_outlined),
            title: const Text('Log an expense'),
            subtitle: const Text('Amount, category and date — when you want'),
            onTap: () => AddTransactionSheet.show(context),
          ),
        );
      case 'checkin':
        return spaced(const DailyCheckInCard());
      case 'vault':
        return spaced(const VaultHomePreview());
      default:
        return const SizedBox.shrink();
    }
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
