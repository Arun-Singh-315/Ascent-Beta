import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/glass_surface.dart';

/// Level 2 · Secondary: Life & Health Hub
/// Redesigned to give spacious, unclustered layout:
/// - Prominent Momentum 30-Day Protocol progress bar and today commitment status.
/// - Medicine prescription tracker with daily dose compliance.
/// - Hydration with instant +250mL action.
/// - Chai & Coffee Break sanctuary footer.
class QuickModulesNavHub extends ConsumerWidget {
  const QuickModulesNavHub({super.key});

  int _calculateCurrentDayNumber(MomentumChallenge challenge) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(challenge.startDate.year, challenge.startDate.month, challenge.startDate.day);
    final diff = today.difference(start).inDays + 1;
    return diff.clamp(1, 30);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;

    // Momentum stream watchers
    final challenge = ref.watch(activeMomentumChallengeStreamProvider).value;
    final commitments = ref.watch(todayMomentumCommitmentsStreamProvider).value ?? [];

    // Medicine stream watchers
    final todayMedicineLogs = ref.watch(todayMedicineLogsStreamProvider).value ?? [];
    final totalMedDoses = todayMedicineLogs.length;
    final takenMedDoses = todayMedicineLogs.where((l) => l.isTaken).length;
    final medProgress = totalMedDoses > 0 ? (takenMedDoses / totalMedDoses).clamp(0.0, 1.0) : 0.0;

    // Hydration stream watchers
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterProgress = waterGoal > 0 ? (waterMl / waterGoal).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION HEADING ───────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Life & Health',
              style: AscentTextStyles.homeTitle.copyWith(
                color: g.ink,
              ),
            ),
            Text(
              'DAILY PROTOCOL',
              style: AscentTextStyles.homeCaption.copyWith(
                color: g.inkMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── UNIFIED GLASS SURFACE ─────────────────────────────────────
        GlassSurface(
          radius: 24,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // ── 1. MOMENTUM PROGRESS HEADER CELL ─────────────────────
              _buildMomentumProgressCell(context, g, challenge, commitments),

              Divider(height: 1, thickness: 1, color: g.line),

              // ── 2. TWO-COLUMN GRID (MEDICINE + HYDRATION) ────────────
              Row(
                children: [
                  // Cell A: Medicine
                  Expanded(
                    child: _LifeGridCell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/medicine');
                      },
                      borderRight: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.medication_rounded, size: 16, color: g.inkMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Medicine',
                                  style: AscentTextStyles.homeSecondary.copyWith(
                                    color: g.inkSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 16, color: g.inkMuted),
                            ],
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                              children: [
                                TextSpan(text: '$takenMedDoses'),
                                TextSpan(
                                  text: ' of $totalMedDoses doses',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: g.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _NeutralProgressBar(progress: medProgress),
                        ],
                      ),
                    ),
                  ),

                  // Cell B: Hydration
                  Expanded(
                    child: _LifeGridCell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/hydration');
                      },
                      borderRight: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.water_drop_rounded, size: 16, color: g.inkMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Hydration',
                                  style: AscentTextStyles.homeSecondary.copyWith(
                                    color: g.inkSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 16, color: g.inkMuted),
                            ],
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                              children: [
                                TextSpan(text: '$waterMl'),
                                TextSpan(
                                  text: ' of $waterGoal mL',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w400,
                                    color: g.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _NeutralProgressBar(progress: waterProgress),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Divider(height: 1, thickness: 1, color: g.line),

              // ── 3. CHAI & COFFEE BREAK SANCTUARY FOOTER ──────────────
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/chai-break');
                  },
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_cafe_rounded,
                          size: 18,
                          color: g.coral,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Chai & Coffee Break',
                            style: AscentTextStyles.homeHeadline.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: g.ink,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: g.claySoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SANCTUARY',
                            style: AscentTextStyles.homeCaption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: g.clay,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: g.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMomentumProgressCell(
    BuildContext context,
    dynamic g,
    MomentumChallenge? challenge,
    List<MomentumCommitment> commitments,
  ) {
    if (challenge == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/momentum-onboarding');
          },
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: g.claySoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt_rounded, size: 20, color: g.clay),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Momentum',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: g.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '6:00 AM wake, daily walk & workout routine',
                        style: TextStyle(fontSize: 11, color: g.inkMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: g.clay,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final dayNum = _calculateCurrentDayNumber(challenge);
    final total = commitments.length;
    final done = commitments.where((c) => c.isCompleted).length;
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    final nextPending = commitments.where((c) => !c.isCompleted).firstOrNull;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/momentum');
        },
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bolt_rounded, size: 18, color: g.clay),
                      const SizedBox(width: 6),
                      Text(
                        'MOMENTUM • DAY $dayNum OF 30',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: g.ink,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '$done of $total Done',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: g.clay,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 16, color: g.inkMuted),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: g.track,
                  valueColor: AlwaysStoppedAnimation<Color>(g.clay),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                nextPending != null
                    ? 'Next: ${nextPending.title}'
                    : (done > 0 ? 'All commitments complete today! 🔥' : 'Ready to start today\'s routine'),
                style: TextStyle(
                  fontSize: 11,
                  color: g.inkSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifeGridCell extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool borderRight;

  const _LifeGridCell({
    required this.child,
    required this.onTap,
    required this.borderRight,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border(
              right: borderRight ? BorderSide(color: g.line, width: 1.0) : BorderSide.none,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _NeutralProgressBar extends StatelessWidget {
  final double progress;

  const _NeutralProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: g.track,
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: g.inkSecondary,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
