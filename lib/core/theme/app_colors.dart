import 'package:flutter/material.dart';

import '../../app/theme/calm_blue_palette.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.groupedBg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentTint,
    required this.onAccent,
    required this.accent2,
    required this.accent2Tint,
    required this.gold,
    required this.goldTint,
    required this.ok,
    required this.okTint,
    required this.warn,
    required this.warnTint,
    required this.alert,
    required this.alertTint,
    required this.headerTop,
  });

  final Color bg, groupedBg, surface, surfaceAlt, border;
  final Color textPrimary, textSecondary, textTertiary;
  final Color accent, accentTint, onAccent;
  final Color accent2, accent2Tint;
  final Color gold, goldTint;
  final Color ok, okTint, warn, warnTint, alert, alertTint;
  final Color headerTop; // top colour of the header gradient

  static const light = AppColors(
    bg: CalmBluePalette.canvas,
    groupedBg: CalmBluePalette.canvas,
    surface: CalmBluePalette.surface,
    surfaceAlt: CalmBluePalette.recessed,
    border: CalmBluePalette.separator,
    textPrimary: CalmBluePalette.label,
    textSecondary: CalmBluePalette.labelSecondary,
    textTertiary: CalmBluePalette.labelTertiary,
    accent: CalmBluePalette.action,
    accentTint: CalmBluePalette.actionTint,
    onAccent: CalmBluePalette.onAction,
    accent2: CalmBluePalette.actionTintInk,
    accent2Tint: CalmBluePalette.actionTint,
    gold: CalmBluePalette.warning,
    goldTint: CalmBluePalette.warningTint,
    ok: CalmBluePalette.success,
    okTint: CalmBluePalette.successTint,
    warn: CalmBluePalette.warning,
    warnTint: CalmBluePalette.warningTint,
    alert: CalmBluePalette.danger,
    alertTint: CalmBluePalette.dangerTint,
    headerTop: CalmBluePalette.canvas,
  );

  static const dark = AppColors(
    bg: CalmBluePalette.darkCanvas,
    groupedBg: CalmBluePalette.darkCanvas,
    surface: CalmBluePalette.darkSurface,
    surfaceAlt: CalmBluePalette.darkRecessed,
    border: CalmBluePalette.darkSeparator,
    textPrimary: CalmBluePalette.darkLabel,
    textSecondary: CalmBluePalette.darkLabelSecondary,
    textTertiary: CalmBluePalette.darkLabelTertiary,
    accent: CalmBluePalette.darkAction,
    accentTint: CalmBluePalette.darkActionTint,
    onAccent: CalmBluePalette.onAction,
    accent2: CalmBluePalette.darkActionTintInk,
    accent2Tint: CalmBluePalette.darkActionTint,
    gold: CalmBluePalette.darkWarning,
    goldTint: CalmBluePalette.darkWarningTint,
    ok: CalmBluePalette.darkSuccess,
    okTint: CalmBluePalette.darkSuccessTint,
    warn: CalmBluePalette.darkWarning,
    warnTint: CalmBluePalette.darkWarningTint,
    alert: CalmBluePalette.darkDanger,
    alertTint: CalmBluePalette.darkDangerTint,
    headerTop: CalmBluePalette.darkCanvas,
  );

  // Semantic Sand & Ember getters
  Color get primary => accent;
  Color get onPrimary => onAccent;
  Color get primaryContainer => accentTint;
  Color get onPrimaryContainer =>
      this == light ? const Color(0xFF004CA6) : const Color(0xFF93C5FD);
  Color get secondary => accent2;
  Color get onSecondary => onAccent;
  Color get secondaryContainer => accent2Tint;
  Color get onSecondaryContainer =>
      this == light ? const Color(0xFF0369A1) : const Color(0xFF93C5FD);
  Color get tertiary => gold;
  Color get tertiaryContainer => goldTint;
  Color get textHint => textTertiary;
  Color get warmShadow =>
      this == light ? const Color(0x0E0F172A) : const Color(0x38000000);

  @override
  AppColors copyWith({
    Color? bg,
    Color? groupedBg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentTint,
    Color? onAccent,
    Color? accent2,
    Color? accent2Tint,
    Color? gold,
    Color? goldTint,
    Color? ok,
    Color? okTint,
    Color? warn,
    Color? warnTint,
    Color? alert,
    Color? alertTint,
    Color? headerTop,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      groupedBg: groupedBg ?? this.groupedBg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      onAccent: onAccent ?? this.onAccent,
      accent2: accent2 ?? this.accent2,
      accent2Tint: accent2Tint ?? this.accent2Tint,
      gold: gold ?? this.gold,
      goldTint: goldTint ?? this.goldTint,
      ok: ok ?? this.ok,
      okTint: okTint ?? this.okTint,
      warn: warn ?? this.warn,
      warnTint: warnTint ?? this.warnTint,
      alert: alert ?? this.alert,
      alertTint: alertTint ?? this.alertTint,
      headerTop: headerTop ?? this.headerTop,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors ? (t < 0.5 ? this : other) : this;
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
