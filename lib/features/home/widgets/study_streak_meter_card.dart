import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../../core/streak/streak_explanation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/merlot_palette.dart';
import '../../../core/streak/study_streak_models.dart';

class StudyStreakMeterCard extends StatelessWidget {
  final StudyStreakStatus status;
  final VoidCallback? onTap;

  const StudyStreakMeterCard({super.key, required this.status, this.onTap});

  void _showExplanation(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (ctx, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(AppSpace.s24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'How your streak works',
                style: AppTypeRoles.typeRole11,
              ),
              const SizedBox(height: 16),
              Text(
                streakExplanation(status),
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got it'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final streakTitle = status.displayStreakDays == 0
        ? (status.phase == StudyStreakPhase.broken
            ? 'A fresh start'
            : 'Start your first day')
        : '${status.displayStreakDays} Day Streak';

    return AppGestureTap(
      onTap: onTap ?? () => _showExplanation(context),
      child: Container(
        decoration: BoxDecoration(
          color: g.merlot
              ? (isDark ? MerlotPalette.darkSurface : MerlotPalette.surface)
              : (g.frozen
                  ? (isDark ? FrozenPalette.darkSurface : FrozenPalette.surface)
                  : (isDark ? g.fill : Colors.white)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: g.merlot
                ? (isDark ? MerlotPalette.darkLine : MerlotPalette.line)
                : (g.frozen
                    ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
                    : (status.isRescueMode
                        ? AppPalette.amber.withValues(alpha: 0.35)
                        : (status.isUrgent
                            ? AppPalette.redAccent.withValues(alpha: 0.35)
                            : (isDark ? g.edge : g.edge.withValues(alpha: 0.45))))),
            width: (g.merlot || g.frozen) ? 0.75 : AppBorderScale.w1,
          ),
          boxShadow: g.merlot
              ? [
                  BoxShadow(
                    color: MerlotPalette.shadowAmbient,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : (g.frozen
                  ? [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.35)
                            : FrozenPalette.shadowAmbient,
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : (isDark
                      ? null
                      : [
                          BoxShadow(
                            color: const Color.fromRGBO(15, 23, 42, 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: const Color.fromRGBO(15, 23, 42, 0.02),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ])),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (g.frozen)
              Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? FrozenPalette.darkSparkTint
                      : FrozenPalette.sparkTint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            // Top Row: Streak Flame + Today study stats + Info action
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  size: 18,
                  color: g.frozen
                      ? (isDark ? FrozenPalette.darkSpark : FrozenPalette.spark)
                      : (status.isTodaySecured
                          ? AppPalette.deepOrangeAccent
                          : (status.isRescueMode ? AppPalette.amber : g.clay)),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    streakTitle,
                    style: AppTypography.plusJakartaSans13W70044(
                      color: g.frozen
                          ? g.ink
                          : (status.isTodaySecured
                              ? AppPalette.deepOrangeAccent
                              : (status.isRescueMode
                                  ? AppPalette.amberAccent
                                  : g.ink)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '•  Longest: ${status.longestStreakDays}d',
                  style: AppTypography.plusJakartaSans12W50020(
                    color: g.inkMuted,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showExplanation(context),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: g.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (status.isRescueMode && !status.isTodaySecured) ...[
              const SizedBox(height: 6),
              Text(
                '${status.targetMinutes}m of study will recover your streak today.',
                style: AppTypography.plusJakartaSans12W60073(
                  color: AppPalette.amber,
                ),
              ),
            ] else if (status.isUrgent && !status.isTodaySecured) ...[
              const SizedBox(height: 6),
              Text(
                '${status.remainingMinutes}m of study will continue your streak today.',
                style: AppTypography.plusJakartaSans12W60073(
                  color: AppPalette.redAccent,
                ),
              ),
            ] else if (!status.isTodaySecured) ...[
              const SizedBox(height: 4),
              Text(
                'Study for ${status.targetMinutes} minutes to complete day ${status.displayStreakDays + 1}.',
                style: AppTypography.plusJakartaSans12W50020(color: g.inkMuted),
              ),
            ],
            const SizedBox(height: 8),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                decoration: BoxDecoration(
                  color: g.track,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: g.line.withValues(alpha: 0.4),
                    width: 0.5,
                  ),
                ),
                child: LinearProgressIndicator(
                  value: status.progressFraction,
                  minHeight: 6,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    g.frozen
                        ? (status.isTodaySecured
                            ? (isDark
                                ? FrozenPalette.darkSpark
                                : FrozenPalette.spark)
                            : (isDark
                                ? FrozenPalette.darkAction
                                : FrozenPalette.action))
                        : (status.isTodaySecured
                            ? AppPalette.deepOrangeAccent
                            : (status.isRescueMode
                                ? AppPalette.amber
                                : (status.isUrgent
                                    ? AppPalette.redAccent
                                    : g.clay))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Bottom stats row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  '${status.todayMinutes} / ${status.targetMinutes}m studied',
                  style: AppTypography.plusJakartaSans12W60073(color: g.ink),
                ),
                Text(
                  status.isTodaySecured
                      ? 'Goal Met 🎉'
                      : '${status.remainingMinutes}m left',
                  style: AppTypography.plusJakartaSans12W60073(
                    color: status.isTodaySecured
                        ? AppPalette.green
                        : g.inkMuted,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showExplanation(context),
                  child: Text(
                    'How your streak works',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: g.clay,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
