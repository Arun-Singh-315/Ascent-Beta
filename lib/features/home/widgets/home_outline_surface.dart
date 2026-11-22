import 'package:flutter/material.dart';

import '../../../app/theme/home_design.dart';

/// Quiet content surface. Depth is reserved for navigation and overlays.
class HomeOutlineSurface extends StatelessWidget {
  const HomeOutlineSurface({
    super.key,
    required this.child,
    this.surfaceKey,
    this.radius = 24,
    this.padding = const EdgeInsets.all(16),
    this.showOutline = true,
    this.frameless = false,
    this.framed = false,
    this.decoration,
  });

  final Widget child;
  final Key? surfaceKey;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool showOutline;
  final bool frameless;
  final bool framed;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    return frameless
        ? Padding(key: surfaceKey, padding: padding, child: child)
        : Container(
            key: surfaceKey,
            padding: padding,
            decoration:
                decoration ??
                (framed
                    ? HomeSurfaceStyle.frame(context, radius: radius)
                    : HomeSurfaceStyle.decoration(
                        context,
                        outlined: showOutline,
                      )),
            child: child,
          );
  }
}

/// Selective materials for the working area, creative space and wellbeing.
abstract final class HomeSurfaceStyle {
  static Color line(BuildContext context) => MediaQuery.highContrastOf(context)
      ? HomeDesign.of(context).controlOutline
      : HomeDesign.of(context).separator;

  static BoxDecoration frame(BuildContext context, {double radius = 18}) =>
      BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line(context)),
      );

  static BoxDecoration work(BuildContext context) {
    final design = HomeDesign.of(context);
    return BoxDecoration(
      color: design.canvas,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: MediaQuery.highContrastOf(context)
            ? design.controlOutline
            : design.workEdge.withValues(alpha: .65),
      ),
    );
  }

  static BoxDecoration mind(BuildContext context) {
    return const BoxDecoration();
  }

  static BoxDecoration wellness(BuildContext context) {
    final design = HomeDesign.of(context);
    return BoxDecoration(
      color: design.canvas,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: MediaQuery.highContrastOf(context)
            ? design.controlOutline
            : design.wellnessEdge.withValues(alpha: .65),
      ),
    );
  }

  static BoxDecoration decoration(
    BuildContext context, {
    double radius = 0,
    bool outlined = true,
    bool transparent = false,
  }) {
    final colors = HomeDesign.of(context);
    return BoxDecoration(
      color: Colors.transparent,
      border: outlined
          ? Border(
              bottom: BorderSide(
                color: MediaQuery.highContrastOf(context)
                    ? colors.controlOutline
                    : Color.lerp(colors.separator, colors.secondaryText, .16)!,
                width: 1,
              ),
            )
          : null,
    );
  }
}

/// The primary working area has the clearest edge and a restrained elevation.
class HomeBorderSection extends StatelessWidget {
  const HomeBorderSection({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final design = HomeDesign.of(context);
    final borderColor = MediaQuery.highContrastOf(context)
        ? design.controlOutline
        : Color.lerp(design.separator, design.secondaryText, .22)!;

    return CustomPaint(
      painter: _HomeNotchedBorderPainter(
        borderColor: borderColor,
        fillColor: design.canvas,
        borderWidth: 1.0,
        radius: 24.0,
        topY: 26.0,
        titleCutoutLeft: 34.0,
        titleCutoutRight: 114.0,
        arrowCutoutWidth: 44.0,
        arrowCutoutRightMargin: 16.0,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 16),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _HomeNotchedBorderPainter extends CustomPainter {
  const _HomeNotchedBorderPainter({
    required this.borderColor,
    required this.fillColor,
    required this.borderWidth,
    required this.radius,
    required this.topY,
    required this.titleCutoutLeft,
    required this.titleCutoutRight,
    required this.arrowCutoutWidth,
    required this.arrowCutoutRightMargin,
  });

  final Color borderColor;
  final Color fillColor;
  final double borderWidth;
  final double radius;
  final double topY;
  final double titleCutoutLeft;
  final double titleCutoutRight;
  final double arrowCutoutWidth;
  final double arrowCutoutRightMargin;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw smooth background fill inside card
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        borderWidth / 2,
        topY,
        size.width - borderWidth / 2,
        size.height - borderWidth / 2,
      ),
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, fillPaint);

    // 2. Draw border with precise notches for title and arrow
    final strokePaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final r = radius;
    final arrowLeft = size.width - arrowCutoutRightMargin - arrowCutoutWidth;
    final arrowRight = size.width - arrowCutoutRightMargin;

    final path = Path();

    // Line from right of title to left of arrow
    if (arrowLeft > titleCutoutRight) {
      path.moveTo(titleCutoutRight, topY);
      path.lineTo(arrowLeft, topY);
    }

    // Line from right of arrow to top-right corner
    final rightCornerStartX = size.width - r;
    if (rightCornerStartX > arrowRight) {
      path.moveTo(arrowRight, topY);
      path.lineTo(rightCornerStartX, topY);
    } else {
      path.moveTo(rightCornerStartX, topY);
    }

    // Top-right corner arc
    path.arcToPoint(
      Offset(size.width, topY + r),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // Right border down
    path.lineTo(size.width, size.height - r);

    // Bottom-right corner arc
    path.arcToPoint(
      Offset(size.width - r, size.height),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // Bottom border line
    path.lineTo(r, size.height);

    // Bottom-left corner arc
    path.arcToPoint(
      Offset(0, size.height - r),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // Left border up
    path.lineTo(0, topY + r);

    // Top-left corner arc
    path.arcToPoint(
      Offset(r, topY),
      radius: Radius.circular(r),
      clockwise: true,
    );

    // Line to left of title
    if (titleCutoutLeft > r) {
      path.lineTo(titleCutoutLeft, topY);
    }

    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _HomeNotchedBorderPainter oldDelegate) =>
      oldDelegate.borderColor != borderColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.radius != radius ||
      oldDelegate.topY != topY ||
      oldDelegate.titleCutoutLeft != titleCutoutLeft ||
      oldDelegate.titleCutoutRight != titleCutoutRight ||
      oldDelegate.arrowCutoutWidth != arrowCutoutWidth ||
      oldDelegate.arrowCutoutRightMargin != arrowCutoutRightMargin;
}
