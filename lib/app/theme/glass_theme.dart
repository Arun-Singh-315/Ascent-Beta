import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'frozen_palette.dart';
import 'merlot_palette.dart';
import 'shared_control_tokens.dart';

/// Glass theme tokens for the Ascent design system.
/// Defined according to the Ascent Liquid Glass specification:
/// - Light base: #F4F3F8, Clay: #A4523A
/// - Dark base: #0D1016, Clay: #E6A088
/// - Harmonic Accents: Slate (Study), Sage (Walk/Health), Amber (Focus/Cash), Coral (Urgent/Danger)
class AscentGlass extends ThemeExtension<AscentGlass> {
  final bool frozen;
  final bool merlot;
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
    this.frozen = false,
    this.merlot = false,
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

  // ── Semantic Roles from Section 3 ─────────────────────────────────────────

  bool get isDark => bg.computeLuminance() < 0.2;

  /// Content/card surface
  Color get surface => frozen
      ? (isDark ? FrozenPalette.darkSurface : FrozenPalette.surface)
      : merlot
      ? (isDark ? MerlotPalette.darkSurface : MerlotPalette.surface)
      : (isDark ? AscentColors.bgSurfaceDark : AscentColors.bgSurface);

  /// Elevated surface (sheet/dialog/menu)
  Color get elevated => frozen
      ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
      : merlot
      ? (isDark ? MerlotPalette.darkElevated : MerlotPalette.surface)
      : (isDark
            ? AscentColors.bgSurfaceElevatedDark
            : AscentColors.bgSurfaceElevated);

  /// Recessed surface (inputs/segment track)
  Color get recessed => frozen
      ? (isDark ? FrozenPalette.darkRecessed : FrozenPalette.recessed)
      : merlot
      ? (isDark ? MerlotPalette.darkCanvas : MerlotPalette.recessedWell)
      : (isDark ? AscentColors.bgBaseDark : AscentColors.bgBase);

  /// Required control outline
  Color get controlOutline => frozen
      ? (isDark
            ? FrozenPalette.darkControlOutline
            : FrozenPalette.controlOutline)
      : merlot
      ? (isDark ? const Color(0xFF8D939F) : MerlotPalette.line)
      : (isDark ? const Color(0xFF8D939F) : AscentColors.outlineDay);

  /// Action ink (links/active icons/focus)
  Color get actionInk => frozen
      ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
      : merlot
      ? (isDark ? MerlotPalette.darkAction : MerlotPalette.action)
      : (isDark ? AscentColors.accentPrimaryDark : AscentColors.accentPrimary);

  /// Filled primary button background
  Color get primaryButtonBg => SharedControlColors.actionBlue;
  Color get primaryButtonFg => Colors.white;
  Color get primaryButtonPressed => const Color(0xFF005AC8);

  /// Tonal/selection background
  Color get tonalBg => frozen
      ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
      : merlot
      ? (isDark ? MerlotPalette.darkTint : MerlotPalette.tint)
      : (isDark
            ? AscentColors.accentPrimaryDimDark
            : AscentColors.accentPrimaryDim);

  /// Tonal/selection foreground
  Color get tonalFg => frozen
      ? (isDark
            ? FrozenPalette.darkTintForeground
            : FrozenPalette.tintForeground)
      : merlot
      ? (isDark ? MerlotPalette.darkAction : MerlotPalette.action)
      : (isDark ? AscentColors.accentPrimaryDark : AscentColors.accentPrimary);

  /// Focus ring
  Color get focusRing => frozen
      ? (isDark ? FrozenPalette.darkFocusRing : FrozenPalette.focusRing)
      : merlot
      ? (isDark ? MerlotPalette.darkAction : MerlotPalette.action)
      : (isDark ? AscentColors.accentPrimaryDark : AscentColors.accentPrimary);

  // ── Shared Control Colors (Section 3.2) ───────────────────────────────────

