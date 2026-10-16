import 'package:flutter/material.dart';

import 'color_tokens.dart';

/// Glass theme tokens for the Ascent design system.
/// Defined according to the Ascent Liquid Glass specification:
/// - Light base: #F4F3F8, Clay: #A4523A
/// - Dark base: #0D1016, Clay: #E6A088
/// - Harmonic Accents: Slate (Study), Sage (Walk/Health), Amber (Focus/Cash), Coral (Urgent/Danger)
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

  // Primary brand / Home anchor
  final Color clay;
  final Color claySoft;

  // Harmonic contextual accents
  final Color slate;
  final Color slateSoft;
  final Color sage;
  final Color sageSoft;
  final Color amber;
  final Color amberSoft;
  final Color coral;
  final Color coralSoft;

  // Unified typography ink
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
    required this.slate,
    required this.slateSoft,
    required this.sage,
    required this.sageSoft,
    required this.amber,
    required this.amberSoft,
    required this.coral,
    required this.coralSoft,
    required this.ink,
    required this.inkSecondary,
    required this.inkMuted,
  });

  static const light = AscentGlass(
    bg: Color(0xFFF4F3F8),
    fill: Color.fromRGBO(255, 255, 255, 0.62),
    edge: Color.fromRGBO(43, 34, 27, 0.08),
    highlight: Color.fromRGBO(255, 255, 255, 0.90),
    line: Color.fromRGBO(43, 34, 27, 0.09),
    glow1: Color.fromRGBO(226, 152, 120, 0.36),
    glow2: Color.fromRGBO(193, 161, 124, 0.28),
    track: Color.fromRGBO(43, 34, 27, 0.10),
    nav: Color.fromRGBO(246, 245, 250, 0.78),
    shadow: Color.fromRGBO(60, 44, 30, 0.22),
    clay: Color(0xFFA4523A),
    claySoft: Color.fromRGBO(164, 82, 58, 0.11),
    slate: Color(0xFFB07A4A),
    slateSoft: Color.fromRGBO(139, 106, 79, 0.11),
    sage: Color(0xFF2C6B45),
    sageSoft: Color.fromRGBO(44, 107, 69, 0.11),
    amber: Color(0xFFB06822),
    amberSoft: Color.fromRGBO(176, 104, 34, 0.11),
    coral: Color(0xFFA63B34),
    coralSoft: Color.fromRGBO(166, 59, 52, 0.11),
    ink: Color(0xFF2B221B),
    inkSecondary: Color(0xFF5F544A),
    inkMuted: Color(0xFF74695F),
  );

  static const nordicSky = AscentGlass(
    bg: Color(0xFFF0F4F9),
    fill: Color.fromRGBO(255, 255, 255, 0.72),
    edge: Color.fromRGBO(15, 23, 42, 0.08),
    highlight: Color.fromRGBO(255, 255, 255, 0.95),
    line: Color.fromRGBO(15, 23, 42, 0.08),
    glow1: Color.fromRGBO(56, 189, 248, 0.22),
    glow2: Color.fromRGBO(96, 165, 250, 0.18),
    track: Color.fromRGBO(15, 23, 42, 0.10),
    nav: Color.fromRGBO(240, 244, 249, 0.85),
    shadow: Color.fromRGBO(15, 23, 42, 0.12),
    clay: Color(0xFF2563EB),
    claySoft: Color.fromRGBO(37, 99, 235, 0.12),
    slate: Color(0xFF0284C7),
    slateSoft: Color.fromRGBO(2, 132, 199, 0.12),
    sage: Color(0xFF16A34A),
    sageSoft: Color.fromRGBO(22, 163, 74, 0.12),
    amber: Color(0xFFD97706),
    amberSoft: Color.fromRGBO(217, 119, 6, 0.12),
    coral: Color(0xFFDC2626),
    coralSoft: Color.fromRGBO(220, 38, 38, 0.12),
    ink: Color(0xFF0F172A),
    inkSecondary: Color(0xFF334155),
    inkMuted: Color(0xFF64748B),
  );

  static const dark = AscentGlass(
    bg: Color(0xFF16110D),
    fill: Color.fromRGBO(255, 255, 255, 0.055),
    edge: Color.fromRGBO(255, 255, 255, 0.10),
    highlight: Color.fromRGBO(255, 255, 255, 0.13),
    line: Color.fromRGBO(255, 255, 255, 0.09),
    glow1: Color.fromRGBO(214, 120, 92, 0.22),
    glow2: Color.fromRGBO(193, 161, 124, 0.24),
    track: Color.fromRGBO(255, 255, 255, 0.10),
    nav: Color.fromRGBO(22, 17, 13, 0.74),
    shadow: Color.fromRGBO(0, 0, 0, 0.50),
    clay: Color(0xFFE6A088),
    claySoft: Color.fromRGBO(230, 160, 136, 0.14),
    slate: Color(0xFFD6A77E),
    slateSoft: Color.fromRGBO(193, 161, 124, 0.14),
    sage: Color(0xFF63BA8B),
    sageSoft: Color.fromRGBO(99, 186, 139, 0.14),
    amber: Color(0xFFECA361),
    amberSoft: Color.fromRGBO(236, 163, 97, 0.14),
    coral: Color(0xFFE26D66),
    coralSoft: Color.fromRGBO(226, 109, 102, 0.14),
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
    Color? slate,
    Color? slateSoft,
    Color? sage,
    Color? sageSoft,
    Color? amber,
    Color? amberSoft,
    Color? coral,
    Color? coralSoft,
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
      slate: slate ?? this.slate,
      slateSoft: slateSoft ?? this.slateSoft,
      sage: sage ?? this.sage,
      sageSoft: sageSoft ?? this.sageSoft,
      amber: amber ?? this.amber,
      amberSoft: amberSoft ?? this.amberSoft,
      coral: coral ?? this.coral,
      coralSoft: coralSoft ?? this.coralSoft,
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
      slate: Color.lerp(slate, other.slate, t)!,
      slateSoft: Color.lerp(slateSoft, other.slateSoft, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      sageSoft: Color.lerp(sageSoft, other.sageSoft, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberSoft: Color.lerp(amberSoft, other.amberSoft, t)!,
      coral: Color.lerp(coral, other.coral, t)!,
      coralSoft: Color.lerp(coralSoft, other.coralSoft, t)!,
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
