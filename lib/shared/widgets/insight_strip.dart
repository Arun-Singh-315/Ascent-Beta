import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';

/// A single-line contextual insight strip used by Ascent's intelligence layer.
///
/// Renders a soft card with a 3 px left-edge accent bar, italic body copy,
/// and an optional dismiss ✕ icon on the right.
///
/// ```dart
/// InsightStrip(
///   message: "You're on a 5-day streak — keep it up! 🌱",
///   onDismiss: () => _hideInsight(),
///   onTap: () => _showWhyDialog(),
/// )
/// ```
class InsightStrip extends StatelessWidget {
  const InsightStrip({
    super.key,
    required this.message,
    this.onDismiss,
    this.onTap,
  });

  /// The positivity / insight text to display.
  final String message;

  /// When non-null a dismiss ✕ button is shown on the trailing edge.
  final VoidCallback? onDismiss;

  /// When non-null the strip is tappable — use for "why?" transparency sheets.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = context.bgSurface;
    final accent = context.accentSecondary;
    final textMuted = context.textMuted;
    final shadow =
        context.isDark ? AscentColors.shadowDark : AscentColors.shadow;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: shadow.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left-edge accent bar
                Container(
                  width: 3,
                  color: accent,
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Text(
                      message,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Optional dismiss button
                if (onDismiss != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: IconButton(
                      icon: Icon(Icons.close, size: 16, color: textMuted),
                      onPressed: onDismiss,
                      splashRadius: 16,
                      tooltip: 'Dismiss',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
