import 'package:flutter/material.dart';
import 'glass_theme.dart';
import 'frozen_palette.dart';

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

  /// Ascent signature terracotta clay — primary accent.
  static const Color accentPrimary = Color(0xFFA4523A);

  /// Matte punchy clay for active/interactive buttons and rings.
  static const Color accentPrimaryBright = Color(0xFF904530);

  /// Subtle soft tint for primary backgrounds and badges.
  static const Color accentPrimaryDim = Color(0xFFF6E7E2);

  /// Calm composed terracotta / amber cedar — secondary accent (soothing in day mode).
  static const Color accentSecondary = Color(0xFF8A513E);

  /// Composed cedar tone for active countdown and focus markers.
  static const Color accentSecondaryBright = Color(0xFF9E5C47);

  /// Warm caramel — informational accent.
  static const Color accentInfo = Color(0xFF9D734F);

  /// Restrained rose-crimson — destructive / error state (calm in day mode).
  static const Color stateDanger = Color(0xFFBA433C);

  /// Saturated red for cancel and delete.
  static const Color stateDangerBright = Color(0xFFA83630);

  /// Success — matches primary forest sage.
  static const Color stateSuccess = Color(0xFF38664D);

  /// Warning — soft warm honey / amber (calm and non-glaring in day mode).
  static const Color stateWarning = Color(0xFFB46824);

  /// Deep near-black graphite text.
  static const Color textPrimary = Color(0xFF1D1916);

  /// Refined secondary text.
  static const Color textSecondary = Color(0xFF635A52);

  /// Muted / placeholder text.
  static const Color textMuted = Color(0xFF74695F);

  /// Text rendered on top of primary-colored surfaces.
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Ultra-thin hairline divider line.
  static const Color divider = Color(0xFFE5E8ED);

  /// Shadow tint for soft diffuse elevation.
  static const Color shadow = Color(0xFF1D1916);

  // ── Dark mode ──────────────────────────────────────────────────────────────

  /// Deep obsidian graphite — page background.
  static const Color bgBaseDark = Color(0xFF16120F);

  /// Matte dark charcoal surface — cards, sheets, inputs.
  static const Color bgSurfaceDark = Color(0xFF221D18);

  /// Elevated dark surface for nested items and chips.
  static const Color bgSurfaceElevatedDark = Color(0xFF322922);

  /// Warm luminous clay / terracotta — primary accent in dark mode.
  static const Color accentPrimaryDark = Color(0xFFE6A088);
  static const Color accentPrimaryBrightDark = Color(0xFFF0B39F);
  static const Color accentPrimaryDimDark = Color(0xFF3A241D);

  /// Warm clay / terracotta — secondary accent.
  static const Color accentSecondaryDark = Color(0xFFE88168);
  static const Color accentSecondaryBrightDark = Color(0xFFF2957E);

  /// Soft sand — informational accent.
  static const Color accentInfoDark = Color(0xFFC1A17C);

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
  static const Color textMutedDark = Color(0xFF8C8075);

  /// Text on primary in dark mode.
  static const Color textOnPrimaryDark = Color(0xFF0D1812);

  /// Subtle dark divider line.
  static const Color dividerDark = Color(0xFF372E26);

  /// Shadow in dark mode.
  static const Color shadowDark = Color(0xFF000000);
}

/// Convenience extension so call-sites never branch on brightness manually.
extension AscentColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  bool get isFrozen => Theme.of(this).extension<AscentGlass>()?.frozen == true;

  Color get bgBase => isFrozen
      ? FrozenPalette.canvas
      : isDark
      ? AscentColors.bgBaseDark
      : AscentColors.bgBase;

  Color get bgSurface => isFrozen
      ? FrozenPalette.surface
      : isDark
      ? AscentColors.bgSurfaceDark
      : AscentColors.bgSurface;

  Color get bgSurfaceElevated => isFrozen
      ? FrozenPalette.elevated
      : isDark
      ? AscentColors.bgSurfaceElevatedDark
      : AscentColors.bgSurfaceElevated;

  Color get accentPrimary =>
      isFrozen ? FrozenPalette.accent : Theme.of(this).colorScheme.primary;

  Color get accentSecondary => isFrozen
      ? FrozenPalette.secondary
      : isDark
      ? AscentColors.accentSecondaryDark
      : AscentColors.accentSecondary;

  Color get accentInfo => isFrozen
      ? FrozenPalette.warning
      : isDark
      ? AscentColors.accentInfoDark
      : AscentColors.accentInfo;

  Color get stateDanger => isFrozen
      ? FrozenPalette.danger
      : isDark
      ? AscentColors.stateDangerDark
      : AscentColors.stateDanger;

  Color get stateSuccess => isFrozen
      ? FrozenPalette.success
      : isDark
      ? AscentColors.stateSuccessDark
      : AscentColors.stateSuccess;

  Color get stateWarning => isFrozen
      ? FrozenPalette.warning
      : isDark
      ? AscentColors.stateWarningDark
      : AscentColors.stateWarning;

  Color get textPrimary => Theme.of(this).colorScheme.onSurface;

  Color get textSecondary => isFrozen
      ? FrozenPalette.secondaryInk
      : isDark
      ? AscentColors.textSecondaryDark
      : AscentColors.textSecondary;

  Color get textMuted => Theme.of(this).colorScheme.onSurfaceVariant;

  Color get textOnPrimary => Theme.of(this).colorScheme.onPrimary;

  Color get divider =>
      Theme.of(this).dividerTheme.color ??
      (isDark ? AscentColors.dividerDark : AscentColors.divider);

  Color get accentPrimaryBright => isFrozen
      ? FrozenPalette.accent
      : isDark
      ? AscentColors.accentPrimaryBrightDark
      : AscentColors.accentPrimaryBright;

  Color get accentPrimaryDim => isFrozen
      ? FrozenPalette.aqua
      : isDark
      ? AscentColors.accentPrimaryDimDark
      : AscentColors.accentPrimaryDim;

  Color get accentSecondaryBright => isFrozen
      ? FrozenPalette.secondary
      : isDark
      ? AscentColors.accentSecondaryBrightDark
      : AscentColors.accentSecondaryBright;

  Color get stateDangerBright => isFrozen
      ? FrozenPalette.danger
      : isDark
      ? AscentColors.stateDangerBrightDark
      : AscentColors.stateDangerBright;
}
