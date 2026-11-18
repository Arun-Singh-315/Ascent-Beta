import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Opaque overlay container for any view that opens on top of content:
/// bottom sheets, dropdowns, dialogs, popup menus, date/time pickers, snackbars.
///
/// Under Section 3 (Glass done safely):
/// Overlays MUST be completely OPAQUE so content never bleeds through or ruins legibility.
/// In dark mode: solid surface #2A2420 (or #221D19 for bottom sheets) + soft shadow.
/// In light mode: solid surface #FFFDF9 / #FAF6F0 + warm shadow.
/// Scrim is black@45%. No transparency and no blur.
class OpaqueOverlaySurface extends StatelessWidget {
  const OpaqueOverlaySurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
    this.isSheet = false,
    this.border,
    this.shadows,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool isSheet;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final solidColor = isDark
        ? (isSheet ? const Color(0xFF14171E) : const Color(0xFF16181F))
        : (isSheet ? const Color(0xFFF8FAFC) : const Color(0xFFFFFFFF));

    final effectiveRadius = borderRadius ??
        (isSheet
            ? BorderRadius.vertical(top: Radius.circular(radius))
            : BorderRadius.circular(radius));

    final effectiveShadows = shadows ??
        [
          BoxShadow(
            color: isDark ? const Color(0x73000000) : const Color(0x1F0F172A),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ];

    return Material(
      color: solidColor,
      borderRadius: effectiveRadius,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: solidColor,
          borderRadius: effectiveRadius,
          border: border ??
              Border.all(
                color: c.border,
                width: 1.0,
              ),
          boxShadow: effectiveShadows,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
