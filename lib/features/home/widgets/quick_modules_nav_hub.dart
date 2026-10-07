import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/walk/walk_tracking_service.dart';
import '../../../shared/widgets/glass_surface.dart';

/// Level 2 · Secondary: Life
/// Redesigned according to Ascent Home Redesign spec:
/// - Single unified glass card with a 2x2 grid.
/// - Chai & Coffee Break as footer row.
/// - Progress bars use neutral ink.
/// - 44dp hit targets with instant hydration quick add.
class QuickModulesNavHub extends ConsumerWidget {
  const QuickModulesNavHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;

    // Stream watchers for the 4 life modules
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterProgress = waterGoal > 0 ? (waterMl / waterGoal).clamp(0.0, 1.0) : 0.0;

    final allHabits = ref.watch(allHabitsStreamProvider).value ?? [];
    final doneHabitIds = ref.watch(todayCompletedHabitIdsStreamProvider).value ?? {};
    final habitsProgress = allHabits.isNotEmpty ? (doneHabitIds.length / allHabits.length).clamp(0.0, 1.0) : 0.0;

    final walkState = ref.watch(walkTrackingProvider);
    final todayWalkMeters = ref.watch(todayWalkDistanceStreamProvider).value ?? 0.0;
    final isWalkActive = walkState.status == WalkTrackingStatus.tracking;
    final distanceKm = isWalkActive ? walkState.distanceKm : (todayWalkMeters / 1000.0);
    final walkProgress = (distanceKm / 5.0).clamp(0.0, 1.0);

    final todaySpending = ref.watch(todaySpendingStreamProvider).value ?? 0.0;

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
              'Life',
              style: AscentTextStyles.homeTitle.copyWith(
                color: g.ink,
              ),
            ),
            Text(
              'LIFE MODULES',
              style: AscentTextStyles.homeCaption.copyWith(
                color: g.inkMuted,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // ── UNIFIED GLASS CARD (2x2 GRID + CHAI FOOTER) ───────────────
        GlassSurface(
          radius: 24,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // 2x2 Grid
              Row(
                children: [
                  // Cell 1: Hydration
                  Expanded(
                    child: _LifeGridCell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/hydration');
                      },
                      borderRight: true,
                      borderBottom: true,
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
                              // Quick + Button
                              SizedBox(
                                width: 34,
                                height: 34,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      HapticFeedback.mediumImpact();
                                      await ref.read(databaseProvider).waterDao.addWater(250);
                                    },
                                    borderRadius: BorderRadius.circular(17),
                                    child: Center(
                                      child: Container(
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: g.claySoft,
                                        ),
                                        child: Icon(Icons.add_rounded, size: 16, color: g.clay),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                              children: [
                                TextSpan(text: '$waterMl'),
                                TextSpan(
                                  text: ' of $waterGoal mL',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: g.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          _NeutralProgressBar(progress: waterProgress),
                        ],
                      ),
                    ),
                  ),

                  // Cell 2: Habits
                  Expanded(
                    child: _LifeGridCell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/habits');
                      },
                      borderRight: false,
                      borderBottom: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.checklist_rounded, size: 16, color: g.inkMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Habits',
                                style: AscentTextStyles.homeSecondary.copyWith(
                                  color: g.inkSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                              children: [
                                TextSpan(text: '${doneHabitIds.length}'),
                                TextSpan(
                                  text: ' of ${allHabits.length} today',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: g.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          _NeutralProgressBar(progress: habitsProgress),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Row(
                children: [
                  // Cell 3: Walk & Run
                  Expanded(
                    child: _LifeGridCell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/walk');
                      },
                      borderRight: true,
                      borderBottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_walk_rounded, size: 16, color: g.inkMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Walk & Run',
                                style: AscentTextStyles.homeSecondary.copyWith(
                                  color: g.inkSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                              children: [
                                TextSpan(text: distanceKm.toStringAsFixed(1)),
                                TextSpan(
                                  text: ' of 5 km',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: g.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          _NeutralProgressBar(progress: walkProgress),
                        ],
                      ),
                    ),
                  ),

                  // Cell 4: Money
                  Expanded(
                    child: _LifeGridCell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/money');
                      },
                      borderRight: false,
                      borderBottom: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.currency_rupee_rounded, size: 16, color: g.inkMuted),
                              const SizedBox(width: 6),
                              Text(
                                'Money',
                                style: AscentTextStyles.homeSecondary.copyWith(
                                  color: g.inkSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.bricolageGrotesque(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                              children: [
                                TextSpan(text: '₹${todaySpending.toStringAsFixed(0)}'),
                                TextSpan(
                                  text: ' logged',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    color: g.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          const SizedBox(height: 3), // maintains uniform height with progress bars
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ── FOOTER ROW: CHAI & COFFEE BREAK SANCTUARY ───────────
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: g.line, width: 1.0)),
                ),
                child: Material(
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
                          Icon(Icons.coffee_rounded, size: 18, color: g.inkMuted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Chai & Coffee Break',
                              style: AscentTextStyles.homeHeadline.copyWith(
                                fontSize: 15,
                                color: g.ink,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
  final bool borderBottom;

  const _LifeGridCell({
    required this.child,
    required this.onTap,
    required this.borderRight,
    required this.borderBottom,
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
              bottom: borderBottom ? BorderSide(color: g.line, width: 1.0) : BorderSide.none,
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
