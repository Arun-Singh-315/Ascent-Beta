import 'package:flutter/material.dart';

/// All color tokens for the Ascent design system.
/// Use the [AscentColorsX] extension on [BuildContext] to get
/// the correct token for the current brightness.
class AscentColors {
  AscentColors._();

  // ── Light mode ─────────────────────────────────────────────────────────────

  /// Soft warm cream — page background.
  static const Color bgBase = Color(0xFFFBF9F6);

  /// White surface — cards, sheets, inputs.
  static const Color bgSurface = Color(0xFFFFFFFF);

  /// Slightly darker surface used to indicate elevation.
  static const Color bgSurfaceElevated = Color(0xFFF5F3F0);

  /// Soft sage green — primary accent.
  static const Color accentPrimary = Color(0xFF7FA88A);

  /// Soft peach/coral — secondary accent.
  static const Color accentSecondary = Color(0xFFE8A57C);

  /// Soft dusty blue — informational accent.
  static const Color accentInfo = Color(0xFF7C9CC4);

  /// Soft coral-red — destructive / error state.
  static const Color stateDanger = Color(0xFFD98C86);

  /// Success — matches primary sage green.
  static const Color stateSuccess = Color(0xFF7FA88A);

  /// Warning — matches secondary peach.
  static const Color stateWarning = Color(0xFFE8A57C);

  /// Near-black warm text.
  static const Color textPrimary = Color(0xFF2A2E33);

  /// Muted/placeholder text — same in both modes.
  static const Color textMuted = Color(0xFF8B9198);

  /// Text rendered on top of primary-colored surfaces.
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Subtle warm divider line.
  static const Color divider = Color(0xFFEAE8E4);

  /// Shadow tint for elevation effects.
  static const Color shadow = Color(0xFF2A2E33);

  // ── V1 Brightness Tokens (Light) ───────────────────────────────────────────

  /// Saturated, punchier sage for active/interactive buttons, timer ring, active nav.
  static const Color accentPrimaryBright = Color(0xFF5FA070);

  /// Flatter, lower-contrast sage for disabled/loading buttons.
  static const Color accentPrimaryDim = Color(0xFFB7CDBE);

  /// Punchier peach for FAB active/pressed state, live-timer accent.
  static const Color accentSecondaryBright = Color(0xFFF2954F);

  /// Bright, saturated red for Cancel and Delete actions specifically.
  static const Color stateDangerBright = Color(0xFFE53935);

  // ── Dark mode ──────────────────────────────────────────────────────────────

  static const Color bgBaseDark = Color(0xFF14181D);
  static const Color bgSurfaceDark = Color(0xFF1C2128);
  static const Color bgSurfaceElevatedDark = Color(0xFF252D37);
  static const Color accentPrimaryDark = Color(0xFF8FBB9A);
  static const Color accentSecondaryDark = Color(0xFFEFB48C);
  static const Color accentInfoDark = Color(0xFF8FADD1);
  static const Color stateDangerDark = Color(0xFFE09B95);
  static const Color stateSuccessDark = Color(0xFF8FBB9A);
  static const Color stateWarningDark = Color(0xFFEFB48C);
  static const Color textPrimaryDark = Color(0xFFEDEFF2);

  /// Muted text — intentionally identical in light and dark.
  static const Color textMutedDark = Color(0xFF8B9198);
  static const Color textOnPrimaryDark = Color(0xFF14181D);
  static const Color dividerDark = Color(0xFF2A3038);
  static const Color shadowDark = Color(0xFF000000);

  // ── V1 Brightness Tokens (Dark) ────────────────────────────────────────────

  static const Color accentPrimaryBrightDark = Color(0xFF7FE39C);
  static const Color accentPrimaryDimDark = Color(0xFF3A4A40);
  static const Color accentSecondaryBrightDark = Color(0xFFFFB877);
  static const Color stateDangerBrightDark = Color(0xFFFF6659);
}

/// Convenience extension so call-sites never branch on brightness manually.
///
/// ```dart
/// Container(color: context.accentPrimary)
/// ```
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
      isDark ? const Color(0xFFB0B7C0) : const Color(0xFF555B63);

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

