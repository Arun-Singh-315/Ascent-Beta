import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/ascent_button.dart';

/// Show the executive new-day morning briefing dialog over [context].
/// Displays a frosted glass freeze overlay, yesterday's multi-module debrief (or day 1 kick-off),
/// and comprehensive inputs for today (hydration kick-off, tasks, focus target, mindset).
Future<void> showNewDayDialog(BuildContext context, WidgetRef ref) async {
  HapticFeedback.mediumImpact();
  return showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.5),
    builder: (ctx) => const _NewDayFreezeDialog(),
  );
}

class _NewDayFreezeDialog extends ConsumerStatefulWidget {
  const _NewDayFreezeDialog();

  @override
  ConsumerState<_NewDayFreezeDialog> createState() => _NewDayFreezeDialogState();
}

class _NewDayFreezeDialogState extends ConsumerState<_NewDayFreezeDialog> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Yesterday's metrics
  int _completedTasks = 0;
  List<Task> _carriedOverTasks = [];
  final Set<int> _selectedCarriedOverTaskIds = {};
  int _yesterdayFocusSeconds = 0;
  double _yesterdayWalkMeters = 0.0;
  int _yesterdayWaterMl = 0;
  int _waterGoalMl = 2500;
  int _currentStreak = 0;

  // Today's action inputs
  int _selectedWaterMl = 250;
  int _selectedStudyTargetHours = 4;
  String _selectedMindset = '⚡ Energized';
  final List<TextEditingController> _taskControllers = [TextEditingController()];

  @override
  void initState() {
    super.initState();
    _loadYesterdayMetrics();
  }

  @override
  void dispose() {
    for (final c in _taskControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadYesterdayMetrics() async {
    try {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));

      final taskDao = ref.read(taskDaoProvider);
      final timeSessionDao = ref.read(timeSessionDaoProvider);
      final walkDao = ref.read(walkDaoProvider);
      final waterDao = ref.read(waterDaoProvider);
      final consistencyDao = ref.read(consistencyDaoProvider);

      // 1. Tasks
      final yesterdayTasksFuture = taskDao
          .watchTasksByDate(yesterday)
          .first
          .timeout(const Duration(seconds: 1), onTimeout: () => []);
      final overdueTasksFuture = taskDao
          .watchOverdueTasks()
          .first
          .timeout(const Duration(seconds: 1), onTimeout: () => []);

      // 2. Focus / Study
      final sessionsFuture = timeSessionDao
          .getSessionsForDate(yesterday)
          .timeout(const Duration(seconds: 1), onTimeout: () => []);

      // 3. Walk
      final walkFuture = walkDao
          .getDistanceForDate(yesterday)
          .timeout(const Duration(seconds: 1), onTimeout: () => 0.0);

      // 4. Water
      final waterFuture = waterDao
          .getWaterForDate(yesterday)
          .timeout(const Duration(seconds: 1), onTimeout: () => 0);
      final goalFuture = waterDao
          .watchDailyWaterGoal()
          .first
          .timeout(const Duration(seconds: 1), onTimeout: () => 2500);

      // 5. Streak
      final streakFuture = consistencyDao
          .watchCurrentStreak()
          .first
          .timeout(const Duration(seconds: 1), onTimeout: () => 0);

      final results = await Future.wait([
        yesterdayTasksFuture,
        overdueTasksFuture,
        sessionsFuture,
        walkFuture,
        waterFuture,
        goalFuture,
        streakFuture,
      ]);

      final yesterdayTasks = results[0] as List<Task>;
      final overdueTasks = results[1] as List<Task>;
      final sessions = results[2] as List<TimeSession>;
      final walkMeters = results[3] as double;
      final waterMl = results[4] as int;
      final goalMl = results[5] as int;
      final streak = results[6] as int;

      final completed = yesterdayTasks.where((t) => t.actualCompletedDate != null).length;

      // Uncompleted tasks from yesterday or overdue
      final uncompletedMap = <int, Task>{};
      for (final t in yesterdayTasks.where((t) => t.actualCompletedDate == null)) {
        uncompletedMap[t.id] = t;
      }
      for (final t in overdueTasks) {
        uncompletedMap[t.id] = t;
      }
      final carriedOver = uncompletedMap.values.toList();

      final totalFocus = sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);

      if (mounted) {
        setState(() {
          _completedTasks = completed;
          _carriedOverTasks = carriedOver;
          _selectedCarriedOverTaskIds.addAll(carriedOver.map((t) => t.id));
          _yesterdayFocusSeconds = totalFocus;
          _yesterdayWalkMeters = walkMeters;
          _yesterdayWaterMl = waterMl;
          _waterGoalMl = goalMl > 0 ? goalMl : 2500;
          _currentStreak = streak;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatFocusDuration(int totalSecs) {
    if (totalSecs <= 0) return '0m';
    final hours = totalSecs ~/ 3600;
    final mins = (totalSecs % 3600) ~/ 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  Future<void> _shareDailyBriefing() async {
    HapticFeedback.lightImpact();
    final dateStr = DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());
    final profile = ref.read(userProfileStreamProvider).value;
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';

    final tasksToCommit = _taskControllers
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final carriedOverTitles = _carriedOverTasks
        .where((t) => _selectedCarriedOverTaskIds.contains(t.id))
        .map((t) => t.title)
        .toList();

    final allTasks = [...carriedOverTitles, ...tasksToCommit];

    final buffer = StringBuffer();
    buffer.writeln('🌅 Ascent Daily Briefing · $dateStr');
    buffer.writeln('👤 Operator: $name');
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('📊 YESTERDAY\'S DEBRIEF:');
    buffer.writeln('• Tasks: $_completedTasks Completed (${_carriedOverTasks.length} carried over)');
    buffer.writeln('• Focus / Study: ${_formatFocusDuration(_yesterdayFocusSeconds)}');
    buffer.writeln(
      '• Walk & Movement: ${(_yesterdayWalkMeters / 1000).toStringAsFixed(1)} km (~${(_yesterdayWalkMeters / 0.75).round()} steps)',
    );
    buffer.writeln('• Hydration: $_yesterdayWaterMl / $_waterGoalMl mL');
    buffer.writeln('• Consistency Streak: $_currentStreak Days 🔥');
    buffer.writeln('');
    buffer.writeln('🎯 TODAY\'S BATTLE PLAN:');
    buffer.writeln('• Daily Target: $_selectedStudyTargetHours hrs Deep Work');
    buffer.writeln('• Morning Mindset: $_selectedMindset');
    if (_selectedWaterMl > 0) {
      buffer.writeln('• Morning Hydration: +$_selectedWaterMl mL Water kick-off');
    }
    if (allTasks.isNotEmpty) {
      buffer.writeln('• Priority Focus Tasks:');
      for (int i = 0; i < allTasks.length; i++) {
        buffer.writeln('  ${i + 1}. ${allTasks[i]}');
      }
    }
    buffer.writeln('────────────────────────────────────────');
    buffer.writeln('Built with Ascent · High-Agency Operating System');

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        subject: 'Ascent Daily Briefing - $dateStr',
      ),
    );
  }

  Future<void> _commitAndLaunch() async {
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final todayStr = now.toIso8601String().substring(0, 10);
      final prefs = ref.read(sharedPreferencesProvider);

      final taskDao = ref.read(taskDaoProvider);
      final waterDao = ref.read(waterDaoProvider);

      // 1. Log morning hydration if selected
      if (_selectedWaterMl > 0) {
        await waterDao.addWater(_selectedWaterMl);
      }

      // 2. Reschedule checked carried-over tasks to today
      for (final task in _carriedOverTasks) {
        if (_selectedCarriedOverTaskIds.contains(task.id)) {
          await taskDao.updateTask(
            TaskTableCompanion(
              id: drift.Value(task.id),
              plannedDate: drift.Value(today),
              updatedAt: drift.Value(now),
            ),
          );
        }
      }

      // 3. Insert new priority tasks
      for (final ctrl in _taskControllers) {
        final title = ctrl.text.trim();
        if (title.isEmpty) continue;
        await taskDao.insertTask(
          TaskTableCompanion.insert(
            title: title,
            plannedDate: drift.Value(today),
            priority: const drift.Value('high'),
          ),
        );
      }

      // 4. Save preferences and prevent hydration prompt collision
      await prefs.setString('ascent_new_day_shown', todayStr);
      await prefs.setInt('ascent_last_hydration_prompt_time', now.millisecondsSinceEpoch);
      await prefs.setInt('ascent_today_study_target_hours', _selectedStudyTargetHours);
      await prefs.setString('ascent_morning_mindset', _selectedMindset);

      // 5. Invalidate relevant stream providers
      ref.invalidate(todayFocusTaskProvider);
      ref.invalidate(todayTasksStreamProvider);
      ref.invalidate(todayWaterMlStreamProvider);
      ref.invalidate(todayWaterLogsStreamProvider);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: Color(0xFF5FA070), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedWaterMl > 0
                        ? 'Plan locked in! +$_selectedWaterMl mL water logged. Conquer your day! 🚀'
                        : 'Plan locked in! Tasks scheduled. Have a high-agency day! 🚀',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(userProfileStreamProvider).value;
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';
    final dateStr = DateFormat('EEEE, MMMM d').format(DateTime.now());

    final media = MediaQuery.of(context);
    final dialogWidth = math.min(media.size.width - 28, 520.0);
    final dialogHeight = math.min(media.size.height * 0.86, 700.0);

    final isFirstDay = !_isLoading &&
        _completedTasks == 0 &&
        _carriedOverTasks.isEmpty &&
        _yesterdayFocusSeconds == 0 &&
        _yesterdayWalkMeters == 0 &&
        _yesterdayWaterMl == 0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: context.bgSurface.withValues(alpha: context.isDark ? 0.94 : 0.98),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: context.divider, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 2,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Header Bar with Close Button
                  _buildHeader(context, name, dateStr),

                  // Scrollable Body Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isLoading)
                            const _LoadingScorecardShimmer()
                          else if (isFirstDay)
                            _buildFirstDayWelcome(context)
                          else
                            _buildYesterdayScorecard(context),

                          // Carried-over Tasks Section (if any)
                          if (_carriedOverTasks.isNotEmpty) ...[
                            const SizedBox(height: 18),
                            _buildCarriedOverSection(context),
                          ],

                          const SizedBox(height: 20),
                          // Today's Battle Plan Inputs Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: context.accentPrimary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.flag_rounded,
                                  size: 16,
                                  color: context.accentPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Today\'s Battle Plan',
                                style: GoogleFonts.plusJakartaSans(
                                  color: context.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // 1. Morning Hydration Boost
                          _buildHydrationKickoffSection(context),
                          const SizedBox(height: 18),

                          // 2. Focus Duration Target
                          _buildStudyTargetSection(context),
                          const SizedBox(height: 18),

                          // 3. Morning Mindset
                          _buildMindsetSection(context),
                          const SizedBox(height: 18),

                          // 4. Priority Tasks Inputs
                          _buildTodayTasksSection(context),
                        ],
                      ),
                    ),
                  ),

                  // Sticky Bottom Action Footer
                  _buildFooter(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String dateStr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
      decoration: BoxDecoration(
        color: context.bgSurfaceElevated.withValues(alpha: 0.7),
        border: Border(bottom: BorderSide(color: context.divider, width: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'EXECUTIVE BRIEFING',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.accentPrimary,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (_currentStreak > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF97316).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '🔥 $_currentStreak DAYS',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFFF97316),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${_greeting()}, $name!',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  dateStr,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.textMuted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: context.textMuted, size: 22),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }

  Widget _buildFirstDayWelcome(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: context.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: context.accentPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF5FA070), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day 1 Kick-Off · Welcome to Ascent!',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Starting your journey today! Set your hydration, study hours target, and outline today\'s key goals below to build momentum.',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.textMuted,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYesterdayScorecard(BuildContext context) {
    final walkKm = (_yesterdayWalkMeters / 1000).toStringAsFixed(1);
    final walkSteps = (_yesterdayWalkMeters / 0.75).round();
    final totalTasks = _completedTasks + _carriedOverTasks.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Yesterday\'s Performance Debrief',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '24h Summary',
                style: AscentTextStyles.caption.copyWith(color: context.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 4-Card Scorecard Grid
          Row(
            children: [
              Expanded(
                child: _ScorecardTile(
                  icon: Icons.check_circle_outline_rounded,
                  iconColor: const Color(0xFF22C55E),
                  label: 'Tasks Done',
                  value: '$_completedTasks / $totalTasks',
                  subtext: _carriedOverTasks.isEmpty
                      ? 'All cleared'
                      : '${_carriedOverTasks.length} carried over',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScorecardTile(
                  icon: Icons.hourglass_top_rounded,
                  iconColor: const Color(0xFF38BDF8),
                  label: 'Deep Focus',
                  value: _formatFocusDuration(_yesterdayFocusSeconds),
                  subtext: _yesterdayFocusSeconds > 0 ? 'Study logged' : 'Rest day',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ScorecardTile(
                  icon: Icons.directions_walk_rounded,
                  iconColor: const Color(0xFFA855F7),
                  label: 'Movement',
                  value: '$walkKm km',
                  subtext: walkSteps > 0 ? '~$walkSteps steps' : 'No walks logged',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ScorecardTile(
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFF0EA5E9),
                  label: 'Hydration',
                  value: '$_yesterdayWaterMl mL',
                  subtext: 'Goal: $_waterGoalMl mL',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarriedOverSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.replay_rounded, size: 16, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Carry forward to today (${_carriedOverTasks.length} tasks)',
                  style: GoogleFonts.plusJakartaSans(
                    color: context.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._carriedOverTasks.map((task) {
            final isChecked = _selectedCarriedOverTaskIds.contains(task.id);
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  if (isChecked) {
                    _selectedCarriedOverTaskIds.remove(task.id);
                  } else {
                    _selectedCarriedOverTaskIds.add(task.id);
                  }
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 18,
                      color: isChecked ? context.accentPrimary : context.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        style: AscentTextStyles.bodyMedium.copyWith(
                          color: isChecked ? context.textPrimary : context.textMuted,
                          decoration: isChecked ? null : TextDecoration.lineThrough,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHydrationKickoffSection(BuildContext context) {
    final waterOptions = [
      {'ml': 250, 'label': '+250 mL', 'desc': 'Glass'},
      {'ml': 350, 'label': '+350 mL', 'desc': 'Mug'},
      {'ml': 500, 'label': '+500 mL', 'desc': 'Bottle'},
      {'ml': 0, 'label': 'Skip', 'desc': 'For now'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.water_drop_rounded, size: 16, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Morning Hydration Boost',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _selectedWaterMl > 0 ? 'Adds +$_selectedWaterMl mL' : 'Not logging',
              style: AscentTextStyles.caption.copyWith(
                color: _selectedWaterMl > 0 ? const Color(0xFF38BDF8) : context.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: waterOptions.map((opt) {
            final ml = opt['ml'] as int;
            final isSelected = _selectedWaterMl == ml;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedWaterMl = ml);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF0284C7).withValues(alpha: 0.18)
                          : context.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF38BDF8)
                            : context.divider,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          opt['label'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            color: isSelected ? const Color(0xFF38BDF8) : context.textPrimary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        Text(
                          opt['desc'] as String,
                          style: AscentTextStyles.caption.copyWith(
                            color: context.textMuted,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStudyTargetSection(BuildContext context) {
    final targets = [2, 4, 6, 8];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Daily Focus Target',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$_selectedStudyTargetHours Hours',
              style: AscentTextStyles.caption.copyWith(
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: targets.map((hrs) {
            final isSelected = _selectedStudyTargetHours == hrs;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedStudyTargetHours = hrs);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF10B981).withValues(alpha: 0.16)
                          : context.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF10B981) : context.divider,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$hrs hrs',
                        style: GoogleFonts.plusJakartaSans(
                          color: isSelected ? const Color(0xFF10B981) : context.textPrimary,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMindsetSection(BuildContext context) {
    final mindsets = ['⚡ Energized', '🎯 Deep Focus', '🧘 Calm', '☕ Need Coffee'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
            const SizedBox(width: 6),
            Text(
              'Morning Mindset',
              style: GoogleFonts.plusJakartaSans(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: mindsets.map((m) {
            final isSelected = _selectedMindset == m;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedMindset = m);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.accentPrimary.withValues(alpha: 0.18)
                      : context.bgSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? context.accentPrimary : context.divider,
                    width: isSelected ? 1.4 : 1.0,
                  ),
                ),
                child: Text(
                  m,
                  style: GoogleFonts.plusJakartaSans(
                    color: isSelected ? context.accentPrimary : context.textSecondary,
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTodayTasksSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.add_task_rounded, size: 16, color: context.accentPrimary),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Today I will execute on:',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_taskControllers.length} focus goal${_taskControllers.length == 1 ? '' : 's'}',
              style: AscentTextStyles.caption.copyWith(color: context.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._taskControllers.asMap().entries.map((entry) {
          final idx = entry.key;
          final ctrl = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: ctrl,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.plusJakartaSans(fontSize: 13.5, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: idx == 0
                    ? 'e.g. Finish System Design Chapter 4'
                    : idx == 1
                        ? 'e.g. Solve 2 Graph DP problems'
                        : 'e.g. Review Core CS & Mock Interview',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                prefixIcon: Icon(
                  Icons.check_circle_outline_rounded,
                  color: context.accentPrimary.withValues(alpha: 0.7),
                  size: 18,
                ),
                suffixIcon: _taskControllers.length > 1
                    ? IconButton(
                        icon: Icon(Icons.remove_circle_outline_rounded,
                            color: context.stateDanger, size: 18),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _taskControllers[idx].dispose();
                            _taskControllers.removeAt(idx);
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.bgSurfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.accentPrimary, width: 1.5),
                ),
              ),
              onSubmitted: (_) {
                setState(() => _taskControllers.add(TextEditingController()));
              },
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _taskControllers.add(TextEditingController()));
            },
            icon: Icon(Icons.add_rounded, size: 18, color: context.accentPrimary),
            label: Text(
              'Add another goal...',
              style: GoogleFonts.plusJakartaSans(
                color: context.accentPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: context.bgSurfaceElevated.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: context.divider, width: 0.8)),
      ),
      child: Row(
        children: [
          // Share Daily Plan Button
          OutlinedButton.icon(
            onPressed: _isSaving ? null : _shareDailyBriefing,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textPrimary,
              side: BorderSide(color: context.divider),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share_rounded, size: 16),
            label: Text(
              'Share',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 10),
          // Primary Let's Go / Conquer Button
          Expanded(
            child: AscentButton.primary(
              label: _isSaving ? 'Locking in...' : 'Let\'s Conquer Today! 🚀',
              onPressed: _isSaving ? null : _commitAndLaunch,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScorecardTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtext;

  const _ScorecardTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.bgSurface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.divider.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: AscentTextStyles.caption.copyWith(
                    color: context.textMuted,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: context.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtext,
            style: AscentTextStyles.caption.copyWith(
              color: context.textMuted,
              fontSize: 9.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LoadingScorecardShimmer extends StatelessWidget {
  const _LoadingScorecardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.bgSurfaceElevated,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.divider),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(
            'Analyzing yesterday\'s activity...',
            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
          ),
        ],
      ),
    );
  }
}
