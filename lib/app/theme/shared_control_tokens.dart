import 'package:flutter/material.dart';

import 'calm_blue_palette.dart';

/// Shared control colours (switches, disabled, error, success, warning),
/// resolved from [CalmBluePalette].
class SharedControlColors {
  SharedControlColors._();

  // Semantic controls: blue = action/selection, red = overdue/destructive,
  // grey = structure/disabled. Importance is a user-selected blue star.
  static const actionBlue = CalmBluePalette.action;
  static const actionBlueDark = CalmBluePalette.darkAction;
  // Blue ink on a tinted action surface needs more contrast than an accent dot.
  static const actionBlueInkLight = CalmBluePalette.actionTintInk;
  static const dueRed = CalmBluePalette.danger;
  static const dueRedDark = CalmBluePalette.darkDanger;
  static const neutralFillLight = CalmBluePalette.recessed;
  static const neutralFillDark = CalmBluePalette.darkRecessed;
  static const labelLight = CalmBluePalette.label;
  static const labelDark = CalmBluePalette.darkLabel;

  // ── Switch colors ─────────────────────────────────────────────────────────
  static const Color switchTrackOn = CalmBluePalette.success;
  static const Color switchThumb = Color(0xFFFFFFFF);
  static const Color switchTrackOffLight = CalmBluePalette.recessed;
  static const Color switchTrackOffDark = CalmBluePalette.darkSeparator;

  // ── Disabled control colors ───────────────────────────────────────────────
  static const Color disabledBgLight = Color(0xFFE5E7EB);
  static const Color disabledBgDark = Color(0xFF292B2D);
  static const Color disabledFgLight = Color(0xFF475467);
  static const Color disabledFgDark = Color(0xFFA7ABB3);

  // ── Error / danger ink & soft bg ──────────────────────────────────────────
  static const Color errorInkLight = CalmBluePalette.danger;
  static const Color errorInkDark = CalmBluePalette.darkDanger;
  static const Color errorSoftBgLight = CalmBluePalette.dangerTint;
  static const Color errorSoftBgDark = CalmBluePalette.darkDangerTint;

  // ── Filled destructive action ─────────────────────────────────────────────
  static const Color filledDestructiveBg = CalmBluePalette.danger;
  static const Color filledDestructiveFg = Color(0xFFFFFFFF);
  static const Color filledDestructivePressed = Color(0xFF912018);

  // ── Success ink & soft bg ─────────────────────────────────────────────────
  static const Color successInkLight = CalmBluePalette.success;
  static const Color successInkDark = CalmBluePalette.darkSuccess;
  static const Color successSoftBgLight = CalmBluePalette.successTint;
  static const Color successSoftBgDark = CalmBluePalette.darkSuccessTint;

  // ── Warning ink & soft bg ─────────────────────────────────────────────────
  static const Color warningInkLight = CalmBluePalette.warning;
  static const Color warningInkDark = CalmBluePalette.darkWarning;
  static const Color warningSoftBgLight = CalmBluePalette.warningTint;
  static const Color warningSoftBgDark = CalmBluePalette.darkWarningTint;

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Color errorSoftBg(bool isDark) =>
      isDark ? errorSoftBgDark : errorSoftBgLight;
  static Color errorInk(bool isDark) => isDark ? errorInkDark : errorInkLight;
  static Color successSoftBg(bool isDark) =>
      isDark ? successSoftBgDark : successSoftBgLight;
  static Color successInk(bool isDark) =>
      isDark ? successInkDark : successInkLight;
  static Color switchTrackOff(bool isDark) =>
      isDark ? switchTrackOffDark : switchTrackOffLight;
  static Color disabledBg(bool isDark) =>
      isDark ? disabledBgDark : disabledBgLight;
  static Color disabledFg(bool isDark) =>
      isDark ? disabledFgDark : disabledFgLight;
}

/// Pillar tints (CLAUDE.md §3.1): small icon tiles, charts and header accents
/// only — never full-screen fills.
class PillarTints {
  PillarTints._();

  static const plan = CalmBluePalette.action;
  static const think = Color(0xFF2F8F8A);
  static const live = Color(0xFFFF2D55);
  static const water = Color(0xFF3A9CC9);
  static const waterDark = Color(0xFF6BBCE0);
  static const money = Color(0xFF3A9A63);
  static const moneyDark = Color(0xFF62C08A);
  static const grow = Color(0xFFFF9500);

  /// Promises: a warm, quiet gold ("keep your word").
  static const promise = Color(0xFFB07A12);
  static const promiseDark = Color(0xFFE6B85C);
  static const assistant = Color(0xFF5E5CE6);
  static const neutral = Color(0xFF8E8E93);
}
