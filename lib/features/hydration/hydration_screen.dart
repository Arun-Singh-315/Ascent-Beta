import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/animated_water_card.dart';

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

    final currentMl = todayWaterAsync.value ?? 0;
    final targetMl = goalAsync.value ?? 2500;
    final percent = ((currentMl / targetMl) * 100).toInt();

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () {
            HapticFeedback.lightImpact();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hydration Tracker',
              style: AscentTextStyles.headlineMedium.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Daily Fluid Health & Vitality',
              style: AscentTextStyles.captionMedium.copyWith(color: context.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Daily Goal',
            icon: Icon(Icons.tune_rounded, color: context.accentPrimary),
            onPressed: () => _showSetGoalDialog(targetMl),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
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
                    color: const Color(0xFF38BDF8),
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
                    color: const Color(0xFF60A5FA),
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
                    color: percent >= 100 ? const Color(0xFF34D399) : context.accentPrimary,
                  ),
                ],
              ),
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
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_drink_rounded,
                              size: 18,
                              color: Color(0xFF38BDF8),
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
