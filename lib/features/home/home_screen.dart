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
import '../../core/insight_engine/insight_engine.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../../shared/widgets/insight_strip.dart';
import '../../shared/widgets/new_day_dialog.dart';
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
        child: Stack(
          children: [
            profileAsync.when(
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
                      // 1. Header (Greeting + Date + Avatar)
                      _HomeHeader(profile: profile),

                      // Return-user cold start welcome-back banner (>3 days absent)
                      if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                        const SizedBox(height: 12),
                        _WelcomeBackBanner(days: daysSinceLastOpen),
                      ],

                      const SizedBox(height: 14),

                      // 2. Interview Date Banner
                      const _InterviewBanner(),

                      const SizedBox(height: 14),

                      // 3. Activity Hub (Hero Card)
                      const _ActivityHubCard(),

                      const SizedBox(height: 14),

                      // 4. Streak & Study & Focus (Quad Group - Break removed)
                      const _QuadGroupCard(),

                      const SizedBox(height: 14),

                      // 5. Notes Preview Card
                      const _NotesPreviewCard(),

                      const SizedBox(height: 14),

                      // 6. Reminders Card
                      const _RemindersPreviewCard(),

                      const SizedBox(height: 14),

                      // 7. Insights Strip (DSA, Apps, Hours)
                      const _InsightsRow(),

                      const SizedBox(height: 16),

                      // 8. Positivity line
                      _HomePositivityLine(profile: profile),

                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),

            // Floating "Plan my day" Pill
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => PlanMyDaySheet.show(context),
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.accentPrimary,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: context.accentPrimary.withValues(alpha: 0.38),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Plan my day',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
// 1. Header
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
    final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Job Seeker';
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
                  fontSize: 21,
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
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => context.push('/settings'),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: context.accentPrimary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
                style: GoogleFonts.plusJakartaSans(
                  color: context.accentPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
          ),
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
// 2. Upcoming Interview Banner
// ---------------------------------------------------------------------------

class _InterviewBanner extends ConsumerWidget {
  const _InterviewBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interviewAsync = ref.watch(nextUpcomingInterviewProvider);
    final upcoming = interviewAsync.value;

    if (upcoming != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(upcoming.interviewDate.year, upcoming.interviewDate.month, upcoming.interviewDate.day);
      final daysLeft = target.difference(today).inDays;

      String countdownText;
      if (daysLeft < 0) {
        countdownText = 'Past';
      } else if (daysLeft == 0) {
        countdownText = 'Today';
      } else if (daysLeft == 1) {
        countdownText = 'Tomorrow';
      } else {
        countdownText = '$daysLeft days';
      }

      return InkWell(
        onTap: () => context.push('/interview-prep'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: context.accentPrimary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.accentPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary, fontSize: 13),
                    children: [
                      const TextSpan(text: 'Meeting with '),
                      TextSpan(
                        text: upcoming.companyName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' · ${DateFormat('EEE, MMM d').format(target)}'),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: context.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  countdownText,
                  style: GoogleFonts.jetBrainsMono(
                    color: context.accentPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => context.push('/interview-prep'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.divider.withValues(alpha: 0.6)),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined, color: context.accentPrimary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No upcoming interview — tap to schedule round',
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted, fontSize: 13),
              ),
            ),
            Icon(Icons.add_circle_outline_rounded, color: context.accentPrimary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Activity Hub (Hero Card)
// ---------------------------------------------------------------------------

class _ActivityHubCard extends ConsumerWidget {
  const _ActivityHubCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(todayActivitiesProvider);

    return activitiesAsync.when(
      loading: () => SkeletonShimmer.card(height: 180),
      error: (err, _) => AscentCard(child: Text('Error loading activities: $err')),
      data: (activities) {
        final doneCount = activities.where((a) => a.status == TodayActivityStatus.done).length;

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
            border: Border.all(color: context.divider.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Activity Hub',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.accentSecondary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          activities.isEmpty
                              ? '0 today'
                              : '$doneCount / ${activities.length} done',
                          style: GoogleFonts.jetBrainsMono(
                            color: context.accentSecondary,
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
                        'View all ›',
                        style: TextStyle(
                          color: context.accentPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Activities List
              if (activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: context.accentPrimary, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'No activities queued yet today',
                          style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap below to add your first study block or task.',
                          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...activities.map((act) => _ActivityRowItem(activity: act)),

              // Add activity button row
              const Divider(height: 1, color: Color(0xFFF1EFEA)),
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
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: context.accentPrimary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 14, color: context.accentPrimary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add activity',
                        style: TextStyle(
                          color: context.accentPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Center(
                child: Text(
                  'Tap a task to start · swipe left to delete',
                  style: TextStyle(fontSize: 11, color: context.textMuted),
                ),
              ),
            ],
          ),
        );
      },
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

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Task?'),
        content: Text('Are you sure you want to remove "${activity.title}" from today\'s activities?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDone = activity.status == TodayActivityStatus.done;
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;

    // Ring styling matching mockup
    Widget ringWidget;
    if (isDone) {
      ringWidget = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.accentPrimary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
      );
    } else if (isRunning) {
      ringWidget = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          border: Border.all(color: context.accentSecondary, width: 2),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.pause_rounded, color: context.accentSecondary, size: 20),
      );
    } else {
      ringWidget = Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          border: Border.all(color: context.divider, width: 1.5),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.play_arrow_rounded, color: isPaused ? context.accentSecondary : context.textMuted, size: 20),
      );
    }

    // Category chip styling
    String chipLabel = activity.categoryTag;
    Color chipBg = context.bgBase;
    Color chipFg = context.textMuted;
    if (activity.categoryTag == 'Study') {
      chipBg = context.accentPrimary.withValues(alpha: 0.12);
      chipFg = context.accentPrimary;
    } else if (activity.categoryTag == 'High Priority') {
      chipBg = Colors.redAccent.withValues(alpha: 0.12);
      chipFg = Colors.redAccent;
    } else {
      chipBg = context.accentInfo.withValues(alpha: 0.12);
      chipFg = context.accentInfo;
    }

    // Time label
    Widget timeWidget;
    if (isDone) {
      timeWidget = Text(
        'Done',
        style: TextStyle(
          color: context.accentPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
      );
    } else if (isRunning) {
      timeWidget = Text(
        _formatTime(activity.elapsedSecondsToday),
        style: GoogleFonts.jetBrainsMono(
          color: context.accentSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      );
    } else if (activity.elapsedSecondsToday > 0) {
      timeWidget = Text(
        _formatTime(activity.elapsedSecondsToday),
        style: GoogleFonts.jetBrainsMono(
          color: context.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      );
    } else {
      timeWidget = Text(
        'Start',
        style: TextStyle(
          color: context.accentPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      );
    }

    return Dismissible(
      key: ValueKey(activity.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        final confirmed = await _confirmDelete(context);
        if (confirmed == true && activity.linkedTaskId != null) {
          await ref.read(taskDaoProvider).deleteTask(activity.linkedTaskId!);
          return true;
        }
        return false;
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
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1EFEA), width: 1)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: InkWell(
          onTap: () async {
            if (isRunning) {
              context.push('/focus');
            } else if (isDone) {
              context.push('/focus');
            } else {
              // Switch active task with autoStart = true so it starts running immediately
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
          child: Row(
            children: [
              ringWidget,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDone ? context.textMuted : context.textPrimary,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        chipLabel,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: chipFg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              timeWidget,
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Streak & Study & Focus (Quad Group - Break Removed)
// ---------------------------------------------------------------------------

class _QuadGroupCard extends ConsumerWidget {
  const _QuadGroupCard();

  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

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

    final timeTracking = ref.watch(timeTrackingProvider);
    final isRunning = timeTracking.isRunning;
    final isPaused = timeTracking.isPaused;

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: context.divider.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              // Tile 1: Streak
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/consistency'),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.accentPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🔥 Streak',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.textMuted,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$streak',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 19,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              streak == 1 ? 'day' : 'days',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Tile 2: Study time
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study time',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        studyMinutes >= 60
                            ? '${(studyMinutes / 60).toStringAsFixed(1)} hrs'
                            : '$studyMinutes min',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tile 3: Focus (Dashed peach border, centered)
          CustomPaint(
            painter: _DashedBorderPainter(
              color: context.accentSecondary,
              strokeWidth: 1.5,
              dashWidth: 6,
              dashSpace: 4,
              borderRadius: 14,
            ),
            child: InkWell(
              onTap: () => context.push('/focus'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.bgSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('⏱', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              'Focus',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRunning || isPaused
                              ? _formatElapsed(timeTracking.elapsedSeconds)
                              : 'Idle',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: isRunning || isPaused ? context.accentSecondary : context.textPrimary,
                          ),
                        ),
                        if (timeTracking.activeSession?.label != null) ...[
                          const SizedBox(height: 2),
                          SizedBox(
                            width: 180,
                            child: Text(
                              timeTracking.activeSession!.label,
                              style: TextStyle(fontSize: 11, color: context.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        if (isRunning) {
                          ref.read(timeTrackingProvider.notifier).pauseSession();
                        } else if (isPaused) {
                          ref.read(timeTrackingProvider.notifier).resumeSession();
                        } else {
                          ref.read(timeTrackingProvider.notifier).switchToTask(
                            title: 'Focus Session',
                            autoStart: true,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRunning ? context.textPrimary : context.accentSecondary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: Text(
                        isRunning ? 'Pause' : (isPaused ? 'Resume' : 'Start'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashWidth,
    required this.dashSpace,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = (distance + dashWidth < metric.length) ? dashWidth : metric.length - distance;
        final extract = metric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
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
    final allNotesAsync = ref.watch(notesDaoProvider).watchAllNotes();

    return StreamBuilder<List<Note>>(
      stream: allNotesAsync,
      builder: (context, snap) {
        final totalCount = snap.data?.length ?? 0;
        final note = noteAsync.value;

        return Container(
          decoration: BoxDecoration(
            color: context.bgSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: context.divider.withValues(alpha: 0.6)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notes',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: () => context.push('/notes'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        totalCount > 0 ? '$totalCount ${totalCount == 1 ? 'note' : 'notes'} · View all ›' : 'View all ›',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (note != null) ...[
                InkWell(
                  onTap: () => context.push('/notes'),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                    bottomLeft: Radius.circular(3),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.bgBase,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        topRight: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                        bottomLeft: Radius.circular(3),
                      ),
                      border: Border.all(color: const Color(0xFFECE8E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (note.title != null && note.title!.isNotEmpty) ? note.title! : 'Untitled Note',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (note.content.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            note.content,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM d, h:mm a').format(note.updatedAt),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                InkWell(
                  onTap: () => context.push('/notes'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.edit_note_rounded, size: 20, color: context.accentPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Jot down your first reflection or STAR answer ›',
                          style: TextStyle(fontSize: 12.5, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Reminders Preview Card
// ---------------------------------------------------------------------------

class _RemindersPreviewCard extends ConsumerWidget {
  const _RemindersPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextReminderAsync = ref.watch(nextUpcomingReminderProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: context.divider.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reminders',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              InkWell(
                onTap: () => context.push('/reminders'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '+ Add',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.accentPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          nextReminderAsync.when(
            data: (reminder) {
              if (reminder == null) {
                return InkWell(
                  onTap: () => context.push('/reminders'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_none_rounded, size: 20, color: context.accentSecondary),
                        const SizedBox(width: 8),
                        Text(
                          'No upcoming reminders · Tap to set alert',
                          style: TextStyle(fontSize: 12.5, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final timeStr = DateFormat('EEE, MMM d • h:mm a').format(reminder.scheduledAt);

              return InkWell(
                onTap: () => context.push('/reminders'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.accentInfo.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('🔔', style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reminder.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$timeStr · notifies you',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.accentPrimary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, s) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 7. Insights Strip (3 Stats)
// ---------------------------------------------------------------------------

class _InsightsRow extends ConsumerWidget {
  const _InsightsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(homeQuickStatsProvider);

    return statsAsync.when(
      loading: () => const StatsStripSkeleton(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stats) {
        return Row(
          children: [
            Expanded(
              child: _InsightTile(
                value: '${stats.dsaSolvedThisWeek}',
                label: 'DSA solved',
                onTap: () => context.push('/dsa'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                value: '${stats.activeApplications}',
                label: 'Applications',
                onTap: () => context.push('/pipeline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _InsightTile(
                value: stats.hoursThisWeek.toStringAsFixed(1),
                label: 'Hours logged',
                onTap: () => context.push('/analytics'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;

  const _InsightTile({
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: context.bgSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: context.divider.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: context.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 8. Positivity Line
// ---------------------------------------------------------------------------

class _HomePositivityLine extends StatelessWidget {
  final UserProfile? profile;

  const _HomePositivityLine({this.profile});

  @override
  Widget build(BuildContext context) {
    int? daysToInterview;
    if (profile?.interviewDate != null) {
      daysToInterview = profile!.interviewDate!.difference(DateTime.now()).inDays;
    }

    final message = InsightEngine.getDailyPositivity(
      daysToInterview: daysToInterview,
      targetRole: profile?.targetRole,
    );

    return InsightStrip(
      message: message,
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton Loading View
// ---------------------------------------------------------------------------

class _HomeLoadingView extends StatelessWidget {
  const _HomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SkeletonShimmer.line(width: 180, height: 24),
        const SizedBox(height: 20),
        SkeletonShimmer.card(height: 60),
        const SizedBox(height: 16),
        SkeletonShimmer.card(height: 200),
        const SizedBox(height: 16),
        SkeletonShimmer.card(height: 130),
        const SizedBox(height: 16),
        const StatsStripSkeleton(),
      ],
    );
  }
}
