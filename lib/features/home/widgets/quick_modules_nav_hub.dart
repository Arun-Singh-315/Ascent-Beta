import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../challenge/challenge_providers.dart';
import '../../challenge/domain/challenge_pace_engine.dart';

/// Level 2 · Secondary: Life & Health Hub
/// Clean, balanced layout:
/// - Challenge banner (full-width, top of card).
/// - Medicine prescription tracker with daily dose compliance.
/// - Hydration with instant +250mL action.
/// - Chai & Coffee Break sanctuary footer.
class QuickModulesNavHub extends ConsumerWidget {
  const QuickModulesNavHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;

    // Medicine stream watchers
    final todayMedicineLogs = ref.watch(todayMedicineLogsStreamProvider).value ?? [];
    final totalMedDoses = todayMedicineLogs.length;
    final takenMedDoses = todayMedicineLogs.where((l) => l.isTaken).length;
    final medProgress = totalMedDoses > 0 ? (takenMedDoses / totalMedDoses).clamp(0.0, 1.0) : 0.0;

    // Hydration stream watchers
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterProgress = waterGoal > 0 ? (waterMl / waterGoal).clamp(0.0, 1.0) : 0.0;

    // Challenge watchers
    final challengeAsync = ref.watch(activeChallengeProvider);
    final challenge = challengeAsync.value;
    final proofsAsync = challenge == null
        ? null
        : ref.watch(challengeProofsProvider(challenge.id));
    final proofs = proofsAsync?.value ?? const [];
    final progress = challenge == null ? null : progressForChallenge(challenge, proofs);

    final challengeStatusColor = switch (progress?.status) {
      ChallengePaceStatus.ahead ||
      ChallengePaceStatus.onTrack ||
      ChallengePaceStatus.complete =>
        const Color(0xFF4E9B6B),
      ChallengePaceStatus.atRisk => const Color(0xFFD99A37),
      ChallengePaceStatus.failed => const Color(0xFFCA5C54),
      null => g.clay,
    };

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
          ],
        ),

        const SizedBox(height: 12),

        // ── UNIFIED GLASS SURFACE ─────────────────────────────────────
        GlassSurface(
          radius: 24,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // ── 0. CHALLENGE BANNER (FULL-WIDTH, TOP) ────────────────
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/momentum');
                  },
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: g.line, width: 1.0),
                      ),
                    ),
                    child: challenge == null
                        ? Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: g.claySoft,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.flag_outlined,
                                  size: 16,
                                  color: g.clay,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Set a Challenge — track real progress',
                                  style: AscentTextStyles.homeSecondary.copyWith(
                                    color: g.inkMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 16, color: g.inkMuted),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: challengeStatusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.bolt_rounded,
                                      size: 16,
                                      color: challengeStatusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      challenge.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AscentTextStyles.homeSecondary.copyWith(
                                        color: g.ink,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${progress?.percent ?? 0}%',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: challengeStatusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded, size: 16, color: g.inkMuted),
                                ],
                              ),
                              const SizedBox(height: 7),
                              // Slim progress bar — clean, no labels
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: (progress?.percent ?? 0) / 100,
                                  minHeight: 3,
                                  backgroundColor: g.track,
                                  valueColor: AlwaysStoppedAnimation(challengeStatusColor),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              // ── 1. TWO-COLUMN GRID (MEDICINE + HYDRATION) ────────────
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
                      borderRadius: BorderRadius.zero,
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
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 17,
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
                      borderRadius: BorderRadius.zero,
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
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.bricolageGrotesque(
                                      fontSize: 17,
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
                              ),
                              // Instant 1-tap +250 mL Habit Button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () async {
                                    HapticFeedback.mediumImpact();
                                    await ref.read(waterDaoProvider).addWater(250);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: g.claySoft,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: g.clay.withValues(alpha: 0.5),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.add_rounded, size: 12, color: g.clay),
                                        Text(
                                          '250',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: g.clay,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
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

              // ── 2. CHAI & COFFEE BREAK FOOTER ──────────────
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_cafe_rounded,
                          size: 18,
                          color: g.coral,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Chai & Coffee Break',
                          style: AscentTextStyles.homeHeadline.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: g.ink,
                          ),
                        ),
                        const SizedBox(width: 4),
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
}

class _LifeGridCell extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool borderRight;
  final BorderRadius? borderRadius;

  const _LifeGridCell({
    required this.child,
    required this.onTap,
    required this.borderRight,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
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
