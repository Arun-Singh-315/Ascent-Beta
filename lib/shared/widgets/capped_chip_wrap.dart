import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_chip.dart';

/// Wraps chips and caps them at [maxRows] (default: 2 rows).
/// If chips exceed [maxRows], an inline "+N more" chip is appended.
/// Tapping "+N more" reveals the rest inline smoothly.
class CappedChipWrap extends StatefulWidget {
  const CappedChipWrap({
    super.key,
    required this.children,
    this.maxRows = 2,
    this.spacing = 8.0,
    this.runSpacing = 8.0,
    this.alignment = WrapAlignment.start,
    this.crossAxisAlignment = WrapCrossAlignment.center,
  });

  final List<Widget> children;
  final int maxRows;
  final double spacing;
  final double runSpacing;
  final WrapAlignment alignment;
  final WrapCrossAlignment crossAxisAlignment;

  @override
  State<CappedChipWrap> createState() => _CappedChipWrapState();
}

class _CappedChipWrapState extends State<CappedChipWrap> {
  bool _expanded = false;

  double _measureChipWidth(
    String label, {
    bool hasIcon = false,
    required TextScaler textScaler,
    required double fontSize,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      maxLines: 1,
    )..layout();

    final textW = painter.width;
    painter.dispose();

    // 28px horizontal padding (14 left + 14 right) + optional icon (16px + 6px gap) + 2px safety
    return 28.0 + (hasIcon ? 22.0 : 0.0) + textW + 2.0;
  }

  double _getWidgetWidth(Widget widget, TextScaler textScaler) {
    if (widget is AppChip) {
      return _measureChipWidth(
        widget.label,
        hasIcon: widget.icon != null || widget.emoji != null,
        textScaler: textScaler,
        fontSize: widget.fontSize,
      );
    }
    // Fallback estimation for arbitrary widget
    return 100.0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();

    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        if (maxWidth <= 0 || maxWidth.isInfinite) {
          return Wrap(
            spacing: widget.spacing,
            runSpacing: widget.runSpacing,
            alignment: widget.alignment,
            crossAxisAlignment: widget.crossAxisAlignment,
            children: widget.children,
          );
        }

        if (_expanded) {
          return AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topLeft,
            child: Wrap(
              spacing: widget.spacing,
              runSpacing: widget.runSpacing,
              alignment: widget.alignment,
              crossAxisAlignment: widget.crossAxisAlignment,
              children: [
                ...widget.children,
                AppChip(
                  key: const ValueKey('capped_chip_show_less'),
                  label: 'Show less',
                  icon: Icons.keyboard_arrow_up_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _expanded = false);
                  },
                ),
              ],
            ),
          );
        }

        // Calculate line breaks to cap at maxRows
        int currentRow = 1;
        double currentWidth = 0.0;
        final visibleIndices = <int>[];

        for (int i = 0; i < widget.children.length; i++) {
          final w = _getWidgetWidth(widget.children[i], textScaler);
          final gap = currentWidth > 0 ? widget.spacing : 0.0;

          if (currentWidth + gap + w <= maxWidth) {
            currentWidth += gap + w;
            visibleIndices.add(i);
          } else {
            // New row
            currentRow++;
            if (currentRow <= widget.maxRows) {
              currentWidth = w;
              visibleIndices.add(i);
            } else {
              break;
            }
          }
        }

        // Check if all children fit within maxRows
        if (visibleIndices.length == widget.children.length) {
          return Wrap(
            spacing: widget.spacing,
            runSpacing: widget.runSpacing,
            alignment: widget.alignment,
            crossAxisAlignment: widget.crossAxisAlignment,
            children: widget.children,
          );
        }

        // We have overflow beyond maxRows: need "+N more" chip
        int hiddenCount = widget.children.length - visibleIndices.length;
        double moreChipW = _measureChipWidth(
          '+$hiddenCount more',
          hasIcon: true,
          textScaler: textScaler,
          fontSize: 13.0,
        );

        // Ensure "+N more" fits on the current (last allowed) row
        while (visibleIndices.isNotEmpty &&
            currentWidth + widget.spacing + moreChipW > maxWidth) {
          final removedIdx = visibleIndices.removeLast();
          final removedW = _getWidgetWidth(widget.children[removedIdx], textScaler);
          currentWidth -= (removedW + widget.spacing);
          hiddenCount = widget.children.length - visibleIndices.length;
          moreChipW = _measureChipWidth(
            '+$hiddenCount more',
            hasIcon: true,
            textScaler: textScaler,
            fontSize: 13.0,
          );
        }

        final visibleWidgets = [
          for (final idx in visibleIndices) widget.children[idx],
          AppChip(
            key: ValueKey('capped_chip_more_$hiddenCount'),
            label: '+$hiddenCount more',
            icon: Icons.add_rounded,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = true);
            },
          ),
        ];

        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: widget.spacing,
            runSpacing: widget.runSpacing,
            alignment: widget.alignment,
            crossAxisAlignment: widget.crossAxisAlignment,
            children: visibleWidgets,
          ),
        );
      },
    );
  }
}