  Color get switchTrackOn => SharedControlColors.switchTrackOn;
  Color get switchThumb => SharedControlColors.switchThumb;
  Color get switchTrackOff => isDark
      ? SharedControlColors.switchTrackOffDark
      : SharedControlColors.switchTrackOffLight;
  Color get disabledBg => isDark
      ? SharedControlColors.disabledBgDark
      : SharedControlColors.disabledBgLight;
  Color get disabledFg => isDark
      ? SharedControlColors.disabledFgDark
      : SharedControlColors.disabledFgLight;
  Color get errorInk => isDark
      ? SharedControlColors.errorInkDark
      : SharedControlColors.errorInkLight;
  Color get errorSoftBg => isDark
      ? SharedControlColors.errorSoftBgDark
      : SharedControlColors.errorSoftBgLight;
  Color get destructiveBg => SharedControlColors.filledDestructiveBg;
  Color get destructiveFg => SharedControlColors.filledDestructiveFg;
  Color get destructivePressed => SharedControlColors.filledDestructivePressed;
  Color get successInk => isDark
      ? SharedControlColors.successInkDark
      : SharedControlColors.successInkLight;
  Color get successSoftBg => isDark
      ? SharedControlColors.successSoftBgDark
      : SharedControlColors.successSoftBgLight;
  Color get warningInk => isDark
      ? SharedControlColors.warningInkDark
      : SharedControlColors.warningInkLight;
  Color get warningSoftBg => isDark
      ? SharedControlColors.warningSoftBgDark
      : SharedControlColors.warningSoftBgLight;

  static const light = AscentGlass(
    bg: Color(0xFFEFF2F6),
    fill: Color.fromRGBO(255, 255, 255, 0.78),
    edge: Color.fromRGBO(255, 255, 255, 0.82),
    highlight: Color.fromRGBO(255, 255, 255, 0.94),
    line: Color.fromRGBO(15, 23, 42, 0.08),
    glow1: Color.fromRGBO(147, 197, 253, 0.28),
    glow2: Color.fromRGBO(199, 210, 254, 0.22),
    track: Color.fromRGBO(15, 23, 42, 0.12),
    nav: Color.fromRGBO(243, 247, 251, 0.92),
    shadow: Color.fromRGBO(15, 23, 42, 0.08),
    clay: Color(0xFFA4523A),
    claySoft: Color(0xFFFDF4F0),
    slate: Color(0xFF2563EB),
    slateSoft: Color(0xFFEFF6FF),
    sage: Color(0xFF059669),
    sageSoft: Color(0xFFECFDF5),
    amber: Color(0xFFD97706),
    amberSoft: Color(0xFFFFFBEB),
    coral: Color(0xFFDC2626),
    coralSoft: Color(0xFFFEF2F2),
    ink: Color(0xFF0F172A),
    inkSecondary: Color(0xFF334155),
    inkMuted: Color(0xFF64748B),
  );

  static const nordicSky = AscentGlass(
    frozen: true,
    bg: FrozenPalette.canvas,
    fill: FrozenPalette.surface,
    edge: FrozenPalette.line,
    highlight: Color.fromRGBO(255, 255, 255, 0.96),
    line: FrozenPalette.line,
    glow1: Color.fromRGBO(147, 197, 253, 0.28),
    glow2: Color.fromRGBO(199, 210, 254, 0.20),
    track: Color.fromRGBO(29, 100, 180, 0.12),
    nav: FrozenPalette.surface,
    shadow: FrozenPalette.shadowAmbient,
    clay: FrozenPalette.action,
    claySoft: FrozenPalette.pillSoft,
    slate: FrozenPalette.action,
    slateSoft: FrozenPalette.pillSoft,
    sage: FrozenPalette.success,
    sageSoft: Color.fromRGBO(22, 101, 52, 0.12),
    amber: FrozenPalette.spark,
    amberSoft: FrozenPalette.sparkTint,
    coral: FrozenPalette.danger,
    coralSoft: Color.fromRGBO(180, 35, 24, 0.12),
    ink: FrozenPalette.ink,
    inkSecondary: FrozenPalette.secondaryInk,
    inkMuted: FrozenPalette.mutedInk,
  );

  static const nordicSkyDark = AscentGlass(
    frozen: true,
    bg: FrozenPalette.darkCanvas,
    fill: FrozenPalette.darkSurface,
    edge: FrozenPalette.darkLine,
    highlight: Color.fromRGBO(120, 180, 255, 0.14),
    line: FrozenPalette.darkLine,
    glow1: Color.fromRGBO(94, 160, 240, 0.32),
    glow2: Color.fromRGBO(125, 180, 245, 0.26),
    track: Color.fromRGBO(255, 255, 255, 0.12),
    nav: FrozenPalette.darkSurface,
    shadow: Color.fromRGBO(0, 0, 0, 0.55),
    clay: FrozenPalette.darkAction,
    claySoft: FrozenPalette.darkTint,
    slate: FrozenPalette.darkAction,
    slateSoft: FrozenPalette.darkTint,
    sage: FrozenPalette.darkSuccess,
    sageSoft: Color.fromRGBO(134, 239, 172, 0.14),
    amber: FrozenPalette.darkSpark,
    amberSoft: FrozenPalette.darkSparkTint,
    coral: FrozenPalette.darkDanger,
    coralSoft: Color.fromRGBO(255, 180, 171, 0.14),
    ink: FrozenPalette.darkInk,
    inkSecondary: FrozenPalette.darkSecondaryInk,
    inkMuted: FrozenPalette.darkMutedInk,
  );

