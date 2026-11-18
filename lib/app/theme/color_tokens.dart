import 'package:flutter/material.dart';
import 'glass_theme.dart';
import 'day_glass_material.dart';
import 'frozen_palette.dart';
import 'merlot_palette.dart';

/// All color tokens for the Ascent design system.
/// Muted, matte, calm, and tailored for focus & productivity.
/// Use the [AscentColorsX] extension on [BuildContext] to get
/// the correct token for the current brightness.
class AscentColors {
  AscentColors._();

  // ── Light mode ─────────────────────────────────────────────────────────────

  /// Clean, airy off-white page canvas (Apple Porcelain).
  static const Color bgBase = Color(0xFFF8FAFC);
  static const Color bgGrouped = Color(0xFFF1F5F9);

  /// Card surface (100% opaque solid white with crisp contrast).
  static const Color bgSurface = Color(0xFFFFFFFF);

  /// Elevated surface for inputs and empty states.
  static const Color bgSurfaceElevated = Color(0xFFF1F5F9);

  /// Primary active Apple Blue CTA accent.
  static const Color accentPrimary = Color(0xFF006FE6);
  static const Color accentPrimaryBright = Color(0xFF006FE6);

  /// Primary container tint for soft buttons and selected chips.
  static const Color accentPrimaryDim = Color(0xFFEBF4FF);

  /// Secondary sky accent.
  static const Color accentSecondary = Color(0xFF0284C7);
  static const Color accentSecondaryBright = Color(0xFF0284C7);
  static const Color accentSecondaryDim = Color(0xFFE0F2FE);

  /// Tertiary amber informational / streaks accent.
  static const Color accentInfo = Color(0xFFD97706);
  static const Color accentGold = Color(0xFFD97706);
  static const Color accentGoldDim = Color(0xFFFEF3C7);

  /// Restrained error state.
  static const Color stateDanger = Color(0xFFDC2626);
  static const Color stateDangerBright = Color(0xFFDC2626);

  /// Success state (clean green).
  static const Color stateSuccess = Color(0xFF16A34A);

  /// Warning state (clean amber).
  static const Color stateWarning = Color(0xFFD97706);

  /// Deep slate-black primary text.
  static const Color textPrimary = Color(0xFF0F172A);

  /// Refined secondary text.
  static const Color textSecondary = Color(0xFF475569);

  /// Muted / placeholder / hint text.
  static const Color textMuted = Color(0xFF94A3B8);

  /// Text rendered on top of primary-colored surfaces.
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// 1px neutral hairline border / outline.
  static const Color divider = Color(0xFFE2E8F0);

  /// Very soft shadow (blur 16, natural neutral slate shadow).
  static const Color shadow = Color(0x0E0F172A);

  // ── Dark mode ──────────────────────────────────────────────────────────────

  /// Deep matte charcoal / obsidian page foundation.
  static const Color bgBaseDark = Color(0xFF0F1115);
  static const Color bgGroupedDark = Color(0xFF14171E);

  /// Clean neutral dark surface — cards, sheets (OPAQUE).
  static const Color bgSurfaceDark = Color(0xFF16181F);

  /// Elevated dark surface for nested items, inputs and chips.
  static const Color bgSurfaceElevatedDark = Color(0xFF1E212B);

  /// Apple Action Blue primary accent in dark mode.
  static const Color accentPrimaryDark = Color(0xFF3B82F6);
  static const Color accentPrimaryBrightDark = Color(0xFF60A5FA);
  static const Color accentPrimaryDimDark = Color(0xFF1E293B);

  /// Rose / secondary accent in dark mode.
  static const Color accentSecondaryDark = Color(0xFF60A5FA);
  static const Color accentSecondaryBrightDark = Color(0xFF93C5FD);
  static const Color accentSecondaryDimDark = Color(0xFF1E293B);

