import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/frozen_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/merlot_palette.dart';
import '../../app/theme/text_styles.dart';

/// Standardized Ascent sleek dark obsidian popup menu item.
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
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: iconColor,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Standardized Ascent destructive popup menu item (e.g. Delete, Remove).
PopupMenuItem<T> ascentPopupDestructiveItem<T>({
  required T value,
  required IconData icon,
  required String label,
  bool enabled = true,
}) {
  const destructiveColor = Color(0xFFEF4444);
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 17,
          color: destructiveColor,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: AscentTextStyles.bodyMedium.copyWith(
              color: destructiveColor,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Standardized Ascent sleek dark obsidian popup menu button.
///
/// Features:
/// - Inherits the centralized sleek dark obsidian theme across all presets.
/// - Injects high-contrast light icon themes into popup items.
/// - Emits subtle tactile haptics on opening and on item selection.
/// - Provides responsive min/max constraints and zero-bleed-through guarantee.
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
    final iconColor = g.merlot
        ? MerlotPalette.darkSecondaryInk
        : g.frozen
        ? FrozenPalette.darkSecondaryInk
        : AscentColors.textSecondaryDark;

    return Theme(
      data: Theme.of(context).copyWith(
        iconTheme: IconThemeData(
          color: iconColor,
          size: 17,
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
