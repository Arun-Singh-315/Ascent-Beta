import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/walk/walk_tracking_service.dart';

class QuickModulesNavHub extends StatelessWidget {
  const QuickModulesNavHub({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'LIFE MODULES',
              style: AscentTextStyles.labelSmall.copyWith(
                color: context.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Tap to open section',
              style: AscentTextStyles.captionMedium.copyWith(color: context.textMuted, fontSize: 10.5),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 2x2 Primary Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.1,
          children: const [
            _HydrationTile(),
            _WalkTile(),
            _MoneyTile(),
            _HabitTile(),
          ],
        ),

        const SizedBox(height: 8),

        // Cozy Chai & Coffee Break Trigger Card
        const _ChaiBreakTriggerCard(),
      ],
    );
  }
}

class _ChaiBreakTriggerCard extends StatelessWidget {
  const _ChaiBreakTriggerCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/chai-break');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFE28B57).withValues(alpha: context.isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFE28B57).withValues(alpha: context.isDark ? 0.4 : 0.3),
              width: 0.9,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFE28B57).withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.coffee_rounded, size: 16, color: Color(0xFFE28B57)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Chai & Coffee Break',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE28B57).withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '5–15 MIN',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE28B57),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Mindful pause with ambient sounds & steam',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFFE28B57)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HydrationTile extends ConsumerWidget {
  const _HydrationTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterPercent = waterGoal > 0 ? ((waterMl / waterGoal) * 100).toInt() : 0;
    final progress = waterGoal > 0 ? (waterMl / waterGoal).clamp(0.0, 1.0) : 0.0;
    final color = const Color(0xFF38BDF8);

    return _NavHubCard(
      title: 'Hydration',
      subtitle: '$waterMl / $waterGoal mL ($waterPercent%)',
      icon: Icons.water_drop_rounded,
      color: color,
      progress: progress,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/hydration');
      },
    );
  }
}

class _WalkTile extends ConsumerWidget {
  const _WalkTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkState = ref.watch(walkTrackingProvider);
    final todayWalkMeters = ref.watch(todayWalkDistanceStreamProvider).value ?? 0.0;
    final isWalkActive = walkState.status == WalkTrackingStatus.tracking;
    final distanceKm = isWalkActive ? walkState.distanceKm : (todayWalkMeters / 1000.0);
    final walkSubtitle = isWalkActive
        ? 'Active · ${distanceKm.toStringAsFixed(2)} km'
        : todayWalkMeters > 0
            ? '${distanceKm.toStringAsFixed(2)} km walked'
            : 'Goal 5.0 km · Start';
    final progress = (distanceKm / 5.0).clamp(0.0, 1.0);
    final color = isWalkActive ? const Color(0xFF22C55E) : const Color(0xFF10B981);

    return _NavHubCard(
      title: 'Walk & Run',
      subtitle: walkSubtitle,
      icon: Icons.directions_walk_rounded,
      color: color,
      progress: progress,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/walk');
      },
    );
  }
}

class _MoneyTile extends ConsumerWidget {
  const _MoneyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySpending = ref.watch(todaySpendingStreamProvider).value ?? 0.0;
    final budget = ref.watch(overallBudgetStreamProvider).value;
    final moneySubtitle = budget != null && budget.monthlyLimit > 0
        ? '₹${todaySpending.toStringAsFixed(0)} · Lim ₹${budget.monthlyLimit.toStringAsFixed(0)}'
        : '₹${todaySpending.toStringAsFixed(0)} logged';
    final color = const Color(0xFFF59E0B);

    return _NavHubCard(
      title: 'Money',
      subtitle: moneySubtitle,
      icon: Icons.account_balance_wallet_rounded,
      color: color,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/money');
      },
    );
  }
}

class _HabitTile extends ConsumerWidget {
  const _HabitTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHabits = ref.watch(allHabitsStreamProvider).value ?? [];
    final doneHabitIds = ref.watch(todayCompletedHabitIdsStreamProvider).value ?? {};
    final habitSubtitle = allHabits.isEmpty
        ? 'Daily routines'
        : '${doneHabitIds.length}/${allHabits.length} completed';
    final progress = allHabits.isNotEmpty ? (doneHabitIds.length / allHabits.length).clamp(0.0, 1.0) : 0.0;
    final color = const Color(0xFF8B5CF6);

    return _NavHubCard(
      title: 'Habits',
      subtitle: habitSubtitle,
      icon: Icons.fact_check_rounded,
      color: color,
      progress: progress,
      onTap: () {
        HapticFeedback.lightImpact();
        context.push('/habits');
      },
    );
  }
}

class _NavHubCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double? progress;
  final VoidCallback onTap;

  const _NavHubCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.divider.withValues(alpha: 0.6),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: color),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          style: GoogleFonts.jetBrainsMono(
                            color: context.textMuted,
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded, size: 12, color: context.textMuted.withValues(alpha: 0.5)),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 2.5,
                    backgroundColor: context.divider.withValues(alpha: 0.4),
                    valueColor: AlwaysStoppedAnimation(color.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
