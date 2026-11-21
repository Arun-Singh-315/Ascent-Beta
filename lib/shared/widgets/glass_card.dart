import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/theme/calm_blue_palette.dart';
import '../../app/theme/glass_theme.dart';

/// iOS-style glass card: frosted white (graphite by night) over the
/// [AscentBackdrop], a bright 1 px rim and a soft blue shadow. Use for Home
/// feed cards; overlays stay opaque (CLAUDE.md §3.4).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 22,
    this.onTap,
    this.semanticLabel,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final dark = context.glass.isDark;
    final r = BorderRadius.circular(radius);
    // Reduce transparency (high contrast) falls back to a solid surface.
    final solid = MediaQuery.highContrastOf(context);
    Widget body = Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
    body = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        color: solid
            ? context.glass.surface
            : (dark
                  ? CalmBluePalette.glassFillDark
                  : CalmBluePalette.glassFillLight),
        border: Border.all(
          color: dark
              ? CalmBluePalette.glassRimDark
              : CalmBluePalette.glassRimLight,
        ),
      ),
      child: body,
    );
    if (!solid) {
      body = ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: body,
        ),
      );
    }
    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: CalmBluePalette.glassShadow,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: body,
    );
    if (semanticLabel == null) return card;
    return Semantics(button: onTap != null, label: semanticLabel, child: card);
  }
}
