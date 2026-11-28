import 'package:flutter/material.dart';
import 'ascent_tokens.dart';
import 'glass_theme.dart';
import 'calm_blue_palette.dart';
import 'shared_control_tokens.dart';

/// Named colour tokens for the Ascent design system, all resolved from
/// [CalmBluePalette].
/// Use the [AscentColorsX] extension on [BuildContext] to get
/// the correct token for the current brightness.
class AscentColors {
  AscentColors._();

  // Every value is a Calm Blue role (see [CalmBluePalette]).

  // ── Light ──────────────────────────────────────────────────────────────────
  static const Color bgBase = CalmBluePalette.canvas;
  static const Color bgGrouped = CalmBluePalette.canvas;
  static const Color bgSurface = CalmBluePalette.surface;
  static const Color bgSurfaceElevated = CalmBluePalette.recessed;
  static const Color accentPrimary = CalmBluePalette.action;
  static const Color accentPrimaryBright = CalmBluePalette.action;
  static const Color accentPrimaryDim = CalmBluePalette.actionTint;
  static const Color accentSecondary = CalmBluePalette.actionTintInk;
  static const Color accentSecondaryBright = CalmBluePalette.action;
  static const Color accentSecondaryDim = CalmBluePalette.actionTint;
  static const Color accentInfo = CalmBluePalette.warning;
  static const Color accentGold = CalmBluePalette.warning;
  static const Color accentGoldDim = CalmBluePalette.warningTint;
  static const Color stateDanger = CalmBluePalette.danger;
  static const Color stateDangerBright = CalmBluePalette.danger;
  static const Color stateSuccess = CalmBluePalette.success;
  static const Color stateWarning = CalmBluePalette.warning;
  static const Color textPrimary = CalmBluePalette.label;
  static const Color textSecondary = CalmBluePalette.labelSecondary;
  static const Color textMuted = CalmBluePalette.labelTertiary;
  static const Color textOnPrimary = CalmBluePalette.onAction;
  static const Color divider = CalmBluePalette.separator;
  static const Color shadow = CalmBluePalette.shadow;

  // ── Dark ───────────────────────────────────────────────────────────────────
  static const Color bgBaseDark = CalmBluePalette.darkCanvas;
  static const Color bgGroupedDark = CalmBluePalette.darkCanvas;
  static const Color bgSurfaceDark = CalmBluePalette.darkSurface;
  static const Color bgSurfaceElevatedDark = CalmBluePalette.darkElevated;
  static const Color accentPrimaryDark = CalmBluePalette.darkAction;
  static const Color accentPrimaryBrightDark = CalmBluePalette.darkAction;
  static const Color accentPrimaryDimDark = CalmBluePalette.darkActionTint;
  static const Color accentSecondaryDark = CalmBluePalette.darkActionTintInk;
  static const Color accentSecondaryBrightDark =
      CalmBluePalette.darkActionTintInk;
  static const Color accentSecondaryDimDark = CalmBluePalette.darkActionTint;
  static const Color accentInfoDark = CalmBluePalette.darkWarning;
  static const Color accentGoldDark = CalmBluePalette.darkWarning;
  static const Color accentGoldDimDark = CalmBluePalette.darkWarningTint;
  static const Color stateDangerDark = CalmBluePalette.darkDanger;
  static const Color stateDangerBrightDark = CalmBluePalette.darkDanger;
  static const Color stateSuccessDark = CalmBluePalette.darkSuccess;
  static const Color stateWarningDark = CalmBluePalette.darkWarning;
  static const Color textPrimaryDark = CalmBluePalette.darkLabel;
  static const Color textSecondaryDark = CalmBluePalette.darkLabelSecondary;
  static const Color textMutedDark = CalmBluePalette.darkLabelTertiary;
  static const Color textOnPrimaryDark = CalmBluePalette.onAction;
  static const Color dividerDark = CalmBluePalette.darkSeparator;
  static const Color shadowDark = CalmBluePalette.darkShadow;

  /// Pillar accents for hydration and finance (CLAUDE.md §3.1).
  static const Color waterPrimary = PillarTints.water;
  static const Color waterBright = PillarTints.waterDark;
  static const Color financePrimary = PillarTints.money;
  static const Color financeBright = PillarTints.moneyDark;

  /// Translucent day surface highlight (e.g. thought bubble day backdrop)
  static const Color translucentSurfaceDay = Color(0x1AFFFFFF);

  /// Day-mode control outline.
  static const Color outlineDay = CalmBluePalette.separator;
}

/// Convenience extension so call-sites never branch on brightness manually.
extension AscentColorsX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get waterAccent =>
      isDark ? AscentColors.waterBright : AscentColors.waterPrimary;
  Color get financeAccent =>
      isDark ? AscentColors.financeBright : AscentColors.financePrimary;

  /// Page background. Reads [AscentTokens] so it fades with a theme switch
  /// instead of jumping at the end.
  Color get bgBase => tokens.canvas;

  Color get bgSurface =>
      isDark ? AscentColors.bgSurfaceDark : AscentColors.bgSurface;

  Color get bgSurfaceElevated => isDark
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

  Color get accentPrimary => Theme.of(this).colorScheme.primary;

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

  Color get textPrimary => Theme.of(this).colorScheme.onSurface;

  Color get textSecondary =>
      isDark ? AscentColors.textSecondaryDark : AscentColors.textSecondary;

  Color get textMuted => Theme.of(this).colorScheme.onSurfaceVariant;

  Color get textOnPrimary => Theme.of(this).colorScheme.onPrimary;

  Color get divider =>
      Theme.of(this).dividerTheme.color ??
      (isDark ? AscentColors.dividerDark : AscentColors.divider);

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

  Color get spark =>
      isDark ? CalmBluePalette.darkWarning : CalmBluePalette.warning;

  Color get sparkTint =>
      isDark ? CalmBluePalette.darkWarningTint : CalmBluePalette.warningTint;
}
