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
  });

  final Widget child;
  final Key? surfaceKey;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool showOutline;
  final bool frameless;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    return frameless
        ? Padding(key: surfaceKey, padding: padding, child: child)
        : Container(
            key: surfaceKey,
            padding: padding,
            decoration: framed
                ? HomeSurfaceStyle.frame(context, radius: radius)
                : HomeSurfaceStyle.decoration(context, outlined: showOutline),
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
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          design.surface,
          Color.lerp(design.surface, design.workTint, .24)!,
        ],
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: MediaQuery.highContrastOf(context)
            ? design.controlOutline
            : design.workEdge.withValues(alpha: .65),
      ),
    );
  }

  static BoxDecoration mind(BuildContext context) {
    final design = HomeDesign.of(context);
    return BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.centerStart,
        end: AlignmentDirectional.centerEnd,
        colors: [design.mindTint, design.mindTint.withValues(alpha: .25)],
      ),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
    );
  }

  static BoxDecoration wellness(BuildContext context) {
    final design = HomeDesign.of(context);
    return BoxDecoration(
      gradient: design.wellness,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: MediaQuery.highContrastOf(context)
            ? design.controlOutline
            : design.wellnessEdge.withValues(alpha: .65),
      ),
    );
  }

  static BoxDecoration rail(BuildContext context) => BoxDecoration(
    border: BorderDirectional(
      start: BorderSide(color: HomeDesign.of(context).mindEdge, width: 2),
    ),
  );

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
  Widget build(BuildContext context) => Container(
    decoration: HomeSurfaceStyle.work(context),
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
    child: child,
  );
}
