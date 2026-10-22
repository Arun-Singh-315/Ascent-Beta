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
  final Gradient? gradient;
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
    this.gradient,
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
        color: gradient == null ? (fillColor ?? g.fill) : null,
        gradient: gradient,
        borderRadius: r,
        border: customBorder ??
            Border.all(color: g.edge, width: AppBorderScale.w1point0),
        boxShadow: context.isDark
            ? (context.surfaces.blur == 0
                ? const []
                : g.frozen
                    ? [
                        BoxShadow(
                          color: g.shadow.withValues(alpha: 0.50),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                          spreadRadius: -2,
                        ),
                        BoxShadow(
                          color: g.highlight.withValues(alpha: 0.60),
                          blurRadius: 0,
                          offset: const Offset(0, 0),
                          spreadRadius: -1,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: g.shadow.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ])
            : [
                BoxShadow(
                  color: g.shadow.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: g.shadow.withValues(alpha: 0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                  spreadRadius: 0,
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
          filter: ImageFilter.blur(
            sigmaX: context.surfaces.blur,
            sigmaY: context.surfaces.blur,
          ),
          child: content,
        ),
      ),
    );
  }
}
