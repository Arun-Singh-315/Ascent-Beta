import 'dart:ui';
import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import 'app_surfaces.dart';

/// Translucent glass container matching Ascent design system:
/// - 22px blur BackdropFilter
/// - Subtle 1px border
/// - 24px default corner radius
/// - RepaintBoundary for 60fps scroll performance
class GlassSurface extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Border? customBorder;
  final Color? fillColor;
  final bool enableBlur;
  final BorderRadius? borderRadius;

  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.padding = const EdgeInsets.all(AppSpace.s16),
    this.onTap,
    this.customBorder,
    this.fillColor,
    this.enableBlur = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final r = borderRadius ?? BorderRadius.circular(radius);

    Widget content = AppCard(
      padding: padding,
      nightDecoration: BoxDecoration(
        color: fillColor ?? g.fill,
        borderRadius: r,
        border:
            customBorder ??
            Border.all(color: g.edge, width: AppBorderScale.w1point0),
        boxShadow: context.surfaces.blur == 0
            ? const []
            : [
                BoxShadow(
                  color: g.shadow.withValues(
                    alpha: context.isDark ? 0.35 : 0.08,
                  ),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: AppPalette.transparent,
        child: AppTapArea(onTap: onTap, borderRadius: r, child: content),
      );
    }

    if (!enableBlur || context.surfaces.blur == 0) {
      return content;
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: content,
        ),
      ),
    );
  }
}
