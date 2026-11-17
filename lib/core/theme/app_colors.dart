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
    bg: Color(0xFFF3F1EC),
    surface: Color(0xFFFAF9F6),
    surfaceAlt: Color(0xFFEFECE5),
    border: Color(0xFFE2DED5),
    textPrimary: Color(0xFF1F2328),
    textSecondary: Color(0xFF6B7280),
    textTertiary: Color(0xFF9AA0A6),
    accent: Color(0xFF2563EB),
    accentTint: Color(0xFFEFF6FF),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF10B981),
    okTint: Color(0xFFECFDF5),
    warn: Color(0xFFF59E0B),
    warnTint: Color(0xFFFFFBEB),
    alert: Color(0xFFEF4444),
    alertTint: Color(0xFFFEF2F2),
    headerTop: Color(0xFFEEF2F6),
  );

  static const dark = AppColors(
    bg: Color(0xFF14171A),
    surface: Color(0xFF1C2024),
    surfaceAlt: Color(0xFF23282D),
    border: Color(0xFF2A2F35),
    textPrimary: Color(0xFFE8E6E1),
    textSecondary: Color(0xFFA3A9B0),
    textTertiary: Color(0xFF6F767E),
    accent: Color(0xFF60A5FA),
    accentTint: Color(0xFF1E293B),
    onAccent: Color(0xFF0F172A),
    ok: Color(0xFF34D399),
    okTint: Color(0xFF064E3B),
    warn: Color(0xFFFBBF24),
    warnTint: Color(0xFF451A03),
    alert: Color(0xFFF87171),
    alertTint: Color(0xFF450A0A),
    headerTop: Color(0xFF0F172A),
  );

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
