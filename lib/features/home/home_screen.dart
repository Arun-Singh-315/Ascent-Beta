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
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../study_plan/lecture_focus_player_sheet.dart';
import '../today/task_board_screen.dart';
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

                  // Return-user cold start welcome-back banner (>3 days absent)
                  if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                    const SizedBox(height: 12),
                    _WelcomeBackBanner(days: daysSinceLastOpen),
                  ],

                  const SizedBox(height: 16),

                  // 2. PRIMARY HERO: Learning Hub Card (37 Lectures, Module Progress & Resume)
                  const _LearningHubCard(),

                  const SizedBox(height: 16),

                  // 3. TODAY'S PRIORITY & FOCUS TASK
                  const _TodayPriorityCard(),

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
// Today's Priority Focus Card
// ---------------------------------------------------------------------------

class _TodayPriorityCard extends ConsumerWidget {
  const _TodayPriorityCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusTaskAsync = ref.watch(todayFocusTaskProvider);
    final streakAsync = ref.watch(currentStreakStreamProvider);
    final streak = streakAsync.value ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.divider.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_rounded, size: 16, color: context.accentPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'TODAY\'S PRIORITY',
                    style: GoogleFonts.jetBrainsMono(
                      color: context.accentPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              if (streak > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          focusTaskAsync.when(
            loading: () => SkeletonShimmer(height: 44, radius: 10),
            error: (_, _) => const SizedBox.shrink(),
            data: (task) {
              if (task == null) {
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'No priority task set for today',
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Plan your day or pick a study milestone',
                            style: AscentTextStyles.captionMedium.copyWith(color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    AscentButton.secondary(
                      label: 'Tasks',
                      icon: Icons.checklist_rounded,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/today');
                      },
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AscentTextStyles.bodyLarge.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          task.priority.toUpperCase(),
                          style: AscentTextStyles.monoCode.copyWith(
                            fontSize: 10,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.accentPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.timer_outlined, size: 16),
                    label: const Text('Focus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      context.push('/focus');
                    },
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
// Quick Life Modules Hub (Transparent Bordered Navigation Cards)
// ---------------------------------------------------------------------------

class _QuickModulesNavHub extends ConsumerWidget {
  const _QuickModulesNavHub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final expenses = ref.watch(todaySpendingStreamProvider).value ?? 0.0;

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
              subtitle: '$waterMl / $waterGoal mL',
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
              subtitle: 'Active GPS tracker',
              icon: Icons.directions_walk_rounded,
              color: const Color(0xFF10B981),
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/walk');
              },
            ),
            // 3. Money & Budget
            _NavHubCard(
              title: 'Money',
              subtitle: '₹${expenses.toStringAsFixed(0)} logged today',
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
              subtitle: 'Daily routines & streaks',
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
// 1. Header with Plan Day button
// ---------------------------------------------------------------------------

class _HomeHeader extends StatelessWidget {
  final UserProfile? profile;

  const _HomeHeader({required this.profile});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';
    final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Software Engineer';
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());

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
            // Settings / Profile avatar
            InkWell(
              onTap: () => context.push('/settings'),
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
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: context.bgSurface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => const AddTaskSheet(),
                  );
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

    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) async {
        if (activity.linkedTaskId != null) {
          await ref.read(taskDaoProvider).deleteTask(activity.linkedTaskId!);
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
        child: InkWell(
          onTap: () async {
            await ref.read(timeTrackingProvider.notifier).switchToTask(
              title: activity.title,
              taskId: activity.linkedTaskId,
              sourceType: activity.sourceType,
              autoStart: !isRunning,
            );
            if (context.mounted) {
              context.push('/focus');
            }
          },
          child: Row(
            children: [
              Icon(
                isDone ? Icons.check_circle_outline_rounded : Icons.radio_button_unchecked_rounded,
                color: isDone ? context.accentSecondary : context.divider,
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: isDone ? context.textMuted : context.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: context.bgBase,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Task',
                        style: TextStyle(fontSize: 9.5, color: context.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isRunning ? context.accentSecondary.withValues(alpha: 0.12) : context.bgBase,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  activity.elapsedSecondsToday > 0
                      ? _formatTime(activity.elapsedSecondsToday)
                      : 'Start',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isRunning ? context.accentSecondary : context.textMuted,
                  ),
                ),
              ),
            ],
          ),
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
              _MetricPill(icon: Icons.menu_book_outlined, label: '1 Course'),
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
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

                // Compact Continue Lecture Button
                AscentButton.primary(
                  label: 'Continue Lecture ${active.id}',
                  icon: Icons.play_circle_outline_rounded,
                  compact: true,
                  onPressed: () {
                    LectureFocusPlayerSheet.show(context);
                  },
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


