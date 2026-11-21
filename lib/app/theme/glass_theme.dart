import 'package:flutter/material.dart';

import 'color_tokens.dart';
import 'monochrome_surfaces.dart';
import 'calm_blue_palette.dart';
import 'shared_control_tokens.dart';

/// Glass theme tokens for the Ascent design system. All values come from
/// [CalmBluePalette], the app's one palette, mirrored for light and dark.
class AscentGlass extends ThemeExtension<AscentGlass> {
  final MonochromeSurfaces? monochrome;
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
    this.monochrome,
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

  // ── Semantic roles (CLAUDE.md §3.1) ──────────────────────────────────────

  bool get isDark => bg.computeLuminance() < 0.2;

  /// Content/card surface
  Color get surface =>
      monochrome?.surface ??
      (isDark ? CalmBluePalette.darkSurface : CalmBluePalette.surface);

  /// Elevated surface (sheet/dialog/menu)
  Color get elevated =>
      monochrome?.elevated ??
      (isDark ? CalmBluePalette.darkElevated : CalmBluePalette.elevated);

  /// Recessed surface (inputs/segment track)
  Color get recessed =>
      monochrome?.groupedFill ??
      (isDark ? CalmBluePalette.darkRecessed : CalmBluePalette.recessed);

  /// Required control outline
  Color get controlOutline =>
      monochrome?.controlOutline ??
      (isDark ? CalmBluePalette.darkSeparator : CalmBluePalette.separator);

  /// Action ink (links/active icons/focus)
  Color get actionInk =>
      isDark ? CalmBluePalette.darkAction : CalmBluePalette.action;

  /// Filled primary button background
  Color get primaryButtonBg =>
      isDark ? CalmBluePalette.darkActionFill : CalmBluePalette.action;
  Color get primaryButtonFg => CalmBluePalette.onAction;
  Color get primaryButtonPressed => isDark
      ? CalmBluePalette.darkActionPressed
      : CalmBluePalette.actionPressed;

  /// Tonal/selection background
  Color get tonalBg =>
      monochrome?.groupedFill ??
      (isDark ? CalmBluePalette.darkActionTint : CalmBluePalette.actionTint);

  /// Tonal/selection foreground
  Color get tonalFg =>
      monochrome?.primaryText ??
      (isDark
          ? CalmBluePalette.darkActionTintInk
          : CalmBluePalette.actionTintInk);

  /// Focus ring
  Color get focusRing => actionInk;

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
    bg: CalmBluePalette.canvas,
    fill: CalmBluePalette.surface,
    edge: CalmBluePalette.separator,
    highlight: Color.fromRGBO(255, 255, 255, 0.92),
    line: CalmBluePalette.separator,
    glow1: Colors.transparent,
    glow2: Colors.transparent,
    track: CalmBluePalette.track,
    nav: CalmBluePalette.surface,
    shadow: CalmBluePalette.shadow,
    clay: CalmBluePalette.action,
    claySoft: CalmBluePalette.actionTint,
    slate: CalmBluePalette.action,
    slateSoft: CalmBluePalette.actionTint,
    sage: CalmBluePalette.success,
    sageSoft: CalmBluePalette.successTint,
    amber: CalmBluePalette.warning,
    amberSoft: CalmBluePalette.warningTint,
    coral: CalmBluePalette.danger,
    coralSoft: CalmBluePalette.dangerTint,
    ink: CalmBluePalette.label,
    inkSecondary: CalmBluePalette.labelSecondary,
    inkMuted: CalmBluePalette.labelTertiary,
  );

  static const dark = AscentGlass(
    bg: CalmBluePalette.darkCanvas,
    fill: CalmBluePalette.darkSurface,
    edge: CalmBluePalette.darkSeparator,
    highlight: Color.fromRGBO(255, 255, 255, 0.06),
    line: CalmBluePalette.darkSeparator,
    glow1: Colors.transparent,
    glow2: Colors.transparent,
    track: CalmBluePalette.darkTrack,
    nav: CalmBluePalette.darkSurface,
    shadow: CalmBluePalette.darkShadow,
    clay: CalmBluePalette.darkAction,
    claySoft: CalmBluePalette.darkActionTint,
    slate: CalmBluePalette.darkAction,
    slateSoft: CalmBluePalette.darkActionTint,
    sage: CalmBluePalette.darkSuccess,
    sageSoft: CalmBluePalette.darkSuccessTint,
    amber: CalmBluePalette.darkWarning,
    amberSoft: CalmBluePalette.darkWarningTint,
    coral: CalmBluePalette.darkDanger,
    coralSoft: CalmBluePalette.darkDangerTint,
    ink: CalmBluePalette.darkLabel,
    inkSecondary: CalmBluePalette.darkLabelSecondary,
    inkMuted: CalmBluePalette.darkLabelTertiary,
  );

  @override
  ThemeExtension<AscentGlass> copyWith({
    MonochromeSurfaces? monochrome,
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
      monochrome: monochrome ?? this.monochrome,
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
      monochrome: monochrome != null && other.monochrome != null
          ? monochrome!.lerp(other.monochrome, t)
          : (t < .5 ? monochrome : other.monochrome),
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

  /// Foreground/border color for a completed item (done chip, completed
  /// thought). Single source for the "done" green that was previously
  /// duplicated as literals across Home widgets.
  Color get doneInk =>
      isDark ? CalmBluePalette.darkSuccess : CalmBluePalette.success;

  /// Positive confirmation tone (e.g. "logged" feedback, check marks) used
  /// identically in every theme.
  Color get confirmInk =>
      isDark ? CalmBluePalette.darkSuccess : CalmBluePalette.success;
}
