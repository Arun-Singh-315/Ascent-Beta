import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/momentum/momentum_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../walk/walk_screen.dart';
import 'momentum_onboarding_screen.dart';

class MomentumScreen extends ConsumerStatefulWidget {
  const MomentumScreen({super.key});

  @override
  ConsumerState<MomentumScreen> createState() => _MomentumScreenState();
}

class _MomentumScreenState extends ConsumerState<MomentumScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _selectedDayNumber = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _calculateCurrentDayNumber(MomentumChallenge challenge) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(challenge.startDate.year, challenge.startDate.month, challenge.startDate.day);
    final diff = today.difference(start).inDays + 1;
    return diff.clamp(1, 30);
  }

  void _showLogWeightDialog(MomentumChallenge challenge) {
    final weightController = TextEditingController(
      text: (challenge.currentWeightKg ?? challenge.startWeightKg ?? 75.0).toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgSurface,
        title: Text(
          'Log Current Weight',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Track your 30-day fat loss trend [ENTERED]:', style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted)),
            const SizedBox(height: 12),
            TextField(
              controller: weightController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Body Weight',
                suffixText: 'kg',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AscentButton.primary(
            label: 'Save Weight',
            compact: true,
            onPressed: () async {
              final newWeight = double.tryParse(weightController.text);
              if (newWeight != null && newWeight > 20 && newWeight < 300) {
                await ref.read(momentumServiceProvider).recordWeight(challenge.id, newWeight);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Weight logged: ${newWeight.toStringAsFixed(1)} kg')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteChallengeDialog(MomentumChallenge challenge) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgSurface,
        title: Text('Reset Momentum Challenge?', style: TextStyle(color: context.textPrimary)),
        content: const Text(
          'This will cleanly remove the 30-day challenge and cancel all scheduled wake and session alarms.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          AscentButton.destructive(
            label: 'Reset Challenge',
            compact: true,
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
              await ref.read(momentumServiceProvider).deleteChallengeCascading(challenge.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Challenge reset.')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final challengeAsync = ref.watch(activeMomentumChallengeStreamProvider);

    return challengeAsync.when(
      loading: () => Scaffold(
        backgroundColor: g.bg,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: g.bg,
        body: Center(child: Text('Error loading Momentum: $err', style: TextStyle(color: g.inkMuted))),
      ),
      data: (challenge) {
        if (challenge == null) {
          return _buildNoActiveChallengeView(context);
        }

        final currentDayNumber = _calculateCurrentDayNumber(challenge);
        if (_selectedDayNumber == 1 && currentDayNumber > 1) {
          _selectedDayNumber = currentDayNumber;
        }

        return AscentScaffold(
          title: 'Ascent Momentum',
          subtitle: 'Day $currentDayNumber of 30 • 6:00 AM & Fitness',
          glow2: g.claySoft,
          actions: [
            IconButton(
              icon: Icon(Icons.monitor_weight_outlined, color: g.clay),
              tooltip: 'Log Weight',
              onPressed: () => _showLogWeightDialog(challenge),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: g.inkMuted),
              onSelected: (val) {
                if (val == 'log_weight') _showLogWeightDialog(challenge);
                if (val == 'reset') _showDeleteChallengeDialog(challenge);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'log_weight',
                  child: Row(
                    children: [
                      Icon(Icons.scale_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Log Body Weight'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Reset Challenge', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: g.clay,
            unselectedLabelColor: g.inkMuted,
            indicatorColor: g.clay,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Today\'s Plan'),
              Tab(text: 'Progress & Stats'),
              Tab(text: 'Live GPS Walk'),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyPlanTab(context, challenge, currentDayNumber),
              _buildProgressTab(context, challenge),
              const WalkScreen(), // Embedded GPS tracker preserving 100% of walk capabilities!
            ],
          ),
        );
      },
    );
  }

  // ── VIEW WHEN NO CHALLENGE IS ACTIVE ──────────────────────────────────────
  Widget _buildNoActiveChallengeView(BuildContext context) {
    final g = context.glass;

    return AscentScaffold(
      title: 'Ascent Momentum',
      subtitle: '30-Day Personalized Fitness Engine',
      glow2: g.claySoft,
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g.clay.withValues(alpha: 0.15),
                border: Border.all(color: g.clay.withValues(alpha: 0.4), width: 1.5),
              ),
              child: Icon(Icons.bolt_rounded, size: 44, color: g.clay),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Start Your 30-Day Momentum Challenge',
            textAlign: TextAlign.center,
            style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 22),
          ),
          const SizedBox(height: 10),
          Text(
            'A structured 30-day transformation combining locked 6:00 AM wake-ups, gym strength splits, progressive outdoor walks, and intelligent adaptive coaching.',
            textAlign: TextAlign.center,
            style: AscentTextStyles.bodyMedium.copyWith(color: g.inkMuted, height: 1.45),
          ),
          const SizedBox(height: 28),

          AscentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildValuePropRow(Icons.alarm_rounded, '6:00 AM Wake Entrainment', 'Gradual circadian ramp with resilient exact alarms.', g.clay),
                const SizedBox(height: 14),
                _buildValuePropRow(Icons.fitness_center_rounded, 'Personalized Gym Split', 'Upper/Lower or Full Body routines with set tracking.', g.clay),
                const SizedBox(height: 14),
                _buildValuePropRow(Icons.directions_walk_rounded, 'Progressive Outdoor Walking', 'Synced with GPS tracker for measurable fat loss.', g.clay),
                const SizedBox(height: 14),
                _buildValuePropRow(Icons.psychology_rounded, 'Strict but Supportive Coach', 'Honest accountability with adaptive rescheduling.', g.clay),
              ],
            ),
          ),

          const SizedBox(height: 32),

          AscentButton.primary(
            label: 'Begin Assessment & Start ⚡',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MomentumOnboardingScreen()),
              );
            },
          ),
          const SizedBox(height: 14),
          AscentButton.outlined(
            label: 'Open GPS Walk Tracker',
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WalkScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildValuePropRow(IconData icon, String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // ── TAB 1: DAILY PLAN ─────────────────────────────────────────────────────
  Widget _buildDailyPlanTab(BuildContext context, MomentumChallenge challenge, int currentDayNumber) {
    final g = context.glass;
    final commitmentsStream = ref.watch(momentumDaoProvider).watchCommitmentsForDay(challenge.id, _selectedDayNumber);

    return StreamBuilder<List<MomentumCommitment>>(
      stream: commitmentsStream,
      builder: (context, snapshot) {
        final commitments = snapshot.data ?? [];
        final doneCount = commitments.where((c) => c.isCompleted).length;
        final totalCount = commitments.length;
        final progressFraction = totalCount > 0 ? doneCount / totalCount : 0.0;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // 1. Day Selector Strip (30 Days horizontal slider)
            _buildDaySelectorStrip(context, currentDayNumber),

            const SizedBox(height: 16),

            // 2. Strict But Supportive Coaching Insight Banner
            _buildCoachInsightBanner(context, commitments, _selectedDayNumber, currentDayNumber),

            const SizedBox(height: 20),

            // 3. Commitments Header & Progress
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $_selectedDayNumber Commitments',
                  style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 18),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: g.clay.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: g.clay.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '$doneCount / $totalCount Done',
                    style: TextStyle(color: g.clay, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progressFraction,
                minHeight: 6,
                backgroundColor: g.fill,
                valueColor: AlwaysStoppedAnimation(g.clay),
              ),
            ),

            const SizedBox(height: 16),

            // 4. Commitments List
            if (commitments.isEmpty)
              const EmptyState(
                icon: Icons.checklist_rounded,
                title: 'No commitments found for this day',
                subtitle: 'Check other days or generate a new challenge.',
              )
            else
              ...commitments.map((c) => _buildCommitmentTile(context, c)),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildDaySelectorStrip(BuildContext context, int currentDayNumber) {
    final g = context.glass;

    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 30,
        itemBuilder: (ctx, index) {
          final dayNum = index + 1;
          final isSelected = dayNum == _selectedDayNumber;
          final isCurrent = dayNum == currentDayNumber;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDayNumber = dayNum);
            },
            child: Container(
              width: 52,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? g.clay : (isCurrent ? g.clay.withValues(alpha: 0.2) : g.fill),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? g.clay : (isCurrent ? g.clay : g.edge),
                  width: isSelected || isCurrent ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'DAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white70 : g.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : g.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCoachInsightBanner(
    BuildContext context,
    List<MomentumCommitment> commitments,
    int selectedDay,
    int currentDay,
  ) {
    final g = context.glass;
    final nextPending = commitments.where((c) => !c.isCompleted).firstOrNull;

    String coachHeadline;
    String coachAdvice;
    IconData coachIcon;

    if (nextPending == null && commitments.isNotEmpty) {
      coachHeadline = 'Day $selectedDay Crushed! ⚡';
      coachAdvice = 'All commitments checked off. Your consistency is compounding. Rest up tonight.';
      coachIcon = Icons.check_circle_rounded;
    } else if (nextPending != null) {
      final timeStr = nextPending.scheduledTimeMinutes != null
          ? '${(nextPending.scheduledTimeMinutes! ~/ 60).toString().padLeft(2, '0')}:${(nextPending.scheduledTimeMinutes! % 60).toString().padLeft(2, '0')}'
          : 'Today';
      coachHeadline = 'Next Action: $timeStr • ${nextPending.title}';
      coachAdvice = nextPending.description ?? 'Execute on this commitment to keep your 30-day momentum locked.';
      coachIcon = Icons.arrow_forward_rounded;
    } else {
      coachHeadline = 'Momentum Engine Active';
      coachAdvice = 'Stay locked in on your daily targets.';
      coachIcon = Icons.bolt_rounded;
    }

    return AscentCard(
      color: g.clay.withValues(alpha: 0.08),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(coachIcon, color: g.clay, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  coachHeadline,
                  style: TextStyle(color: g.ink, fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            coachAdvice,
            style: AscentTextStyles.bodySmall.copyWith(color: g.inkSecondary, height: 1.4),
          ),
          if (nextPending != null && (nextPending.commitmentType == 'gym' || nextPending.commitmentType == 'walk')) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildAdaptiveActionButton('Short on time? (20m express)', () {
                  _adaptSession(nextPending.id, 'shorten');
                }),
                _buildAdaptiveActionButton('Move to 6:30 PM', () {
                  _adaptSession(nextPending.id, 'reschedule_evening');
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdaptiveActionButton(String label, VoidCallback onTap) {
    final g = context.glass;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: g.fill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: g.edge),
        ),
        child: Text(
          label,
          style: TextStyle(color: g.clay, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Future<void> _adaptSession(int commitmentId, String type) async {
    await ref.read(momentumServiceProvider).adaptCommitment(
      commitmentId: commitmentId,
      adaptationType: type,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(type == 'shorten' ? 'Session condensed to 20 mins express!' : 'Rescheduled to 06:30 PM evening window.')),
      );
    }
  }

  Widget _buildCommitmentTile(BuildContext context, MomentumCommitment c) {
    final g = context.glass;
    IconData icon;
    Color iconColor;

    switch (c.commitmentType) {
      case 'wake':
        icon = Icons.alarm_rounded;
        iconColor = Colors.orange;
        break;
      case 'walk':
        icon = Icons.directions_walk_rounded;
        iconColor = g.sage;
        break;
      case 'gym':
        icon = Icons.fitness_center_rounded;
        iconColor = g.clay;
        break;
      case 'wind_down':
        icon = Icons.bedtime_rounded;
        iconColor = Colors.indigoAccent;
        break;
      default:
        icon = Icons.water_drop_rounded;
        iconColor = Colors.blue;
        break;
    }

    final timeStr = c.scheduledTimeMinutes != null
        ? '${(c.scheduledTimeMinutes! ~/ 60).toString().padLeft(2, '0')}:${(c.scheduledTimeMinutes! % 60).toString().padLeft(2, '0')}'
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AscentCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: c.isCompleted ? g.fill.withValues(alpha: 0.5) : g.fill,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox Toggle
            Checkbox(
              value: c.isCompleted,
              activeColor: g.clay,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              onChanged: (_) async {
                HapticFeedback.lightImpact();
                await ref.read(momentumServiceProvider).toggleCommitment(c.id);
              },
            ),
            const SizedBox(width: 8),

            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 12),

            // Title & Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (timeStr.isNotEmpty) ...[
                        Text(
                          timeStr,
                          style: TextStyle(
                            color: g.clay,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: TextStyle(color: g.inkMuted, fontSize: 10)),
                        const SizedBox(width: 6),
                      ],
                      if (c.wasAdapted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Adapted', style: TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      Expanded(
                        child: Text(
                          c.title,
                          style: TextStyle(
                            color: c.isCompleted ? g.inkMuted : g.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: c.isCompleted ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (c.description != null && c.description!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      c.description!,
                      style: TextStyle(color: g.inkMuted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Direct Action CTAs for Walk and Gym
            if (!c.isCompleted && c.commitmentType == 'walk')
              IconButton(
                icon: Icon(Icons.play_circle_fill_rounded, color: g.sage, size: 28),
                tooltip: 'Start Live GPS Walk',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WalkScreen()));
                },
              )
            else if (!c.isCompleted && c.commitmentType == 'gym')
              IconButton(
                icon: Icon(Icons.timer_rounded, color: g.clay, size: 24),
                tooltip: 'Start Gym Timer',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/focus');
                },
              ),
          ],
        ),
      ),
    );
  }

  // ── TAB 2: PROGRESS & STATS ───────────────────────────────────────────────
  Widget _buildProgressTab(BuildContext context, MomentumChallenge challenge) {
    final g = context.glass;
    final allCommitmentsStream = ref.watch(momentumDaoProvider).watchAllCommitments(challenge.id);

    return StreamBuilder<List<MomentumCommitment>>(
      stream: allCommitmentsStream,
      builder: (context, snapshot) {
        final all = snapshot.data ?? [];
        final totalScheduled = all.length;
        final totalDone = all.where((c) => c.isCompleted).length;
        final adherencePercent = totalScheduled > 0 ? ((totalDone / totalScheduled) * 100).round() : 0;

        final walkCommitmentsDone = all.where((c) => c.commitmentType == 'walk' && c.isCompleted).toList();
        final gymCommitmentsDone = all.where((c) => c.commitmentType == 'gym' && c.isCompleted).toList();

        final totalWalkMeters = walkCommitmentsDone.fold<double>(0.0, (acc, c) => acc + (c.targetDistanceMeters ?? 0.0));
        final totalGymMinutes = gymCommitmentsDone.fold<int>(0, (acc, c) => acc + (c.targetDurationMinutes ?? 45));

        // MET Calorie estimation
        final weight = challenge.currentWeightKg ?? challenge.startWeightKg ?? 75.0;
        final estimatedWalkCalories = MomentumService.estimateCaloriesBurned(type: 'walk', userWeightKg: weight, durationMinutes: (totalWalkMeters / 80).round());
        final estimatedGymCalories = MomentumService.estimateCaloriesBurned(type: 'gym', userWeightKg: weight, durationMinutes: totalGymMinutes);
        final totalCaloriesBurned = estimatedWalkCalories + estimatedGymCalories;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Top Weight Card
            AscentCard(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('START WEIGHT', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${challenge.startWeightKg?.toStringAsFixed(1) ?? "--"} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  Icon(Icons.arrow_forward_rounded, color: g.inkMuted),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('CURRENT [ENTERED]', style: TextStyle(color: g.clay, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${challenge.currentWeightKg?.toStringAsFixed(1) ?? "--"} kg', style: TextStyle(color: g.clay, fontWeight: FontWeight.bold, fontSize: 20)),
                    ],
                  ),
                  Icon(Icons.arrow_forward_rounded, color: g.inkMuted),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TARGET', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${challenge.targetWeightKg?.toStringAsFixed(1) ?? "--"} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Adherence & Volume Metrics (2x2 Grid)
            Row(
              children: [
                Expanded(
                  child: AscentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ADHERENCE', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$adherencePercent%', style: TextStyle(color: g.sage, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('$totalDone / $totalScheduled completed', style: TextStyle(color: g.inkMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL CALORIES', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$totalCaloriesBurned', style: TextStyle(color: g.clay, fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('MET formula [ESTIMATED]', style: TextStyle(color: g.inkMuted, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: AscentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WALKING DISTANCE', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${(totalWalkMeters / 1000).toStringAsFixed(1)} km', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('${walkCommitmentsDone.length} walks completed', style: TextStyle(color: g.inkMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GYM TIME', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$totalGymMinutes min', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('${gymCommitmentsDone.length} sessions logged', style: TextStyle(color: g.inkMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Telemetry Scientific Footnote
            AscentCard(
              color: g.fill,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: g.inkMuted),
                      const SizedBox(width: 6),
                      Text('Data Classification Standard', style: TextStyle(color: g.ink, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• [MEASURED]: GPS distance, live chronometer duration.\n• [ENTERED]: Body weight inputs.\n• [ESTIMATED]: Energy expenditure via validated MET formula (MET 4.2 for brisk walk, MET 5.5 for lifting).',
                    style: TextStyle(color: g.inkMuted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
