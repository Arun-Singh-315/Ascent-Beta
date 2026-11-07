import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/dimension_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_card.dart';
import 'daily_briefing_card.dart';

/// Linear & Things 3-inspired Executive Daily Momentum Hero Card on Home.
///
/// Eliminates cluttered concentric circle graphs in favor of razor-sharp,
/// high-signal executive telemetry:
/// - Segmented velocity bar representing today's scheduled priorities.
/// - 3-column Bento telemetry trio (Tasks, Hydration, Medicine compliance).
/// - Tactile interactive navigation to the Daily Briefing.
class HomeExecutiveFocusCard extends ConsumerWidget {
  const HomeExecutiveFocusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;

    // 1. Task telemetry
    final activities = ref.watch(todayActivitiesProvider).value ?? const [];
    final totalTasks = activities.length;
    final completedTasks =
        activities.where((a) => a.status == TodayActivityStatus.done).length;

    // 2. Hydration telemetry
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final waterPct = waterGoal > 0 ? (waterMl / waterGoal * 100).toInt() : 0;

    // 3. Medicine telemetry
    final medLogs =
        ref.watch(todayMedicineLogsStreamProvider).value ?? const [];
    final totalMeds = medLogs.length;
    final takenMeds = medLogs.where((l) => l.isTaken).length;

    // Status label
    final String statusBadge;
    if (totalTasks == 0 && waterMl == 0 && totalMeds == 0) {
      statusBadge = 'Ready to begin';
    } else if (totalTasks > 0 && completedTasks >= totalTasks && waterMl >= waterGoal) {
      statusBadge = 'All targets hit';
    } else if (totalTasks > 0) {
      statusBadge = '$completedTasks of $totalTasks priorities done';
    } else {
      statusBadge = '${(waterMl / 1000).toStringAsFixed(1)}L logged';
    }

    // Segment count for the velocity bar (at least 3 segments for visual balance)
    final segmentCount = totalTasks > 0 ? math.min(totalTasks, 6) : 4;
    final filledSegments = totalTasks > 0
        ? ((completedTasks / totalTasks) * segmentCount).round()
        : (waterMl > 0 ? 1 : 0);

    return AscentCard.glass(
      key: const ValueKey('home_executive_focus_card'),
      onTap: () {
        HapticFeedback.lightImpact();
        DailyBriefingCard.show(context, DateTime.now());
      },
      radius: AscentDimensions.radiusLg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── TOP HEADER ROW: Tracked Label & Dynamic Badge ───────────────
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'TODAY’S EXECUTION',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: g.inkMuted,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completedTasks > 0
                          ? const Color(0xFF10B981)
                          : SharedControlColors.actionBlue,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    statusBadge,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: g.ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: g.inkMuted,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── SEGMENTED LINEAR VELOCITY BAR (Things 3 / Linear style) ──────
          Row(
            children: List.generate(segmentCount, (index) {
              final isFilled = index < filledSegments;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < segmentCount - 1 ? 4 : 0,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: isFilled
                        ? (completedTasks >= totalTasks && totalTasks > 0
                            ? const Color(0xFF10B981)
                            : SharedControlColors.actionBlue)
                        : g.line.withValues(alpha: context.isDark ? 0.35 : 0.5),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 14),

          // ── HIGH-SIGNAL TELEMETRY BENTO TRIO ─────────────────────────────
          Row(
            children: [
              // 1. Tasks
              Expanded(
                child: _TelemetryBentoCell(
                  label: 'PRIORITIES',
                  value: totalTasks > 0 ? '$completedTasks/$totalTasks' : 'Clear',
                  sub: totalTasks > 0
                      ? '${totalTasks - completedTasks} pending'
                      : 'No tasks',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Hydration
              Expanded(
                child: _TelemetryBentoCell(
                  label: 'HYDRATION',
                  value: '${(waterMl / 1000).toStringAsFixed(2)}L',
                  sub: '$waterPct% of ${waterGoal ~/ 1000}L',
                  color: SharedControlColors.actionBlue,
                ),
              ),
              const SizedBox(width: 8),

              // 3. Medicine
              Expanded(
                child: _TelemetryBentoCell(
                  label: 'MEDICINE',
                  value: totalMeds > 0 ? '$takenMeds/$totalMeds' : 'Intact',
                  sub: totalMeds > 0
                      ? (takenMeds >= totalMeds ? 'All taken' : '${totalMeds - takenMeds} pending')
                      : 'Routine clean',
                  color: const Color(0xFFF43F5E),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TelemetryBentoCell extends StatelessWidget {
  const _TelemetryBentoCell({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: g.fill.withValues(alpha: context.isDark ? 0.25 : 0.45),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: g.line.withValues(alpha: 0.3),
          width: 0.75,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: g.inkMuted,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: g.ink,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.dmSans(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: g.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}
