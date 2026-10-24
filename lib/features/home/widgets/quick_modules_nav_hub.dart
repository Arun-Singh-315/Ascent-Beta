import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/merlot_palette.dart';
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
    final todayMedicineLogs =
        ref.watch(todayMedicineLogsStreamProvider).value ?? [];
    final totalMedDoses = todayMedicineLogs.length;
    final takenMedDoses = todayMedicineLogs.where((l) => l.isTaken).length;
    final medProgress = totalMedDoses > 0
        ? (takenMedDoses / totalMedDoses).clamp(0.0, 1.0)
        : 0.0;

    // Hydration stream watchers
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterProgress = waterGoal > 0
        ? (waterMl / waterGoal).clamp(0.0, 1.0)
        : 0.0;

    // Challenge watchers
    final challengeAsync = ref.watch(activeChallengeProvider);
    final challenge = challengeAsync.value;
    final proofsAsync = challenge == null
        ? null
        : ref.watch(challengeProofsProvider(challenge.id));
    final proofs = proofsAsync?.value ?? const [];
    final progress = challenge == null
        ? null
        : progressForChallenge(challenge, proofs);

    final challengeStatusColor = switch (progress?.status) {
      ChallengePaceStatus.ahead ||
      ChallengePaceStatus.onTrack ||
      ChallengePaceStatus.complete => AppPalette.colorFF4E9B6B,
      ChallengePaceStatus.atRisk => AppPalette.colorFFD99A37,
      ChallengePaceStatus.failed => AppPalette.colorFFCA5C54,
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
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── UNIFIED GLASS SURFACE ─────────────────────────────────────
        GlassSurface(
          radius: 24,
          fillColor: Theme.of(context).brightness == Brightness.light
              ? (g.merlot ? MerlotPalette.surface : Colors.white)
              : null,
          customBorder: Theme.of(context).brightness == Brightness.light
              ? Border.all(
                  color: g.merlot ? MerlotPalette.line : g.edge.withValues(alpha: .45),
                  width: g.merlot ? 0.75 : 1,
                )
              : null,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // ── 0. CHALLENGE BANNER (FULL-WIDTH, TOP) ────────────────
              Material(
                color: AppPalette.transparent,
                child: AppTapArea(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/momentum');
                  },
                  borderRadius: const BorderRadius.vertical(
                    top: AppGeometry.radiusr24,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s16,
                      vertical: AppSpace.s13,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: g.line,
                          width: AppBorderScale.w1point0,
                        ),
                      ),
                    ),
                    child: challenge == null
                        ? Row(
                            children: [
                              AppTag(
                                width: 30,
                                height: 30,
                                nightDecoration: BoxDecoration(
                                  color: g.claySoft,
                                  borderRadius: AppGeometry.roundedr8,
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
                                  style: AscentTextStyles.homeSecondary
                                      .copyWith(color: g.inkMuted)
                                      .merge(AppTypeRoles.typeRole15),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: g.inkMuted,
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  AppTag(
                                    width: 30,
                                    height: 30,
                                    nightDecoration: BoxDecoration(
                                      color: challengeStatusColor.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: AppGeometry.roundedr8,
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
                                      style: AscentTextStyles.homeSecondary
                                          .copyWith(color: g.ink)
                                          .merge(AppTypeRoles.typeRole8),
                                    ),
                                  ),
                                  Text(
                                    '${progress?.percent ?? 0}%',
                                    style: AppTypography.jetBrainsMono12W70063(
                                      color: challengeStatusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: g.inkMuted,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              // Progress bar with visible track and clean geometry
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: g.track,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: g.line.withValues(alpha: 0.5),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: LinearProgressIndicator(
                                    value: (progress?.percent ?? 0) / 100,
                                    minHeight: 5,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation(
                                      challengeStatusColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

              // ── 1. TWO-COLUMN GRID (MEDICINE + HYDRATION) ────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked =
                      constraints.maxWidth < 320 ||
                      MediaQuery.textScalerOf(context).scale(14) > 18;

                  final medicineCell = _LifeGridCell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/medicine');
                    },
                    borderRight: !stacked,
                    borderRadius: BorderRadius.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.medication_rounded,
                                  size: 16,
                                  color: g.inkMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Medicine',
                                    style: AscentTextStyles.homeSecondary
                                        .copyWith(color: g.inkSecondary)
                                        .merge(AppTypeRoles.typeRole15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: g.inkMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            RichText(
                              textScaler: MediaQuery.textScalerOf(context),
                              text: TextSpan(
                                style:
                                    AppTypography.bricolageGrotesque17W600107(
                                      color: g.ink,
                                    ).copyWith(fontSize: 22),
                                children: [
                                  TextSpan(text: '$takenMedDoses'),
                                  TextSpan(
                                    text: ' of $totalMedDoses doses',
                                    style: AppTypography.dmSans11W400108(
                                      color: g.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            _NeutralProgressBar(
                              key: const ValueKey('medicine_progress_bar'),
                              progress: medProgress,
                              fillColor: g.clay,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  final hydrationCell = _LifeGridCell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/hydration');
                    },
                    borderRight: false,
                    borderRadius: BorderRadius.zero,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.water_drop_rounded,
                                  size: 16,
                                  color: g.inkMuted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Hydration',
                                    style: AscentTextStyles.homeSecondary
                                        .copyWith(color: g.inkSecondary)
                                        .merge(AppTypeRoles.typeRole15),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: g.inkMuted,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: RichText(
                                    textScaler: MediaQuery.textScalerOf(
                                      context,
                                    ),
                                    text: TextSpan(
                                      style:
                                          AppTypography.bricolageGrotesque17W600107(
                                            color: g.ink,
                                          ).copyWith(fontSize: 22),
                                      children: [
                                        TextSpan(text: '$waterMl'),
                                        TextSpan(
                                          text: ' of $waterGoal mL',
                                          style:
                                              AppTypography.dmSans11W400108(
                                                color: g.inkMuted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpace.s6),
                                // Instant 1-tap +250 mL Habit Button
                                Material(
                                  color: AppPalette.transparent,
                                  child: AppTapArea(
                                    onTap: () async {
                                      HapticFeedback.mediumImpact();
                                      await ref
                                          .read(waterDaoProvider)
                                          .addWater(250);
                                    },
                                    borderRadius: AppGeometry.roundedr8,
                                    child: AppTag(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpace.s7,
                                        vertical: AppSpace.s3,
                                      ),
                                      nightDecoration: BoxDecoration(
                                        color: g.claySoft,
                                        borderRadius: AppGeometry.roundedr8,
                                        border: Border.all(
                                          color: g.clay.withValues(
                                            alpha: 0.2,
                                          ),
                                          width: AppBorderScale.w1point0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.add_rounded,
                                            size: 12,
                                            color: g.clay,
                                          ),
                                          Text(
                                            '250',
                                            style:
                                                AppTypography.jetBrainsMono11W7002(
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
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 8),
                            _NeutralProgressBar(
                              key: const ValueKey('hydration_progress_bar'),
                              progress: waterProgress,
                              fillColor: g.clay,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );

                  if (stacked) {
                    return Column(
                      children: [
                        medicineCell,
                        AppDivider(height: 1, thickness: 1, color: g.line),
                        hydrationCell,
                      ],
                    );
                  }

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: medicineCell),
                        Expanded(child: hydrationCell),
                      ],
                    ),
                  );
                },
              ),

              AppDivider(height: 1, thickness: 1, color: g.line),

              // ── 2. CHAI & COFFEE BREAK FOOTER ──────────────
              Material(
                color: AppPalette.transparent,
                child: AppTapArea(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/chai-break');
                  },
                  borderRadius: const BorderRadius.vertical(
                    bottom: AppGeometry.radiusr24,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s16,
                      vertical: AppSpace.s14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_cafe_rounded,
                          size: 18,
                          color: g.coral,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Chai & Coffee Break',
                            style: AscentTextStyles.homeHeadline
                                .copyWith(color: g.ink)
                                .merge(AppTypeRoles.typeRole61),
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
      color: AppPalette.transparent,
      child: AppTapArea(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(AppSpace.s14),
          decoration: BoxDecoration(
            border: Border(
              right: borderRight
                  ? BorderSide(color: g.line, width: AppBorderScale.w1point0)
                  : BorderSide.none,
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
  final Color? fillColor;

  const _NeutralProgressBar({
    super.key,
    required this.progress,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: g.track,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: g.line.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: progress.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: fillColor ?? g.clay,
            borderRadius: BorderRadius.circular(2.5),
          ),
        ),
      ),
    );
  }
}
