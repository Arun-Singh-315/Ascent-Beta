import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_snack_bar.dart';

/// Refined Momentum screen (Tab 3) for Ascent Pre-Release.
///
/// Replaces the legacy 30-day protocol with a sleek, unified Coming Soon
/// overview for Momentum 2.0 (Atomic Habits, Adaptive Streaks & Routine Engine).
class MomentumScreen extends ConsumerWidget {
  const MomentumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;

    return AscentScaffold(
      title: 'Momentum',
      subtitle: 'Habits • Routines • Peak State',
      glow1: g.clay,
      glow2: g.slate,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AscentSpacing.lg,
          vertical: AscentSpacing.md,
        ),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO CARD ──────────────────────────────────────────────────
            AscentCard.glass(
              padding: const EdgeInsets.all(AscentSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: g.claySoft,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: g.clay.withValues(alpha: 0.3),
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.bolt_rounded,
                          color: g.clay,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: AscentSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AscentSpacing.sm,
                                vertical: AscentSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: g.claySoft,
                                borderRadius: BorderRadius.circular(AscentRadii.smVal),
                              ),
                              child: Text(
                                'MOMENTUM 2.0',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: g.clay,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(height: AscentSpacing.xs),
                            Text(
                              'Architecting Peak Flow',
                              style: AscentTextStyles.homeHeadline.copyWith(
                                color: g.ink,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AscentSpacing.lg),
                  Text(
                    'We are rebuilding Momentum from the ground up into a science-backed habit and routine operating system tailored for deep work and physical vitality.',
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: g.inkSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AscentSpacing.lg),
                  AscentButton.primary(
                    label: 'Notify Me On Release',
                    icon: Icons.notifications_active_outlined,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      AscentSnackBar.success(
                        context,
                        message: 'You\'re on the list! Momentum 2.0 notification enabled.',
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AscentSpacing.xl),

            // ── PILLARS HEADER ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AscentSpacing.xs),
              child: Text(
                'WHAT IS COMING',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.textMuted,
                  letterSpacing: 1.1,
                ),
              ),
            ),

            const SizedBox(height: AscentSpacing.md),

            // ── PILLAR 1: ATOMIC HABITS ────────────────────────────────────
            _buildFeaturePillar(
              context: context,
              icon: Icons.check_circle_outline_rounded,
              title: 'Atomic Habit Stacking',
              description: 'Link micro-habits to daily anchors with friction-free one-tap tracking and visual streaks.',
            ),

            const SizedBox(height: AscentSpacing.md),

            // ── PILLAR 2: ADAPTIVE STREAK GUARDIAN ─────────────────────────
            _buildFeaturePillar(
              context: context,
              icon: Icons.shield_outlined,
              title: 'Adaptive Streak Guardian',
              description: 'Flexible streak preservation that forgives rest days, travel, and emergencies without killing your progress.',
            ),

            const SizedBox(height: AscentSpacing.md),

            // ── PILLAR 3: TIME-BOXED ROUTINES ──────────────────────────────
            _buildFeaturePillar(
              context: context,
              icon: Icons.timelapse_rounded,
              title: 'Morning & Evening Rituals',
              description: 'Guided sequential routine players that walk you through your start-of-day and shutdown checklists.',
            ),

            const SizedBox(height: AscentSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturePillar({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
  }) {
    final g = context.glass;

    return AscentCard.glass(
      padding: const EdgeInsets.all(AscentSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: g.claySoft,
              borderRadius: BorderRadius.circular(AscentRadii.mdVal),
              border: Border.all(color: g.line, width: 1),
            ),
            child: Icon(icon, size: 20, color: g.clay),
          ),
          const SizedBox(width: AscentSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: g.ink,
                  ),
                ),
                const SizedBox(height: AscentSpacing.xs),
                Text(
                  description,
                  style: AscentTextStyles.captionMedium.copyWith(
                    color: g.inkSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
