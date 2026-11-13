import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/monochrome_surfaces.dart';
import '../../app/theme/text_styles.dart';
import '../../app/theme/shared_control_tokens.dart';

class AscentSegment<T> {
  const AscentSegment({
    required this.value,
    required this.label,
    this.icon,
    this.key,
    this.flex = 1,
  }) : assert(flex > 0);
  final Key? key;
  final T value;
  final String label;

  /// Relative width in the horizontal layout; stacked options remain full width.
  final int flex;
  final IconData? icon;
}

/// Generic single-selection segmented control as specified in Section 5 (C04).
///
/// Features:
/// - Container: neutral recessed fill, 4px padding, 12px radius.
/// - Selected segment: raised neutral surface and primary text.
/// - Unselected segment: transparent fill, secondary text.
/// - Highlight animation: 180ms easeOutCubic (instant with reduced motion).
/// - Emits selectionClick haptic only when switching to a different option.
/// - Accessible fallback at 200% / large text scales: vertically stacked single-choice list.
class AscentSegmentedControl<T> extends StatelessWidget {
  const AscentSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.accented = false,
    this.restrained = false,
    this.vertical = false,
    this.inline = false,
    this.pill = false,
    this.selectionColor,
  });

  final List<AscentSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool accented;
  final bool restrained;

  /// Reuses the accessible stacked layout for selection sheets.
  final bool vertical;

  /// Open tabs with a sliding accent rule, without nested selection boxes.
  final bool inline;
  final bool pill;
  final Color? selectionColor;

  void _handleSelect(T value) {
    if (!enabled) return;
    if (value != selected) {
      HapticFeedback.selectionClick();
      onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final textScaler = MediaQuery.textScalerOf(context);
    final isLargeText = textScaler.scale(1.0) >= 1.45;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    final neutral = MonochromeSurfaces.of(context);
    final containerBg = restrained
        ? neutral.groupedFill
        : accented
        ? (dark
              ? g.elevated.withValues(alpha: .72)
              : g.fill.withValues(alpha: .82))
        : (dark
              ? SharedControlColors.neutralFillDark
              : const Color(0xFFE9E9EE));
    final selectedSurface = restrained
        ? (dark ? neutral.neutralSelection : neutral.surface)
        : accented
        ? accentColor.withValues(alpha: dark ? .20 : .12)
        : (dark ? const Color(0xFF636366) : Colors.white);
    final selectedTextColor = restrained
        ? neutral.primaryText
        : accented
        ? accentColor
        : (dark
              ? SharedControlColors.labelDark
              : SharedControlColors.labelLight);
    final selectedBorderColor = restrained
        ? neutral.separator
        : accented
        ? accentColor.withValues(alpha: dark ? .48 : .32)
        : g.line;
    final unselectedTextColor = restrained
        ? neutral.secondaryText
        : dark
        ? const Color(0xFFCCCCD2)
        : const Color(0xFF636366);

    if (inline) {
      final stacked = isLargeText || vertical;
      final activeInk = selectionColor ?? accentColor;
      Widget option(AscentSegment<T> segment) {
        final active = segment.value == selected;
        return Semantics(
          button: true,
          selected: active,
          child: InkWell(
            key: segment.key,
            onTap: enabled ? () => _handleSelect(segment.value) : null,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                color: pill && active
                    ? activeInk.withValues(alpha: dark ? .18 : .09)
                    : Colors.transparent,
                borderRadius: pill ? BorderRadius.circular(28) : null,
                border: pill
                    ? null
                    : stacked
                    ? BorderDirectional(
                        start: BorderSide(
                          color: active ? accentColor : Colors.transparent,
                          width: 3,
                        ),
                      )
                    : Border(
                        bottom: BorderSide(
                          color: active ? accentColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
              ),
              child: Row(
                mainAxisAlignment: stacked
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.center,
                children: [
                  if (segment.icon != null) ...[
                    Icon(
                      segment.icon,
                      size: 17,
                      color: active ? activeInk : neutral.secondaryText,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      segment.label,
                      textAlign: stacked ? TextAlign.start : TextAlign.center,
                      style: AscentTextStyles.interfaceSupporting.copyWith(
                        color: !enabled
                            ? neutral.secondaryText
                            : active
                            ? activeInk
                            : neutral.secondaryText,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (stacked) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: segments.map(option).toList(),
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          final widths = [
            for (final segment in segments)
              ((TextPainter(
                        text: TextSpan(
                          text: segment.label,
                          style: AscentTextStyles.interfaceSupporting.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        textDirection: Directionality.of(context),
                        textScaler: textScaler,
                      )..layout()).width +
                      20 +
                      (segment.icon == null ? 0 : 23))
                  .clamp(48.0, double.infinity),
          ];
          final minimum = widths.fold<double>(0, (sum, width) => sum + width);
          final flex = segments.fold<int>(
            0,
            (sum, segment) => sum + segment.flex,
          );
          final extra = (constraints.maxWidth - minimum).clamp(
            0.0,
            double.infinity,
          );
          final row = Row(
            children: [
              for (var i = 0; i < segments.length; i++)
                SizedBox(
                  width:
                      widths[i] +
                      (flex == 0 ? 0 : extra * segments[i].flex / flex),
                  child: option(segments[i]),
                ),
            ],
          );
          return minimum > constraints.maxWidth
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: row,
                )
              : row;
        },
      );
    }

    if (isLargeText || vertical) {
      // Large text vertical fallback as required by Section 4 & C04
      return Container(
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
          border: Border.all(
            color: g.line,
            width: AscentDimensions.contentOutlineWidth,
          ),
        ),
        padding: const EdgeInsets.all(AscentDimensions.spaceXs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: segments.map((segment) {
            final isSelected = segment.value == selected;
            return Semantics(
              button: true,
              selected: isSelected,
              label: segment.label,
              child: InkWell(
                key: segment.key,
                onTap: enabled ? () => _handleSelect(segment.value) : null,
                borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AscentDimensions.minTouchTarget,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedSurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AscentDimensions.radiusMd,
                    ),
                    border: isSelected
                        ? Border.all(
                            color: selectedBorderColor,
                            width: AscentDimensions.contentOutlineWidth,
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AscentDimensions.spaceMd,
                    vertical: AscentDimensions.spaceSm,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      if (segment.icon != null) ...[
                        Icon(
                          segment.icon,
                          size: 17,
                          color: isSelected
                              ? selectedTextColor
                              : unselectedTextColor,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          segment.label,
                          style:
                              (restrained
                                      ? AscentTextStyles.interfaceSupporting
                                      : AscentTextStyles.segmentLabel)
                                  .copyWith(
                                    color: isSelected
                                        ? selectedTextColor
                                        : unselectedTextColor,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    }

    // Standard horizontal capsule layout
    return Container(
      constraints: const BoxConstraints(
        minHeight: AscentDimensions.buttonHeightStandard,
      ),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: g.line,
          width: AscentDimensions.contentOutlineWidth,
        ),
      ),
      padding: const EdgeInsets.all(AscentDimensions.spaceXs),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = segments.length;
          if (count == 0) return const SizedBox.shrink();

          final selectedIndex = segments.indexWhere((s) => s.value == selected);
          final activeIndex = selectedIndex >= 0 ? selectedIndex : 0;
          final totalFlex = segments.fold(
            0,
            (sum, segment) => sum + segment.flex,
          );
          final segmentWidth =
              constraints.maxWidth * segments[activeIndex].flex / totalFlex;
          final precedingFlex = segments
              .take(activeIndex)
              .fold(0, (sum, segment) => sum + segment.flex);
          final leadingOffset =
              constraints.maxWidth * precedingFlex / totalFlex;

          return Stack(
            children: [
              // Animated highlight pill
              AnimatedPositioned(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: Directionality.of(context) == TextDirection.rtl
                    ? constraints.maxWidth - leadingOffset - segmentWidth
                    : leadingOffset,
                top: 0,
                bottom: 0,
                width: segmentWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: selectedSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedBorderColor,
                      width: AscentDimensions.contentOutlineWidth,
                    ),
                  ),
                ),
              ),
              // Segment labels
              Row(
                children: segments.map((segment) {
                  final isSelected = segment.value == selected;
                  return Expanded(
                    flex: segment.flex,
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label: segment.label,
                      child: InkWell(
                        key: segment.key,
                        onTap: enabled
                            ? () => _handleSelect(segment.value)
                            : null,
                        borderRadius: BorderRadius.circular(
                          AscentDimensions.radiusFull,
                        ),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: AscentDimensions.buttonHeightCompact,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AscentDimensions.spaceSm,
                            vertical: AscentDimensions.spaceSm,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (segment.icon != null) ...[
                                  Icon(
                                    segment.icon,
                                    size: 15,
                                    color: isSelected
                                        ? selectedTextColor
                                        : unselectedTextColor,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  segment.label,
                                  textAlign: TextAlign.center,
                                  style:
                                      (restrained
                                              ? AscentTextStyles.interfaceLabel
                                              : AscentTextStyles.segmentLabel)
                                          .copyWith(
                                            color: isSelected
                                                ? selectedTextColor
                                                : unselectedTextColor,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.w500,
                                          ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}
