import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/services/hydration_reminder_service.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import 'widgets/activity_hub_card.dart';
import 'widgets/day_one_tutorial_card.dart';
import 'widgets/home_atmosphere.dart';
import 'widgets/home_header.dart';
import 'widgets/learning_hub_card.dart';
import 'widgets/quick_modules_nav_hub.dart';
import 'widgets/thought_wall_home_preview.dart';
import 'widgets/welcome_back_banner.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      ref.read(hydrationReminderServiceProvider).checkAndPromptHydration(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final profileAsync = ref.watch(userProfileStreamProvider);
    final daysSinceLastOpen = ref.watch(daysSinceLastOpenProvider);

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
                },
                color: g.clay,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 96),
                  children: [
                    // 1. Top Header (Date caption + Riya gateway + Profile avatar + Greeting + Name)
                    HomeHeader(profile: profile),

                    // Day 1 Welcome & Interactive Mental Model Guide (Zero freeze, dismissible)
                    DayOneTutorialCard(userName: profile?.name ?? 'Friend'),

                    // Return-user cold start welcome banner (>3 days absent)
                    if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                      const SizedBox(height: 12),
                      WelcomeBackBanner(days: daysSinceLastOpen),
                    ],

                    const SizedBox(height: 16),

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
