import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';

class AscentSegment<T> {
  const AscentSegment({required this.value, required this.label});
  final T value;
  final String label;
}

/// Generic single-selection segmented control as specified in Section 5 (C04).
///
/// Features:
/// - Container: recessed fill, 4px padding, 999px capsule radius, minHeight: 48px.
/// - Selected segment: content surface fill, 999px radius, primary text.
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
  });

  final List<AscentSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool enabled;

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

    final containerBg = g.recessed;
    final selectedSurface = g.surface;
    final selectedTextColor = g.ink;
    final unselectedTextColor = g.inkSecondary;

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
                onTap: () => _handleSelect(segment.value),
                borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: AscentDimensions.minTouchTarget,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedSurface : Colors.transparent,
                    borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
                    border: isSelected
                        ? Border.all(
                            color: g.line,
                            width: AscentDimensions.contentOutlineWidth,
                          )
                        : null,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AscentDimensions.spaceMd,
                    vertical: AscentDimensions.spaceSm,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    segment.label,
                    style: AscentTextStyles.segmentLabel.copyWith(
                      color: isSelected ? selectedTextColor : unselectedTextColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
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
        borderRadius: BorderRadius.circular(AscentDimensions.radiusFull),
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
          final segmentWidth = (constraints.maxWidth - 2 * AscentDimensions.spaceXs) / count;

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
                    borderRadius: BorderRadius.circular(AscentDimensions.radiusFull),
                    border: Border.all(
                      color: g.line,
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
                            horizontal: AscentDimensions.spaceMd,
                            vertical: AscentDimensions.spaceSm,
                          ),
                          child: Text(
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
