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

  /// Crisp, misty cool-slate off-white — page background with glass depth.
  static const Color bgBase = Color(0xFFEFF2F6);

  /// Pure white surface — cards, sheets, inputs.
  static const Color bgSurface = Color(0xFFFFFFFF);

  /// Slightly elevated surface for nested cards and chips.
  static const Color bgSurfaceElevated = Color(0xFFFAF7F4);

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

  /// Deep near-black obsidian slate text.
  static const Color textPrimary = Color(0xFF0F172A);

  /// Refined secondary slate text.
  static const Color textSecondary = Color(0xFF334155);

  /// Muted / placeholder slate text.
  static const Color textMuted = Color(0xFF64748B);

  /// Text rendered on top of primary-colored surfaces.
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  /// Ultra-thin hairline divider line.
  static const Color divider = Color(0xFFE2E8F0);

  /// Shadow tint for soft diffuse elevation.
  static const Color shadow = Color(0xFF0F172A);

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

  /// Secondary text in dark mode — soft clear silver (10+:1 contrast).
  static const Color textSecondaryDark = Color(0xFFCBD5E1);

  /// Muted text in dark mode — readable slate-oat (6.5+:1 contrast).
  static const Color textMutedDark = Color(0xFFA89F96);

  /// Text on primary in dark mode — dark ink on peach clay.
  static const Color textOnPrimaryDark = Color(0xFF0D1812);

  /// Subtle dark divider line.
  static const Color dividerDark = Color(0xFF372E26);

  /// Shadow in dark mode.
  static const Color shadowDark = Color(0xFF000000);

  /// Water & Hydration accent tokens.
  static const Color waterPrimary = Color(0xFF0284C7);
  static const Color waterBright = Color(0xFF38BDF8);

  /// Money & Finance accent tokens.
  static const Color financePrimary = Color(0xFF059669);
  static const Color financeBright = Color(0xFF34D399);

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
