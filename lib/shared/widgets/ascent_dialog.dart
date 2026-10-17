import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import 'ascent_button.dart';
import 'glass_surface.dart';

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

    return Dialog(
      backgroundColor: AppPalette.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AscentDimensions.radiusXl),
        side: BorderSide(color: g.edge, width: AppBorderScale.w1point0),
      ),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s24,
        vertical: AppSpace.s24,
      ),
      child: GlassSurface(
        radius: AscentDimensions.radiusXl,
        padding: const EdgeInsets.all(AscentDimensions.spaceXl),
        fillColor: context.isDark
            ? (g.frozen ? const Color(0xF2162338) : const Color(0xF41E1914))
            : (g.frozen ? const Color(0xF4F7FAFD) : const Color(0xF6FFFFFF)),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppTag(
                    padding: const EdgeInsets.all(AppSpace.s8),
                    nightDecoration: BoxDecoration(
                      color: (iconColor ?? context.accentPrimary).withValues(
                        alpha: 0.14,
                      ),
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
                style: AscentTextStyles.displaySmall
                    .copyWith(color: context.textPrimary)
                    .merge(AppTypeRoles.typeRole2),
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
      ),
    );
  }
}
