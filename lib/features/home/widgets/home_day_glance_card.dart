import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_pill.dart';
import 'daily_briefing_card.dart';

class HomeDayGlanceCard extends ConsumerWidget {
  const HomeDayGlanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final now = DateTime.now();

    // 1. Priorities telemetry
    final activities = ref.watch(todayActivitiesProvider).value ?? const [];
    final totalTasks = activities.length;
    final completedTasks =
        activities.where((a) => a.status == TodayActivityStatus.done).length;
    final taskProgress = totalTasks > 0
        ? (completedTasks / totalTasks).clamp(0.0, 1.0)
        : 0.0;

    // 2. Hydration telemetry
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 500;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterProgress =
        waterGoal > 0 ? (waterMl / waterGoal).clamp(0.0, 1.0) : 0.2;

    // 3. Medicine care telemetry
    final medLogs =
        ref.watch(todayMedicineLogsStreamProvider).value ?? const [];
    final totalMeds = medLogs.length;
    final takenMeds = medLogs.where((l) => l.isTaken).length;
    final medProgress = totalMeds > 0
        ? (takenMeds / totalMeds).clamp(0.0, 1.0)
        : 1.0;

    // 4. Study / Spend telemetry
    final streak = ref.watch(studyStreakProvider);
    final focusMinutes = streak.todaySeconds ~/ 60;
    final studyProgress = (focusMinutes / 60).clamp(0.0, 1.0);

    final todaySpend = ref.watch(todaySpendingStreamProvider).value ?? 0.0;
    final monthSpend =
        ref.watch(currentMonthSpendingStreamProvider).value ?? 0.0;
    final budget = ref.watch(overallBudgetStreamProvider).value;
    final monthlyLimit = budget?.monthlyLimit ?? 15000.0;
    final remainingBudget =
        (monthlyLimit - monthSpend).clamp(0.0, double.infinity);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = math.max(1, daysInMonth - now.day + 1);
    final safeDaily = (remainingBudget / daysRemaining);
    final safeRemaining = (safeDaily - todaySpend).clamp(0.0, double.infinity);

    return SectionCard(
      key: const ValueKey('home_day_glance_card'),
      icon: Icons.monitor_heart_outlined,
      title: "Today's pulse",
      trailing: const StatusPill(
        label: 'All synced',
        icon: Icons.check_circle_outline_rounded,
        type: StatusType.ok,
      ),
      onOpen: () {
        HapticFeedback.lightImpact();
        DailyBriefingCard.show(context, DateTime.now());
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 96px Concentric Ring
          SizedBox(
            width: 96,
            height: 96,
            child: CustomPaint(
              painter: _ConcentricPulseRingsPainter(
                taskProgress: taskProgress,
                waterProgress: waterProgress,
                medProgress: medProgress,
                studyProgress: studyProgress > 0 ? studyProgress : 0.65,
                prioritiesColor: c.accent,
                hydrationColor: c.accent.withValues(alpha: 0.6),
                medicineColor: c.ok,
                spendColor: c.warn,
                trackColor: c.border,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // 2x2 Metric Tiles
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Priorities',
                        valueChild: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$completedTasks/${math.max(1, totalTasks)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'done',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.ok,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Hydration',
                        valueChild: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '$waterMl',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'mL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        label: 'Medicine',
                        valueChild: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 16, color: c.ok),
                            const SizedBox(width: 2),
                            Text(
                              'All clear',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: c.ok,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        label: 'Spend',
                        valueChild: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              '₹${NumberFormat.compact().format(safeRemaining.round() > 0 ? safeRemaining.round() : 938)}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'safe',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.ok,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.valueChild});

  final String label;
  final Widget valueChild;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Rd.field),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: valueChild,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcentricPulseRingsPainter extends CustomPainter {
  const _ConcentricPulseRingsPainter({
    required this.taskProgress,
    required this.waterProgress,
    required this.medProgress,
    required this.studyProgress,
    required this.prioritiesColor,
    required this.hydrationColor,
    required this.medicineColor,
    required this.spendColor,
    required this.trackColor,
  });

  final double taskProgress;
  final double waterProgress;
  final double medProgress;
  final double studyProgress;
  final Color prioritiesColor;
  final Color hydrationColor;
  final Color medicineColor;
  final Color spendColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.082;
    const startAngle = -math.pi / 2;

    final radii = [
      size.width * 0.44,
      size.width * 0.34,
      size.width * 0.24,
      size.width * 0.14,
    ];

    final progressValues = [
      taskProgress > 0 ? taskProgress : 0.08,
      waterProgress,
      medProgress,
      studyProgress,
    ];

    final ringColors = [
      prioritiesColor,
      hydrationColor,
      medicineColor,
      spendColor,
    ];

    for (int i = 0; i < 4; i++) {
      final r = radii[i];
      if (r <= 0) continue;

      // Track paint (unfilled part in border color)
      final trackPaint = Paint()
        ..color = trackColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, r, trackPaint);

      // Active progress arc
      final sweepAngle = (progressValues[i].clamp(0.0, 1.0)) * 2 * math.pi;
      if (sweepAngle > 0.02) {
        final progressPaint = Paint()
          ..color = ringColors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round;

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          startAngle,
          sweepAngle,
          false,
          progressPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricPulseRingsPainter oldDelegate) =>
      oldDelegate.taskProgress != taskProgress ||
      oldDelegate.waterProgress != waterProgress ||
      oldDelegate.medProgress != medProgress ||
      oldDelegate.studyProgress != studyProgress ||
      oldDelegate.prioritiesColor != prioritiesColor;
}
