import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import 'ascent_button.dart';

/// Standardized modal dialog utility for Ascent.
///
/// Ensures consistent 20px corner radii, theme-aware surface backgrounds,
/// refined typography, and standardized [AscentButton] actions.
class AscentDialog extends StatelessWidget {
  const AscentDialog({
    super.key,
    required this.title,
    this.content,
    this.contentWidget,
    this.actions,
    this.icon,
    this.iconColor,
  });

  final String title;
  final String? content;
  final Widget? contentWidget;
  final List<Widget>? actions;
  final IconData? icon;
  final Color? iconColor;

  /// Shows an Ascent confirmation dialog. Returns true if confirmed, false or null if canceled.
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData? icon,
  }) {
    HapticFeedback.lightImpact();

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AscentDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        icon: icon ?? (isDestructive ? Icons.warning_amber_rounded : null),
        iconColor: isDestructive ? context.stateDanger : context.accentPrimary,
        actions: [
          Row(
            children: [
              Expanded(
                child: AscentButton.outlined(
                  label: cancelLabel,
                  compact: true,
                  onPressed: () => Navigator.pop(ctx, false),
                ),
              ),
              const SizedBox(width: AscentDimensions.spaceSm),
              Expanded(
                child: isDestructive
                    ? AscentButton.destructive(
                        label: confirmLabel,
                        compact: true,
                        expanded: true,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx, true);
                        },
                      )
                    : AscentButton.primary(
                        label: confirmLabel,
                        compact: true,
                        expanded: true,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx, true);
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows a simple informational alert dialog.
  static Future<void> alert({
    required BuildContext context,
    required String title,
    String? content,
    Widget? contentWidget,
    String buttonLabel = 'Understood',
    IconData? icon,
  }) {
    HapticFeedback.lightImpact();

    return showDialog<void>(
      context: context,
      builder: (ctx) => AscentDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        icon: icon,
        actions: [
          AscentButton.primary(
            label: buttonLabel,
            compact: true,
            expanded: true,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = context.isDark;

    return Dialog(
      backgroundColor: context.bgSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AscentDimensions.radiusXl),
        side: BorderSide(
          color: g.edge.withValues(alpha: isDark ? 0.4 : 0.8),
          width: 1.0,
        ),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(AscentDimensions.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (iconColor ?? context.accentPrimary).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: iconColor ?? context.accentPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AscentDimensions.spaceMd),
            ],
            Text(
              title,
              style: AscentTextStyles.displaySmall.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (content != null && content!.isNotEmpty) ...[
              const SizedBox(height: AscentDimensions.spaceSm),
              Text(
                content!,
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: context.textMuted,
                  height: 1.45,
                ),
              ),
            ],
            if (contentWidget != null) ...[
              const SizedBox(height: AscentDimensions.spaceSm),
              contentWidget!,
            ],
            if (actions != null && actions!.isNotEmpty) ...[
              const SizedBox(height: AscentDimensions.spaceXl),
              ...actions!,
            ],
          ],
        ),
      ),
    );
  }
}
