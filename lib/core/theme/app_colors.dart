import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentTint,
    required this.onAccent,
    required this.ok,
    required this.okTint,
    required this.warn,
    required this.warnTint,
    required this.alert,
    required this.alertTint,
    required this.headerTop,
  });

  final Color bg, surface, surfaceAlt, border;
  final Color textPrimary, textSecondary, textTertiary;
  final Color accent, accentTint, onAccent;
  final Color ok, okTint, warn, warnTint, alert, alertTint;
  final Color headerTop; // top colour of the header gradient

  static const light = AppColors(
    bg: Color(0xFFFBF8F3), // warm paper
    surface: Color(0xFFFFFDF9), // cards
    surfaceAlt: Color(0xFFF4EEE6), // inputs, empty states
    border: Color(0xFFE9E1D5), // warm 1px hairline
    textPrimary: Color(0xFF2A2521), // warm charcoal
    textSecondary: Color(0xFF6B635A),
    textTertiary: Color(0xFF9A9086), // hint
    accent: Color(0xFFBF5A36), // primary warm clay
    accentTint: Color(0xFFFBE6DA), // primaryContainer
    onAccent: Color(0xFFFFFFFF), // onPrimary
    ok: Color(0xFF7C6FB0), // secondary cool dusk lavender
    okTint: Color(0xFFECE8F6), // secondaryContainer
    warn: Color(0xFFC99A3C), // tertiary soft gold
    warnTint: Color(0xFFF7EBCF), // tertiaryContainer
    alert: Color(0xFFB3473F), // error
    alertTint: Color(0xFFFDE8E8),
    headerTop: Color(0xFFFBF8F3),
  );

  static const dark = AppColors(
    bg: Color(0xFF1F1B18), // warm dark (not black)
    surface: Color(0xFF2A2420),
    surfaceAlt: Color(0xFF352F2A),
    border: Color(0xFF433C35),
    textPrimary: Color(0xFFF5EFEB),
    textSecondary: Color(0xFFBAAFA4),
    textTertiary: Color(0xFF8C8176),
    accent: Color(0xFFE28A6D), // primary warm clay
    accentTint: Color(0xFF4D2415), // primaryContainer
    onAccent: Color(0xFF1F1B18),
    ok: Color(0xFFA79BD6), // secondary cool dusk lavender
    okTint: Color(0xFF2D2545), // secondaryContainer
    warn: Color(0xFFE3B863), // tertiary soft gold
    warnTint: Color(0xFF4A3B18), // tertiaryContainer
    alert: Color(0xFFE2756E), // error
    alertTint: Color(0xFF4D1D1B),
    headerTop: Color(0xFF1F1B18),
  );

  // Semantic Sand & Dusk getters
  Color get primary => accent;
  Color get onPrimary => onAccent;
  Color get primaryContainer => accentTint;
  Color get onPrimaryContainer =>
      this == light ? const Color(0xFF6B2E14) : const Color(0xFFFBE6DA);
  Color get secondary => ok;
  Color get onSecondary => onAccent;
  Color get secondaryContainer => okTint;
  Color get onSecondaryContainer =>
      this == light ? const Color(0xFF3A3266) : const Color(0xFFECE8F6);
  Color get tertiary => warn;
  Color get tertiaryContainer => warnTint;
  Color get textHint => textTertiary;
  Color get warmShadow => const Color(0x0A5C4A3E);

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentTint,
    Color? onAccent,
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
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentTint: accentTint ?? this.accentTint,
      onAccent: onAccent ?? this.onAccent,
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
