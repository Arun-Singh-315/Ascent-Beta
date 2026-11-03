import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../app/theme/shared_control_tokens.dart';

class AscentSegment<T> {
  const AscentSegment({
    required this.value,
    required this.label,
    this.icon,
    this.key,
  });
  final Key? key;
  final T value;
  final String label;
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
  });

  final List<AscentSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final bool accented;

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
    final containerBg = accented
        ? (dark
              ? g.elevated.withValues(alpha: .72)
              : g.fill.withValues(alpha: .82))
        : (dark
              ? SharedControlColors.neutralFillDark
              : const Color(0xFFE9E9EE));
    final selectedSurface = accented
        ? accentColor.withValues(alpha: dark ? .20 : .12)
        : (dark ? const Color(0xFF636366) : Colors.white);
    final selectedTextColor = accented
        ? accentColor
        : (dark
              ? SharedControlColors.labelDark
              : SharedControlColors.labelLight);
    final selectedBorderColor = accented
        ? accentColor.withValues(alpha: dark ? .48 : .32)
        : g.line;
    final unselectedTextColor = dark
        ? const Color(0xFFCCCCD2)
        : const Color(0xFF636366);

    if (isLargeText) {
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
                onTap: () => _handleSelect(segment.value),
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
                    mainAxisSize: MainAxisSize.min,
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
                      Text(
                        segment.label,
                        style: AscentTextStyles.segmentLabel.copyWith(
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
          final segmentWidth = constraints.maxWidth / count;

          return Stack(
            children: [
              // Animated highlight pill
              AnimatedPositioned(
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                left: activeIndex * segmentWidth,
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
                    child: Semantics(
                      button: true,
                      selected: isSelected,
                      label: segment.label,
                      child: InkWell(
                        key: segment.key,
                        onTap: () => _handleSelect(segment.value),
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
                                  style: AscentTextStyles.segmentLabel.copyWith(
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
