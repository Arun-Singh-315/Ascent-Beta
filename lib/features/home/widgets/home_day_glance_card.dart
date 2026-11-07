import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/dimension_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_card.dart';
import 'daily_briefing_card.dart';

/// iOS Apple Fitness/Health-style concentric glance card on Home.
///
/// Features 3 concentric momentum rings:
/// 1. Outer: Tasks / Priorities completed today.
/// 2. Middle: Hydration intake progress.
/// 3. Inner: Medicine prescription adherence.
///
/// Fully responsive and immune to overflows at 320px width & 2.0x font scaling.
class HomeDayGlanceCard extends ConsumerWidget {
  const HomeDayGlanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;

    // 1. Task telemetry
    final activities = ref.watch(todayActivitiesProvider).value ?? const [];
    final totalTasks = activities.length;
    final completedTasks = activities.where((a) => a.status == TodayActivityStatus.done).length;
    final taskProgress = totalTasks > 0
        ? (completedTasks / totalTasks).clamp(0.0, 1.0)
        : 0.0;

    // 2. Hydration telemetry
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterProgress = waterGoal > 0
        ? (waterMl / waterGoal).clamp(0.0, 1.0)
        : 0.0;

    // 3. Medicine telemetry
    final medLogs = ref.watch(todayMedicineLogsStreamProvider).value ?? const [];
    final totalMeds = medLogs.length;
    final takenMeds = medLogs.where((l) => l.isTaken).length;
    final medProgress = totalMeds > 0
        ? (takenMeds / totalMeds).clamp(0.0, 1.0)
        : (totalTasks > 0 || waterMl > 0 ? 1.0 : 0.0);

    // Dynamic headline copy
    final bool allDone = (totalTasks > 0 && completedTasks >= totalTasks) &&
        (waterProgress >= 1.0) &&
        (totalMeds == 0 || takenMeds >= totalMeds);

    final String headline;
    final String statusSubtitle;
    if (totalTasks == 0 && waterMl == 0 && totalMeds == 0) {
      headline = "Today's Momentum";
      statusSubtitle = 'Ready to begin · Tap for daily briefing';
    } else if (allDone) {
      headline = 'All Targets Hit';
      statusSubtitle = 'Peak daily pace achieved';
    } else if (totalTasks > 0) {
      headline = '$completedTasks of $totalTasks priorities done';
      statusSubtitle = '${(waterProgress * 100).toInt()}% hydration · ${totalMeds > 0 ? '$takenMeds/$totalMeds meds' : 'routine intact'}';
    } else {
      headline = "Today's Momentum";
      statusSubtitle = '$waterMl mL logged · ${(waterProgress * 100).toInt()}% of hydration goal';
    }

    const taskColor = Color(0xFF10B981);
    const waterColor = Color(0xFF0284C7);
    const medColor = Color(0xFFE11D48);

    return AscentCard.glass(
      key: const ValueKey('home_day_glance_card'),
      onTap: () {
        HapticFeedback.lightImpact();
        DailyBriefingCard.show(context, DateTime.now());
      },
      radius: AscentDimensions.radiusLg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: 3 Concentric Apple-Style Rings
          Semantics(
            label: 'Today momentum rings: Tasks $completedTasks of $totalTasks, Hydration $waterMl of $waterGoal mL',
            child: SizedBox(
              width: 72,
              height: 72,
              child: CustomPaint(
                painter: _ConcentricMomentumRingsPainter(
                  taskProgress: taskProgress,
                  waterProgress: waterProgress,
                  medProgress: medProgress,
                  taskColor: taskColor,
                  waterColor: waterColor,
                  medColor: medColor,
                ),
              ),
            ),
          ),

          const SizedBox(width: 14),

          // Right: Telemetry headlines & metrics
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        headline,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: g.ink,
                          letterSpacing: -0.2,
                        ),
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
                const SizedBox(height: 3),
                Text(
                  statusSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: g.inkMuted,
                    fontSize: 12,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 8),

                // Telemetry indicators row with overflow immunity
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MiniIndicator(
                      color: taskColor,
                      label: totalTasks > 0 ? '$completedTasks/$totalTasks' : '0 tasks',
                    ),
                    _MiniIndicator(
                      color: waterColor,
                      label: '${waterMl}mL',
                    ),
                    if (totalMeds > 0)
                      _MiniIndicator(
                        color: medColor,
                        label: '$takenMeds/$totalMeds',
                      )
                    else
                      _MiniIndicator(
                        color: taskProgress >= 1.0 && totalTasks > 0 ? taskColor : g.inkMuted,
                        label: 'Active',
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

class _MiniIndicator extends StatelessWidget {
  const _MiniIndicator({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: g.inkSecondary,
          ),
        ),
      ],
    );
  }
}

class _ConcentricMomentumRingsPainter extends CustomPainter {
  const _ConcentricMomentumRingsPainter({
    required this.taskProgress,
    required this.waterProgress,
    required this.medProgress,
    required this.taskColor,
    required this.waterColor,
    required this.medColor,
  });

  final double taskProgress;
  final double waterProgress;
  final double medProgress;
  final Color taskColor;
  final Color waterColor;
  final Color medColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 5.2;
    const gap = 3.2;

    final outerR = (size.width / 2) - (strokeWidth / 2);
    final middleR = outerR - strokeWidth - gap;
    final innerR = middleR - strokeWidth - gap;

    _drawRing(canvas, center, outerR, strokeWidth, taskColor, taskProgress);
    _drawRing(canvas, center, middleR, strokeWidth, waterColor, waterProgress);
    _drawRing(canvas, center, innerR, strokeWidth, medColor, medProgress);
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
    Color color,
    double progress,
  ) {
    // 1. Background ring track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    // 2. Active momentum arc
    if (progress > 0.0) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress.clamp(0.01, 1.0);
      const startAngle = -math.pi / 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricMomentumRingsPainter oldDelegate) {
    return oldDelegate.taskProgress != taskProgress ||
        oldDelegate.waterProgress != waterProgress ||
        oldDelegate.medProgress != medProgress ||
        oldDelegate.taskColor != taskColor ||
        oldDelegate.waterColor != waterColor ||
        oldDelegate.medColor != medColor;
  }
}
