import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';

/// iOS-style glass for persistent chrome only (CLAUDE.md §3.4): the tab bar,
/// docked composers, the running-session bar and chips over the header sky.
///
/// * Real blur (24) with a tinted fill strong enough that text on it stays
///   readable over anything scrolling underneath (dark tint .72, light .78).
/// * A 1 px rim: white 10 % in dark, black 6 % in light.
/// * High contrast on → solid fill, no blur.
///
/// Overlays (sheets, dialogs, menus, snackbars, notifications) are never
/// glass: they stay opaque so nothing behind them can make them hard to read.
class GlassChrome extends StatelessWidget {
  const GlassChrome({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.rimTopOnly = false,
    this.padding,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// For bars attached to an edge (the tab bar): only the top hairline.
  final bool rimTopOnly;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = g.isDark;
    final solid = MediaQuery.highContrastOf(context);
    final base = dark ? g.surface : g.elevated;
    final rim = dark
        ? Colors.white.withValues(alpha: .10)
        : Colors.black.withValues(alpha: .06);
    final decoration = BoxDecoration(
      color: solid ? base : base.withValues(alpha: dark ? .72 : .78),
      borderRadius: borderRadius,
      border: rimTopOnly
          ? Border(top: BorderSide(color: rim))
          : Border.all(color: rim),
    );
    final body = DecoratedBox(
      decoration: decoration,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (solid) return body;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: body,
      ),
    );
  }
}
