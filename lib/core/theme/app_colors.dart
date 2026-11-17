import 'package:flutter/material.dart';

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
    bg: Color(0xFFFAF6F0), // warm paper
    groupedBg: Color(0xFFF3ECE2),
    surface: Color(0xEBFFFFFF), // cards (92% opacity)
    surfaceAlt: Color(0xFFF1E9DD), // inputs, chips, empty states
    border: Color(0xFFE6DCCD), // warm 1px hairline
    textPrimary: Color(0xFF2B2622), // warm charcoal
    textSecondary: Color(0xFF6F665C),
    textTertiary: Color(0xFFA0958A), // hint
    accent: Color(0xFFD2643A), // primary ember
    accentTint: Color(0xFFFCE5D8), // primaryContainer
    onAccent: Color(0xFFFFFFFF), // onPrimary
    accent2: Color(0xFFC4506A), // rose clay
    accent2Tint: Color(0xFFF8E1E6),
    gold: Color(0xFFD6A23E), // soft olive-gold
    goldTint: Color(0xFFF8EDD0),
    ok: Color(0xFFD6A23E), // success (soft olive-gold, not green)
    okTint: Color(0xFFF8EDD0),
    warn: Color(0xFFD6A23E), // tertiary gold
    warnTint: Color(0xFFF8EDD0),
    alert: Color(0xFFB8433B), // error
    alertTint: Color(0xFFFBEBEA),
    headerTop: Color(0xFFFAF6F0),
  );

  static const dark = AppColors(
    bg: Color(0xFF0F1115), // Deep matte charcoal / obsidian
    groupedBg: Color(0xFF14171E),
    surface: Color(0xFF16181F), // Cards (clean neutral obsidian)
    surfaceAlt: Color(0xFF1E212B), // Inputs, chips, elevated wells
    border: Color(0xFF262933), // 1px subtle neutral edge
    textPrimary: Color(0xFFF8FAFC), // Cool crisp white
    textSecondary: Color(0xFF94A3B8), // Slate secondary
    textTertiary: Color(0xFF64748B), // Slate tertiary / hint
    accent: Color(0xFF3B82F6), // Apple Blue in dark mode
    accentTint: Color(0xFF1E293B), // Slate blue container
    onAccent: Color(0xFFFFFFFF),
    accent2: Color(0xFF60A5FA),
    accent2Tint: Color(0xFF1E293B),
    gold: Color(0xFFF59E0B),
    goldTint: Color(0xFF292014),
    ok: Color(0xFF10B981),
    okTint: Color(0xFF132A22),
    warn: Color(0xFFF59E0B),
    warnTint: Color(0xFF292014),
    alert: Color(0xFFEF4444),
    alertTint: Color(0xFF2E1719),
    headerTop: Color(0xFF0F1115),
  );

  // Semantic Sand & Ember getters
  Color get primary => accent;
  Color get onPrimary => onAccent;
  Color get primaryContainer => accentTint;
  Color get onPrimaryContainer =>
      this == light ? const Color(0xFF6E2E15) : const Color(0xFFFFD9C6);
  Color get secondary => accent2;
  Color get onSecondary => onAccent;
  Color get secondaryContainer => accent2Tint;
  Color get onSecondaryContainer =>
      this == light ? const Color(0xFF5A1C29) : const Color(0xFFF8E1E6);
  Color get tertiary => gold;
  Color get tertiaryContainer => goldTint;
  Color get textHint => textTertiary;
  Color get warmShadow =>
      this == light ? const Color(0x0A5C4A3E) : const Color(0x38000000);

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
