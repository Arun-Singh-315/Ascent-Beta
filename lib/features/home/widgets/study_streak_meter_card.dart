import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/streak/study_streak_models.dart';

class StudyStreakMeterCard extends StatelessWidget {
  final StudyStreakStatus status;
  final VoidCallback? onTap;

  const StudyStreakMeterCard({super.key, required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: g.fill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: status.isRescueMode
                ? Colors.amber.withValues(alpha: 0.35)
                : (status.isUrgent
                      ? Colors.redAccent.withValues(alpha: 0.35)
                      : g.edge),
            width: 1,
          ),
          boxShadow: [
            if (status.isUrgent || status.isRescueMode)
              BoxShadow(
                color: (status.isRescueMode ? Colors.amber : Colors.redAccent)
                    .withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Streak Flame + Stats ──
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: status.isTodaySecured
                        ? Colors.deepOrange.withValues(alpha: 0.18)
                        : (status.isRescueMode
                              ? Colors.amber.withValues(alpha: 0.18)
                              : g.clay.withValues(alpha: 0.12)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: status.isTodaySecured
                          ? Colors.deepOrange.withValues(alpha: 0.4)
                          : (status.isRescueMode
                                ? Colors.amber.withValues(alpha: 0.4)
                                : g.clay.withValues(alpha: 0.25)),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.isTodaySecured
                            ? '🔥'
                            : (status.isRescueMode ? '⚡' : '🔥'),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status.displayStreakDays == 0
                            ? status.phase == StudyStreakPhase.broken
                                  ? 'A fresh start'
                                  : 'Start your first day'
                            : '${status.displayStreakDays} Day Streak',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: status.isTodaySecured
                              ? Colors.deepOrangeAccent
                              : (status.isRescueMode
                                    ? Colors.amberAccent
                                    : g.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Longest: ${status.longestStreakDays}d',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: g.inkMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: g.inkMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Base: ${status.shortestStreakDays}d',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: g.inkMuted,
                  ),
                ),
              ],
            ),

            // ── 0 Streak Boost Banner ──
            if (status.displayStreakDays == 0 &&
                !status.isRescueMode &&
                !status.isTodaySecured) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: g.claySoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: g.clay.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.rocket_launch_rounded, size: 16, color: g.clay),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Study for ${status.targetMinutes} minutes to complete ${status.phase == StudyStreakPhase.broken ? 'a fresh day' : 'day 1'}.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: g.clay,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Mode-Specific Urgency / Rescue Banner ──
            if (status.isRescueMode && !status.isTodaySecured) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You can recover your streak with ${status.targetMinutes}m of study today.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (status.isUrgent && !status.isTodaySecured) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${status.remainingMinutes}m of study will continue your streak today.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (status.isTodaySecured) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status.isRescuedToday
                            ? 'Your streak is recovered. Well done.'
                            : 'Today’s ${status.targetMinutes}m study goal is complete.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: g.sage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ── Live Dopamine Progress Bar ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${status.todayMinutes} / ${status.targetMinutes}m studied',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: g.ink,
                  ),
                ),
                Text(
                  status.isTodaySecured
                      ? 'Goal Met 🎉'
                      : '${status.remainingMinutes}m left',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: status.isTodaySecured ? Colors.green : g.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: status.progressFraction,
                minHeight: 8,
                backgroundColor: g.bg.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  status.isTodaySecured
                      ? Colors.deepOrangeAccent
                      : (status.isRescueMode
                            ? Colors.amber
                            : (status.isUrgent ? Colors.redAccent : g.clay)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
