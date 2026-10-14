import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';
import 'ascent_button.dart';

/// A full-screen or section-level empty state following the Ascent design system.
///
/// Renders a centred column with an outlined icon in a soft matte container,
/// a restrained title, supportive subtitle, and an optional compact CTA button.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// The icon displayed at the top of the empty state.
  final IconData icon;

  /// Short, descriptive title.
  final String title;

  /// Supportive body copy.
  final String subtitle;

  /// Label for the optional CTA button.
  final String? actionLabel;

  /// Callback for the CTA button.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;
    final divider = context.divider;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s28,
          vertical: AppSpace.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Outlined icon container with subtle matte fill
            AppCard(
              width: 72,
              height: 72,
              nightDecoration: BoxDecoration(
                color: context.bgSurfaceElevated,
                borderRadius: AppGeometry.roundedr20,
                border: Border.all(
                  color: divider,
                  width: AppBorderScale.w1point0,
                ),
              ),
              child: Center(
                child: Icon(icon, size: 32, color: context.accentPrimary),
              ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              title,
              style: AscentTextStyles.displaySmall
                  .copyWith(color: textPrimary)
                  .merge(AppTypeRoles.typeRole70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),

            // Subtitle
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                subtitle,
                style: AscentTextStyles.bodySmall.copyWith(
                  color: textMuted,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Optional compact action
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              AscentButton.outlined(
                label: actionLabel!,
                onPressed: onAction,
                compact: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
