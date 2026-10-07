import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/walk/walk_tracking_service.dart';

class QuickModulesNavHub extends StatefulWidget {
  const QuickModulesNavHub({super.key});

  @override
  State<QuickModulesNavHub> createState() => _QuickModulesNavHubState();
}

class _QuickModulesNavHubState extends State<QuickModulesNavHub> {
  bool _isChaiExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE28B57).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.coffee_rounded,
                    size: 12,
                    color: Color(0xFFE28B57),
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'LIFE MODULES',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
            Text(
              'Habits · Chai · Health',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 10.5,
                color: context.textMuted.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Bento Item 1: Hero Chai & Coffee Break Sanctuary (Maximizable / Minimizable)
        _ChaiBreakBentoHero(
          isExpanded: _isChaiExpanded,
          onToggleExpand: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isChaiExpanded = !_isChaiExpanded;
            });
          },
        ),

        const SizedBox(height: 10),

        // Bento Row: Asymmetrical split cards (Hydration Square + Habits Square)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Hydration Square Card (with quick inline log)
            const Expanded(
              child: _HydrationBentoCard(),
            ),
            const SizedBox(width: 10),
            // Right: Habits Square Card
            const Expanded(
              child: _HabitsBentoCard(),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Bento Row: Horizontal split for Walk & Run + Money
        Row(
          children: const [
            Expanded(child: _WalkBentoCard()),
            SizedBox(width: 10),
            Expanded(child: _MoneyBentoCard()),
          ],
        ),
      ],
    );
  }
}

/// Maximizable / Minimizable Hero Bento Card for Chai & Coffee Break
class _ChaiBreakBentoHero extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const _ChaiBreakBentoHero({
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    const accent = Color(0xFFE28B57);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/chai-break');
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.45 : 0.35),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withValues(alpha: 0.5)),
                    ),
                    child: const Center(
                      child: Icon(Icons.coffee_rounded, size: 18, color: accent),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'SANCTUARY',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ambient soundscapes • steam wisp • mindful flow',
                          style: GoogleFonts.plusJakartaSans(
                            color: context.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Maximize / Minimize toggle button
                  IconButton(
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(
                      isExpanded ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                      color: accent,
                    ),
                    tooltip: isExpanded ? 'Minimize card' : 'Maximize quick actions',
                    onPressed: onToggleExpand,
                  ),
                ],
              ),

              // Maximized content
              if (isExpanded) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.bgSurface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divider.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _PresetQuickPill(
                        label: '5m Chai',
                        accent: accent,
                        onTap: () => context.push('/chai-break'),
                      ),
                      _PresetQuickPill(
                        label: '10m Coffee',
                        accent: accent,
                        onTap: () => context.push('/chai-break'),
                      ),
                      _PresetQuickPill(
                        label: '15m Reset',
                        accent: accent,
                        onTap: () => context.push('/chai-break'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Includes non-zero lecture flow resume guarantee',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: context.textMuted,
                      ),
                    ),
                    Text(
                      'Open Sanctuary ›',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetQuickPill extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _PresetQuickPill({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: accent,
          ),
        ),
      ),
    );
  }
}

/// Square Bento Tile for Hydration with quick log button
class _HydrationBentoCard extends ConsumerWidget {
  const _HydrationBentoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterPercent = waterGoal > 0 ? ((waterMl / waterGoal) * 100).toInt() : 0;
    final progress = waterGoal > 0 ? (waterMl / waterGoal).clamp(0.0, 1.0) : 0.0;
    const color = Color(0xFF38BDF8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/hydration');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.divider.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.water_drop_rounded, size: 15, color: color),
                  ),
                  Text(
                    '$waterPercent%',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Hydration',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$waterMl / $waterGoal mL',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3.5,
                  backgroundColor: context.divider.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 8),
              // Inline Quick-Add Button
              InkWell(
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await ref.read(databaseProvider).waterDao.addWater(250);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '+250 mL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Square Bento Tile for Daily Habits
class _HabitsBentoCard extends ConsumerWidget {
  const _HabitsBentoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allHabits = ref.watch(allHabitsStreamProvider).value ?? [];
    final doneHabitIds = ref.watch(todayCompletedHabitIdsStreamProvider).value ?? {};
    final progress = allHabits.isNotEmpty ? (doneHabitIds.length / allHabits.length).clamp(0.0, 1.0) : 0.0;
    const color = Color(0xFF8B5CF6);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/habits');
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.divider.withValues(alpha: 0.7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.fact_check_rounded, size: 15, color: color),
                  ),
                  Text(
                    allHabits.isEmpty ? '0/0' : '${doneHabitIds.length}/${allHabits.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Habits',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                allHabits.isEmpty ? 'Daily routines' : '${(progress * 100).toInt()}% completed',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3.5,
                  backgroundColor: context.divider.withValues(alpha: 0.4),
                  valueColor: const AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'Check Routine ›',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact Horizontal Bento Tile for Walk & Run
class _WalkBentoCard extends ConsumerWidget {
  const _WalkBentoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkState = ref.watch(walkTrackingProvider);
    final todayWalkMeters = ref.watch(todayWalkDistanceStreamProvider).value ?? 0.0;
    final isWalkActive = walkState.status == WalkTrackingStatus.tracking;
    final distanceKm = isWalkActive ? walkState.distanceKm : (todayWalkMeters / 1000.0);
    final progress = (distanceKm / 5.0).clamp(0.0, 1.0);
    const color = Color(0xFF10B981);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/walk');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.divider.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.directions_walk_rounded, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Walk & Run',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} / 5.0 km',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2.5,
                        backgroundColor: context.divider.withValues(alpha: 0.4),
                        valueColor: const AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact Horizontal Bento Tile for Money
class _MoneyBentoCard extends ConsumerWidget {
  const _MoneyBentoCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySpending = ref.watch(todaySpendingStreamProvider).value ?? 0.0;
    const color = Color(0xFFF59E0B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/money');
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.divider.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 15, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Money',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: context.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '₹${todaySpending.toStringAsFixed(0)} logged',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
