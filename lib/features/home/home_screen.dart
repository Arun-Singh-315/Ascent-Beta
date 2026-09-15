import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/insight_engine/insight_engine.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../../shared/widgets/insight_strip.dart';
import '../../shared/widgets/new_day_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
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
      // First time launch: register today without interrupting user
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
              },
              color: context.accentPrimary,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // 1. Header (Greeting + Date + Avatar)
                  _HomeHeader(profile: profile),

                  // Return-user cold start welcome-back banner (>3 days absent)
                  if (daysSinceLastOpen >= 3 && daysSinceLastOpen < 999) ...[
                    const SizedBox(height: 12),
                    _WelcomeBackBanner(days: daysSinceLastOpen),
                  ],

                  const SizedBox(height: 16),

                  // 2. Interview Date / Meeting Banner (Persistent with company & countdown chip in Mono, §1)
                  const _InterviewBanner(),

                  const SizedBox(height: 16),

                  // "Plan My Day" chat-style fast capture button (§4)
                  AscentButton.primary(
                    label: 'Plan my day',
                    icon: Icons.chat_bubble_outline_rounded,
                    expanded: true,
                    onPressed: () => PlanMyDaySheet.show(context),
                  ),

                  const SizedBox(height: 16),

                  // 3. Activity Hub (Single largest container, multi-row, live ticking, §2)
                  const _ActivityHubCard(),

                  const SizedBox(height: 16),

                  // 4. Consistency Check-in (Present/Absent + Streak in Mono)
                  const _ConsistencyCheckInCard(),

                  const SizedBox(height: 16),

                  // Quick Action Shortcuts
                  const _QuickActionsRow(),

                  const SizedBox(height: 16),

                  // 5. Quick Stats Strip (DSA this week · Active applications · Hours this week)
                  const _QuickStatsStrip(),

                  const SizedBox(height: 18),

                  // 6. Positivity / Intelligence line
                  _HomePositivityLine(profile: profile),

                  const SizedBox(height: 24),
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
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Friend';
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
                style: AscentTextStyles.displaySmall.copyWith(
                  color: context.textPrimary,
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
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => context.push('/settings'),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: context.accentPrimary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: context.accentPrimary.withValues(alpha: 0.3),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
                style: AscentTextStyles.labelLarge.copyWith(
                  color: context.accentPrimary,
                  fontWeight: FontWeight.w700,
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

class _WelcomeBackBanner extends StatelessWidget {
  final int days;

  const _WelcomeBackBanner({required this.days});

  @override
  Widget build(BuildContext context) {
    return AscentCard(
      color: context.accentSecondary.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.waving_hand_rounded, color: context.accentSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Welcome back! It has been $days days. Ready to restart your streak today?',
              style: AscentTextStyles.bodySmall.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Interview Date / Meeting Banner (§1)
// ---------------------------------------------------------------------------

class _InterviewBanner extends ConsumerWidget {
  const _InterviewBanner();

  void _showAddModal(BuildContext context, WidgetRef ref, int? profileId) {
    final companyController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            decoration: BoxDecoration(
              color: ctx.bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Set Target Interview Deadline',
                  style: AscentTextStyles.displaySmall.copyWith(color: ctx.textPrimary, fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: companyController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Company / Organization',
                    hintText: 'e.g., Google, Stripe, Meta',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_month_rounded, color: ctx.accentPrimary),
                  title: Text(
                    DateFormat('EEEE, MMMM d, y').format(selectedDate),
                    style: AscentTextStyles.labelLarge.copyWith(color: ctx.textPrimary),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: const Text('Change'),
                  ),
                ),
                const SizedBox(height: 16),
                AscentButton.primary(
                  label: 'Save Deadline',
                  onPressed: () async {
                    final company = companyController.text.trim();
                    if (company.isEmpty) return;

                    final interviewDao = ref.read(upcomingInterviewDaoProvider);
                    await interviewDao.insertInterview(
                      UpcomingInterviewTableCompanion.insert(
                        companyName: company,
                        interviewDate: selectedDate,
                      ),
                    );

                    final profileDao = ref.read(userProfileDaoProvider);
                    if (profileId != null) {
                      await profileDao.upsertProfile(
                        UserProfileTableCompanion(
                          id: drift.Value(profileId),
                          interviewDate: drift.Value(selectedDate),
                        ),
                      );
                    }
                    ref.invalidate(userProfileStreamProvider);
                    ref.invalidate(nextUpcomingInterviewProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDetailModal(BuildContext context, WidgetRef ref, UpcomingInterview interview, int? profileId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: ctx.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Interview with ${interview.companyName}',
              style: AscentTextStyles.displaySmall.copyWith(color: ctx.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              DateFormat('EEEE, MMMM d, y').format(interview.interviewDate),
              style: AscentTextStyles.bodyMedium.copyWith(color: ctx.textMuted),
            ),
            const SizedBox(height: 24),
            AscentButton.secondary(
              label: 'Edit Interview Details',
              icon: Icons.edit_outlined,
              expanded: true,
              onPressed: () {
                Navigator.pop(ctx);
                _showEditModal(context, ref, interview, profileId);
              },
            ),
            const SizedBox(height: 10),
            AscentButton.destructive(
              label: 'Clear Deadline',
              expanded: true,
              onPressed: () async {
                final interviewDao = ref.read(upcomingInterviewDaoProvider);
                await interviewDao.deleteInterview(interview.id);

                final profileDao = ref.read(userProfileDaoProvider);
                if (profileId != null) {
                  await profileDao.upsertProfile(
                    UserProfileTableCompanion(
                      id: drift.Value(profileId),
                      interviewDate: const drift.Value(null),
                    ),
                  );
                }
                ref.invalidate(userProfileStreamProvider);
                ref.invalidate(nextUpcomingInterviewProvider);
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditModal(BuildContext context, WidgetRef ref, UpcomingInterview interview, int? profileId) {
    final companyController = TextEditingController(text: interview.companyName);
    DateTime selectedDate = interview.interviewDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Container(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
            decoration: BoxDecoration(
              color: ctx.bgSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ctx.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Edit Interview Deadline',
                  style: AscentTextStyles.displaySmall.copyWith(color: ctx.textPrimary, fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: companyController,
                  decoration: InputDecoration(
                    labelText: 'Company / Organization',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.calendar_month_rounded, color: ctx.accentPrimary),
                  title: Text(
                    DateFormat('EEEE, MMMM d, y').format(selectedDate),
                    style: AscentTextStyles.labelLarge.copyWith(color: ctx.textPrimary),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    child: const Text('Change'),
                  ),
                ),
                const SizedBox(height: 16),
                AscentButton.primary(
                  label: 'Update Deadline',
                  onPressed: () async {
                    final company = companyController.text.trim();
                    if (company.isEmpty) return;

                    final interviewDao = ref.read(upcomingInterviewDaoProvider);
                    await interviewDao.updateInterview(
                      UpcomingInterviewTableCompanion(
                        id: drift.Value(interview.id),
                        companyName: drift.Value(company),
                        interviewDate: drift.Value(selectedDate),
                      ),
                    );

                    final profileDao = ref.read(userProfileDaoProvider);
                    if (profileId != null) {
                      await profileDao.upsertProfile(
                        UserProfileTableCompanion(
                          id: drift.Value(profileId),
                          interviewDate: drift.Value(selectedDate),
                        ),
                      );
                    }
                    ref.invalidate(userProfileStreamProvider);
                    ref.invalidate(nextUpcomingInterviewProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interviewAsync = ref.watch(nextUpcomingInterviewProvider);
    final profileAsync = ref.watch(userProfileStreamProvider);
    final profile = profileAsync.value;

    final upcoming = interviewAsync.value;

    if (upcoming != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(upcoming.interviewDate.year, upcoming.interviewDate.month, upcoming.interviewDate.day);
      final daysLeft = target.difference(today).inDays;

      return AscentCard(
        onTap: () => _showDetailModal(context, ref, upcoming, profile?.id),
        color: context.accentPrimary.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded, color: context.accentPrimary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                  children: [
                    const TextSpan(text: 'Meeting with '),
                    TextSpan(
                      text: upcoming.companyName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' on ${DateFormat('EEEE, MMM d').format(target)}'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.accentPrimary.withValues(alpha: 0.3)),
              ),
              child: Text(
                daysLeft > 0
                    ? '$daysLeft days left'
                    : (daysLeft == 0 ? 'Today' : 'Past'),
                style: GoogleFonts.jetBrainsMono(
                  textStyle: AscentTextStyles.statSmall.copyWith(
                    color: context.accentPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Soft prompt if no date set
    return AscentCard(
      onTap: () => _showAddModal(context, ref, profile?.id),
      color: context.bgSurfaceElevated,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.event_outlined, color: context.accentInfo, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No interview set — tap to add target deadline',
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted, fontSize: 13),
            ),
          ),
          Icon(Icons.add_circle_outline_rounded, color: context.accentInfo, size: 20),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. The Activity Hub Card (§2)
// ---------------------------------------------------------------------------

class _ActivityHubCard extends ConsumerWidget {
  const _ActivityHubCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(todayActivitiesProvider);

    return activitiesAsync.when(
      loading: () => SkeletonShimmer.card(height: 180),
      error: (err, _) => AscentCard(
        child: Text('Error loading activities: $err'),
      ),
      data: (activities) {
        return AscentCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.accentPrimary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ACTIVITY HUB',
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: context.accentPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${activities.length} ${activities.length == 1 ? 'item' : 'items'} today',
                        style: AscentTextStyles.bodySmall.copyWith(
                          color: context.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => context.push('/today'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Row(
                        children: [
                          Text(
                            'View all',
                            style: AscentTextStyles.labelMedium.copyWith(
                              color: context.accentPrimary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 16, color: context.accentPrimary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Activity List or Empty State
              if (activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: context.accentPrimary, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No activities queued yet today',
                              style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap "Plan my day" above to quickly braindump your day.',
                              style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: activities.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      return _ActivityRow(activity: activity);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityRow extends ConsumerWidget {
  final TodayActivityItem activity;

  const _ActivityRow({required this.activity});

  String _formatElapsed(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final h = seconds ~/ 3600;
    if (h > 0) {
      final remM = (seconds % 3600) ~/ 60;
      return '${h}h ${remM}m';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = activity.status == TodayActivityStatus.inProgress;
    final isPaused = activity.status == TodayActivityStatus.paused;
    final isDone = activity.status == TodayActivityStatus.done;

    Widget rowContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isRunning
            ? context.accentPrimary.withValues(alpha: 0.1)
            : (isPaused ? context.accentSecondary.withValues(alpha: 0.06) : context.bgSurfaceElevated),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRunning
              ? context.accentPrimary.withValues(alpha: 0.5)
              : (isPaused ? context.accentSecondary.withValues(alpha: 0.3) : context.divider),
        ),
      ),
      child: Row(
        children: [
          // Leading icon / status indicator
          if (isRunning)
            Icon(Icons.play_circle_fill_rounded, color: context.accentPrimary, size: 22)
          else if (isPaused)
            Icon(Icons.pause_circle_outline_rounded, color: context.accentSecondary, size: 22)
          else if (isDone)
            Icon(Icons.check_circle_rounded, color: context.accentPrimary, size: 22)
          else
            Icon(Icons.radio_button_unchecked_rounded, color: context.textMuted, size: 20),

          const SizedBox(width: 12),

          // Title & Category tag
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  activity.title,
                  style: AscentTextStyles.bodyMedium.copyWith(
                    color: isDone ? context.textMuted : context.textPrimary,
                    fontWeight: isRunning ? FontWeight.w600 : FontWeight.normal,
                    decoration: isDone ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    activity.categoryTag,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: activity.categoryTag == 'High Priority'
                          ? context.stateDanger
                          : context.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Trailing action / status chip
          if (isRunning) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentPrimary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatElapsed(activity.elapsedSecondsToday),
                style: GoogleFonts.jetBrainsMono(
                  textStyle: AscentTextStyles.statSmall.copyWith(
                    color: context.textOnPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ] else if (isPaused) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: context.accentSecondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _formatElapsed(activity.elapsedSecondsToday),
                style: GoogleFonts.jetBrainsMono(
                  textStyle: AscentTextStyles.statSmall.copyWith(
                    color: context.accentSecondary,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Resume ▶',
              style: AscentTextStyles.labelSmall.copyWith(
                color: context.accentSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else if (isDone) ...[
            if (activity.elapsedSecondsToday > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: context.bgBase,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _formatElapsed(activity.elapsedSecondsToday),
                  style: GoogleFonts.jetBrainsMono(
                    textStyle: AscentTextStyles.statSmall.copyWith(
                      color: context.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
          ] else ...[
            // Not started
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_arrow_rounded, size: 14, color: context.accentPrimary),
                  const SizedBox(width: 2),
                  Text(
                    'Start',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.accentPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (isRunning) {
      rowContent = _PulsingRowBorder(child: rowContent);
    }

    return InkWell(
      onTap: () async {
        if (isRunning) {
          context.push('/focus');
        } else if (isPaused || activity.status == TodayActivityStatus.notStarted) {
          await ref.read(timeTrackingProvider.notifier).switchToTask(
                title: activity.title,
                taskId: activity.linkedTaskId,
                sourceType: activity.sourceType,
              );
          if (context.mounted) {
            context.push('/focus');
          }
        } else {
          context.push('/focus');
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: rowContent,
    );
  }
}

class _PulsingRowBorder extends StatefulWidget {
  final Widget child;

  const _PulsingRowBorder({required this.child});

  @override
  State<_PulsingRowBorder> createState() => _PulsingRowBorderState();
}

class _PulsingRowBorderState extends State<_PulsingRowBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: context.accentPrimary.withValues(alpha: 0.25 * _animation.value),
                blurRadius: 8 * _animation.value,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Today's Focus & Consistency Card (§6)
// ---------------------------------------------------------------------------

class _ConsistencyCheckInCard extends ConsumerWidget {
  const _ConsistencyCheckInCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(currentStreakStreamProvider);
    final streak = streakAsync.value ?? 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionsAsync = ref.watch(todayTimeSessionsProvider(today));
    final sessions = sessionsAsync.value ?? [];

    int studySeconds = 0;
    int breakSeconds = 0;

    for (final s in sessions) {
      final duration = TimeSessionDao.computeActiveDurationSeconds(
        s.startedAt,
        s.endedAt ?? (s.status == 'running' ? DateTime.now() : s.startedAt),
        s.pausedIntervals,
      );
      if (s.activityType.toLowerCase() == 'entertainment') {
        breakSeconds += duration;
      } else {
        studySeconds += duration;
      }
    }

    final studyMinutes = studySeconds ~/ 60;
    final breakMinutes = breakSeconds ~/ 60;

    return AscentCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: streak > 0 ? context.accentSecondary : context.textMuted,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$streak',
                    style: AscentTextStyles.statLarge.copyWith(
                      color: streak > 0 ? context.accentSecondary : context.textMuted,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    streak == 1 ? 'day streak' : 'days streak',
                    style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/consistency'),
                child: Text(
                  'Heatmap →',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Today's Focus Breakdown: Study vs Entertainment
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.accentPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.accentPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.school_rounded, size: 16, color: context.accentPrimaryBright),
                          const SizedBox(width: 6),
                          Text(
                            'Study Time',
                            style: AscentTextStyles.labelSmall.copyWith(color: context.accentPrimaryBright),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        studyMinutes >= 60
                            ? '${(studyMinutes / 60).toStringAsFixed(1)} hrs'
                            : '$studyMinutes mins',
                        style: AscentTextStyles.statMedium.copyWith(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.accentSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.accentSecondary.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sports_esports_rounded, size: 16, color: context.accentSecondaryBright),
                          const SizedBox(width: 6),
                          Text(
                            'Break Time',
                            style: AscentTextStyles.labelSmall.copyWith(color: context.accentSecondaryBright),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        breakMinutes >= 60
                            ? '${(breakMinutes / 60).toStringAsFixed(1)} hrs'
                            : '$breakMinutes mins',
                        style: AscentTextStyles.statMedium.copyWith(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick Action Shortcuts Row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends ConsumerWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.timer_rounded,
            label: 'Focus',
            color: context.accentPrimaryBright,
            onTap: () => context.push('/focus'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.code_rounded,
            label: 'DSA Log',
            color: context.accentPrimary,
            onTap: () => context.push('/dsa'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.business_center_rounded,
            label: 'Pipeline',
            color: context.accentInfo,
            onTap: () => context.push('/pipeline'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_task_rounded,
            label: 'New Task',
            color: context.accentSecondary,
            onTap: () => context.push('/today'),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.edit_note_rounded,
            label: 'Notes',
            color: context.textPrimary,
            onTap: () => context.push('/notes'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: context.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.divider),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: AscentTextStyles.bodySmall.copyWith(
                fontSize: 10,
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
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
// 5. Quick Stats Strip (3 Numbers)
// ---------------------------------------------------------------------------

class _QuickStatsStrip extends ConsumerWidget {
  const _QuickStatsStrip();

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
              child: _StatBlock(
                label: 'DSA Solved',
                subtitle: 'this week',
                value: '${stats.dsaSolvedThisWeek}',
                onTap: () => context.push('/dsa'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBlock(
                label: 'Applications',
                subtitle: 'in pipeline',
                value: '${stats.activeApplications}',
                onTap: () => context.push('/pipeline'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatBlock(
                label: 'Hours Logged',
                subtitle: 'this week',
                value: stats.hoursThisWeek.toStringAsFixed(1),
                onTap: () => context.push('/analytics'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  const _StatBlock({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AscentCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AscentTextStyles.statMedium.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AscentTextStyles.labelSmall.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Positivity Line
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
        SkeletonShimmer.card(height: 70),
        const SizedBox(height: 16),
        SkeletonShimmer.card(height: 140),
        const SizedBox(height: 16),
        SkeletonShimmer.card(height: 110),
        const SizedBox(height: 16),
        const StatsStripSkeleton(),
      ],
    );
  }
}


