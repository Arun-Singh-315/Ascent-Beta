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
import 'package:drift/drift.dart' as drift;
import '../../shared/widgets/new_day_dialog.dart';
import '../../shared/widgets/animated_water_card.dart';
import '../thought_wall/thought_wall_home_card.dart';
import '../thought_wall/drop_thought_sheet.dart';
import '../../core/walk/walk_tracking_service.dart';
import '../../shared/widgets/jarvis_copilot_card.dart';
import '../../shared/widgets/jarvis_omnibar.dart';


enum _HomeViewFilter {
  all('All Cockpit', Icons.dashboard_rounded),
  focus('⚡ Focus & Study', Icons.school_rounded),
  wellness('🌿 Wellness & Mind', Icons.spa_rounded);

  final String label;
  final IconData icon;
  const _HomeViewFilter(this.label, this.icon);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeViewFilter _selectedFilter = _HomeViewFilter.all;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    final savedFilter = prefs.getString('home_view_segment');
    if (savedFilter != null) {
      for (final f in _HomeViewFilter.values) {
        if (f.name == savedFilter) {
          _selectedFilter = f;
          break;
        }
      }
    }
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
                ref.invalidate(homeQuickStatsProvider);
                ref.invalidate(nextUpcomingInterviewProvider);
                ref.invalidate(nextUpcomingReminderProvider);
                ref.invalidate(mostRecentNoteProvider);
              },
              color: context.accentPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(left: 18, right: 18, top: 14, bottom: 90),
                children: [
                  // 1. Header (Greeting + Settings Avatar)
                  _HomeHeader(profile: profile),

                  const SizedBox(height: 12),

                  // Universal Riya Omnibar (Natural language 1-step logging & execution)
                  const JarvisOmnibar(),

                  const SizedBox(height: 12),

                  // Smart 1-Tap Quick Action Dock (Water, Chai, Commute, Walk, Focus)
                  const _SmartQuickLogDock(),

                  // Return-user cold start welcome-back banner (>3 days absent)
                  if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                    const SizedBox(height: 12),
                    _WelcomeBackBanner(days: daysSinceLastOpen),
                  ],

                  // Live GPS Walk Status (if active/paused)
                  const _LiveWalkSessionCard(),

                  const SizedBox(height: 14),

                  // Segmented Density Switcher (All | Focus & Study | Wellness & Mind)
                  _HomeSegmentSelector(
                    selected: _selectedFilter,
                    onSelected: (filter) {
                      setState(() => _selectedFilter = filter);
                      ref.read(sharedPreferencesProvider).setString('home_view_segment', filter.name);
                    },
                  ),

                  const SizedBox(height: 14),

                  // Riya AI Companion Card (lightweight — 3 providers, no continuous animation)
                  const JarvisCopilotCard(),

                  const SizedBox(height: 14),

                  // ── Screen Content based on Segment Filter ─────────────────
                  if (_selectedFilter == _HomeViewFilter.wellness) ...[
                    // Animated Fluid Water Hydration Card
                    const AnimatedWaterCard(),

                    const SizedBox(height: 14),

                    // Quick Metrics 2x2 Grid (4 Life Pillars: Study, Money, Walk, Streak)
                    const _QuickStats2x2Grid(),

                    const SizedBox(height: 14),

                    // Daily Habits Strip (Quick checkoffs)
                    const _DailyHabitsHomeCard(),

                    const SizedBox(height: 14),

                    // Mind Space • Thought Wall (Me to Me talk)
                    const ThoughtWallHomeCard(),

                    const SizedBox(height: 18),
                  ] else if (_selectedFilter == _HomeViewFilter.focus) ...[
                    // Activity Hub (Hero Card with In-Card Focus Timer & Filter Tabs)
                    const _ActivityHubCard(),

                    const SizedBox(height: 14),

                    // Learning Hub (Spring Boot Mastery, 4 Modules, 37 Lectures, Resume Button)
                    const _LearningHubCard(),

                    const SizedBox(height: 14),

                    // Quick Metrics 2x2 Grid (4 Life Pillars: Study, Money, Walk, Streak)
                    const _QuickStats2x2Grid(),

                    const SizedBox(height: 14),

                    // Notes Preview Card
                    const _NotesPreviewCard(),

                    const SizedBox(height: 14),

                    // Reminders Card
                    const _RemindersPreviewCard(),

                    const SizedBox(height: 18),
                  ] else ...[
                    // All Cockpit View: Full suite with collapsible secondary tools
                    const AnimatedWaterCard(),

                    const SizedBox(height: 14),

                    const _ActivityHubCard(),

                    const SizedBox(height: 14),

                    const _LearningHubCard(),

                    const SizedBox(height: 14),

                    const _QuickStats2x2Grid(),

                    const SizedBox(height: 14),

                    const _DailyHabitsHomeCard(),

                    const SizedBox(height: 14),

                    const ThoughtWallHomeCard(),

                    const SizedBox(height: 14),

                    // Collapsible Secondary Section (Notes & Reminders)
                    const _CollapsibleSecondarySection(
                      notesCard: _NotesPreviewCard(),
                      remindersCard: _RemindersPreviewCard(),
                    ),

                    const SizedBox(height: 18),
                  ],

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
// 4. Quick Stats 2x2 Grid (4 Pillars: Study, Money, Walk, Streak)
// ---------------------------------------------------------------------------

