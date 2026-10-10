import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/animated_water_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';

class HydrationScreen extends ConsumerStatefulWidget {
  const HydrationScreen({super.key});

  @override
  ConsumerState<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends ConsumerState<HydrationScreen> {
  final TextEditingController _goalController = TextEditingController();

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _showSetGoalDialog(int currentGoal) {
    _goalController.text = currentGoal.toString();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: context.divider.withValues(alpha: 0.8), width: 1),
        ),
        title: Text(
          'Daily Water Target',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set your ideal daily hydration goal in milliliters (mL):',
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _goalController,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: AscentTextStyles.displaySmall.copyWith(color: context.accentPrimary),
              decoration: InputDecoration(
                suffixText: 'mL',
                suffixStyle: TextStyle(color: context.textMuted),
                filled: true,
                fillColor: context.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: context.accentPrimary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              final newGoal = int.tryParse(_goalController.text.trim());
              if (newGoal != null && newGoal > 0) {
                HapticFeedback.mediumImpact();
                await ref.read(waterDaoProvider).setDailyWaterGoal(newGoal);
              }
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: const Text('Save Goal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayWaterAsync = ref.watch(todayWaterMlStreamProvider);
    final goalAsync = ref.watch(dailyWaterGoalStreamProvider);
    final logsAsync = ref.watch(todayWaterLogsStreamProvider);
    final historyAsync = ref.watch(past7DaysHydrationStreamProvider);

    final currentMl = todayWaterAsync.value ?? 0;
    final targetMl = goalAsync.value ?? 2500;
    final percent = ((currentMl / targetMl) * 100).toInt();

    final g = context.glass;

    return AscentScaffold(
      title: 'Hydration Tracker',
      subtitle: 'Daily fluid health & vitality',
      glow2: g.slateSoft,
      actions: [
        IconButton(
          tooltip: 'Edit Daily Goal',
          icon: Icon(Icons.tune_rounded, color: g.clay),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showSetGoalDialog(targetMl);
          },
        ),
      ],
      body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          children: [
            // 1. Standalone Fluid Animated Card (Isolated strictly on this screen)
            const AnimatedWaterCard(),

            const SizedBox(height: 16),

            // 2. Hydration Stats Overview (Transparent Bordered Card)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: context.bgSurface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: context.divider.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'CONSUMED',
                    value: '$currentMl mL',
                    icon: Icons.water_drop_rounded,
                    color: g.clay,
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: context.divider.withValues(alpha: 0.5),
                  ),
                  _StatItem(
                    label: 'TARGET',
                    value: '$targetMl mL',
                    icon: Icons.flag_rounded,
                    color: context.accentPrimary,
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: context.divider.withValues(alpha: 0.5),
                  ),
                  _StatItem(
                    label: 'COMPLETION',
                    value: '$percent%',
                    icon: Icons.check_circle_rounded,
                    color: percent >= 100 ? const Color(0xFF10B981) : g.clay,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 7-Day Hydration History & Trend Graph
            historyAsync.when(
              data: (history) => _HydrationHistorySection(history: history),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // 3. Section Header: Today's Intake Log
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TODAY\'S LOGS',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: context.textMuted,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${logsAsync.value?.length ?? 0} entries',
                  style: AscentTextStyles.captionMedium.copyWith(color: context.textMuted),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // 4. Logs List
            logsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Unable to load logs: $err', style: TextStyle(color: context.textMuted)),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: context.bgSurface.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.divider.withValues(alpha: 0.4),
                        width: 0.9,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.water_drop_outlined, size: 36, color: context.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 10),
                          Text(
                            'No hydration logs yet today',
                            style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap the quick intake buttons above to log water',
                            style: AscentTextStyles.captionMedium.copyWith(color: context.textMuted.withValues(alpha: 0.7)),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, index) {
                    final log = logs[index];
                    final timeStr = DateFormat('h:mm a').format(log.timestamp);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: context.bgSurface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: context.divider.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: g.claySoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.local_drink_rounded,
                              size: 18,
                              color: g.clay,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '+${log.amountMl} mL Water',
                                  style: AscentTextStyles.bodyMedium.copyWith(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeStr,
                                  style: AscentTextStyles.captionMedium.copyWith(
                                    color: context.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded, size: 20, color: context.textMuted),
                            tooltip: 'Delete Entry',
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await ref.read(waterDaoProvider).deleteWater(log.id);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 24),
          ],
        ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: AscentTextStyles.bodyMedium.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AscentTextStyles.captionMedium.copyWith(
            color: context.textMuted,
            fontSize: 10,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _HydrationHistorySection extends StatelessWidget {
  final List<DailyHydrationRecord> history;

  const _HydrationHistorySection({required this.history});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    if (history.isEmpty) return const SizedBox.shrink();

    final totalVolume = history.fold<int>(0, (sum, r) => sum + r.totalMl);
    final avgVolume = (totalVolume / history.length).round();
    final daysMet = history.where((r) => r.isGoalMet).length;

    final maxVal = history.fold<int>(2500, (max, r) => math.max(max, math.max(r.totalMl, r.goalMl)));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.bgSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.divider.withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: g.claySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.insights_rounded, size: 16, color: g.clay),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '7-DAY HYDRATION TREND',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.textPrimary,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: daysMet >= 4 ? const Color(0xFF10B981).withValues(alpha: 0.15) : g.claySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$daysMet/7 Goals Met',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: daysMet >= 4 ? const Color(0xFF10B981) : g.clay,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 7-day Bar Chart
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: history.map((record) {
                final heightFactor = (record.totalMl / maxVal).clamp(0.06, 1.0);
                final now = DateTime.now();
                final isToday = record.date.day == now.day &&
                    record.date.month == now.month &&
                    record.date.year == now.year;
                final dayLabel = DateFormat('E').format(record.date).substring(0, 1);

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      record.totalMl > 0 ? '${(record.totalMl / 1000).toStringAsFixed(1)}L' : '0',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: record.isGoalMet ? const Color(0xFF10B981) : context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 26,
                      height: (74 * heightFactor).toDouble(),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: record.isGoalMet
                              ? [const Color(0xFF34D399), const Color(0xFF059669)]
                              : (isToday
                                  ? [g.clay, g.clay.withValues(alpha: 0.8)]
                                  : [g.clay.withValues(alpha: 0.45), g.claySoft.withValues(alpha: 0.3)]),
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: isToday
                            ? Border.all(color: g.clay, width: 1.5)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isToday ? 'Today' : dayLabel,
                      style: GoogleFonts.inter(
                        fontSize: isToday ? 10.5 : 11,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? g.clay : context.textMuted,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: context.divider.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '7-Day Average: $avgVolume mL / day',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: context.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Total: ${(totalVolume / 1000).toStringAsFixed(1)} L',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  color: g.clay,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

