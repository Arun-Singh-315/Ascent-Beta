import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/merlot_palette.dart';
import 'app_surfaces.dart';

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

  /// Inner padding. Defaults to [EdgeInsets.all(AppSpace.s16)] when null.
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
          surfaceColor = AppPalette.transparent;
          break;
      }
    }

    final isMerlotDay = g.merlot && !context.isDark && color == null && variant != AscentCardVariant.outlined;

    final borderColor = isMerlotDay
        ? MerlotPalette.line
        : (variant == AscentCardVariant.outlined ? context.divider : g.edge);

    final shadowColor = g.shadow;

    Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(AscentDimensions.spaceLg),
      child: child,
    );

    if (isMerlotDay) {
      final cardGlass = AscentGlass(
        merlot: true,
        bg: MerlotPalette.surface,
        fill: MerlotPalette.surface,
        edge: MerlotPalette.line,
        highlight: const Color.fromRGBO(255, 255, 255, 0.15),
        line: MerlotPalette.lineSubtle,
        glow1: const Color.fromRGBO(229, 169, 78, 0.25),
        glow2: const Color.fromRGBO(196, 77, 86, 0.20),
        track: MerlotPalette.recessedWell,
        nav: MerlotPalette.surface,
        shadow: MerlotPalette.shadowAmbient,
        clay: MerlotPalette.antiqueGold,
        claySoft: MerlotPalette.pillSoft,
        slate: MerlotPalette.antiqueGold,
        slateSoft: MerlotPalette.sparkTint,
        sage: const Color(0xFF68D391),
        sageSoft: MerlotPalette.successTint,
        amber: MerlotPalette.antiqueGold,
        amberSoft: MerlotPalette.sparkTint,
        coral: const Color(0xFFFC8181),
        coralSoft: MerlotPalette.terracottaTint,
        ink: MerlotPalette.cardInk,
        inkSecondary: MerlotPalette.cardSecondaryInk,
        inkMuted: MerlotPalette.cardMutedInk,
      );
      final parentTheme = Theme.of(context);
      final cardTheme = parentTheme.copyWith(
        brightness: Brightness.dark,
        textTheme: parentTheme.textTheme.apply(
          bodyColor: MerlotPalette.cardInk,
          displayColor: MerlotPalette.cardInk,
        ),
        colorScheme: parentTheme.colorScheme.copyWith(
          brightness: Brightness.dark,
          onSurface: MerlotPalette.cardInk,
          onSurfaceVariant: MerlotPalette.cardSecondaryInk,
          surface: MerlotPalette.surface,
          surfaceContainer: MerlotPalette.recessedWell,
          primary: MerlotPalette.antiqueGold,
          onPrimary: MerlotPalette.ink,
        ),
        extensions: [
          ...parentTheme.extensions.values.where((e) => e is! AscentGlass),
          cardGlass,
        ],
      );
      content = Theme(
        data: cardTheme,
        child: DefaultTextStyle(
          style: const TextStyle(color: MerlotPalette.cardInk),
          child: content,
        ),
      );
    }

    return AppCard(
      margin: margin,
      nightDecoration: BoxDecoration(
        color: isMerlotDay ? null : surfaceColor,
        gradient: isMerlotDay
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  MerlotPalette.surface,
                  MerlotPalette.surfaceBottom,
                ],
              )
            : null,
        borderRadius: borderRadius,
        border: hasBorder
            ? Border.all(color: borderColor, width: AppBorderScale.w0point9)
            : null,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: isMerlotDay
                      ? MerlotPalette.shadowAmbient
                      : shadowColor.withValues(
                          alpha: context.isDark ? 0.25 : 0.03,
                        ),
                  blurRadius: isMerlotDay ? 16 : 8,
                  offset: isMerlotDay ? const Offset(0, 4) : const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: AppPalette.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: AppTapArea(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          borderRadius: borderRadius,
          child: content,
        ),
      ),
    );
  }
}