  /// Soft gold informational / tertiary accent in dark mode.
  static const Color accentInfoDark = Color(0xFFF59E0B);
  static const Color accentGoldDark = Color(0xFFF59E0B);
  static const Color accentGoldDimDark = Color(0xFF292014);

  /// Error state in dark mode.
  static const Color stateDangerDark = Color(0xFFEF4444);
  static const Color stateDangerBrightDark = Color(0xFFF87171);

  /// Success state in dark mode.
  static const Color stateSuccessDark = Color(0xFF10B981);
  static const Color stateWarningDark = Color(0xFFF59E0B);

  /// Cool crisp white text.
  static const Color textPrimaryDark = Color(0xFFF8FAFC);

  /// Secondary text in dark mode.
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  /// Muted / hint text in dark mode.
  static const Color textMutedDark = Color(0xFF64748B);

  /// Text on primary in dark mode.
  static const Color textOnPrimaryDark = Color(0xFFFFFFFF);

  /// Subtle neutral dark border (1px hairline).
  static const Color dividerDark = Color(0xFF262933);

  /// Shadow in dark mode — clean neutral black shadow.
  static const Color shadowDark = Color(0x40000000);

  /// Warm accents for hydration and finance (no saturated blue/green).
  static const Color waterPrimary = Color(0xFFD2643A);
  static const Color waterBright = Color(0xFFF08A5D);
  static const Color financePrimary = Color(0xFFD6A23E);
  static const Color financeBright = Color(0xFFE8B65A);

  /// Translucent day surface highlight (e.g. thought bubble day backdrop)
  static const Color translucentSurfaceDay = Color(0x1AFFFFFF);

  /// Day mode subdued outline border
  static const Color outlineDay = Color(0xFF73727B);
}

