import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import 'ascent_button.dart';

/// A full-screen or section-level empty state following the Ascent design system.
///
/// Renders a centred column with an icon in a soft circle, a title,
/// a subtitle, and an optional primary CTA button.
///
/// ```dart
/// EmptyState(
///   icon: Icons.bookmark_outline,
///   title: 'No saved jobs yet',
///   subtitle: 'Jobs you save will appear here for quick access.',
///   actionLabel: 'Browse jobs',
///   onAction: () => context.go('/explore'),
/// )
/// ```
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

  /// Short, descriptive title (displayed in [AscentTextStyles.displaySmall]).
  final String title;

  /// Supportive body copy (displayed in [AscentTextStyles.bodyMedium]).
  final String subtitle;

  /// Label for the optional CTA button. When null, no button is shown.
  final String? actionLabel;

  /// Callback for the CTA button.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentPrimary;
    final textPrimary = context.textPrimary;
    final textMuted = context.textMuted;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon circle
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 40,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              title,
              style: AscentTextStyles.displaySmall
                  .copyWith(color: textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              subtitle,
              style:
                  AscentTextStyles.bodyMedium.copyWith(color: textMuted),
              textAlign: TextAlign.center,
            ),

            // Optional action
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              AscentButton.primary(
                label: actionLabel!,
                onPressed: onAction,
                expanded: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
