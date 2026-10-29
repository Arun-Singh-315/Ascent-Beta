import 'package:flutter/material.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/services/cosmic_profile_service.dart';
import 'ascent_card.dart';

/// An interactive, translucent glass card presenting the user's
/// personalized Zodiac alignment, Vedic Rashi, daily boosting spark,
/// and the day's planetary living mood.
class CosmicSparkCard extends StatelessWidget {
  final DateTime dateOfBirth;
  final bool compact;
  final VoidCallback? onTap;

  const CosmicSparkCard({
    super.key,
    required this.dateOfBirth,
    this.compact = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const service = CosmicProfileService();
    final insight = service.getDailyInsight(dob: dateOfBirth);
    final livingMood = insight.livingMood;
    final sign = insight.sign;

    return Semantics(
      container: true,
      label: insight.isBirthday
          ? 'Birthday greeting and cosmic alignment'
          : 'Daily cosmic alignment and boosting spark for ${sign.name}',
      child: AscentCard(
        onTap: onTap,
        padding: compact
            ? const EdgeInsets.symmetric(
                horizontal: AppSpace.s14,
                vertical: AppSpace.s12,
              )
            : const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Header: Zodiac Badges + Living Day Mood
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s6,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Zodiac & Rashi Micro-pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s10,
                    vertical: AppSpace.s4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? livingMood.livingTint.withValues(alpha: 0.16)
                        : livingMood.livingTint.withValues(alpha: 0.10),
                    borderRadius: AppGeometry.roundedr12,
                    border: Border.all(
                      color: livingMood.livingTint.withValues(
                        alpha: isDark ? 0.35 : 0.25,
                      ),
                      width: AppBorderScale.w0point8,
                    ),
                  ),
                  child: Wrap(
                    spacing: AppSpace.s4,
                    runSpacing: AppSpace.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        sign.symbol,
                        style: const TextStyle(fontSize: 14),
                      ),
                      Text(
                        '${sign.name} · ${sign.vedicRashi}',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '(${sign.element.icon} ${sign.element.label})',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.inkSecondary,
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                // Living Planetary Ruler Indicator (Living Day Accent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s8,
                    vertical: AppSpace.s3,
                  ),
                  decoration: BoxDecoration(
                    color: g.recessed,
                    borderRadius: AppGeometry.roundedr12,
                    border: Border.all(
                      color: g.controlOutline,
                      width: AppBorderScale.w0point8,
                    ),
                  ),
                  child: Wrap(
                    spacing: AppSpace.s6,
                    runSpacing: AppSpace.s2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: livingMood.livingTint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        livingMood.rulingTitle,
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpace.s12),

            // Birthday Celebration Banner or Daily Boosting Quote
            if (insight.isBirthday) ...[
              Container(
                padding: const EdgeInsets.all(AppSpace.s12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      livingMood.livingTint.withValues(alpha: 0.18),
                      g.clay.withValues(alpha: 0.12),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppGeometry.roundedr12,
                  border: Border.all(
                    color: livingMood.livingTint.withValues(alpha: 0.40),
                    width: AppBorderScale.w1point2,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🎂', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: AppSpace.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Happy Birthday! ✨',
                            style: AscentTextStyles.labelLarge.copyWith(
                              color: g.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: AppSpace.s4),
                          Text(
                            insight.quote,
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: g.inkSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 8),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 16,
                      color: livingMood.livingTint,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      insight.quote,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: g.ink,
                        height: 1.42,
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (!compact) ...[
              const SizedBox(height: AppSpace.s12),
              // Archetype & Trait Footer
              Wrap(
                spacing: AppSpace.s6,
                runSpacing: AppSpace.s4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Archetype:',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: g.inkMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sign.archetype,
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: g.inkSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '·',
                    style: TextStyle(color: g.inkMuted, fontSize: 11),
                  ),
                  Text(
                    sign.traits,
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: g.inkMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
