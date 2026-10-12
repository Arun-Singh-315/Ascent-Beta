import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/glass_theme.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/services/hydration_reminder_service.dart';
import '../../core/streak/study_streak_provider.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../reminders/widgets/in_app_reminder_dialog.dart';
import 'widgets/activity_hub_card.dart';
import 'widgets/day_one_tutorial_card.dart';
import 'widgets/home_atmosphere.dart';
import 'widgets/home_dismissible_reminders_section.dart';
import 'widgets/home_header.dart';
import 'widgets/learning_hub_card.dart';
import 'widgets/quick_modules_nav_hub.dart';
import 'widgets/streak_celebration_dialog.dart';
import 'widgets/study_streak_meter_card.dart';
import 'widgets/thought_wall_home_preview.dart';
import 'widgets/welcome_back_banner.dart';
import '../challenge/integration/challenge_proof_sync.dart';

/// Redesigned Home Screen according to the Ascent Home Redesign specification:
/// - Clean intentional surface levels.
/// - Clay accent with neutral ink hierarchy.
/// - First screen leads with Today execution.
/// - Stationary ambient atmosphere painter behind smooth scrolling view.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasCheckedOverdueReminders = false;

  @override
  void initState() {
    super.initState();
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
      ref
          .read(hydrationReminderServiceProvider)
          .checkAndPromptHydration(context);

      if (!_hasCheckedOverdueReminders) {
        _hasCheckedOverdueReminders = true;
        _checkAndPromptOverdueReminder();
      }
    });
  }

  Future<void> _checkAndPromptOverdueReminder() async {
    try {
      final overdueReminders = await ref
          .read(reminderDaoProvider)
          .getOverdueActiveReminders();
      final quietReminders = overdueReminders.where((r) => !r.alarmEnabled).toList();
      if (quietReminders.isNotEmpty && mounted) {
        await InAppReminderDialog.show(context, quietReminders.first);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    final profileAsync = ref.watch(userProfileStreamProvider);
    final daysSinceLastOpen = ref.watch(daysSinceLastOpenProvider);
    final studyStreak = ref.watch(studyStreakProvider);
    final isStreakCardVisible = ref.watch(studyStreakCardVisibleProvider);
    final visibleReminders = ref.watch(homeVisibleRemindersProvider);
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
        child: HomeAtmosphereBackground(
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
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: 96,
                  ),
                  children: [
                    // 1. Top Header (Date caption + Riya gateway + Profile avatar + Greeting + Name)
                    HomeHeader(profile: profile),

                    // Day 1 Welcome & Interactive Mental Model Guide (Zero freeze, dismissible)
                    DayOneTutorialCard(userName: profile?.name ?? ''),

                    // Return-user cold start welcome banner (>3 days absent)
                    if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                      const SizedBox(height: 12),
                      WelcomeBackBanner(days: daysSinceLastOpen),
                    ],

                    // ── STREAK DOPAMINE METER (TOGGLEABLE VIA HEADER FLAME) ──
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOutCubic,
                      child: isStreakCardVisible
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 16),
                                StudyStreakMeterCard(
                                  status: studyStreak,
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    ref
                                        .read(
                                          studyStreakCardVisibleProvider
                                              .notifier,
                                        )
                                        .toggle();
                                  },
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 16),

                    // ── HOME DISMISSIBLE REMINDERS (SWIPE TO REMOVE / ACTION) ──
                    if (visibleReminders.isNotEmpty)
                      HomeDismissibleRemindersSection(
                        reminders: visibleReminders,
                        onAddReminder: () => context.push('/reminders'),
                        onViewAll: () => context.push('/reminders'),
                        onDismissReminder: (reminder) async {
                          await ref
                              .read(dismissedTodayReminderIdsProvider.notifier)
                              .dismissReminderId(reminder.id);
                        },
                        onCompleteReminder: (reminder) async {
                          try {
                            final dao = ref.read(reminderDaoProvider);
                            await dao.updateReminder(
                              reminder
                                  .toCompanion(true)
                                  .copyWith(isActive: const drift.Value(false)),
                            );
                            await NotificationService.instance.cancel(
                              reminder.id,
                            );
                            ref.invalidate(allRemindersProvider);
                          } catch (_) {}
                        },
                      ),

                    if (visibleReminders.isNotEmpty) const SizedBox(height: 16),

                    // ── LEVEL 1: TODAY EXECUTION (PRIMARY) ───────────────
                    const ActivityHubCard(),

                    const SizedBox(height: 24),

                    // ── LEVEL 2: LEARNING HUB ────────────────────────────
                    const LearningHubCard(),

                    const SizedBox(height: 32),

                    // ── LEVEL 2: LIFE & SANCTUARY (2x2 GRID + CHAI) ──────
                    const QuickModulesNavHub(),

                    const SizedBox(height: 32),

                    // ── LEVEL 3: MIND SPACE & SELF-TALK (NOTES) ──────────
                    const ThoughtWallHomePreview(),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
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
