import 'package:flutter/material.dart';

/// Centralized shared control colors across all three presets (Nordic Sky, Merlot Linen, Classic Clay)
/// as specified in Section 3.2 of the visual upgrade handoff.
class SharedControlColors {
  SharedControlColors._();

  // Semantic controls: ember = action/selection, red = overdue/destructive,
  // grey = structure/disabled. Importance is a user-selected ember star.
  static const actionBlue = Color(0xFFD2643A);
  static const actionBlueDark = Color(0xFFF08A5D);
  // Ink on a tinted action surface.
  static const actionBlueInkLight = Color(0xFF6E2E15);
  static const dueRed = Color(0xFFB8433B);
  static const dueRedDark = Color(0xFFE06D65);
  static const neutralFillLight = Color(0xFFF1E9DD);
  static const neutralFillDark = Color(0xFF332C27);
  static const labelLight = Color(0xFF2B2622);
  static const labelDark = Color(0xFFF3EBE2);

  // ── Switch colors ─────────────────────────────────────────────────────────
  static const Color switchTrackOn = actionBlue;
  static const Color switchThumb = Color(0xFFFFFFFF);
  static const Color switchTrackOffLight = Color(0xFFE6DCCD);
  static const Color switchTrackOffDark = Color(0xFF3D342E);

  // ── Disabled control colors ───────────────────────────────────────────────
  static const Color disabledBgLight = Color(0xFFF1E9DD);
  static const Color disabledBgDark = Color(0xFF2A2420);
  static const Color disabledFgLight = Color(0xFFA0958A);
  static const Color disabledFgDark = Color(0xFF857A6F);

  // ── Error / danger ink & soft bg ──────────────────────────────────────────
  static const Color errorInkLight = Color(0xFFB8433B);
  static const Color errorInkDark = Color(0xFFE06D65);
  static const Color errorSoftBgLight = Color(0xFFFBEBEA);
  static const Color errorSoftBgDark = Color(0xFF4A1E1C);

  // ── Filled destructive action ─────────────────────────────────────────────
  static const Color filledDestructiveBg = Color(0xFFB8433B);
  static const Color filledDestructiveFg = Color(0xFFFFFFFF);
  static const Color filledDestructivePressed = Color(0xFF912018);

  // ── Success ink & soft bg (Soft olive-gold, never green) ───────────────────
  static const Color successInkLight = Color(0xFFD6A23E);
  static const Color successInkDark = Color(0xFFE8B65A);
  static const Color successSoftBgLight = Color(0xFFF8EDD0);
  static const Color successSoftBgDark = Color(0xFF45351C);

  // ── Warning ink & soft bg ─────────────────────────────────────────────────
  static const Color warningInkLight = Color(0xFFD6A23E);
  static const Color warningInkDark = Color(0xFFE8B65A);
  static const Color warningSoftBgLight = Color(0xFFF8EDD0);
  static const Color warningSoftBgDark = Color(0xFF45351C);

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
