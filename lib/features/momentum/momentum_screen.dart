import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/momentum/momentum_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass_surface.dart';

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
    _tabController = TabController(length: 2, vsync: this);
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
    final g = context.glass;
    final weightController = TextEditingController(
      text: (challenge.currentWeightKg ?? challenge.startWeightKg ?? 75.0).toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: g.edge),
        ),
        title: Text(
          'Log Current Weight',
          style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Track your progress against your starting baseline:',
              style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: weightController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: g.ink, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: 'Body Weight',
                labelStyle: TextStyle(color: g.inkMuted),
                suffixText: 'kg',
                suffixStyle: TextStyle(color: g.clay, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: g.fill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: g.edge),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: g.edge),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: g.clay, width: 1.2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: g.inkMuted)),
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
    final g = context.glass;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: g.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: g.edge),
        ),
        title: Text('Reset Momentum?', style: TextStyle(color: g.ink, fontWeight: FontWeight.bold)),
        content: Text(
          'This will reset your current protocol and cancel all scheduled wake-up and session alarms.',
          style: TextStyle(color: g.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: g.inkMuted)),
          ),
          AscentButton.destructive(
            label: 'Reset Protocol',
            compact: true,
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
              await ref.read(momentumServiceProvider).deleteChallengeCascading(challenge.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Momentum reset.')),
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
          title: 'Momentum',
          subtitle: 'Day $currentDayNumber • 6:00 AM & Fitness',
          glow2: g.claySoft,
          actions: [
            IconButton(
              icon: Icon(Icons.directions_walk_rounded, color: g.sage),
              tooltip: 'Live GPS Walk',
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/walk');
              },
            ),
            IconButton(
              icon: Icon(Icons.monitor_weight_outlined, color: g.clay),
              tooltip: 'Log Weight',
              onPressed: () => _showLogWeightDialog(challenge),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: g.inkMuted),
              onSelected: (val) {
                if (val == 'walk') context.push('/walk');
                if (val == 'log_weight') _showLogWeightDialog(challenge);
                if (val == 'reset') _showDeleteChallengeDialog(challenge);
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'walk',
                  child: Row(
                    children: [
                      Icon(Icons.directions_walk_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Open GPS Walk'),
                    ],
                  ),
                ),
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
                      Text('Reset Protocol', style: TextStyle(color: Colors.red)),
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
              Tab(text: 'Today'),
              Tab(text: 'Progress & Stats'),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildDailyPlanTab(context, challenge, currentDayNumber),
              _buildProgressTab(context, challenge),
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
      title: 'Momentum',
      subtitle: 'Personalized Fitness & Routine Engine',
      glow2: g.claySoft,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g.claySoft,
                border: Border.all(color: g.clay.withValues(alpha: 0.35), width: 1.5),
              ),
              child: Icon(Icons.bolt_rounded, size: 42, color: g.clay),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Build Unbreakable Momentum',
            textAlign: TextAlign.center,
            style: AscentTextStyles.displaySmall.copyWith(color: g.ink, fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            'A unified protocol combining locked 6:00 AM wake entrainment, progressive outdoor walks, structured gym training, and strict accountability.',
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
                _buildValuePropRow(Icons.directions_walk_rounded, 'Progressive Outdoor Walking', 'Synced with GPS tracker for measurable fat loss.', g.sage),
                const SizedBox(height: 14),
                _buildValuePropRow(Icons.psychology_rounded, 'Strict but Supportive Coach', 'Honest accountability with adaptive rescheduling.', g.slate),
              ],
            ),
          ),

          const SizedBox(height: 28),

          AscentButton.primary(
            label: 'Begin Assessment & Start',
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/momentum-onboarding');
            },
          ),
          const SizedBox(height: 12),
          AscentButton.outlined(
            label: 'Open GPS Walk Tracker',
            icon: Icons.directions_walk_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/walk');
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildValuePropRow(IconData icon, String title, String subtitle, Color color) {
    final g = context.glass;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: g.ink)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: g.inkMuted, fontSize: 12)),
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
        final progressFraction = totalCount > 0 ? (doneCount / totalCount).clamp(0.0, 1.0) : 0.0;
        
        MomentumCommitment? nextPending;
        if (_selectedDayNumber == currentDayNumber) {
          final now = DateTime.now();
          final currentMinutes = now.hour * 60 + now.minute;
          nextPending = commitments
              .where((c) => !c.isCompleted && (c.scheduledTimeMinutes == null || c.scheduledTimeMinutes! >= currentMinutes))
              .firstOrNull;
          nextPending ??= commitments.where((c) => !c.isCompleted).firstOrNull;
        } else {
          nextPending = commitments.where((c) => !c.isCompleted).firstOrNull;
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Day Selector Strip (1..7 capsules + 31 inline matrix)
            _buildDaySelectorStrip(context, currentDayNumber),

            const SizedBox(height: 18),

            // 2. Unified Executive Today Progress & Next Action Card
            _buildExecutiveTodayActionCard(
              context,
              doneCount: doneCount,
              totalCount: totalCount,
              progressFraction: progressFraction,
              currentDayNumber: currentDayNumber,
              nextPending: nextPending,
              hasCommitments: commitments.isNotEmpty,
            ),

            const SizedBox(height: 20),

            // 3. Chronological Activity Timeline
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: g.clay),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'DAY $_selectedDayNumber TIMELINE',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: g.inkMuted,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$doneCount of $totalCount done',
                  style: AscentTextStyles.captionMedium.copyWith(color: g.clay, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (commitments.isEmpty)
              const EmptyState(
                icon: Icons.checklist_rounded,
                title: 'No commitments for this day',
                subtitle: 'Select another day or adjust your plan.',
              )
            else
              _buildTimelineList(context, commitments, nextPending),

            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  // ── UNIFIED EXECUTIVE TODAY + NEXT ACTION CARD ────────────────────────────
  Widget _buildExecutiveTodayActionCard(
    BuildContext context, {
    required int doneCount,
    required int totalCount,
    required double progressFraction,
    required int currentDayNumber,
    required MomentumCommitment? nextPending,
    required bool hasCommitments,
  }) {
    VoidCallback? onActionTap;
    if (nextPending != null) {
      if (nextPending.commitmentType == 'walk') {
        onActionTap = () {
          HapticFeedback.lightImpact();
          context.push('/walk');
        };
      } else if (nextPending.commitmentType == 'gym') {
        onActionTap = () async {
          HapticFeedback.lightImpact();
          await ref.read(timeTrackingProvider.notifier).switchToTask(
                title: nextPending.title,
                sourceType: 'gym',
                autoStart: true,
              );
          if (context.mounted) {
            context.push('/focus');
          }
        };
      } else {
        onActionTap = () async {
          HapticFeedback.mediumImpact();
          await ref.read(momentumServiceProvider).toggleCommitment(nextPending.id);
        };
      }
    }

    return MomentumExecutiveTodayActionCard(
      doneCount: doneCount,
      totalCount: totalCount,
      progressFraction: progressFraction,
      selectedDayNumber: _selectedDayNumber,
      currentDayNumber: currentDayNumber,
      nextCommitment: nextPending,
      hasCommitments: hasCommitments,
      onActionTap: onActionTap,
      onAdaptSession: nextPending != null ? (type) => _adaptSession(nextPending.id, type) : null,
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

  // ── COMPACT CHRONOLOGICAL TIMELINE (Spec §5D) ─────────────────────────────
  Widget _buildTimelineList(
    BuildContext context,
    List<MomentumCommitment> commitments,
    MomentumCommitment? nextPending,
  ) {
    return Column(
      children: List.generate(commitments.length, (index) {
        final c = commitments[index];
        final isFirst = index == 0;
        final isLast = index == commitments.length - 1;
        final isCurrent = c.id == nextPending?.id;

        return TimelineItemCard(
          commitment: c,
          isFirst: isFirst,
          isLast: isLast,
          isCurrent: isCurrent,
          onToggle: () async {
            HapticFeedback.lightImpact();
            await ref.read(momentumServiceProvider).toggleCommitment(c.id);
          },
          onAction: () async {
            if (c.commitmentType == 'walk') {
              HapticFeedback.lightImpact();
              context.push('/walk');
            } else if (c.commitmentType == 'gym') {
              HapticFeedback.lightImpact();
              await ref.read(timeTrackingProvider.notifier).switchToTask(
                    title: c.title,
                    sourceType: 'gym',
                    autoStart: true,
                  );
              if (context.mounted) {
                context.push('/focus');
              }
            }
          },
        );
      }),
    );
  }

  // ── DAY SELECTOR STRIP ────────────────────────────────────────────────────
  Widget _buildDaySelectorStrip(BuildContext context, int currentDayNumber) {
    return MomentumDayCapsuleStrip(
      selectedDayNumber: _selectedDayNumber,
      currentDayNumber: currentDayNumber,
      completedDayNumbers: const {},
      onSelectDay: (day) => setState(() => _selectedDayNumber = day),
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

        final weight = challenge.currentWeightKg ?? challenge.startWeightKg ?? 75.0;
        final estimatedWalkCalories = MomentumService.estimateCaloriesBurned(type: 'walk', userWeightKg: weight, durationMinutes: (totalWalkMeters / 80).round());
        final estimatedGymCalories = MomentumService.estimateCaloriesBurned(type: 'gym', userWeightKg: weight, durationMinutes: totalGymMinutes);
        final totalCaloriesBurned = estimatedWalkCalories + estimatedGymCalories;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Top Weight Card
            AscentCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('START WEIGHT', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${challenge.startWeightKg?.toStringAsFixed(1) ?? "--"} kg', style: TextStyle(color: g.ink, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  Icon(Icons.arrow_forward_rounded, color: g.inkMuted, size: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('CURRENT', style: TextStyle(color: g.clay, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${challenge.currentWeightKg?.toStringAsFixed(1) ?? "--"} kg', style: TextStyle(color: g.clay, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  Icon(Icons.arrow_forward_rounded, color: g.inkMuted, size: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('TARGET', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${challenge.targetWeightKg?.toStringAsFixed(1) ?? "--"} kg', style: TextStyle(color: g.ink, fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Adherence & Volume Metrics (2x2 Grid)
            Row(
              children: [
                Expanded(
                  child: AscentCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ADHERENCE', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$adherencePercent%', style: TextStyle(color: g.sage, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('$totalDone / $totalScheduled done', style: TextStyle(color: g.inkMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOTAL CALORIES', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$totalCaloriesBurned', style: TextStyle(color: g.clay, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text('MET formula est.', style: TextStyle(color: g.inkMuted, fontSize: 11)),
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
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('WALKING DISTANCE', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${(totalWalkMeters / 1000).toStringAsFixed(1)} km', style: TextStyle(color: g.ink, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${walkCommitmentsDone.length} walks logged', style: TextStyle(color: g.inkMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GYM TIME', style: TextStyle(color: g.inkMuted, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('$totalGymMinutes min', style: TextStyle(color: g.ink, fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('${gymCommitmentsDone.length} workouts logged', style: TextStyle(color: g.inkMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Walk Tracker Shortcut
            AscentButton.outlined(
              label: 'Launch Live GPS Walk Tracker',
              icon: Icons.directions_walk_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/walk');
              },
            ),
            const SizedBox(height: 28),
          ],
        );
      },
    );
  }
}

// ── MOMENTUM DAY CAPSULE STRIP ─────────────────────────────────────────────
class MomentumDayCapsuleStrip extends StatefulWidget {
  final int selectedDayNumber;
  final int currentDayNumber;
  final Set<int> completedDayNumbers;
  final ValueChanged<int> onSelectDay;
  final int totalDays;

  const MomentumDayCapsuleStrip({
    super.key,
    required this.selectedDayNumber,
    required this.currentDayNumber,
    this.completedDayNumbers = const {},
    required this.onSelectDay,
    this.totalDays = 31,
  });

  @override
  State<MomentumDayCapsuleStrip> createState() => _MomentumDayCapsuleStripState();
}

class _MomentumDayCapsuleStripState extends State<MomentumDayCapsuleStrip> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Days 1..7 + More Trigger Row (Fits across screen without horizontal scrolling)
        Row(
          children: [
            for (int dayNum = 1; dayNum <= 7; dayNum++) ...[
              Expanded(
                child: _buildDayCapsule(
                  dayNum: dayNum,
                  isSelected: dayNum == widget.selectedDayNumber,
                  isCurrent: dayNum == widget.currentDayNumber,
                  isCompleted: widget.completedDayNumbers.contains(dayNum),
                  g: g,
                ),
              ),
              if (dayNum < 7) const SizedBox(width: 5),
            ],
            const SizedBox(width: 6),
            _buildMoreButton(g),
          ],
        ),

        // Inline 31-Day Matrix (Zero scrolling needed, directly open on screen)
        if (_isExpanded) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: g.fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: g.edge),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ALL 31 DAYS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: g.inkMuted,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isExpanded = false);
                      },
                      child: Row(
                        children: [
                          Text('Close', style: TextStyle(fontSize: 11, color: g.clay, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_up_rounded, size: 16, color: g.clay),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: widget.totalDays,
                  itemBuilder: (ctx, index) {
                    final d = index + 1;
                    final isSelected = d == widget.selectedDayNumber;
                    final isCurrent = d == widget.currentDayNumber;
                    final isCompleted = widget.completedDayNumbers.contains(d);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSelectDay(d);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? g.clay
                              : (isCurrent ? g.claySoft : g.fill),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? g.clay
                                : (isCurrent ? g.clay.withValues(alpha: 0.6) : g.edge),
                            width: isSelected || isCurrent ? 1.4 : 0.8,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$d',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : (isCurrent ? g.clay : g.ink),
                              ),
                            ),
                            if (isCompleted || isCurrent) ...[
                              const SizedBox(height: 2),
                              Container(
                                width: 3,
                                height: 3,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : (isCompleted ? g.sage : g.clay),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDayCapsule({
    required int dayNum,
    required bool isSelected,
    required bool isCurrent,
    required bool isCompleted,
    required AscentGlass g,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onSelectDay(dayNum);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? g.clay
              : (isCurrent ? g.claySoft : g.fill),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? g.clay
                : (isCurrent ? g.clay.withValues(alpha: 0.5) : g.edge),
            width: isSelected || isCurrent ? 1.4 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: g.clay.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNum',
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : (isCurrent ? g.clay : g.ink),
                letterSpacing: -0.2,
              ),
            ),
            if (isCompleted || isCurrent) ...[
              const SizedBox(height: 3),
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.white
                      : (isCompleted ? g.sage : g.clay),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoreButton(AscentGlass g) {
    final isBeyond7 = widget.selectedDayNumber > 7;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _isExpanded = !_isExpanded);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _isExpanded || isBeyond7 ? g.claySoft : g.fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _isExpanded || isBeyond7 ? g.clay.withValues(alpha: 0.6) : g.edge,
            width: _isExpanded || isBeyond7 ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isBeyond7 ? '${widget.selectedDayNumber}' : 'More',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isBeyond7 || _isExpanded ? g.clay : g.inkMuted,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isBeyond7 || _isExpanded ? g.clay : g.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ── MOMENTUM EXECUTIVE UNIFIED TODAY + NEXT ACTION CARD ───────────────────
class MomentumExecutiveTodayActionCard extends StatelessWidget {
  final int doneCount;
  final int totalCount;
  final double progressFraction;
  final int selectedDayNumber;
  final int currentDayNumber;
  final MomentumCommitment? nextCommitment;
  final bool hasCommitments;
  final VoidCallback? onActionTap;
  final void Function(String type)? onAdaptSession;

  const MomentumExecutiveTodayActionCard({
    super.key,
    required this.doneCount,
    required this.totalCount,
    required this.progressFraction,
    required this.selectedDayNumber,
    required this.currentDayNumber,
    this.nextCommitment,
    this.hasCommitments = true,
    this.onActionTap,
    this.onAdaptSession,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final percent = (progressFraction * 100).round();

    final next = nextCommitment;
    IconData actionIcon = Icons.check_circle_outline_rounded;
    Color actionTint = g.clay;
    String actionBtnLabel = 'Done';

    if (next != null) {
      if (next.commitmentType == 'walk') {
        actionIcon = Icons.directions_walk_rounded;
        actionTint = g.sage;
        actionBtnLabel = 'Start Walk';
      } else if (next.commitmentType == 'gym') {
        actionIcon = Icons.fitness_center_rounded;
        actionTint = g.clay;
        actionBtnLabel = 'Start Gym';
      }
    }

    final timeStr = next?.scheduledTimeMinutes != null
        ? '${(next!.scheduledTimeMinutes! ~/ 60).toString().padLeft(2, '0')}:${(next.scheduledTimeMinutes! % 60).toString().padLeft(2, '0')}'
        : 'Up next';

    final innerContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row: Tags + Straight Percentage Text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: g.claySoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selectedDayNumber == currentDayNumber ? 'TODAY' : 'DAY $selectedDayNumber',
                    style: TextStyle(
                      color: g.clay,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: g.fill,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: g.edge, width: 0.8),
                  ),
                  child: Text(
                    '$doneCount of $totalCount completed',
                    style: TextStyle(
                      color: g.inkMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '$percent%',
              style: TextStyle(
                color: g.clay,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          percent == 100
              ? 'Daily Target Locked In'
              : (percent >= 50 ? 'Strong Steady Pace' : 'Morning Focus Phase'),
          style: TextStyle(
            color: g.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          percent == 100
              ? 'All targets completed for today. Great discipline.'
              : 'Complete your planned activities to solidify daily momentum.',
          style: TextStyle(color: g.inkMuted, fontSize: 12),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 12),

        // Straight Progress Bar (No round ring, straight line)
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progressFraction,
            minHeight: 6,
            backgroundColor: g.edge.withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation(g.clay),
          ),
        ),

        // Bottom Portion: Next Action or All Completed
        if (next != null) ...[
          Container(
            height: 1,
            color: g.edge.withValues(alpha: 0.6),
            margin: const EdgeInsets.symmetric(vertical: 14),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: actionTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'NEXT ACTION • $timeStr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (next.wasAdapted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Adapted', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: actionTint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: actionTint.withValues(alpha: 0.25)),
                ),
                child: Icon(actionIcon, size: 22, color: actionTint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.title,
                      style: TextStyle(
                        color: g.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (next.description != null && next.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        next.description!,
                        style: TextStyle(color: g.inkMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onActionTap != null)
                AscentButton.primary(
                  label: actionBtnLabel,
                  compact: true,
                  onPressed: onActionTap,
                ),
            ],
          ),
          if ((next.commitmentType == 'gym' || next.commitmentType == 'walk') && onAdaptSession != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAdaptiveChip('Short on time? (20m express)', () {
                  onAdaptSession!('shorten');
                }, g),
                const SizedBox(width: 8),
                _buildAdaptiveChip('Move to evening', () {
                  onAdaptSession!('reschedule_evening');
                }, g),
              ],
            ),
          ],
        ] else if (hasCommitments) ...[
          Container(
            height: 1,
            color: g.edge.withValues(alpha: 0.6),
            margin: const EdgeInsets.symmetric(vertical: 14),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: g.sage.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.check_rounded, color: g.sage, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day $selectedDayNumber Crushed! ⚡',
                      style: TextStyle(color: g.ink, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'All planned commitments completed. Rest up tonight.',
                      style: TextStyle(color: g.inkMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );

    // In dark: Ascent's signature glass theme (GlassSurface with blur and g.fill/g.edge)
    // In day: AscentCard clean surface
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return GlassSurface(
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: innerContent,
      );
    } else {
      return AscentCard(
        radius: 20,
        padding: const EdgeInsets.all(18),
        hasShadow: true,
        child: innerContent,
      );
    }
  }

  static Widget _buildAdaptiveChip(String label, VoidCallback onTap, AscentGlass g) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: g.fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: g.edge),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: g.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── MOMENTUM EXECUTIVE NEXT ACTION CARD ──────────────────────────────────
class MomentumExecutiveNextActionCard extends StatelessWidget {
  final MomentumCommitment commitment;
  final VoidCallback onActionTap;
  final void Function(String type)? onAdaptSession;

  const MomentumExecutiveNextActionCard({
    super.key,
    required this.commitment,
    required this.onActionTap,
    this.onAdaptSession,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final next = commitment;

    IconData actionIcon;
    Color actionTint;
    String actionBtnLabel;

    if (next.commitmentType == 'walk') {
      actionIcon = Icons.directions_walk_rounded;
      actionTint = g.sage;
      actionBtnLabel = 'Start Walk';
    } else if (next.commitmentType == 'gym') {
      actionIcon = Icons.fitness_center_rounded;
      actionTint = g.clay;
      actionBtnLabel = 'Start Gym';
    } else {
      actionIcon = Icons.check_circle_outline_rounded;
      actionTint = g.clay;
      actionBtnLabel = 'Done';
    }

    final timeStr = next.scheduledTimeMinutes != null
        ? '${(next.scheduledTimeMinutes! ~/ 60).toString().padLeft(2, '0')}:${(next.scheduledTimeMinutes! % 60).toString().padLeft(2, '0')}'
        : 'Up next';

    return AscentCard(
      padding: const EdgeInsets.all(16),
      color: g.fill,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: actionTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'NEXT ACTION • $timeStr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (next.wasAdapted)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Adapted', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: actionTint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: actionTint.withValues(alpha: 0.25)),
                ),
                child: Icon(actionIcon, size: 22, color: actionTint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      next.title,
                      style: TextStyle(
                        color: g.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (next.description != null && next.description!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        next.description!,
                        style: TextStyle(color: g.inkMuted, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AscentButton.primary(
                label: actionBtnLabel,
                compact: true,
                onPressed: onActionTap,
              ),
            ],
          ),
          if ((next.commitmentType == 'gym' || next.commitmentType == 'walk') && onAdaptSession != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAdaptiveChip('Short on time? (20m express)', () {
                  onAdaptSession!('shorten');
                }, g),
                const SizedBox(width: 8),
                _buildAdaptiveChip('Move to evening', () {
                  onAdaptSession!('reschedule_evening');
                }, g),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildAdaptiveChip(String label, VoidCallback onTap, AscentGlass g) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: g.fill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: g.edge),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: g.inkMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ── MOMENTUM PROGRESS HERO CARD ──────────────────────────────────────────
class MomentumProgressHeroCard extends StatelessWidget {
  final int doneCount;
  final int totalCount;
  final double progressFraction;
  final int selectedDayNumber;
  final int currentDayNumber;

  const MomentumProgressHeroCard({
    super.key,
    required this.doneCount,
    required this.totalCount,
    required this.progressFraction,
    required this.selectedDayNumber,
    required this.currentDayNumber,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final percent = (progressFraction * 100).round();

    return GlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Circular Progress Arc with spacious dedicated percentage
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressFraction,
                  strokeWidth: 6.5,
                  backgroundColor: g.edge,
                  valueColor: AlwaysStoppedAnimation(g.clay),
                  strokeCap: StrokeCap.round,
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: g.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),

          // Contextual Status Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: g.claySoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedDayNumber == currentDayNumber ? 'TODAY' : 'DAY $selectedDayNumber',
                        style: TextStyle(
                          color: g.clay,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: g.fill,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: g.edge, width: 0.8),
                      ),
                      child: Text(
                        '$doneCount of $totalCount completed',
                        style: TextStyle(
                          color: g.inkMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  percent == 100
                      ? 'Daily Target Locked In'
                      : (percent >= 50 ? 'Strong Steady Pace' : 'Morning Focus Phase'),
                  style: TextStyle(
                    color: g.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  percent == 100
                      ? 'All targets completed for today. Great discipline.'
                      : 'Complete your planned activities to solidify daily momentum.',
                  style: TextStyle(color: g.inkMuted, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── CONNECTED TIMELINE ITEM WIDGET (Spec §5D) ──────────────────────────────
class TimelineItemCard extends StatelessWidget {
  final MomentumCommitment commitment;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final VoidCallback onToggle;
  final VoidCallback onAction;

  const TimelineItemCard({
    super.key,
    required this.commitment,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    required this.onToggle,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final c = commitment;

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
      case 'hydration':
      default:
        icon = Icons.water_drop_rounded;
        iconColor = Colors.blue;
        break;
    }

    final timeStr = c.scheduledTimeMinutes != null
        ? '${(c.scheduledTimeMinutes! ~/ 60).toString().padLeft(2, '0')}:${(c.scheduledTimeMinutes! % 60).toString().padLeft(2, '0')}'
        : '';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Timeline Track (Node + Connector Line)
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Upper Connector
                Container(
                  width: 2,
                  height: 14,
                  color: isFirst ? Colors.transparent : g.edge,
                ),
                // Timeline Node
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.isCompleted ? g.clay : (isCurrent ? g.fill : g.bg),
                    border: Border.all(
                      color: c.isCompleted ? g.clay : (isCurrent ? g.clay : g.edge),
                      width: isCurrent ? 2 : 1.2,
                    ),
                  ),
                  child: c.isCompleted
                      ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
                      : (isCurrent
                          ? Center(
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: g.clay),
                              ),
                            )
                          : null),
                ),
                // Lower Connector
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : g.edge,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right Content Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: AscentCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                color: g.fill,
                child: Row(
                  children: [
                    // Icon Squircle
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 16, color: iconColor),
                    ),
                    const SizedBox(width: 12),

                    // Title & Description
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
                                    color: c.isCompleted ? g.inkMuted : g.clay,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text('•', style: TextStyle(color: g.inkMuted, fontSize: 10)),
                                const SizedBox(width: 6),
                              ],
                              Expanded(
                                child: Text(
                                  c.title,
                                  style: TextStyle(
                                    color: c.isCompleted ? g.inkMuted : g.ink,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    decoration: c.isCompleted ? TextDecoration.lineThrough : null,
                                    decorationColor: g.inkMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (c.description != null && c.description!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              c.description!,
                              style: TextStyle(
                                color: g.inkMuted,
                                fontSize: 11,
                                decoration: c.isCompleted ? TextDecoration.lineThrough : null,
                                decorationColor: g.inkMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Quick Action Button (for Walk or Gym if pending)
                    if (!c.isCompleted && c.commitmentType == 'walk')
                      IconButton(
                        icon: Icon(Icons.play_circle_fill_rounded, color: g.sage, size: 26),
                        tooltip: 'Start Walk',
                        visualDensity: VisualDensity.compact,
                        onPressed: onAction,
                      )
                    else if (!c.isCompleted && c.commitmentType == 'gym')
                      IconButton(
                        icon: Icon(Icons.timer_rounded, color: g.clay, size: 22),
                        tooltip: 'Start Gym Timer',
                        visualDensity: VisualDensity.compact,
                        onPressed: onAction,
                      ),

                    // Checkbox Toggle
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Checkbox(
                        value: c.isCompleted,
                        activeColor: g.clay,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        onChanged: (_) => onToggle(),
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
