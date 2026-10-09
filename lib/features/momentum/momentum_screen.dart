import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/momentum/momentum_service.dart';
import '../../core/providers/database_provider.dart';
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
        final nextPending = commitments.where((c) => !c.isCompleted).firstOrNull;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 1. Day Selector Strip (Horizontal 30-day slider)
            _buildDaySelectorStrip(context, currentDayNumber),

            const SizedBox(height: 18),

            // 2. Integrated Daily-Progress Hero Visual (Circle Ring + Day Headline)
            _buildProgressHeroCard(context, doneCount, totalCount, progressFraction, currentDayNumber),

            const SizedBox(height: 18),

            // 3. Prominent Next Action Card
            if (nextPending != null) ...[
              _buildProminentNextAction(context, nextPending),
              const SizedBox(height: 20),
            ] else if (commitments.isNotEmpty) ...[
              _buildAllCompletedCard(context),
              const SizedBox(height: 20),
            ],

            // 4. Chronological Activity Timeline
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

  // ── PROGRESS HERO CARD (Coherent Visual Treatment - Spec §5B) ────────────
  Widget _buildProgressHeroCard(
    BuildContext context,
    int doneCount,
    int totalCount,
    double progressFraction,
    int currentDayNumber,
  ) {
    final g = context.glass;
    final percent = (progressFraction * 100).round();

    return GlassSurface(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          // Circular Progress Arc
          SizedBox(
            width: 72,
            height: 72,
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
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: g.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '$doneCount/$totalCount',
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
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
                        _selectedDayNumber == currentDayNumber ? 'TODAY' : 'DAY $_selectedDayNumber',
                        style: TextStyle(
                          color: g.clay,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Phase 1 · Ramp',
                      style: TextStyle(color: g.inkMuted, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
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

  // ── PROMINENT NEXT ACTION (Spec §5C) ──────────────────────────────────────
  Widget _buildProminentNextAction(BuildContext context, MomentumCommitment next) {
    final g = context.glass;
    final timeStr = next.scheduledTimeMinutes != null
        ? '${(next.scheduledTimeMinutes! ~/ 60).toString().padLeft(2, '0')}:${(next.scheduledTimeMinutes! % 60).toString().padLeft(2, '0')}'
        : 'Up next';

    IconData actionIcon;
    Color actionTint;
    String actionBtnLabel;
    VoidCallback onActionTap;

    if (next.commitmentType == 'walk') {
      actionIcon = Icons.directions_walk_rounded;
      actionTint = g.sage;
      actionBtnLabel = 'Start Walk';
      onActionTap = () {
        HapticFeedback.lightImpact();
        context.push('/walk');
      };
    } else if (next.commitmentType == 'gym') {
      actionIcon = Icons.fitness_center_rounded;
      actionTint = g.clay;
      actionBtnLabel = 'Start Gym';
      onActionTap = () {
        HapticFeedback.lightImpact();
        context.push('/focus');
      };
    } else {
      actionIcon = Icons.check_circle_outline_rounded;
      actionTint = g.clay;
      actionBtnLabel = 'Done';
      onActionTap = () async {
        HapticFeedback.mediumImpact();
        await ref.read(momentumServiceProvider).toggleCommitment(next.id);
      };
    }

    return AscentCard(
      padding: const EdgeInsets.all(16),
      color: g.claySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: g.clay,
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
          const SizedBox(height: 10),
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
          if (next.commitmentType == 'gym' || next.commitmentType == 'walk') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _buildAdaptivePill('Short on time? (20m express)', () {
                  _adaptSession(next.id, 'shorten');
                }),
                const SizedBox(width: 8),
                _buildAdaptivePill('Move to evening', () {
                  _adaptSession(next.id, 'reschedule_evening');
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllCompletedCard(BuildContext context) {
    final g = context.glass;
    return AscentCard(
      padding: const EdgeInsets.all(16),
      color: g.sageSoft,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: g.sage.withValues(alpha: 0.18),
            ),
            child: Icon(Icons.check_rounded, color: g.sage, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Day $_selectedDayNumber Crushed! ⚡',
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
    );
  }

  Widget _buildAdaptivePill(String label, VoidCallback onTap) {
    final g = context.glass;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: g.fill,
          borderRadius: BorderRadius.circular(10),
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

        return _TimelineItem(
          commitment: c,
          isFirst: isFirst,
          isLast: isLast,
          isCurrent: isCurrent,
          onToggle: () async {
            HapticFeedback.lightImpact();
            await ref.read(momentumServiceProvider).toggleCommitment(c.id);
          },
          onAction: () {
            if (c.commitmentType == 'walk') {
              HapticFeedback.lightImpact();
              context.push('/walk');
            } else if (c.commitmentType == 'gym') {
              HapticFeedback.lightImpact();
              context.push('/focus');
            }
          },
        );
      }),
    );
  }

  // ── DAY SELECTOR STRIP ────────────────────────────────────────────────────
  Widget _buildDaySelectorStrip(BuildContext context, int currentDayNumber) {
    final g = context.glass;

    return SizedBox(
      height: 60,
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
              width: 50,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? g.clay : (isCurrent ? g.claySoft : g.fill),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? g.clay : (isCurrent ? g.clay.withValues(alpha: 0.5) : g.edge),
                  width: isSelected || isCurrent ? 1.2 : 0.8,
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
                      letterSpacing: 0.4,
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

// ── CONNECTED TIMELINE ITEM WIDGET (Spec §5D) ──────────────────────────────
class _TimelineItem extends StatelessWidget {
  final MomentumCommitment commitment;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final VoidCallback onToggle;
  final VoidCallback onAction;

  const _TimelineItem({
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
                color: c.isCompleted ? g.fill.withValues(alpha: 0.45) : g.fill,
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
                              style: TextStyle(color: g.inkMuted, fontSize: 11),
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
