import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../../core/streak/streak_explanation.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/streak/study_streak_models.dart';

class StudyStreakMeterCard extends StatelessWidget {
  final StudyStreakStatus status;
  final VoidCallback? onTap;

  const StudyStreakMeterCard({super.key, required this.status, this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return AppGestureTap(
      onTap: onTap,
      child: AppCard(
        nightDecoration: BoxDecoration(
          color: g.fill,
          borderRadius: AppGeometry.roundedr20,
          border: Border.all(
            color: status.isRescueMode
                ? AppPalette.amber.withValues(alpha: 0.35)
                : (status.isUrgent
                      ? AppPalette.redAccent.withValues(alpha: 0.35)
                      : g.edge),
            width: AppBorderScale.w1,
          ),
          boxShadow: [
            if (status.isUrgent || status.isRescueMode)
              BoxShadow(
                color:
                    (status.isRescueMode
                            ? AppPalette.amber
                            : AppPalette.redAccent)
                        .withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Row: Streak Flame + Stats ──
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppTag(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s10,
                    vertical: AppSpace.s5,
                  ),
                  nightDecoration: BoxDecoration(
                    color: status.isTodaySecured
                        ? AppPalette.deepOrange.withValues(alpha: 0.18)
                        : (status.isRescueMode
                              ? AppPalette.amber.withValues(alpha: 0.18)
                              : g.clay.withValues(alpha: 0.12)),
                    borderRadius: AppGeometry.roundedr20,
                    border: Border.all(
                      color: status.isTodaySecured
                          ? AppPalette.deepOrange.withValues(alpha: 0.4)
                          : (status.isRescueMode
                                ? AppPalette.amber.withValues(alpha: 0.4)
                                : g.clay.withValues(alpha: 0.25)),
                      width: AppBorderScale.w1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        status.isTodaySecured
                            ? '🔥'
                            : (status.isRescueMode ? '⚡' : '🔥'),
                        style: AppTypeRoles.typeRole59,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        status.displayStreakDays == 0
                            ? status.phase == StudyStreakPhase.broken
                                  ? 'A fresh start'
                                  : 'Start your first day'
                            : '${status.displayStreakDays} Day Streak',
                        style: AppTypography.plusJakartaSans13W70044(
                          color: status.isTodaySecured
                              ? AppPalette.deepOrangeAccent
                              : (status.isRescueMode
                                    ? AppPalette.amberAccent
                                    : g.ink),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Longest: ${status.longestStreakDays}d',
                  style: AppTypography.plusJakartaSans12W50020(
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
              AppTag(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                nightDecoration: BoxDecoration(
                  color: g.claySoft,
                  borderRadius: AppGeometry.roundedr12,
                  border: Border.all(color: g.clay.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.rocket_launch_rounded, size: 16, color: g.clay),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Study for ${status.targetMinutes} minutes to complete ${status.phase == StudyStreakPhase.broken ? 'a fresh day' : 'day 1'}.',
                        style: AppTypography.plusJakartaSans12W60073(
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
              AppTag(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                nightDecoration: BoxDecoration(
                  color: AppPalette.amber.withValues(alpha: 0.12),
                  borderRadius: AppGeometry.roundedr12,
                  border: Border.all(
                    color: AppPalette.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: AppPalette.amber,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'You can recover your streak with ${status.targetMinutes}m of study today.',
                        style: AppTypography.plusJakartaSans12W60073(
                          color: AppPalette.amber,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (status.isUrgent && !status.isTodaySecured) ...[
              const SizedBox(height: 12),
              AppTag(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                nightDecoration: BoxDecoration(
                  color: AppPalette.redAccent.withValues(alpha: 0.12),
                  borderRadius: AppGeometry.roundedr12,
                  border: Border.all(
                    color: AppPalette.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AppPalette.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${status.remainingMinutes}m of study will continue your streak today.',
                        style: AppTypography.plusJakartaSans12W60073(
                          color: AppPalette.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (status.isTodaySecured) ...[
              const SizedBox(height: 12),
              AppTag(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s8,
                ),
                nightDecoration: BoxDecoration(
                  color: AppPalette.green.withValues(alpha: 0.12),
                  borderRadius: AppGeometry.roundedr12,
                  border: Border.all(
                    color: AppPalette.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppPalette.green,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status.isRescuedToday
                            ? 'Your streak is recovered. Well done.'
                            : 'Today’s ${status.targetMinutes}m study goal is complete.',
                        style: AppTypography.plusJakartaSans12W60073(
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
                  style: AppTypography.plusJakartaSans13W70044(color: g.ink),
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
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: AppGeometry.roundedr8,
              child: LinearProgressIndicator(
                value: status.progressFraction,
                minHeight: 8,
                backgroundColor: g.bg.withValues(alpha: 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  status.isTodaySecured
                      ? AppPalette.deepOrangeAccent
                      : (status.isRescueMode
                            ? AppPalette.amber
                            : (status.isUrgent
                                  ? AppPalette.redAccent
                                  : g.clay)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Only active Study Focus and Learning time counts.',
              style: AppTypeRoles.typeRole27.copyWith(color: g.inkMuted),
            ),
            TextButton.icon(
              style: context.surfaces.buttonStyle(
                TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: g.clay,
                ),
                filled: false,
                icon: false,
              ),
              icon: const Icon(Icons.info_outline, size: 17),
              label: const Text('How your streak works'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (ctx) => DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.7,
                  minChildSize: 0.4,
                  maxChildSize: 0.95,
                  builder: (ctx, controller) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(AppSpace.s24),
                    children: [
                      const Text(
                        'How your streak works',
                        style: AppTypeRoles.typeRole11,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        streakExplanation(status),
                        style: const TextStyle(height: 1.6),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Got it'),
                      ),
                    ],
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
