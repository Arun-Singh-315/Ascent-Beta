import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';

/// Supported visual surface variants for [AscentCard].
enum AscentCardVariant {
  /// Frosted liquid glass surface (`g.fill` + subtle 0.9px border + diffuse shadow).
  glass,

  /// Opaque surface card (`context.bgSurface`). Ideal for form cards and high readability.
  solid,

  /// Slightly elevated nested surface (`context.bgSurfaceElevated`).
  elevated,

  /// Transparent surface with crisp border. Ideal for list rows.
  outlined,
}

/// A surface card that follows the Ascent design system.
///
/// Supports 4 variants: [glass], [solid], [elevated], and [outlined].
/// Features tactile haptics when [onTap] is provided.
class AscentCard extends StatelessWidget {
  const AscentCard({
    super.key,
    required this.child,
    this.variant = AscentCardVariant.glass,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.radius = AscentDimensions.radiusLg,
    this.hasShadow = true,
    this.hasBorder = true,
  });

  /// Translucent liquid glass card (signature Ascent surface).
  const AscentCard.glass({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.radius = AscentDimensions.radiusLg,
    this.hasShadow = true,
    this.hasBorder = true,
  }) : variant = AscentCardVariant.glass;

  /// Pure solid surface card (`context.bgSurface`).
  const AscentCard.solid({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.radius = AscentDimensions.radiusLg,
    this.hasShadow = true,
    this.hasBorder = true,
  }) : variant = AscentCardVariant.solid;

  /// Elevated surface card (`context.bgSurfaceElevated`).
  const AscentCard.elevated({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.radius = AscentDimensions.radiusLg,
    this.hasShadow = false,
    this.hasBorder = true,
  }) : variant = AscentCardVariant.elevated;

  /// Transparent outlined surface card with subtle border.
  const AscentCard.outlined({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.radius = AscentDimensions.radiusLg,
    this.hasShadow = false,
    this.hasBorder = true,
  }) : variant = AscentCardVariant.outlined;

  /// The content displayed inside the card.
  final Widget child;

  /// Card visual variant.
  final AscentCardVariant variant;

  /// Inner padding. Defaults to [EdgeInsets.all(16)] when null.
  final EdgeInsetsGeometry? padding;

  /// Outer margin. Defaults to null.
  final EdgeInsetsGeometry? margin;

  /// When non-null the card becomes tappable with an ink ripple and tactile haptics.
  final VoidCallback? onTap;

  /// Optional background color override.
  final Color? color;

  /// Corner radius. Defaults to 16.
  final double radius;

  /// When true (default) adds a delicate diffuse shadow.
  final bool hasShadow;

  /// When true (default) adds a refined hairline border.
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final borderRadius = BorderRadius.circular(radius);

    Color surfaceColor;
    if (color != null) {
      surfaceColor = color!;
    } else {
      switch (variant) {
        case AscentCardVariant.glass:
          surfaceColor = g.fill;
          break;
        case AscentCardVariant.solid:
          surfaceColor = context.bgSurface;
          break;
        case AscentCardVariant.elevated:
          surfaceColor = context.bgSurfaceElevated;
          break;
        case AscentCardVariant.outlined:
          surfaceColor = Colors.transparent;
          break;
      }
    }

    final borderColor = variant == AscentCardVariant.outlined
        ? context.divider
        : g.edge;

    final shadowColor = g.shadow;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius,
        border: hasBorder ? Border.all(color: borderColor, width: 0.9) : null,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: shadowColor.withValues(alpha: context.isDark ? 0.25 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          borderRadius: borderRadius,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(AscentDimensions.spaceLg),
            child: child,
          ),
        ),
      ),
    );
  }
}
