import 'dart:ui';
import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/day_glass_material.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/merlot_palette.dart';
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
  final bool hasShadow;
  final double minimumOpacity;
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
    this.hasShadow = true,
    this.minimumOpacity = 0,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final material = Theme.of(context).extension<DayGlassMaterial>();
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
            (material != null && !transparent
                ? material.gradient(base, minimumOpacity: minimumOpacity)
                : null) ??
            (transparent
                ? null
                : (g.merlot && !dark
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            MerlotPalette.surface,
                            MerlotPalette.surfaceBottom,
                          ],
                        )
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            base.withValues(alpha: dark ? .66 : .82),
                            base.withValues(alpha: dark ? .38 : .54),
                          ],
                        ))),
        borderRadius: r,
        border:
            customBorder ??
            (transparent ? null : material?.rim) ??
            (g.merlot && !dark
                ? Border.all(color: MerlotPalette.line, width: 0.85)
                : Border.all(color: g.ink.withValues(alpha: dark ? .24 : .20))),
        boxShadow: transparent || material != null || !hasShadow
            ? const []
            : [
                BoxShadow(
                  color: g.shadow.withValues(
                    alpha: dark ? .16 : (g.merlot ? .07 : .06),
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: () {
        if (!g.merlot || dark || transparent) return child;
        if (Theme.of(context).colorScheme.onSurface == MerlotPalette.cardInk) {
          return child;
        }
        final cardGlass = g.copyWith(
          ink: MerlotPalette.cardInk,
          inkSecondary: MerlotPalette.cardSecondaryInk,
          inkMuted: MerlotPalette.cardMutedInk,
          clay: MerlotPalette.action,
          claySoft: MerlotPalette.pillSoft,
          line: MerlotPalette.lineSubtle,
          edge: MerlotPalette.line,
          track: MerlotPalette.recessedWell,
          fill: MerlotPalette.surface,
          coral: MerlotPalette.terracotta,
          sage: MerlotPalette.success,
        );

        final parentTheme = Theme.of(context);
        final cardTheme = parentTheme.copyWith(
          brightness: Brightness.light,
          textTheme: parentTheme.textTheme.apply(
            bodyColor: MerlotPalette.cardInk,
            displayColor: MerlotPalette.cardInk,
          ),
          colorScheme: parentTheme.colorScheme.copyWith(
            brightness: Brightness.light,
            onSurface: MerlotPalette.cardInk,
            onSurfaceVariant: MerlotPalette.cardSecondaryInk,
            surface: MerlotPalette.surface,
            surfaceContainer: MerlotPalette.recessedWell,
            primary: MerlotPalette.action,
            onPrimary: Colors.white,
          ),
          extensions: [
            ...parentTheme.extensions.values.where((e) => e is! AscentGlass),
            cardGlass,
          ],
        );

        return Theme(
          data: cardTheme,
          child: DefaultTextStyle(
            style: const TextStyle(color: MerlotPalette.cardInk),
            child: child,
          ),
        );
      }(),
    );

    if (onTap != null) {
      content = Material(
        color: AppPalette.transparent,
        child: InkWell(onTap: onTap, borderRadius: r, child: content),
      );
    }

    Widget withShadow(Widget pane) =>
        material == null || transparent || !hasShadow
        ? pane
        : DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              boxShadow: material.shadows,
            ),
            child: pane,
          );
    final blurVal =
        material?.blur ?? (context.surfaces.blur > 0 ? context.surfaces.blur : 0.0);
    if (!enableBlur || blurVal <= 0.01) {
      return withShadow(content);
    }

    return withShadow(
      RepaintBoundary(
        child: ClipRRect(
          borderRadius: r,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX:
                  material?.blur ??
                  (context.surfaces.blur > 0 ? context.surfaces.blur : 12),
              sigmaY:
                  material?.blur ??
                  (context.surfaces.blur > 0 ? context.surfaces.blur : 12),
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}
