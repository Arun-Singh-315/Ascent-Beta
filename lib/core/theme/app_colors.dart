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
    accent: Color(0xFF2F6F6A),
    accentTint: Color(0xFFE3EEEB),
    onAccent: Color(0xFFF7F6F2),
    ok: Color(0xFF3F8F6B),
    okTint: Color(0xFFE4F1EA),
    warn: Color(0xFFC98A2B),
    warnTint: Color(0xFFF6EBD6),
    alert: Color(0xFFC0473F),
    alertTint: Color(0xFFF6E1DF),
    headerTop: Color(0xFFE3EAE4),
  );

  static const dark = AppColors(
    bg: Color(0xFF14171A),
    surface: Color(0xFF1C2024),
    surfaceAlt: Color(0xFF23282D),
    border: Color(0xFF2A2F35),
    textPrimary: Color(0xFFE8E6E1),
    textSecondary: Color(0xFFA3A9B0),
    textTertiary: Color(0xFF6F767E),
    accent: Color(0xFF5FB3AB),
    accentTint: Color(0xFF1F3532),
    onAccent: Color(0xFF0F1A19),
    ok: Color(0xFF6BC29A),
    okTint: Color(0xFF1B2E26),
    warn: Color(0xFFE0A94E),
    warnTint: Color(0xFF30271A),
    alert: Color(0xFFE5766E),
    alertTint: Color(0xFF32201F),
    headerTop: Color(0xFF1D2A28),
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
