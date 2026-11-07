import 'dart:math' as math;
import 'dart:ui';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import 'ascent_button.dart';

/// Displays a centered glass modal dialog with a frosted background freeze blur.
Future<T?> showAscentFrostedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String barrierLabel = 'Dismiss',
  Color? barrierColor,
  double blurSigma = 16.0,
  Duration transitionDuration = const Duration(milliseconds: 280),
  bool useRootNavigator = true,
}) {
  HapticFeedback.lightImpact();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final effectiveBarrierColor =
      barrierColor ?? Color.fromRGBO(0, 0, 0, isDark ? 0.40 : 0.18);

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel,
    barrierColor: effectiveBarrierColor,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : transitionDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        builder(dialogContext),
    transitionBuilder: (dialogContext, anim, secondaryAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return AnimatedBuilder(
        animation: anim,
        builder: (context, child) {
          final sigma = math.max(0.001, blurSigma * anim.value);
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          );
        },
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Presents a form in a centered, keyboard-aware viewport over the shared
/// frozen backdrop. The form widget owns its surface and scroll behavior.
Future<T?> showAscentCenteredForm<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 440,
  bool barrierDismissible = true,
}) => showAscentFrostedDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  builder: (dialogContext) {
    final media = MediaQuery.of(dialogContext);
    final keyboard = media.viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(24, 20, 24, keyboard + 20),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: (media.size.height - keyboard - 40).clamp(
                220,
                double.infinity,
              ),
            ),
            child: builder(dialogContext),
          ),
        ),
      ),
    );
  },
);

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barrierColor = Color.fromRGBO(0, 0, 0, isDark ? 0.56 : 0.38);

    return showAscentFrostedDialog<bool>(
      context: context,
      barrierColor: barrierColor,
      builder: (ctx) {
        final textScaler = MediaQuery.textScalerOf(ctx);
        final isLargeText = textScaler.scale(1.0) >= 1.45;

        final cancelBtn = AscentButton.outlined(
          label: cancelLabel,
          compact: true,
          expanded: isLargeText,
          onPressed: () => Navigator.pop(ctx, false),
        );

        final confirmBtn = isDestructive
            ? AscentButton.destructive(
                label: confirmLabel,
                compact: true,
                expanded: isLargeText,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx, true);
                },
              )
            : AscentButton.tonal(
                label: confirmLabel,
                compact: true,
                expanded: isLargeText,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(ctx, true);
                },
              );

        return AscentDialog(
          title: title,
          content: content,
          contentWidget: contentWidget,
          icon: icon ?? (isDestructive ? Icons.warning_amber_rounded : null),
          iconColor: isDestructive ? ctx.stateDanger : ctx.accentPrimary,
          actions: [
            if (isLargeText) ...[
              confirmBtn,
              const SizedBox(height: AscentDimensions.spaceSm),
              cancelBtn,
            ] else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AscentDimensions.spaceSm,
                children: [cancelBtn, confirmBtn],
              ),
          ],
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barrierColor = Color.fromRGBO(0, 0, 0, isDark ? 0.56 : 0.38);

    return showAscentFrostedDialog<void>(
      context: context,
      barrierColor: barrierColor,
      builder: (ctx) => AscentDialog(
        title: title,
        content: content,
        contentWidget: contentWidget,
        icon: icon,
        actions: [
          Align(
            alignment: Alignment.centerRight,
            child: AscentButton.tonal(
              label: buttonLabel,
              compact: true,
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AscentDimensions.spaceXxl,
        vertical: AscentDimensions.spaceXxl,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: g.elevated,
          borderRadius: BorderRadius.circular(AscentDimensions.radiusXl),
          border: Border.all(
            color: g.line,
            width: AscentDimensions.contentOutlineWidth,
          ),
        ),
        padding: const EdgeInsets.all(AscentDimensions.spaceXl),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(AscentDimensions.spaceSm),
                    decoration: BoxDecoration(
                      color: (iconColor ?? g.actionInk).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: iconColor ?? g.actionInk,
                    ),
                  ),
                ),
                const SizedBox(height: AscentDimensions.spaceMd),
              ],
              Text(
                title,
                style: AscentTextStyles.cardTitle.copyWith(color: g.ink),
              ),
              if (content != null && content!.isNotEmpty) ...[
                const SizedBox(height: AscentDimensions.spaceSm),
                Text(
                  content!,
                  style: AscentTextStyles.supportingText.copyWith(
                    color: g.inkSecondary,
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
