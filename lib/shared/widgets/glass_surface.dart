import 'dart:ui';
import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';

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

    final dark = context.isDark;
    final base = fillColor ?? Theme.of(context).colorScheme.surfaceContainer;
    final transparent = base.a == 0;
    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: transparent && gradient == null ? Colors.transparent : null,
        gradient:
            gradient ??
            (transparent
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      base.withValues(alpha: dark ? .66 : .82),
                      base.withValues(alpha: dark ? .38 : .54),
                    ],
                  )),
        borderRadius: r,
        border:
            customBorder ??
            Border.all(color: g.ink.withValues(alpha: dark ? .24 : .20)),
        boxShadow: transparent
            ? const []
            : [
                BoxShadow(
                  color: g.shadow.withValues(alpha: dark ? .16 : .06),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: AppPalette.transparent,
        child: InkWell(onTap: onTap, borderRadius: r, child: content),
      );
    }

    if (!enableBlur) {
      return content;
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: context.surfaces.blur > 0 ? context.surfaces.blur : 12,
            sigmaY: context.surfaces.blur > 0 ? context.surfaces.blur : 12,
          ),
          child: content,
        ),
      ),
    );
  }
}
