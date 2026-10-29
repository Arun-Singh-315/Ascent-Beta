import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../shared/widgets/glass_surface.dart';

/// Quiet content surface. Depth is reserved for navigation and overlays.
class HomeOutlineSurface extends StatelessWidget {
  const HomeOutlineSurface({
    super.key,
    required this.child,
    this.surfaceKey,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
    this.showOutline = true,
  });

  final Widget child;
  final Key? surfaceKey;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool showOutline;

  @override
  Widget build(BuildContext context) => GlassSurface(
    key: surfaceKey,
    radius: radius,
    padding: padding,
    enableBlur: false,
    hasShadow: false,
    customBorder: showOutline
        ? Border.all(color: context.glass.line, width: .75)
        : const Border.fromBorderSide(BorderSide.none),
    child: child,
  );
}
