import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/database/app_database.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/hydration_reminder_service.dart';
import '../../shared/widgets/new_day_dialog.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import 'widgets/activity_hub_card.dart';
import 'widgets/home_header.dart';
import 'widgets/home_reminder_banners.dart';
import 'widgets/learning_hub_card.dart';
import 'widgets/quick_modules_nav_hub.dart';
import 'widgets/riya_floating_gateway.dart';
import 'widgets/secondary_tools_section.dart';
import 'widgets/thought_wall_home_preview.dart';

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
      final newDayShown = await _checkNewDay();
      if (!newDayShown && mounted) {
        ref.read(hydrationReminderServiceProvider).checkAndPromptHydration(context);
      }
    });
  }

  Future<bool> _checkNewDay() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final lastShown = prefs.getString('ascent_new_day_shown');
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (lastShown != todayStr) {
      prefs.setString('ascent_new_day_shown', todayStr);
      await showNewDayDialog(context, ref);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileStreamProvider);
    final daysSinceLastOpen = ref.watch(daysSinceLastOpenProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      floatingActionButton: const RiyaFloatingGateway(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const _HomeLoadingView(),
          error: (err, _) => Center(
            child: Text('Failed to load dashboard: $err'),
          ),
          data: (profile) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userProfileStreamProvider);
                ref.invalidate(todayFocusTaskProvider);
                ref.invalidate(currentStreakStreamProvider);
                ref.invalidate(learningHubProvider);
                ref.invalidate(nextUpcomingInterviewProvider);
                ref.invalidate(nextUpcomingReminderProvider);
                ref.invalidate(mostRecentNoteProvider);
                ref.invalidate(recentThoughtsStreamProvider);
              },
              color: context.accentPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 96),
                children: [
                  // 1. Header (Greeting + User Profile + Streak + Day/Night Toggle)
                  HomeHeader(profile: profile),

                  // Top indicator for upcoming/pending reminders
                  const TopReminderAlertBanner(),

                  // Return-user cold start welcome-back banner (>3 days absent)
                  if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                    const SizedBox(height: 12),
                    WelcomeBackBanner(days: daysSinceLastOpen),
                  ],

                  const SizedBox(height: 14),

                  // ── SECTION 1: TODAY'S EXECUTION ─────────────────────
                  _HomeSectionHeader(
                    icon: Icons.bolt_rounded,
                    iconColor: context.accentSecondary,
                    title: "TODAY'S EXECUTION",
                    subtitle: 'Tasks & Lectures',
                  ),
                  const SizedBox(height: 8),

                  // Today's activities, intelligent types, active timer & quick add
                  const ActivityHubCard(),

                  const SizedBox(height: 14),

                  // Multi-course hero, course switcher, progress & resume
                  const LearningHubCard(),

                  const SizedBox(height: 20),

                  // ── SECTION 2: LIFE & SANCTUARY MODULES ──────────────
                  const QuickModulesNavHub(),

                  const SizedBox(height: 20),

                  // ── SECTION 3: MIND SPACE & KNOWLEDGE ARCHIVE ────────
                  _HomeSectionHeader(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: const Color(0xFF8338EC),
                    title: 'MIND SPACE & REFLECTION',
                    subtitle: 'Self-Talk & Notes',
                  ),
                  const SizedBox(height: 8),

                  // Thought Wall (Quick spark prompt + pinned reflection)
                  const ThoughtWallHomePreview(),

                  const SizedBox(height: 14),

                  // Collapsible Secondary Section (Notes & Reminders)
                  const SecondaryToolsSection(),

                  const SizedBox(height: 22),

                  // Positivity line
                  _HomePositivityLine(profile: profile),

                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;

  const _HomeSectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 12, color: iconColor),
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                color: context.textMuted.withValues(alpha: 0.8),
              ),
            ),
        ],
      ),
    );
  }
}

class _HomePositivityLine extends StatelessWidget {
  final UserProfile? profile;
  const _HomePositivityLine({this.profile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          'Prepare with purpose — clarity comes from daily reps.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: context.textMuted,
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
      padding: const EdgeInsets.all(18),
      children: [
        SkeletonShimmer.card(height: 50),
        const SizedBox(height: 12),
        SkeletonShimmer.card(height: 80),
        const SizedBox(height: 12),
        SkeletonShimmer.card(height: 160),
        const SizedBox(height: 12),
        SkeletonShimmer.card(height: 140),
        const SizedBox(height: 12),
        SkeletonShimmer.card(height: 90),
      ],
    );
  }
}
