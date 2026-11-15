import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/dimension_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../shared/widgets/ascent_card.dart';
import 'daily_briefing_card.dart';

/// iOS Health & Fitness-inspired Concentric Glance Card on Home.
///
/// Features 4 concentric momentum rings:
/// 1. Outer: Priorities / Tasks completed today (Apple Emerald Green).
/// 2. 2nd: Hydration intake progress (Apple Electric Blue).
/// 3. 3rd: Medicine prescription adherence (Apple Rose Red).
/// 4. Inner: Study focus minutes & pacing (Apple Sun Amber).
///
/// Accompanied by a 2x2 high-contrast numbers-and-text creative data matrix.
/// Fully responsive and immune to overflows at 320px width & 2.0x font scaling.
class HomeDayGlanceCard extends ConsumerWidget {
  const HomeDayGlanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    // 1. Task telemetry (iOS Green)
    final activities = ref.watch(todayActivitiesProvider).value ?? const [];
    final totalTasks = activities.length;
    final completedTasks =
        activities.where((a) => a.status == TodayActivityStatus.done).length;
    final taskProgress = totalTasks > 0
        ? (completedTasks / totalTasks).clamp(0.0, 1.0)
        : 0.0;

    // 2. Hydration telemetry (iOS Blue)
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterProgress =
        waterGoal > 0 ? (waterMl / waterGoal).clamp(0.0, 1.0) : 0.0;

    // 3. Medicine care telemetry (iOS Rose/Red)
    final medLogs =
        ref.watch(todayMedicineLogsStreamProvider).value ?? const [];
    final totalMeds = medLogs.length;
    final takenMeds = medLogs.where((l) => l.isTaken).length;
    final medProgress = totalMeds > 0
        ? (takenMeds / totalMeds).clamp(0.0, 1.0)
        : (totalTasks > 0 || waterMl > 0 ? 1.0 : 0.0);

    // 4. Study / Focus telemetry (iOS Amber)
    final streak = ref.watch(studyStreakProvider);
    final focusMinutes = streak.todaySeconds ~/ 60;
    const focusGoalMinutes = 60;
    final studyProgress = (focusMinutes / focusGoalMinutes).clamp(0.0, 1.0);

    // 5. Mindful Money / Safe Spend telemetry
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

    // iOS Canonical Vivid Accent Colors:
    final taskColor = dark ? const Color(0xFF30D158) : const Color(0xFF34C759);
    final waterColor = dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);
    final medColor = dark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55);
    final studyColor = dark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500);

    return AscentCard.glass(
      key: const ValueKey('home_day_glance_card'),
      onTap: () {
        HapticFeedback.lightImpact();
        DailyBriefingCard.show(context, DateTime.now());
      },
      radius: AscentDimensions.radiusLg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Header Row: Label & Status Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: taskColor,
                      boxShadow: [
                        BoxShadow(
                          color: taskColor.withValues(alpha: 0.6),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "TODAY'S PULSE",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: g.inkMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (dark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: g.line,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'All Synced',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: g.inkSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 13,
                      color: g.inkMuted,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Main Centerpiece: Concentric Rings + 2x2 Data Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Concentric 4-Ring Apple Momentum Painter
              Semantics(
                label:
                    'Momentum rings: Tasks $completedTasks of $totalTasks, Hydration $waterMl of $waterGoal mL',
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: CustomPaint(
                    painter: _ConcentricMomentumRingsPainter(
                      taskProgress: taskProgress,
                      waterProgress: waterProgress,
                      medProgress: medProgress,
                      studyProgress: studyProgress,
                      taskColor: taskColor,
                      waterColor: waterColor,
                      medColor: medColor,
                      studyColor: studyColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // 2x2 Creative Numbers & Text Combination Matrix
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DataPill(
                            color: taskColor,
                            number: totalTasks > 0
                                ? '$completedTasks/$totalTasks'
                                : '0',
                            unit: 'done',
                            label: 'Priorities',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DataPill(
                            color: waterColor,
                            number: NumberFormat.compact().format(waterMl),
                            unit: 'mL',
                            label: 'Hydration',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _DataPill(
                            color: medColor,
                            number: totalMeds > 0
                                ? '$takenMeds/$totalMeds'
                                : 'All',
                            unit: totalMeds > 0 ? 'taken' : 'clear',
                            label: 'Medicine',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DataPill(
                            color: focusMinutes > 0 ? studyColor : taskColor,
                            number: focusMinutes > 0
                                ? '$focusMinutes'
                                : '₹${NumberFormat.compact().format(safeRemaining)}',
                            unit: focusMinutes > 0 ? 'min' : 'safe',
                            label: focusMinutes > 0 ? 'Focus' : 'Spend',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataPill extends StatelessWidget {
  const _DataPill({
    required this.color,
    required this.number,
    required this.unit,
    required this.label,
  });

  final Color color;
  final String number;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: (dark ? const Color(0xFF161B26) : Colors.white)
            .withValues(alpha: dark ? 0.65 : 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: dark ? 0.35 : 0.25),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.15 : 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  number,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: g.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: g.inkMuted,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConcentricMomentumRingsPainter extends CustomPainter {
  const _ConcentricMomentumRingsPainter({
    required this.taskProgress,
    required this.waterProgress,
    required this.medProgress,
    required this.studyProgress,
    required this.taskColor,
    required this.waterColor,
    required this.medColor,
    required this.studyColor,
  });

  final double taskProgress;
  final double waterProgress;
  final double medProgress;
  final double studyProgress;
  final Color taskColor;
  final Color waterColor;
  final Color medColor;
  final Color studyColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 4.6;
    const gap = 2.6;

    final r1 = (size.width / 2) - (strokeWidth / 2);
    final r2 = r1 - strokeWidth - gap;
    final r3 = r2 - strokeWidth - gap;
    final r4 = r3 - strokeWidth - gap;

    _drawRing(canvas, center, r1, strokeWidth, taskColor, taskProgress);
    _drawRing(canvas, center, r2, strokeWidth, waterColor, waterProgress);
    _drawRing(canvas, center, r3, strokeWidth, medColor, medProgress);
    _drawRing(canvas, center, r4, strokeWidth, studyColor, studyProgress);
  }

  void _drawRing(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
    Color color,
    double progress,
  ) {
    if (radius <= 0) return;

    // Track
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    // Active Arc
    if (progress <= 0.0) return;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ConcentricMomentumRingsPainter oldDelegate) {
    return oldDelegate.taskProgress != taskProgress ||
        oldDelegate.waterProgress != waterProgress ||
        oldDelegate.medProgress != medProgress ||
        oldDelegate.studyProgress != studyProgress ||
        oldDelegate.taskColor != taskColor ||
        oldDelegate.waterColor != waterColor ||
        oldDelegate.medColor != medColor ||
        oldDelegate.studyColor != studyColor;
  }
}
