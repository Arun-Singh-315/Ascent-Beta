import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/streak/study_streak_models.dart';

class StreakCelebrationDialog extends StatelessWidget {
  final StudyStreakStatus status;

  const StreakCelebrationDialog({super.key, required this.status});

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
      backgroundColor: AppPalette.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpace.s24),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.s24),
        nightDecoration: BoxDecoration(
          color: g.fill,
          borderRadius: AppGeometry.roundedr28,
          border: Border.all(
            color: isRescue
                ? AppPalette.amberAccent.withValues(alpha: 0.5)
                : AppPalette.deepOrangeAccent.withValues(alpha: 0.5),
            width: AppBorderScale.w1point5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isRescue ? AppPalette.amber : AppPalette.deepOrange)
                  .withValues(alpha: 0.2),
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
                      ? [
                          AppPalette.amberAccent.withValues(alpha: 0.3),
                          AppPalette.transparent,
                        ]
                      : [
                          AppPalette.deepOrangeAccent.withValues(alpha: 0.3),
                          AppPalette.transparent,
                        ],
                ),
              ),
              child: Center(
                child: Text(
                  isRescue ? '🛡️' : '🔥',
                  style: AppTypeRoles.typeRole64,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isRescue ? 'STREAK RESCUED!' : 'STREAK SECURED!',
              style: AppTypography.plusJakartaSans20W800112(
                color: isRescue
                    ? AppPalette.amberAccent
                    : AppPalette.deepOrangeAccent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isRescue
                  ? 'You paid off yesterday\'s deficit and completed your 2-hour study goal today. Your discipline is unbroken!'
                  : 'You completed your full 2 hours of study today. Another day conquered!',
              textAlign: TextAlign.center,
              style: AppTypography.plusJakartaSans14Regular89(
                color: g.inkMuted,
              ),
            ),
            const SizedBox(height: 20),

            // Streak Metric Box
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s20,
                vertical: AppSpace.s12,
              ),
              nightDecoration: BoxDecoration(
                color: g.bg.withValues(alpha: 0.6),
                borderRadius: AppGeometry.roundedr16,
                border: Border.all(color: g.edge),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${status.displayStreakDays}',
                    style: AppTypography.plusJakartaSans32W800113(color: g.ink),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DAYS STREAK',
                        style: AppTypography.plusJakartaSans12W700114(
                          color: isRescue ? AppPalette.amberAccent : g.clay,
                        ),
                      ),
                      Text(
                        'Personal Best: ${status.longestStreakDays}d',
                        style: AppTypography.plusJakartaSans11Regular58(
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
                style: context.surfaces.buttonStyle(
                  ElevatedButton.styleFrom(
                    backgroundColor: isRescue
                        ? AppPalette.amber.shade700
                        : g.clay,
                    foregroundColor: AppPalette.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppGeometry.roundedr16,
                    ),
                  ),
                  filled: true,
                  icon: false,
                ),
                child: Text(
                  'Keep Crushing It 🚀',
                  style: AppTypography.plusJakartaSans15W700115(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