/// Convenience extension so call-sites never branch on brightness manually.
extension AscentColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  bool get isMerlot => Theme.of(this).extension<AscentGlass>()?.merlot == true;

  bool get isFrozen => Theme.of(this).extension<AscentGlass>()?.frozen == true;

  Color get waterAccent =>
      isDark ? AscentColors.waterBright : AscentColors.waterPrimary;
  Color get financeAccent =>
      isDark ? AscentColors.financeBright : AscentColors.financePrimary;

  Color get bgBase =>
      Theme.of(this).extension<DayGlassMaterial>()?.canvas ??
      (isMerlot
          ? (isDark ? MerlotPalette.darkCanvas : MerlotPalette.canvas)
          : isFrozen
          ? (isDark ? FrozenPalette.darkCanvas : FrozenPalette.canvas)
          : isDark
          ? AscentColors.bgBaseDark
          : AscentColors.bgBase);

  Color get bgSurface => isMerlot
      ? (isDark ? MerlotPalette.darkSurface : MerlotPalette.surface)
      : isFrozen
      ? (isDark ? FrozenPalette.darkSurface : FrozenPalette.surface)
      : isDark
      ? AscentColors.bgSurfaceDark
      : AscentColors.bgSurface;

  Color get bgSurfaceElevated => isMerlot
      ? (isDark ? MerlotPalette.darkSurface : MerlotPalette.surface)
      : isFrozen
      ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
      : isDark
      ? AscentColors.bgSurfaceElevatedDark
      : AscentColors.bgSurfaceElevated;

  Color get surface =>
      Theme.of(this).extension<AscentGlass>()?.surface ?? bgSurface;

  Color get elevatedSurface =>
      Theme.of(this).extension<AscentGlass>()?.elevated ?? bgSurfaceElevated;

  Color get recessedSurface =>
      Theme.of(this).extension<AscentGlass>()?.recessed ?? bgBase;

  Color get controlOutline =>
      Theme.of(this).extension<AscentGlass>()?.controlOutline ?? divider;

  Color get actionInk =>
      Theme.of(this).extension<AscentGlass>()?.actionInk ?? accentPrimary;

  Color get primaryButtonBg =>
      Theme.of(this).extension<AscentGlass>()?.primaryButtonBg ?? accentPrimary;

  Color get primaryButtonFg =>
      Theme.of(this).extension<AscentGlass>()?.primaryButtonFg ?? textOnPrimary;

  Color get primaryButtonPressed =>
      Theme.of(this).extension<AscentGlass>()?.primaryButtonPressed ??
      accentPrimaryBright;

  Color get tonalBg =>
      Theme.of(this).extension<AscentGlass>()?.tonalBg ?? accentPrimaryDim;

  Color get tonalFg =>
      Theme.of(this).extension<AscentGlass>()?.tonalFg ?? accentPrimary;

  Color get focusRing =>
      Theme.of(this).extension<AscentGlass>()?.focusRing ?? accentPrimary;

  Color get accentPrimary => isFrozen
      ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
      : Theme.of(this).colorScheme.primary;

  Color get accentSecondary => isFrozen
      ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
      : isDark
      ? AscentColors.accentSecondaryDark
      : AscentColors.accentSecondary;

  Color get accentInfo => isFrozen
      ? (isDark ? FrozenPalette.darkWarning : FrozenPalette.warning)
      : isDark
      ? AscentColors.accentInfoDark
      : AscentColors.accentInfo;

  Color get stateDanger => isFrozen
      ? (isDark ? FrozenPalette.darkDanger : FrozenPalette.danger)
      : isDark
      ? AscentColors.stateDangerDark
      : AscentColors.stateDanger;

  Color get stateSuccess => isFrozen
      ? (isDark ? FrozenPalette.darkSuccess : FrozenPalette.success)
      : isDark
      ? AscentColors.stateSuccessDark
      : AscentColors.stateSuccess;

  Color get stateWarning => isFrozen
      ? (isDark ? FrozenPalette.darkWarning : FrozenPalette.warning)
      : isDark
      ? AscentColors.stateWarningDark
      : AscentColors.stateWarning;

  Color get textPrimary => Theme.of(this).colorScheme.onSurface;

  Color get textSecondary => isFrozen
      ? (isDark ? FrozenPalette.darkSecondaryInk : FrozenPalette.secondaryInk)
      : isDark
      ? AscentColors.textSecondaryDark
      : AscentColors.textSecondary;

  Color get textMuted => Theme.of(this).colorScheme.onSurfaceVariant;

  Color get textOnPrimary => Theme.of(this).colorScheme.onPrimary;

  Color get divider =>
      Theme.of(this).dividerTheme.color ??
      (isDark ? AscentColors.dividerDark : AscentColors.divider);

  Color get accentPrimaryBright => isFrozen
      ? (isDark ? FrozenPalette.darkActionBright : FrozenPalette.actionBright)
      : isDark
      ? AscentColors.accentPrimaryBrightDark
      : AscentColors.accentPrimaryBright;

  Color get accentPrimaryDim => isFrozen
      ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
      : isDark
      ? AscentColors.accentPrimaryDimDark
      : AscentColors.accentPrimaryDim;

  Color get accentSecondaryBright => isFrozen
      ? (isDark ? FrozenPalette.darkActionBright : FrozenPalette.actionBright)
      : isDark
      ? AscentColors.accentSecondaryBrightDark
      : AscentColors.accentSecondaryBright;

  Color get stateDangerBright => isFrozen
      ? (isDark ? FrozenPalette.darkDanger : FrozenPalette.danger)
      : isDark
      ? AscentColors.stateDangerBrightDark
      : AscentColors.stateDangerBright;

  Color get spark => isFrozen
      ? (isDark ? FrozenPalette.darkSpark : FrozenPalette.spark)
      : (isDark ? const Color(0xFFECA361) : const Color(0xFFB06822));

  Color get sparkTint => isFrozen
      ? (isDark ? FrozenPalette.darkSparkTint : FrozenPalette.sparkTint)
      : (isDark
            ? const Color.fromRGBO(236, 163, 97, 0.14)
            : const Color.fromRGBO(176, 104, 34, 0.11));
}