  static const merlotLinenLight = AscentGlass(
    merlot: true,
    bg: MerlotPalette.canvas,
    fill: MerlotPalette.surface,
    edge: MerlotPalette.line,
    highlight: Color.fromRGBO(255, 255, 255, 0.92),
    line: MerlotPalette.lineSubtle,
    glow1: Color.fromRGBO(194, 136, 52, 0.16),
    glow2: Color.fromRGBO(88, 24, 37, 0.18),
    track: Color.fromRGBO(88, 24, 37, 0.12),
    nav: MerlotPalette.surface,
    shadow: MerlotPalette.shadowAmbient,
    clay: MerlotPalette.action,
    claySoft: MerlotPalette.pillSoft,
    slate: MerlotPalette.antiqueGold,
    slateSoft: MerlotPalette.sparkTint,
    sage: MerlotPalette.success,
    sageSoft: MerlotPalette.successTint,
    amber: MerlotPalette.antiqueGold,
    amberSoft: MerlotPalette.sparkTint,
    coral: MerlotPalette.terracotta,
    coralSoft: MerlotPalette.terracottaTint,
    ink: MerlotPalette.ink,
    inkSecondary: MerlotPalette.secondaryInk,
    inkMuted: MerlotPalette.mutedInk,
  );

  static const merlotLinenDark = AscentGlass(
    merlot: true,
    bg: MerlotPalette.darkCanvas,
    fill: MerlotPalette.darkSurface,
    edge: MerlotPalette.darkLine,
    highlight: Color.fromRGBO(255, 255, 255, 0.12),
    line: MerlotPalette.darkLineSubtle,
    glow1: Color.fromRGBO(194, 136, 52, 0.06),
    glow2: Color.fromRGBO(88, 24, 37, 0.10),
    track: Color.fromRGBO(255, 255, 255, 0.12),
    nav: Color.fromRGBO(22, 16, 18, 0.88),
    shadow: Color.fromRGBO(0, 0, 0, 0.55),
    clay: MerlotPalette.darkAction,
    claySoft: MerlotPalette.darkTint,
    slate: MerlotPalette.darkSpark,
    slateSoft: MerlotPalette.darkSparkTint,
    sage: MerlotPalette.darkSuccess,
    sageSoft: Color.fromRGBO(74, 222, 128, 0.14),
    amber: MerlotPalette.darkSpark,
    amberSoft: MerlotPalette.darkSparkTint,
    coral: MerlotPalette.darkTerracotta,
    coralSoft: Color.fromRGBO(224, 122, 95, 0.14),
    ink: MerlotPalette.darkInk,
    inkSecondary: MerlotPalette.darkSecondaryInk,
    inkMuted: MerlotPalette.darkMutedInk,
  );

  static const dark = AscentGlass(
    bg: Color(0xFF16110D),
    fill: Color.fromRGBO(255, 255, 255, 0.055),
    edge: Color.fromRGBO(255, 255, 255, 0.10),
    highlight: Color.fromRGBO(255, 255, 255, 0.13),
    line: Color.fromRGBO(255, 255, 255, 0.09),
    glow1: Color.fromRGBO(214, 120, 92, 0.22),
    glow2: Color.fromRGBO(193, 161, 124, 0.24),
    track: Color.fromRGBO(255, 255, 255, 0.12),
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
    bool? frozen,
    bool? merlot,
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
      frozen: frozen ?? this.frozen,
      merlot: merlot ?? this.merlot,
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
  ThemeExtension<AscentGlass> lerp(
    covariant ThemeExtension<AscentGlass>? other,
    double t,
  ) {
    if (other is! AscentGlass) return this;
    return AscentGlass(
      frozen: t < 0.5 ? frozen : other.frozen,
      merlot: t < 0.5 ? merlot : other.merlot,
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
      Theme.of(this).extension<AscentGlass>() ??
      (isDark ? AscentGlass.dark : AscentGlass.light);
}
