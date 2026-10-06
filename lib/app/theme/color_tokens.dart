import 'package:flutter/material.dart';

/// All color tokens for the Ascent design system.
/// Muted, matte, calm, and tailored for focus & productivity.
/// Use the [AscentColorsX] extension on [BuildContext] to get
/// the correct token for the current brightness.
class AscentColors {
  AscentColors._();

  // ── Light mode ─────────────────────────────────────────────────────────────

  /// Crisp, clean matte off-white — page background.
  static const Color bgBase = Color(0xFFF8F9FA);

  /// Pure white surface — cards, sheets, inputs.
  static const Color bgSurface = Color(0xFFFFFFFF);

  /// Slightly elevated surface for nested cards and chips.
  static const Color bgSurfaceElevated = Color(0xFFF1F3F6);

  /// Deep calm forest sage — primary accent.
  static const Color accentPrimary = Color(0xFF38664D);

  /// Matte punchy sage for active/interactive buttons and rings.
  static const Color accentPrimaryBright = Color(0xFF2C553E);

  /// Subtle soft tint for primary backgrounds and badges.
  static const Color accentPrimaryDim = Color(0xFFD6E8DC);

  /// Muted terracotta / warm clay — secondary accent.
  static const Color accentSecondary = Color(0xFFD06548);

  /// Punchier terracotta for active countdown and focus markers.
  static const Color accentSecondaryBright = Color(0xFFBA5438);

  /// Soft slate blue — informational accent.
  static const Color accentInfo = Color(0xFF4F739D);

  /// Restrained coral-red — destructive / error state.
  static const Color stateDanger = Color(0xFFC94A42);

  /// Saturated red for cancel and delete.
  static const Color stateDangerBright = Color(0xFFB83A32);

  /// Success — matches primary forest sage.
  static const Color stateSuccess = Color(0xFF38664D);

  /// Warning — amber/clay.
  static const Color stateWarning = Color(0xFFD97736);

  /// Deep near-black graphite text.
  static const Color textPrimary = Color(0xFF16191D);

  /// Refined secondary text.
  static const Color textSecondary = Color(0xFF525963);

  /// Muted / placeholder text.
  static const Color textMuted = Color(0xFF868E99);

  /// Text rendered on top of primary-colored surfaces.
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Ultra-thin hairline divider line.
  static const Color divider = Color(0xFFE5E8ED);

  /// Shadow tint for soft diffuse elevation.
  static const Color shadow = Color(0xFF16191D);

  // ── Dark mode ──────────────────────────────────────────────────────────────

  /// Deep obsidian graphite — page background.
  static const Color bgBaseDark = Color(0xFF0F1216);

  /// Matte dark charcoal surface — cards, sheets, inputs.
  static const Color bgSurfaceDark = Color(0xFF181C22);

  /// Elevated dark surface for nested items and chips.
  static const Color bgSurfaceElevatedDark = Color(0xFF222832);

  /// Soft luminous sage — primary accent.
  static const Color accentPrimaryDark = Color(0xFF63BA8B);
  static const Color accentPrimaryBrightDark = Color(0xFF78CCA0);
  static const Color accentPrimaryDimDark = Color(0xFF233E30);

  /// Warm clay / terracotta — secondary accent.
  static const Color accentSecondaryDark = Color(0xFFE88168);
  static const Color accentSecondaryBrightDark = Color(0xFFF2957E);

  /// Muted slate blue — info accent.
  static const Color accentInfoDark = Color(0xFF7FA7D6);

  /// Soft coral red — danger.
  static const Color stateDangerDark = Color(0xFFE26D66);
  static const Color stateDangerBrightDark = Color(0xFFEE8079);

  static const Color stateSuccessDark = Color(0xFF63BA8B);
  static const Color stateWarningDark = Color(0xFFECA361);

  /// Crisp off-white text.
  static const Color textPrimaryDark = Color(0xFFEFF2F6);

  /// Secondary text in dark mode.
  static const Color textSecondaryDark = Color(0xFFA2ACB8);

  /// Muted text in dark mode.
  static const Color textMutedDark = Color(0xFF757E8C);

  /// Text on primary in dark mode.
  static const Color textOnPrimaryDark = Color(0xFF0D1812);

  /// Subtle dark divider line.
  static const Color dividerDark = Color(0xFF262D37);

  /// Shadow in dark mode.
  static const Color shadowDark = Color(0xFF000000);
}

/// Convenience extension so call-sites never branch on brightness manually.
extension AscentColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bgBase =>
      isDark ? AscentColors.bgBaseDark : AscentColors.bgBase;

  Color get bgSurface =>
      isDark ? AscentColors.bgSurfaceDark : AscentColors.bgSurface;

  Color get bgSurfaceElevated => isDark
      ? AscentColors.bgSurfaceElevatedDark
      : AscentColors.bgSurfaceElevated;

  Color get accentPrimary =>
      isDark ? AscentColors.accentPrimaryDark : AscentColors.accentPrimary;

  Color get accentSecondary =>
      isDark ? AscentColors.accentSecondaryDark : AscentColors.accentSecondary;

  Color get accentInfo =>
      isDark ? AscentColors.accentInfoDark : AscentColors.accentInfo;

  Color get stateDanger =>
      isDark ? AscentColors.stateDangerDark : AscentColors.stateDanger;

  Color get stateSuccess =>
      isDark ? AscentColors.stateSuccessDark : AscentColors.stateSuccess;

  Color get stateWarning =>
      isDark ? AscentColors.stateWarningDark : AscentColors.stateWarning;

  Color get textPrimary =>
      isDark ? AscentColors.textPrimaryDark : AscentColors.textPrimary;

  Color get textSecondary =>
      isDark ? AscentColors.textSecondaryDark : AscentColors.textSecondary;

  Color get textMuted =>
      isDark ? AscentColors.textMutedDark : AscentColors.textMuted;

  Color get textOnPrimary =>
      isDark ? AscentColors.textOnPrimaryDark : AscentColors.textOnPrimary;

  Color get divider =>
      isDark ? AscentColors.dividerDark : AscentColors.divider;

  Color get accentPrimaryBright => isDark
      ? AscentColors.accentPrimaryBrightDark
      : AscentColors.accentPrimaryBright;

  Color get accentPrimaryDim => isDark
      ? AscentColors.accentPrimaryDimDark
      : AscentColors.accentPrimaryDim;

  Color get accentSecondaryBright => isDark
      ? AscentColors.accentSecondaryBrightDark
      : AscentColors.accentSecondaryBright;

  Color get stateDangerBright => isDark
      ? AscentColors.stateDangerBrightDark
      : AscentColors.stateDangerBright;
}
