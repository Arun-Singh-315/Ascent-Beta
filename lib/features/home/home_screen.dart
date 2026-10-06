import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../../core/walk/walk_tracking_service.dart';
import '../study_plan/lecture_focus_player_sheet.dart';
import '../today/add_activity_sheet.dart';
import 'package:flutter/services.dart';
import '../../shared/widgets/new_day_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkNewDay();
    });
  }

  void _checkNewDay() {
    final prefs = ref.read(sharedPreferencesProvider);
    final lastShown = prefs.getString('ascent_new_day_shown');
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    if (lastShown == null) {
      prefs.setString('ascent_new_day_shown', todayStr);
      return;
    }
    if (lastShown != todayStr) {
      prefs.setString('ascent_new_day_shown', todayStr);
      showNewDayDialog(context, ref);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileStreamProvider);
    final daysSinceLastOpen = ref.watch(daysSinceLastOpenProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      floatingActionButton: const _RiyaSeBaatFloatingButton(),
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
              },
              color: context.accentPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 96),
                children: [
                  // 1. Header (Greeting + User Profile + Plan Day)
                  _HomeHeader(profile: profile),

                  // Top indicator for upcoming/pending reminders
                  const _TopReminderAlertBanner(),

                  // Return-user cold start welcome-back banner (>3 days absent)
                  if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                    const SizedBox(height: 12),
                    _WelcomeBackBanner(days: daysSinceLastOpen),
                  ],

                  const SizedBox(height: 16),

                  // 2. ACTIVITY HUB: Today's activities, intelligent types, active timer & quick add
                  const _ActivityHubCard(),

                  const SizedBox(height: 16),

                  // 3. LEARNING HUB: Multi-course hero, course switcher, progress & resume
                  const _LearningHubCard(),

                  const SizedBox(height: 16),

                  // 4. QUICK LIFE MODULES (Transparent Bordered Hub linking to dedicated screens)
                  const _QuickModulesNavHub(),

                  const SizedBox(height: 16),

                  // 5. Collapsible Secondary Section (Notes & Reminders)
                  const _CollapsibleSecondarySection(
                    notesCard: _NotesPreviewCard(),
                    remindersCard: _RemindersPreviewCard(),
                  ),

                  const SizedBox(height: 18),

                  // 6. Positivity line
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

// ---------------------------------------------------------------------------
// Floating AI Gateway: 'Riya se Baat'
// ---------------------------------------------------------------------------

class _RiyaSeBaatFloatingButton extends StatelessWidget {
  const _RiyaSeBaatFloatingButton();

  @override
  Widget build(BuildContext context) {
    final accent = context.accentPrimary;
    final isDark = context.isDark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.35 : 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/ai-assistant');
          },
          borderRadius: BorderRadius.circular(28),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1E2638).withValues(alpha: 0.95),
                        const Color(0xFF151A28).withValues(alpha: 0.95),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.96),
                        const Color(0xFFF8FAFC).withValues(alpha: 0.96),
                      ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: accent.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Riya se Baat',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 11,
                  color: context.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Quick Life Modules Hub (Transparent Bordered Navigation Cards)
// ---------------------------------------------------------------------------

class _QuickModulesNavHub extends ConsumerWidget {
  const _QuickModulesNavHub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Water
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterPercent = waterGoal > 0 ? ((waterMl / waterGoal) * 100).toInt() : 0;

    // 2. Walk
    final walkState = ref.watch(walkTrackingProvider);
    final todayWalkMeters = ref.watch(todayWalkDistanceStreamProvider).value ?? 0.0;
    final isWalkActive = walkState.status == WalkTrackingStatus.tracking;
    final walkSubtitle = isWalkActive
        ? 'Active · ${(walkState.distanceKm).toStringAsFixed(2)} km'
        : todayWalkMeters > 0
            ? '${(todayWalkMeters / 1000.0).toStringAsFixed(2)} km walked today'
            : 'Goal 5.0 km · Tap to start';

