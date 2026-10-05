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
import '../../shared/widgets/new_day_dialog.dart';
import '../study_plan/lecture_focus_player_sheet.dart';
import '../today/task_board_screen.dart';
import 'plan_my_day_sheet.dart';

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
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const _HomeLoadingView(),
          error: (err, stack) => Center(
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
                  // 1. Header (Greeting + Plan Day Coral Button + Avatar)
                  _HomeHeader(profile: profile),

                  // Return-user cold start welcome-back banner (>3 days absent)
                  if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                    const SizedBox(height: 12),
                    _WelcomeBackBanner(days: daysSinceLastOpen),
                  ],

                  const SizedBox(height: 14),

                  // 2. Activity Hub (Hero Card with In-Card Focus Timer & Filter Tabs)
                  const _ActivityHubCard(),

                  const SizedBox(height: 14),

                  // 3. Learning Hub (Spring Boot Mastery, 4 Modules, 37 Lectures, Resume Button)
                  const _LearningHubCard(),

                  const SizedBox(height: 14),

                  // 4. Quick Metrics 2x2 Grid (Streak, Study Time, DSA, Pipeline)
                  const _QuickStats2x2Grid(),

                  const SizedBox(height: 14),

                  // 5. Notes Preview Card
                  const _NotesPreviewCard(),

                  const SizedBox(height: 14),

                  // 6. Reminders Card
                  const _RemindersPreviewCard(),

                  const SizedBox(height: 16),

                  // 7. Positivity line
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
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Arun singh';
    final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Backend Engineer';
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
                  fontSize: 20,
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
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Plan Day coral button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => PlanMyDaySheet.show(context),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE26D5C), // Coral color from video
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE26D5C).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(
                        'Plan Day',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Profile avatar
            InkWell(
              onTap: () => context.push('/settings'),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0ECE4),
                  shape: BoxShape.circle,
                  border: Border.all(color: context.divider.withValues(alpha: 0.6)),
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
                    style: GoogleFonts.plusJakartaSans(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.accentSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.accentSecondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_rounded, color: context.accentSecondary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back! You were away $days days.',
                  style: AscentTextStyles.labelLarge.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Consistency starts with one focused block. Let\'s build momentum today!',
                  style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
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

        return Container(
          decoration: BoxDecoration(
            color: context.bgSurface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: context.divider.withValues(alpha: 0.7)),
          ),
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
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.bgBase,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.divider),
                        ),
                        child: Text(
                          '$doneCount/${activities.length} Done',
                          style: GoogleFonts.jetBrainsMono(
                            color: context.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => context.push('/today'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View board ›',
                        style: TextStyle(
                          color: context.accentSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Active Focus Banner (Inside Activity Hub as in Video 00:00 - 00:04)
              if (hasActiveSession) ...[
                InkWell(
                  onTap: () => context.push('/focus'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: trackingState.isRunning
                          ? context.accentSecondary.withValues(alpha: 0.08)
                          : context.bgBase,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: trackingState.isRunning
                            ? context.accentSecondary.withValues(alpha: 0.3)
                            : context.divider,
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
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: trackingState.isRunning
                                          ? context.accentSecondary
                                          : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    trackingState.isRunning ? 'FOCUSING NOW' : 'FOCUS PAUSED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: trackingState.isRunning
                                          ? context.accentSecondary
                                          : Colors.orange,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeSession.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
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
                            fontSize: 15,
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
                            trackingState.isRunning ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                            size: 28,
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
                  const SizedBox(width: 8),
                  _ActivityTabChip(
                    label: 'Completed',
                    count: doneCount,
                    isSelected: _selectedTabIndex == 1,
                    onTap: () => setState(() => _selectedTabIndex = 1),
                  ),
                  const SizedBox(width: 8),
                  _ActivityTabChip(
                    label: 'All',
                    count: activities.length,
                    isSelected: _selectedTabIndex == 2,
                    onTap: () => setState(() => _selectedTabIndex = 2),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Filtered activities list
              if (filteredList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.flash_on_rounded, size: 28, color: Colors.orange),
                        const SizedBox(height: 6),
                        Text(
                          'No activities queued for today',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap "Add activity" below to plan your next block.',
                          style: TextStyle(fontSize: 11.5, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredList.map((act) => _ActivityRowItem(activity: act)),

              const Divider(height: 1, color: Color(0xFFF1EFEA)),

              // Add activity button
              InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: context.bgSurface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (ctx) => const AddTaskSheet(),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: context.accentSecondary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 14, color: context.accentSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add activity',
                        style: TextStyle(
                          color: context.accentSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Swipe to delete',
                        style: TextStyle(fontSize: 10.5, color: context.textMuted),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentSecondary.withValues(alpha: 0.15)
              : context.bgBase,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: context.accentSecondary.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? context.accentSecondary : context.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? context.accentSecondary : context.divider,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
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
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
                isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: isDone ? context.accentSecondary : context.divider,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDone ? context.textMuted : context.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: context.bgBase,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Task',
                        style: TextStyle(fontSize: 10, color: context.textMuted),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                activity.elapsedSecondsToday > 0
                    ? _formatTime(activity.elapsedSecondsToday)
                    : 'Start',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isRunning ? context.accentSecondary : context.textMuted,
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
// 3. Learning Hub Card (Directly from Video 00:00 - 00:04, 00:35 - 00:38)
// ---------------------------------------------------------------------------

class _LearningHubCard extends ConsumerWidget {
  const _LearningHubCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(learningHubProvider);
    final course = state.course;
    final active = state.activeLecture;
    final activeMod = state.activeModule;

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: context.divider.withValues(alpha: 0.7)),
      ),
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
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'LEARNING HUB',
                    style: GoogleFonts.jetBrainsMono(
                      color: context.accentSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/study-plan'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '${course.progressPercent}% Done ›',
                    style: TextStyle(
                      color: context.textMuted,
                      fontSize: 12,
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
              _MetricPill(icon: Icons.menu_book_rounded, label: '1 Courses'),
              const SizedBox(width: 6),
              _MetricPill(icon: Icons.folder_outlined, label: '${course.modules.length} Modules'),
              const SizedBox(width: 6),
              _MetricPill(icon: Icons.playlist_play_rounded, label: '${course.completedLectures}/${course.totalLectures} Lectures'),
              const SizedBox(width: 6),
              _MetricPill(icon: Icons.access_time_rounded, label: '${course.totalWatchedSeconds ~/ 60}m Watched'),
            ],
          ),
          const SizedBox(height: 14),

          // Featured Course Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.bgBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.divider.withValues(alpha: 0.8)),
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
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Lecture ${active.id} - ${active.title}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Coral Button: Continue Lecture
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE26D5C), // Coral matching video
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      LectureFocusPlayerSheet.show(context);
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 20),
                    label: Text(
                      'Continue Lecture ${active.id}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
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
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: context.bgBase,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.divider.withValues(alpha: 0.6)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: context.textMuted),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
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
// 4. Quick Stats 2x2 Grid (Streak, Study Time, DSA, Pipeline)
// ---------------------------------------------------------------------------

class _QuickStats2x2Grid extends ConsumerWidget {
  const _QuickStats2x2Grid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(currentStreakStreamProvider);
    final streak = streakAsync.value ?? 1;

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

    return Column(
      children: [
        Row(
          children: [
            // Tile 1: Streak
            Expanded(
              child: _StatCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: Colors.orange,
                pillText: 'ON TRACK',
                pillColor: Colors.orange.withValues(alpha: 0.15),
                pillTextColor: Colors.orange,
                mainValue: '$streak day streak',
                subtitle: 'Consistency momentum',
                onTap: () => context.push('/consistency'),
              ),
            ),
            const SizedBox(width: 12),

            // Tile 2: Study Time
            Expanded(
              child: _StatCard(
                icon: Icons.schedule_rounded,
                iconColor: context.accentSecondary,
                pillText: 'TODAY',
                pillColor: context.bgBase,
                pillTextColor: context.textMuted,
                mainValue: '${studyMinutes}m study time',
                subtitle: 'Target 2.0h / day',
                onTap: () => context.push('/focus'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Tile 3: DSA
            Expanded(
              child: _StatCard(
                icon: Icons.code_rounded,
                iconColor: Colors.purple,
                pillText: 'THIS WEEK',
                pillColor: Colors.purple.withValues(alpha: 0.12),
                pillTextColor: Colors.purple,
                mainValue: '0 DSA solved',
                subtitle: 'Algorithms & patterns',
                onTap: () => context.push('/dsa'),
              ),
            ),
            const SizedBox(width: 12),

            // Tile 4: Active Applications
            Expanded(
              child: _StatCard(
                icon: Icons.work_outline_rounded,
                iconColor: Colors.blue,
                pillText: 'PIPELINE',
                pillColor: Colors.blue.withValues(alpha: 0.12),
                pillTextColor: Colors.blue,
                mainValue: '1 active application',
                subtitle: 'Tap to manage pipeline',
                onTap: () => context.push('/pipeline'),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.bgSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.divider.withValues(alpha: 0.8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: iconColor),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: pillColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pillText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: pillTextColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              mainValue,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: context.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divider.withValues(alpha: 0.8)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Notes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          noteAsync.when(
            loading: () => const SizedBox(height: 20),
            error: (_, _) => const SizedBox.shrink(),
            data: (note) {
              return Text(
                note?.title ?? 'Jot down your first reflection or STAR answer ›',
                style: TextStyle(
                  fontSize: 12.5,
                  color: context.textMuted,
                ),
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

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divider.withValues(alpha: 0.8)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_outlined, size: 19),
                  const SizedBox(width: 6),
                  Text(
                    'Reminders',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.accentSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          reminderAsync.when(
            loading: () => const SizedBox(height: 20),
            error: (_, _) => const SizedBox.shrink(),
            data: (reminder) {
              if (reminder == null) {
                return Text(
                  'No upcoming reminders scheduled.',
                  style: TextStyle(fontSize: 12.5, color: context.textMuted),
                );
              }
              final dateStr = DateFormat('EEE, MMM d • h:mm a').format(reminder.scheduledAt);
              return Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        Text(
                          '$dateStr • notifies you',
                          style: TextStyle(fontSize: 11, color: context.textMuted),
                        ),
                      ],
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
            fontSize: 12.5,
            fontStyle: FontStyle.italic,
            color: const Color(0xFFC07361), // Subdued terracotta
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
        SkeletonShimmer.card(height: 60),
        const SizedBox(height: 14),
        SkeletonShimmer.card(height: 180),
        const SizedBox(height: 14),
        SkeletonShimmer.card(height: 150),
        const SizedBox(height: 14),
        SkeletonShimmer.card(height: 100),
      ],
    );
  }
}
