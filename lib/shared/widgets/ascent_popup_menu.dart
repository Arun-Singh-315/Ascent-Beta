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

/// A single-choice menu row whose selected state is a rounded pill that
/// follows the menu's own corners, instead of Material's full-width rectangle.
///
/// Use it with [AscentPopupMenuButton] and do not pass `initialValue`: the
/// selected row is drawn here, so Material's rectangular highlight stays off.
PopupMenuItem<T> ascentChoiceItem<T>({
  required T value,
  required String label,
  required bool selected,
}) {
  return PopupMenuItem<T>(
    value: value,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    child: Builder(
      builder: (context) {
        final g = context.glass;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(
            minHeight: AscentDimensions.minTouchTarget - 4,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AscentDimensions.spaceMd,
          ),
          alignment: AlignmentDirectional.centerStart,
          decoration: ShapeDecoration(
            color: selected ? g.claySoft : Colors.transparent,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AscentTextStyles.body.copyWith(
                    color: g.ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, size: 18, color: g.clay),
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
          menuPadding: const EdgeInsets.symmetric(vertical: 6),
          textStyle: AscentTextStyles.body.copyWith(color: g.ink),
        ),
      ),
      child: PopupMenuButton<T>(
        clipBehavior: Clip.antiAlias,
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

/// One option of an [AscentSelectField].
class AscentSelectOption<T> {
  const AscentSelectOption(this.value, this.label);
  final T value;
  final String label;
}

/// A labelled single-choice field: one input container showing the current
/// choice, opening an [AscentPopupMenuButton] of [ascentChoiceItem] rows.
///
/// Replaces Material `DropdownButton` / `DropdownButtonFormField` in feature
/// code. A `null` [value] is a valid choice (for "None" style options).
/// Passing `null` for [onChanged] disables the field.
class AscentSelectField<T> extends StatelessWidget {
  const AscentSelectField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<AscentSelectOption<T>> options;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final enabled = onChanged != null && options.isNotEmpty;
    final selected = options.indexWhere((o) => o.value == value);
    final current = selected >= 0 ? options[selected].label : '–';
    return AscentPopupMenuButton<int>(
      enabled: enabled,
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
      onSelected: (i) => onChanged?.call(options[i].value),
      itemBuilder: (_) => [
        for (var i = 0; i < options.length; i++)
          ascentChoiceItem<int>(
            value: i,
            label: options[i].label,
            selected: i == selected,
          ),
      ],
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          labelText: label,
          enabled: enabled,
          suffixIcon: Icon(
            Icons.unfold_more_rounded,
            size: 20,
            color: enabled ? g.inkSecondary : g.disabledFg,
          ),
        ),
        child: Text(
          current,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AscentTextStyles.body.copyWith(
            color: enabled ? g.ink : g.disabledFg,
          ),
        ),
      ),
    );
  }
}
