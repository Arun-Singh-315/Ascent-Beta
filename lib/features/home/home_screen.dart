import '../reminders/reminder_action_ui.dart';
import 'dart:async';

import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter/services.dart';
import '../../app/theme/frozen_palette.dart';
import '../../app/theme/merlot_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/color_tokens.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/home_layout_provider.dart';
import '../money/add_transaction_sheet.dart';
import 'daily_checkin_card.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/streak/study_streak_provider.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../reminders/widgets/in_app_reminder_dialog.dart';
import 'widgets/activity_hub_card.dart';
import 'widgets/day_one_tutorial_card.dart';
import 'widgets/daily_briefing_card.dart';
import '../../core/providers/daily_briefing_provider.dart';
import 'widgets/home_atmosphere.dart';
import 'widgets/home_dismissible_reminders_section.dart';
import 'widgets/home_header.dart';
import 'widgets/home_theme.dart';
import 'widgets/learning_hub_card.dart';
import 'widgets/quick_modules_nav_hub.dart';
import 'widgets/streak_celebration_dialog.dart';
import 'widgets/study_streak_meter_card.dart';
import 'widgets/thought_wall_home_preview.dart';
import 'widgets/planning_notification_handler.dart';
import 'widgets/welcome_back_banner.dart';
import '../challenge/integration/challenge_proof_sync.dart';

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
  bool _openingBriefing = false;
  bool _startupComplete = false;
  Timer? _dayTimer;
  bool _hasCheckedOverdueReminders = false;
  int? _welcomeBackDays;

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

      if (!_hasCheckedOverdueReminders) {
        _hasCheckedOverdueReminders = true;
        await _checkAndPromptOverdueReminder();
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
      _startupComplete = true;
      await _maybeOpenBriefing();
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
      _maybeOpenBriefing();
    }
  }

  void _refreshBriefingDay() {
    final day = briefingDay(DateTime.now());
    if (mounted && day != _briefingDate) {
      setState(() => _briefingDate = day);
    }
    _scheduleDayChange();
  }

  void _scheduleDayChange() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(tomorrow.difference(now), () {
      _refreshBriefingDay();
      _maybeOpenBriefing();
    });
  }

  Future<void> _maybeOpenBriefing() async {
    if (!mounted ||
        !_startupComplete ||
        !ref.read(dailyBriefingAutoOpenProvider) ||
        _openingBriefing ||
        (widget.notificationUri?.hasQuery ?? false) ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final preferences = ref.read(sharedPreferencesProvider);
    final key = _briefingDate.toIso8601String();
    if (preferences.getString('ascent_daily_briefing_seen_v1') == key) return;
    _openingBriefing = true;
    try {
      // Mark it seen when presented, so dismissing it respects the user's choice.
      final sheet = DailyBriefingCard.show(context, _briefingDate);
      await preferences.setString('ascent_daily_briefing_seen_v1', key);
      await sheet;
    } finally {
      _openingBriefing = false;
    }
  }

  Future<bool> _checkAndPromptOverdueReminder() async {
    try {
      final overdueReminders = await ref
          .read(reminderDaoProvider)
          .getOverdueActiveReminders();
      final quietReminders = overdueReminders
          .where((r) => !r.alarmEnabled)
          .toList();
      if (quietReminders.isNotEmpty && mounted) {
        await InAppReminderDialog.show(context, quietReminders.first);
        return true;
      }
    } catch (e) {
      debugPrint('Error checking overdue reminders: $e');
    }
    return false;
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

    return Scaffold(
      backgroundColor: g.bg,
      floatingActionButton: _buildFloatingAssistantPill(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
                  ref.invalidate(todayMomentumCommitmentsStreamProvider);
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
                    DailyBriefingCard(day: _briefingDate, minimal: true),

                    // Mind Space keeps its familiar composer and recent notes above other cards.
                    if (layout.visible.contains('mind'))
                      const Padding(
                        padding: EdgeInsets.only(bottom: AppSpace.s16),
                        child: ThoughtWallHomePreview(),
                      ),
                    PlanningNotificationHandler(uri: widget.notificationUri),

                    if (layout.shortcuts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s18),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: layout.shortcuts
                              .map(
                                (id) => AppPill.action(
                                  label: Text(homeShortcutRoutes[id]!),
                                  onPressed: () => context.push('/$id'),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    for (final id in layout.order.where(
                      (id) => id != 'mind' && layout.visible.contains(id),
                    ))
                      _homeSection(id, layout),
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
                ),
              );
            },
                ),
              ),
              // Return-user greeting: floats at the top for a few seconds and
              // never pushes the Things hub down.
              if (_welcomeBackDays != null)
                Positioned(
                  top: AppSpace.s8,
                  left: AppSpace.s24,
                  right: AppSpace.s24,
                  child: WelcomeBackBanner(
                    days: _welcomeBackDays!,
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

  Widget _buildFloatingAssistantPill(BuildContext context) {
    final isDark = context.isDark;
    final g = context.glass;
    final assistantName = ref.watch(assistantNameProvider);
    final accentColors = g.frozen
        ? (isDark
              ? [FrozenPalette.darkActionBright, FrozenPalette.darkAction]
              : [FrozenPalette.actionBright, FrozenPalette.action])
        : g.merlot
        ? (isDark
              ? [g.clay, g.clay.withValues(alpha: 0.82)]
              : [MerlotPalette.actionBright, MerlotPalette.actionDeep])
        : (isDark
              ? [g.clay, g.clay.withValues(alpha: 0.82)]
              : [const Color(0xFFE86B43), const Color(0xFFC85A32)]);
    final shadowColor = g.frozen
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : g.merlot
        ? (isDark ? g.clay : MerlotPalette.actionDeep)
        : (isDark ? g.clay : const Color(0xFFC85A32));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/ai-assistant');
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: accentColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: g.merlot && !isDark
                      ? MerlotPalette.antiqueGold
                      : Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ask $assistantName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                context, ref, reminder, ReminderRowAction.delete,
              );
            },
            onCompleteReminder: (reminder) async {
              await runReminderAction(
                context, ref, reminder, ReminderRowAction.done,
              );
            },
            onSnoozeReminder: (reminder) async {
              await runReminderAction(
                context, ref, reminder, ReminderRowAction.snooze,
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
