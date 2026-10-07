import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Glass theme tokens for the Ascent design system.
/// Defined according to the Ascent Home Redesign spec:
/// - Light base: #F4F3F8, Clay: #A4523A
/// - Dark base: #0D1016, Clay: #E6A088
class AscentGlass extends ThemeExtension<AscentGlass> {
  final Color bg;
  final Color fill;
  final Color edge;
  final Color highlight;
  final Color line;
  final Color glow1;
  final Color glow2;
  final Color track;
  final Color nav;
  final Color shadow;
  final Color clay;
  final Color claySoft;
  final Color ink;
  final Color inkSecondary;
  final Color inkMuted;

  const AscentGlass({
    required this.bg,
    required this.fill,
    required this.edge,
    required this.highlight,
    required this.line,
    required this.glow1,
    required this.glow2,
    required this.track,
    required this.nav,
    required this.shadow,
    required this.clay,
    required this.claySoft,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
  });

  static const light = AscentGlass(
    bg: Color(0xFFF4F3F8),
    fill: Color.fromRGBO(255, 255, 255, 0.62),
    edge: Color.fromRGBO(27, 30, 43, 0.08),
    highlight: Color.fromRGBO(255, 255, 255, 0.90),
    line: Color.fromRGBO(27, 30, 43, 0.09),
    glow1: Color.fromRGBO(226, 152, 120, 0.36),
    glow2: Color.fromRGBO(120, 142, 204, 0.28),
    track: Color.fromRGBO(27, 30, 43, 0.10),
    nav: Color.fromRGBO(246, 245, 250, 0.78),
    shadow: Color.fromRGBO(30, 34, 60, 0.22),
    clay: Color(0xFFA4523A),
    claySoft: Color.fromRGBO(164, 82, 58, 0.11),
    ink: Color(0xFF1B1E2B),
    inkSecondary: Color(0xFF4A4E5F),
    inkMuted: Color(0xFF6A6E7E),
  );

  static const dark = AscentGlass(
    bg: Color(0xFF0D1016),
    fill: Color.fromRGBO(255, 255, 255, 0.055),
    edge: Color.fromRGBO(255, 255, 255, 0.10),
    highlight: Color.fromRGBO(255, 255, 255, 0.13),
    line: Color.fromRGBO(255, 255, 255, 0.09),
    glow1: Color.fromRGBO(214, 120, 92, 0.22),
    glow2: Color.fromRGBO(92, 114, 190, 0.24),
    track: Color.fromRGBO(255, 255, 255, 0.10),
    nav: Color.fromRGBO(13, 16, 22, 0.74),
    shadow: Color.fromRGBO(0, 0, 0, 0.50),
    clay: Color(0xFFE6A088),
    claySoft: Color.fromRGBO(230, 160, 136, 0.14),
    ink: Color(0xFFECEAF2),
    inkSecondary: Color(0xFFB4B7C6),
    inkMuted: Color(0xFF9094A4),
  );

  @override
  ThemeExtension<AscentGlass> copyWith({
    Color? bg,
    Color? fill,
    Color? edge,
    Color? highlight,
    Color? line,
    Color? glow1,
    Color? glow2,
    Color? track,
    Color? nav,
    Color? shadow,
    Color? clay,
    Color? claySoft,
    Color? ink,
    Color? inkSecondary,
    Color? inkMuted,
  }) {
    return AscentGlass(
      bg: bg ?? this.bg,
      fill: fill ?? this.fill,
      edge: edge ?? this.edge,
      highlight: highlight ?? this.highlight,
      line: line ?? this.line,
      glow1: glow1 ?? this.glow1,
      glow2: glow2 ?? this.glow2,
      track: track ?? this.track,
      nav: nav ?? this.nav,
      shadow: shadow ?? this.shadow,
      clay: clay ?? this.clay,
      claySoft: claySoft ?? this.claySoft,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkMuted: inkMuted ?? this.inkMuted,
    );
  }

  @override
  ThemeExtension<AscentGlass> lerp(covariant ThemeExtension<AscentGlass>? other, double t) {
    if (other is! AscentGlass) return this;
    return AscentGlass(
      bg: Color.lerp(bg, other.bg, t)!,
      fill: Color.lerp(fill, other.fill, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      line: Color.lerp(line, other.line, t)!,
      glow1: Color.lerp(glow1, other.glow1, t)!,
      glow2: Color.lerp(glow2, other.glow2, t)!,
      track: Color.lerp(track, other.track, t)!,
      nav: Color.lerp(nav, other.nav, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      clay: Color.lerp(clay, other.clay, t)!,
      claySoft: Color.lerp(claySoft, other.claySoft, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
    );
  }
}

extension AscentGlassX on BuildContext {
  AscentGlass get glass =>
      Theme.of(this).extension<AscentGlass>() ?? (isDark ? AscentGlass.dark : AscentGlass.light);
}