    // 3. Money
    final todaySpending = ref.watch(todaySpendingStreamProvider).value ?? 0.0;
    final budget = ref.watch(overallBudgetStreamProvider).value;
    final moneySubtitle = budget != null && budget.monthlyLimit > 0
        ? '₹${todaySpending.toStringAsFixed(0)} today · Limit ₹${budget.monthlyLimit.toStringAsFixed(0)}'
        : '₹${todaySpending.toStringAsFixed(0)} logged today';

    // 4. Habits
    final allHabits = ref.watch(allHabitsStreamProvider).value ?? [];
    final doneHabitIds = ref.watch(todayCompletedHabitIdsStreamProvider).value ?? {};
    final habitSubtitle = allHabits.isEmpty
        ? 'Daily routines & streaks'
        : '${doneHabitIds.length}/${allHabits.length} completed today';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIFE MODULES',
              style: AscentTextStyles.labelSmall.copyWith(
                color: context.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Tap to open section',
              style: AscentTextStyles.captionMedium.copyWith(color: context.textMuted, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            // 1. Hydration
            _NavHubCard(
              title: 'Hydration',
              subtitle: '$waterMl / $waterGoal mL ($waterPercent%)',
              icon: Icons.water_drop_rounded,
              color: const Color(0xFF38BDF8),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/hydration');
              },
            ),
            // 2. Walk & Activity
            _NavHubCard(
              title: 'Walk & Run',
              subtitle: walkSubtitle,
              icon: Icons.directions_walk_rounded,
              color: isWalkActive ? const Color(0xFF22C55E) : const Color(0xFF10B981),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/walk');
              },
            ),
            // 3. Money & Budget
            _NavHubCard(
              title: 'Money',
              subtitle: moneySubtitle,
              icon: Icons.account_balance_wallet_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/money');
              },
            ),
            // 4. Daily Habits
            _NavHubCard(
              title: 'Habits',
              subtitle: habitSubtitle,
              icon: Icons.fact_check_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/habits');
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _NavHubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _NavHubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.divider.withValues(alpha: 0.6),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 16, color: color),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: context.textMuted.withValues(alpha: 0.6)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AscentTextStyles.captionMedium.copyWith(
                      color: context.textMuted,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Header with Day/Night toggle and Settings avatar
// ---------------------------------------------------------------------------

class _HomeHeader extends ConsumerWidget {
  final UserProfile? profile;

  const _HomeHeader({required this.profile});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';
    final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Software Engineer';
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting()}, $name',
                style: GoogleFonts.plusJakartaSans(
                  color: context.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$dateStr · $role',
                style: AscentTextStyles.bodySmall.copyWith(
                  color: context.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Day / Night Toggle button
            IconButton(
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 21,
                color: isDark ? const Color(0xFFFBBF24) : context.textSecondary,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(themeModeProvider.notifier).setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                );
              },
            ),
            const SizedBox(width: 4),
            // Settings / Profile avatar
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/settings');
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.bgSurfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.divider, width: 0.8),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
                    style: GoogleFonts.plusJakartaSans(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 1b. Top Reminder Alert Banner (Prominent upcoming reminder indication)
// ---------------------------------------------------------------------------

class _TopReminderAlertBanner extends ConsumerWidget {
  const _TopReminderAlertBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextReminderAsync = ref.watch(nextUpcomingReminderProvider);
    final reminder = nextReminderAsync.value;

    if (reminder == null) return const SizedBox.shrink();

    final dueTime = DateFormat('h:mm a').format(reminder.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: context.accentSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.accentSecondary.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/reminders');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.accentSecondary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: context.accentSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'UPCOMING REMINDER',
                            style: AscentTextStyles.captionMedium.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: context.accentSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· $dueTime',
                            style: AscentTextStyles.captionMedium.copyWith(
                              fontSize: 10.5,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reminder.title,
                        style: AscentTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: context.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Cold Start Welcome Back Banner
// ---------------------------------------------------------------------------

class _WelcomeBackBanner extends ConsumerWidget {
  final int days;
  const _WelcomeBackBanner({required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.accentSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.accentSecondary.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_outlined, color: context.accentSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back! You were away $days days.',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Consistency starts with one focused block. Let\'s build momentum today!',
                  style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Activity Hub (Hero Card with In-Card Focus Banner)
// ---------------------------------------------------------------------------

class _ActivityHubCard extends ConsumerStatefulWidget {
  const _ActivityHubCard();

  @override
  ConsumerState<_ActivityHubCard> createState() => _ActivityHubCardState();
}

class _ActivityHubCardState extends ConsumerState<_ActivityHubCard> {
  int _selectedTabIndex = 0; // 0: Up Next, 1: Completed, 2: All

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(todayActivitiesProvider);
    final trackingState = ref.watch(timeTrackingProvider);
    final trackingNotifier = ref.read(timeTrackingProvider.notifier);

    return activitiesAsync.when(
      loading: () => SkeletonShimmer.card(height: 180),
      error: (err, _) => AscentCard(child: Text('Error loading activities: $err')),
      data: (activities) {
        final doneActivities = activities.where((a) => a.status == TodayActivityStatus.done).toList();
        final pendingActivities = activities.where((a) => a.status != TodayActivityStatus.done).toList();
        final doneCount = doneActivities.length;

        List<TodayActivityItem> filteredList;
        if (_selectedTabIndex == 0) {
          filteredList = pendingActivities;
        } else if (_selectedTabIndex == 1) {
          filteredList = doneActivities;
        } else {
          filteredList = activities;
        }

        final activeSession = trackingState.activeSession;
        final hasActiveSession = activeSession != null;

        return AscentCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Activity Hub',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.bgBase,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.divider, width: 0.8),
                        ),
                        child: Text(
                          '$doneCount/${activities.length} Done',
                          style: GoogleFonts.jetBrainsMono(
                            color: context.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => context.push('/today'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View board ›',
                        style: TextStyle(
                          color: context.accentSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Active Focus Banner
              if (hasActiveSession) ...[
                InkWell(
                  onTap: () => context.push('/focus'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: trackingState.isRunning
                          ? context.accentSecondary.withValues(alpha: 0.08)
                          : context.bgBase,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: trackingState.isRunning
                            ? context.accentSecondary.withValues(alpha: 0.3)
                            : context.divider,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: trackingState.isRunning
                                          ? context.accentSecondary
                                          : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    trackingState.isRunning ? 'FOCUSING NOW' : 'FOCUS PAUSED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: trackingState.isRunning
                                          ? context.accentSecondary
                                          : Colors.orange,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeSession.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          trackingState.formattedTime,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: trackingState.isRunning
                                ? context.accentSecondary
                                : context.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            trackingState.isRunning ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                            size: 26,
                            color: context.accentSecondary,
                          ),
                          onPressed: () {
                            if (trackingState.isRunning) {
                              trackingNotifier.pauseSession();
                            } else {
                              trackingNotifier.resumeSession();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Filter Tabs (Up Next / Completed / All)
              Row(
                children: [
                  _ActivityTabChip(
                    label: 'Up Next',
                    count: pendingActivities.length,
                    isSelected: _selectedTabIndex == 0,
                    onTap: () => setState(() => _selectedTabIndex = 0),
                  ),
                  const SizedBox(width: 6),
                  _ActivityTabChip(
                    label: 'Completed',
                    count: doneCount,
                    isSelected: _selectedTabIndex == 1,
                    onTap: () => setState(() => _selectedTabIndex = 1),
                  ),
                  const SizedBox(width: 6),
                  _ActivityTabChip(
                    label: 'All',
                    count: activities.length,
                    isSelected: _selectedTabIndex == 2,
                    onTap: () => setState(() => _selectedTabIndex = 2),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filtered activities list
              if (filteredList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.checklist_rounded, size: 24, color: context.textMuted),
                        const SizedBox(height: 6),
                        Text(
                          'No activities in this view',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap "+ Add activity" below to queue your next task.',
                          style: TextStyle(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredList.map((act) => _ActivityRowItem(activity: act)),

              Divider(height: 1, color: context.divider, thickness: 0.8),

              // Add activity button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  AddActivitySheet.show(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: context.accentSecondary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 13, color: context.accentSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add activity',
                        style: TextStyle(
                          color: context.accentSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Swipe left to delete',
                        style: TextStyle(fontSize: 10, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityTabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityTabChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentSecondary.withValues(alpha: 0.12)
              : context.bgBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.accentSecondary.withValues(alpha: 0.35)
                : context.divider,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? context.accentSecondary : context.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? context.accentSecondary : context.divider,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : context.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRowItem extends ConsumerWidget {
  final TodayActivityItem activity;

  const _ActivityRowItem({required this.activity});

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = activity.status == TodayActivityStatus.done;
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;

    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        await deleteTodayActivity(ref, activity);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Activity "${activity.title}" deleted'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          color: context.stateDanger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.delete_outline_rounded, color: context.stateDanger, size: 20),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            // 1. Completion Checkbox (or duration indicator)
            if (activity.kind == ActivityKind.todo)
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (activity.linkedTaskId != null) {
                    await ref.read(taskDaoProvider).toggleTaskCompletion(
                          activity.linkedTaskId!,
                          !isDone,
                        );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isDone ? context.accentSecondary : context.divider,
                    size: 22,
                  ),
                ),
              )
            else
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (activity.linkedTaskId != null) {
                    await ref.read(taskDaoProvider).toggleTaskCompletion(
                          activity.linkedTaskId!,
                          !isDone,
                        );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : (activity.kind == ActivityKind.duration
                            ? Icons.timer_outlined
                            : Icons.all_inclusive_rounded),
                    color: isDone
                        ? context.accentSecondary
                        : (isRunning ? context.accentSecondary : context.textMuted),
                    size: 22,
                  ),
                ),
              ),

            const SizedBox(width: 8),

            // 2. Activity Info (Title, Subtitle/Duration/Tags)
            Expanded(
              child: InkWell(
                onLongPress: () async {
                  HapticFeedback.lightImpact();
                  Task? task;
                  if (activity.linkedTaskId != null) {
                    task = await ref.read(taskDaoProvider).getTaskById(activity.linkedTaskId!);
                  }
                  if (context.mounted) {
                    AddActivitySheet.show(
                      context,
                      existingTask: task,
                      initialTitle: activity.title,
                      initialKind: activity.kind,
                      initialDurationMinutes: activity.targetMinutes,
                    );
                  }
                },
                onTap: () async {
                  if (activity.kind == ActivityKind.todo) {
                    // Open task editor
                    Task? task;
                    if (activity.linkedTaskId != null) {
                      task = await ref.read(taskDaoProvider).getTaskById(activity.linkedTaskId!);
                    }
                    if (context.mounted) {
                      AddActivitySheet.show(
                        context,
                        existingTask: task,
                        initialTitle: activity.title,
                        initialKind: activity.kind,
                        initialDurationMinutes: activity.targetMinutes,
                      );
                    }
                  } else {
                    // Duration or flexible: start or open focus
                    await ref.read(timeTrackingProvider.notifier).switchToTask(
                          title: activity.title,
                          taskId: activity.linkedTaskId,
                          sourceType: activity.sourceType,
                          autoStart: !isRunning,
                        );
                    if (context.mounted) {
                      context.push('/focus');
                    }
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isDone ? context.textMuted : context.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        // Type Tag / Priority Tag
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: context.bgBase,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            activity.kind == ActivityKind.todo
                                ? (activity.priority != null ? activity.priority!.toUpperCase() : 'TASK')
                                : (activity.kind == ActivityKind.duration
                                    ? '${activity.targetMinutes ?? 30} MIN'
                                    : 'FLEXIBLE'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: activity.priority == 'high'
                                  ? context.stateDanger
                                  : context.textMuted,
                            ),
                          ),
                        ),

                        if (activity.isOverdue) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: context.stateDanger.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'OVERDUE',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: context.stateDanger,
                              ),
                            ),
                          ),
                        ],

                        if (activity.kind == ActivityKind.duration && activity.targetMinutes != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            activity.elapsedSecondsToday > 0
                                ? '${activity.elapsedSecondsToday ~/ 60}m tracked'
                                : '${activity.targetMinutes}m target',
                            style: TextStyle(fontSize: 10, color: context.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),

            IconButton(
              icon: Icon(Icons.edit_outlined, size: 15, color: context.textMuted),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              tooltip: 'Edit activity',
              onPressed: () async {
                HapticFeedback.lightImpact();
                Task? task;
                if (activity.linkedTaskId != null) {
                  task = await ref.read(taskDaoProvider).getTaskById(activity.linkedTaskId!);
                }
                if (context.mounted) {
                  AddActivitySheet.show(
                    context,
                    existingTask: task,
                    initialTitle: activity.title,
                    initialKind: activity.kind,
                    initialDurationMinutes: activity.targetMinutes,
                  );
                }
              },
            ),
            const SizedBox(width: 4),

            // 3. Right Action: Play / Pause / Start for Timed & Flexible; nothing for To-do
            if (activity.kind != ActivityKind.todo)
              InkWell(
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (isRunning) {
                    ref.read(timeTrackingProvider.notifier).pauseSession();
                  } else if (isPaused) {
                    ref.read(timeTrackingProvider.notifier).resumeSession();
                  } else {
                    await ref.read(timeTrackingProvider.notifier).switchToTask(
                          title: activity.title,
                          taskId: activity.linkedTaskId,
                          sourceType: activity.sourceType,
                          autoStart: true,
                        );
                    if (context.mounted) {
                      context.push('/focus');
                    }
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? context.accentSecondary.withValues(alpha: 0.15)
                        : (isPaused
                            ? Colors.orange.withValues(alpha: 0.15)
                            : context.bgBase),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isRunning
                          ? context.accentSecondary.withValues(alpha: 0.4)
                          : context.divider,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isRunning
                            ? Icons.pause_rounded
                            : (isPaused ? Icons.play_arrow_rounded : Icons.play_arrow_rounded),
                        size: 14,
                        color: isRunning
                            ? context.accentSecondary
                            : (isPaused ? Colors.orange : context.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        activity.elapsedSecondsToday > 0
                            ? _formatTime(activity.elapsedSecondsToday)
                            : (activity.kind == ActivityKind.duration ? 'Start' : 'Track'),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isRunning
                              ? context.accentSecondary
                              : (isPaused ? Colors.orange : context.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Learning Hub Card
// ---------------------------------------------------------------------------

class _LearningHubCard extends ConsumerWidget {
  const _LearningHubCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(learningHubProvider);
    final course = state.course;
    final active = state.activeLecture;
    final activeMod = state.activeModule;
    final isLive = state.isPlaying || state.isLiveFocusActive;

    if (isLive) {
      // ── Rich Expanded Active Lecture Container ────────────────────────
      return Container(
        decoration: BoxDecoration(
          color: context.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.accentSecondary.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.accentSecondary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Live Focus Badge & View Hub CTA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/study-plan');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: state.isPlaying ? context.accentSecondary : context.stateWarning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.isPlaying ? 'LIVE LECTURE IN PROGRESS' : 'LECTURE PAUSED',
                          style: GoogleFonts.jetBrainsMono(
                            color: state.isPlaying ? context.accentSecondary : context.stateWarning,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/study-plan');
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.bgBase,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.divider.withValues(alpha: 0.8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Hub',
                            style: GoogleFonts.plusJakartaSans(
                              color: context.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: context.accentSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Course & Module Hierarchy (also tappable to navigate to hub)
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/study-plan');
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${course.title} • ${activeMod.title}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 3),

            // Lecture Title
            Text(
              'Lecture ${active.id}: ${active.title}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: state.progressFraction,
                minHeight: 6,
                backgroundColor: context.bgBase,
                valueColor: AlwaysStoppedAnimation<Color>(context.accentSecondary),
              ),
            ),
            const SizedBox(height: 6),

            // Elapsed / Remaining Time Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${state.formattedElapsed} / ${active.formattedDuration}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: state.isPlaying ? context.accentSecondary : context.textPrimary,
                  ),
                ),
                Text(
                  '${state.formattedRemaining} left (${state.progressPercent}%)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Interactive Controls Row
            Row(
              children: [
                IconButton(
                  tooltip: 'Rewind 15s',
                  icon: const Icon(Icons.replay_10_rounded, size: 20),
                  color: context.textPrimary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(learningHubProvider.notifier).seekBy(-15);
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isPlaying
                          ? context.stateWarning
                          : context.accentPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(
                      state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(
                      state.isPlaying ? 'Pause' : 'Resume Focus',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(learningHubProvider.notifier).togglePlayPause();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Forward 15s',
                  icon: const Icon(Icons.forward_10_rounded, size: 20),
                  color: context.textPrimary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(learningHubProvider.notifier).seekBy(15);
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Open Full Player Sheet',
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  color: context.textMuted,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    LectureFocusPlayerSheet.show(context);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AscentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LEARNING HUB',
                    style: GoogleFonts.jetBrainsMono(
                      color: context.accentSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/study-plan'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '${course.progressPercent}% Done ›',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4 Metric Chips
          Row(
            children: [
              _MetricPill(
                icon: Icons.menu_book_outlined,
                label: '${state.courses.length} Course${state.courses.length == 1 ? "" : "s"}',
              ),
              const SizedBox(width: 6),
              _MetricPill(icon: Icons.folder_outlined, label: '${course.modules.length} Modules'),
              const SizedBox(width: 6),
              _MetricPill(icon: Icons.playlist_play_rounded, label: '${course.completedLectures}/${course.totalLectures} Done'),
              const SizedBox(width: 6),
              _MetricPill(icon: Icons.access_time_outlined, label: '${course.totalWatchedSeconds ~/ 60}m Watched'),
            ],
          ),
          const SizedBox(height: 12),

          // Featured Course Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.bgBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.divider, width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        course.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: context.accentSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      activeMod.title,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Lecture ${active.id} - ${active.title}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Compact Continue/Focus Lecture Button
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.accentSecondary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                        label: Text(
                          'Continue Lecture ${active.id}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref.read(learningHubProvider.notifier).play();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Open Player',
                      icon: const Icon(Icons.open_in_full_rounded, size: 18),
                      color: context.textMuted,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        LectureFocusPlayerSheet.show(context);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        decoration: BoxDecoration(
          color: context.bgBase,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.divider, width: 0.7),
        ),
        child: Column(
          children: [
            Icon(icon, size: 13, color: context.textMuted),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}



// ---------------------------------------------------------------------------
// 5. Notes Preview Card
// ---------------------------------------------------------------------------

class _NotesPreviewCard extends ConsumerWidget {
  const _NotesPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(mostRecentNoteProvider);

    return AscentCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 18, color: context.accentPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Notes & Journal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/notes'),
                child: Text(
                  'View all ›',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          noteAsync.when(
            loading: () => const SizedBox(height: 16),
            error: (_, _) => const SizedBox.shrink(),
            data: (note) {
              return Text(
                note?.title ?? 'Jot down your first reflection or STAR prep notes ›',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Reminders Card
// ---------------------------------------------------------------------------

class _RemindersPreviewCard extends ConsumerWidget {
  const _RemindersPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderAsync = ref.watch(nextUpcomingReminderProvider);

    return AscentCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_none_rounded, size: 18, color: context.accentSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Upcoming Reminders',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/reminders'),
                child: Text(
                  '+ Add',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.accentSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          reminderAsync.when(
            loading: () => const SizedBox(height: 16),
            error: (_, _) => const SizedBox.shrink(),
            data: (reminder) {
              if (reminder == null) {
                return Text(
                  'No upcoming reminders scheduled.',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                );
              }
              final dateStr = DateFormat('EEE, MMM d • h:mm a').format(reminder.scheduledAt);
              return Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${reminder.title} ($dateStr)',
                      style: TextStyle(fontSize: 12, color: context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Positivity Quote Line
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// Loading Shimmer
// ---------------------------------------------------------------------------

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        SkeletonShimmer.card(height: 50),
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



class _CollapsibleSecondarySection extends StatefulWidget {
  final Widget notesCard;
  final Widget remindersCard;

  const _CollapsibleSecondarySection({
    required this.notesCard,
    required this.remindersCard,
  });

  @override
  State<_CollapsibleSecondarySection> createState() => _CollapsibleSecondarySectionState();
}

class _CollapsibleSecondarySectionState extends State<_CollapsibleSecondarySection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider, width: 0.8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: context.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Secondary Tools • Notes & Reminders',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isExpanded ? 'Collapse' : 'Expand (2)',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: context.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: context.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  widget.notesCard,
                  const SizedBox(height: 12),
                  widget.remindersCard,
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