class _QuickStats2x2Grid extends ConsumerWidget {
  const _QuickStats2x2Grid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(currentStreakStreamProvider);
    final streak = streakAsync.value ?? 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionsAsync = ref.watch(todayTimeSessionsProvider(today));
    final sessions = sessionsAsync.value ?? [];

    int studySeconds = 0;
    for (final s in sessions) {
      if (s.activityType.toLowerCase() == 'entertainment') continue;
      studySeconds += TimeSessionDao.computeActiveDurationSeconds(
        s.startedAt,
        s.endedAt ?? (s.status == 'running' ? DateTime.now() : s.startedAt),
        s.pausedIntervals,
      );
    }
    final studyMinutes = studySeconds ~/ 60;

    final todaySpendAsync = ref.watch(todaySpendingStreamProvider);
    final todaySpend = todaySpendAsync.value ?? 0.0;

    final todayWalkAsync = ref.watch(todayWalkDistanceStreamProvider);
    final walkKm = (todayWalkAsync.value ?? 0.0) / 1000.0;

    return Column(
      children: [
        Row(
          children: [
            // Tile 1: Study Time
            Expanded(
              child: _StatCard(
                icon: Icons.schedule_outlined,
                iconColor: context.accentSecondary,
                pillText: 'STUDY',
                pillColor: context.bgBase,
                pillTextColor: context.textMuted,
                mainValue: '${studyMinutes}m logged',
                subtitle: 'Daily focus timer',
                onTap: () => context.push('/focus'),
              ),
            ),
            const SizedBox(width: 10),

            // Tile 2: Spending / Money
            Expanded(
              child: _StatCard(
                icon: Icons.account_balance_wallet_outlined,
                iconColor: context.accentPrimary,
                pillText: 'FINANCE',
                pillColor: context.accentPrimary.withValues(alpha: 0.1),
                pillTextColor: context.accentPrimary,
                mainValue: '₹${todaySpend.toStringAsFixed(0)} today',
                subtitle: 'Expense & budgets',
                onTap: () => context.push('/money'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Tile 3: Walking Distance
            Expanded(
              child: _StatCard(
                icon: Icons.directions_walk_rounded,
                iconColor: Colors.teal,
                pillText: 'ACTIVITY',
                pillColor: Colors.teal.withValues(alpha: 0.12),
                pillTextColor: Colors.teal,
                mainValue: '${walkKm.toStringAsFixed(1)} km walked',
                subtitle: 'Target 5.0 km',
                onTap: () => context.push('/walk'),
              ),
            ),
            const SizedBox(width: 10),

            // Tile 4: Streak Momentum
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_outlined,
                iconColor: Colors.orange,
                pillText: 'STREAK',
                pillColor: Colors.orange.withValues(alpha: 0.12),
                pillTextColor: Colors.orange,
                mainValue: '$streak day streak',
                subtitle: 'Daily momentum',
                onTap: () => context.push('/consistency'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String pillText;
  final Color pillColor;
  final Color pillTextColor;
  final String mainValue;
  final String subtitle;
  final VoidCallback onTap;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.pillText,
    required this.pillColor,
    required this.pillTextColor,
    required this.mainValue,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AscentCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: iconColor),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  pillText,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: pillTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mainValue,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10.5, color: context.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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

// ---------------------------------------------------------------------------
// 8. Live GPS Walk Session Card (Active / Paused Status)
// ---------------------------------------------------------------------------

class _LiveWalkSessionCard extends ConsumerWidget {
  const _LiveWalkSessionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkState = ref.watch(walkTrackingProvider);
    if (walkState.status == WalkTrackingStatus.idle) {
      return const SizedBox.shrink();
    }

    final isTracking = walkState.status == WalkTrackingStatus.tracking;
    final km = (walkState.distanceMeters / 1000.0).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.accentPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.accentPrimary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTracking ? context.accentPrimary : Colors.orange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isTracking ? 'GPS WALK IN PROGRESS' : 'GPS WALK PAUSED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isTracking ? context.accentPrimary : Colors.orange,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$km km • ${walkState.formattedDuration} active',
                  style: AscentTextStyles.labelMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          AscentButton.outlined(
            label: 'View Map',
            compact: true,
            onPressed: () => context.push('/walk'),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// 10. Daily Habits Home Strip (Quick 1-tap checkoff)
// ---------------------------------------------------------------------------

class _DailyHabitsHomeCard extends ConsumerWidget {
  const _DailyHabitsHomeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(allHabitsStreamProvider);
    final completedIdsAsync = ref.watch(todayCompletedHabitIdsStreamProvider);
    final completedIds = completedIdsAsync.value ?? <int>{};

    final habits = habitsAsync.value ?? [];
    if (habits.isEmpty) return const SizedBox.shrink();

    return AscentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Habits',
                style: AscentTextStyles.headlineMedium.copyWith(
                  color: context.textPrimary,
                  fontSize: 15,
                ),
              ),
              InkWell(
                onTap: () => context.push('/habits'),
                child: Text(
                  'Manage (${completedIds.length}/${habits.length}) →',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: context.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: habits.map((h) {
              final isDone = completedIds.contains(h.id);
              return ActionChip(
                avatar: Icon(
                  isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  size: 16,
                  color: isDone ? Colors.white : context.textMuted,
                ),
                label: Text(h.title),
                backgroundColor: isDone ? context.accentPrimary : context.bgBase,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isDone ? FontWeight.w600 : FontWeight.w500,
                  color: isDone ? Colors.white : context.textPrimary,
                ),
                side: BorderSide(color: isDone ? context.accentPrimary : context.divider),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  await ref.read(habitDaoProvider).toggleHabitToday(h.id);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 11. Smart 1-Tap Quick Action Dock (Zero typing required)
// ---------------------------------------------------------------------------

class _SmartQuickLogDock extends ConsumerWidget {
  const _SmartQuickLogDock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AscentCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 16, color: context.accentPrimary),
              const SizedBox(width: 6),
              Text(
                'SMART 1-TAP LOG',
                style: AscentTextStyles.labelSmall.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: context.accentPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Zero typing required',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickDockChip(
                  label: '+250ml',
                  emoji: '💧',
                  color: const Color(0xFF0096C7),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(waterDaoProvider).addWater(250);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('💧 +250 mL water logged! Keep hydrating.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _QuickDockChip(
                  label: '₹40 Chai',
                  emoji: '☕',
                  color: const Color(0xFFD4A373),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(financeDaoProvider).insertTransaction(
                      FinanceTransactionTableCompanion.insert(
                        title: 'Tea & Snacks',
                        amount: 40.0,
                        category: const drift.Value('Food & Groceries'),
                        account: const drift.Value('UPI'),
                        date: DateTime.now(),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('☕ ₹40 Tea & Snacks saved to expenses!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _QuickDockChip(
                  label: '₹50 Metro',
                  emoji: '🚇',
                  color: const Color(0xFF4A90E2),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(financeDaoProvider).insertTransaction(
                      FinanceTransactionTableCompanion.insert(
                        title: 'Metro / Auto commute',
                        amount: 50.0,
                        category: const drift.Value('Transport'),
                        account: const drift.Value('UPI'),
                        date: DateTime.now(),
                      ),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🚇 ₹50 Metro fare saved to expenses!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                _QuickDockChip(
                  label: 'Start Walk',
                  emoji: '🚶',
                  color: Colors.teal,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/walk');
                  },
                ),
                const SizedBox(width: 8),
                _QuickDockChip(
                  label: '25m Focus',
                  emoji: '⏱',
                  color: context.accentSecondary,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/focus');
                  },
                ),
                const SizedBox(width: 8),
                _QuickDockChip(
                  label: 'AI Plan',
                  emoji: '🤖',
                  color: Colors.purple,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/ai-assistant');
                  },
                ),
                const SizedBox(width: 8),
                _QuickDockChip(
                  label: 'Thought',
                  emoji: '🪞',
                  color: const Color(0xFF8338EC),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    DropThoughtSheet.show(context);
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

class _QuickDockChip extends StatefulWidget {
  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;

  const _QuickDockChip({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  State<_QuickDockChip> createState() => _QuickDockChipState();
}

class _QuickDockChipState extends State<_QuickDockChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AscentTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
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
// Segment Selector & Collapsible Section for Home Screen Density
// ---------------------------------------------------------------------------

class _HomeSegmentSelector extends StatelessWidget {
  final _HomeViewFilter selected;
  final ValueChanged<_HomeViewFilter> onSelected;

  const _HomeSegmentSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider, width: 0.8),
      ),
      child: Row(
        children: _HomeViewFilter.values.map((filter) {
          final isSelected = selected == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(filter);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? context.bgSurface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      filter.icon,
                      size: 14,
                      color: isSelected ? context.accentPrimary : context.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        filter.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? context.textPrimary : context.textMuted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
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


