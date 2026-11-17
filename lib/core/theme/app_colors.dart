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
    bg: Color(0xFFF1F4F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8EEF5),
    border: Color(0xFFD6DFE8),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textTertiary: Color(0xFF64748B),
    accent: Color(0xFF285A94),
    accentTint: Color(0xFFEBF2FA),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF16A34A),
    okTint: Color(0xFFF0FDF4),
    warn: Color(0xFFD97706),
    warnTint: Color(0xFFFFFBEB),
    alert: Color(0xFFDC2626),
    alertTint: Color(0xFFFEF2F2),
    headerTop: Color(0xFFE8EFF6),
  );

  static const dark = AppColors(
    bg: Color(0xFF0B0F15),
    surface: Color(0xFF131922),
    surfaceAlt: Color(0xFF1A222E),
    border: Color(0xFF222C3A),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textTertiary: Color(0xFF64748B),
    accent: Color(0xFF5B8AC4),
    accentTint: Color(0xFF132030),
    onAccent: Color(0xFFFFFFFF),
    ok: Color(0xFF34D399),
    okTint: Color(0xFF064E3B),
    warn: Color(0xFFFBBF24),
    warnTint: Color(0xFF451A03),
    alert: Color(0xFFF87171),
    alertTint: Color(0xFF450A0A),
    headerTop: Color(0xFF151D29),
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
