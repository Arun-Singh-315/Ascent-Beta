import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/streak/study_streak_models.dart';

class StreakCelebrationDialog extends StatelessWidget {
  final StudyStreakStatus status;

  const StreakCelebrationDialog({
    super.key,
    required this.status,
  });

  static Future<void> show(BuildContext context, StudyStreakStatus status) {
    HapticFeedback.heavyImpact();
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StreakCelebrationDialog(status: status),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isRescue = status.isRescuedToday;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: g.fill,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isRescue ? Colors.amberAccent.withValues(alpha: 0.5) : Colors.deepOrangeAccent.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isRescue ? Colors.amber : Colors.deepOrange).withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon Flame Container
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isRescue
                      ? [Colors.amberAccent.withValues(alpha: 0.3), Colors.transparent]
                      : [Colors.deepOrangeAccent.withValues(alpha: 0.3), Colors.transparent],
                ),
              ),
              child: Center(
                child: Text(
                  isRescue ? '🛡️' : '🔥',
                  style: const TextStyle(fontSize: 44),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isRescue ? 'STREAK RESCUED!' : 'STREAK SECURED!',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: isRescue ? Colors.amberAccent : Colors.deepOrangeAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRescue
                  ? 'You paid off yesterday\'s deficit and completed your 2-hour study goal today. Your discipline is unbroken!'
                  : 'You completed your full 2 hours of study today. Another day conquered!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: g.inkMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Streak Metric Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: g.bg.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: g.edge),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${status.displayStreakDays}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: g.ink,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAYS STREAK',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isRescue ? Colors.amberAccent : g.clay,
                        ),
                      ),
                      Text(
                        'Personal Best: ${status.longestStreakDays}d',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: g.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dismiss Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRescue ? Colors.amber.shade700 : g.clay,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Keep Crushing It 🚀',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
