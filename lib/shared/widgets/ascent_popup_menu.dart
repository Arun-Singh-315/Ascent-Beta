import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';

/// Standardized Ascent popup menu item conforming to Section 5 (C08).
/// - Minimum row height: 48px
/// - Icons: 20px
/// - Icon-label gap: 12px
/// - Text: 16px body style
/// - Horizontal padding: 16px
PopupMenuItem<T> ascentPopupItem<T>({
  required T value,
  required IconData icon,
  required String label,
  Color? iconColor,
  TextStyle? textStyle,
  bool enabled = true,
}) {
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    padding: const EdgeInsets.symmetric(horizontal: AscentDimensions.spaceLg),
    child: Builder(
      builder: (context) {
        final g = context.glass;
        final effectiveIconColor = iconColor ?? (enabled ? g.inkSecondary : g.disabledFg);
        final effectiveTextStyle = (textStyle ?? AscentTextStyles.body).copyWith(
          color: enabled ? g.ink : g.disabledFg,
        );

        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AscentDimensions.minTouchTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: effectiveIconColor,
              ),
              const SizedBox(width: AscentDimensions.spaceMd),
              Flexible(
                child: Text(
                  label,
                  style: effectiveTextStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Standardized Ascent destructive popup menu item conforming to Section 5 (C08).
PopupMenuItem<T> ascentPopupDestructiveItem<T>({
  required T value,
  required IconData icon,
  required String label,
  bool enabled = true,
}) {
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    padding: const EdgeInsets.symmetric(horizontal: AscentDimensions.spaceLg),
    child: Builder(
      builder: (context) {
        final g = context.glass;
        final errorColor = enabled ? g.errorInk : g.disabledFg;

        return ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AscentDimensions.minTouchTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: errorColor,
              ),
              const SizedBox(width: AscentDimensions.spaceMd),
              Flexible(
                child: Text(
                  label,
                  style: AscentTextStyles.body.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Standardized Ascent popup menu button conforming to Section 5 (C08).
/// Uses the current appearance (respects light/dark modes) instead of forcing dark colors in daylight.
class AscentPopupMenuButton<T> extends StatelessWidget {
  const AscentPopupMenuButton({
    super.key,
    required this.itemBuilder,
    this.onSelected,
    this.onCanceled,
    this.onOpened,
    this.initialValue,
    this.icon,
    this.child,
    this.tooltip,
    this.enabled = true,
    this.padding = EdgeInsets.zero,
    this.offset = Offset.zero,
    this.constraints = const BoxConstraints(minWidth: 170, maxWidth: 280),
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final VoidCallback? onOpened;
  final T? initialValue;
  final Widget? icon;
  final Widget? child;
  final String? tooltip;
  final bool enabled;
  final EdgeInsetsGeometry padding;
  final Offset offset;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = g.isDark;

    return Theme(
      data: Theme.of(context).copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: g.elevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AscentDimensions.radiusLg),
            side: BorderSide(
              color: g.line,
              width: AscentDimensions.contentOutlineWidth,
            ),
          ),
          elevation: 4,
          shadowColor: Color.fromRGBO(0, 0, 0, isDark ? 0.20 : 0.10),
          menuPadding: const EdgeInsets.symmetric(vertical: 4),
          textStyle: AscentTextStyles.body.copyWith(color: g.ink),
        ),
      ),
      child: PopupMenuButton<T>(
        tooltip: tooltip,
        enabled: enabled,
        padding: padding,
        offset: offset,
        constraints: constraints,
        initialValue: initialValue,
        onOpened: () {
          HapticFeedback.lightImpact();
          onOpened?.call();
        },
        onCanceled: onCanceled,
        onSelected: (val) {
          HapticFeedback.lightImpact();
          onSelected?.call(val);
        },
        itemBuilder: itemBuilder,
        icon: icon,
        child: child,
      ),
    );
  }
}
