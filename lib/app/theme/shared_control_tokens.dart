import 'package:flutter/material.dart';

/// Centralized shared control colors across all three presets (Nordic Sky, Merlot Linen, Classic Clay)
/// as specified in Section 3.2 of the visual upgrade handoff.
class SharedControlColors {
  SharedControlColors._();

  // ── Switch colors ─────────────────────────────────────────────────────────
  static const Color switchTrackOn = Color(0xFF16803C);
  static const Color switchThumb = Color(0xFFFFFFFF);
  static const Color switchTrackOffLight = Color(0xFF737984);
  static const Color switchTrackOffDark = Color(0xFF656C78);

  // ── Disabled control colors ───────────────────────────────────────────────
  static const Color disabledBgLight = Color(0xFFE5E7EB);
  static const Color disabledBgDark = Color(0xFF292B2D);
  static const Color disabledFgLight = Color(0xFF475467);
  static const Color disabledFgDark = Color(0xFFA7ABB3);

  // ── Error / danger ink & soft bg ──────────────────────────────────────────
  static const Color errorInkLight = Color(0xFFB42318);
  static const Color errorInkDark = Color(0xFFFFB4AB);
  static const Color errorSoftBgLight = Color(0xFFFEE4E2);
  static const Color errorSoftBgDark = Color(0xFF4A2525);

  // ── Filled destructive action ─────────────────────────────────────────────
  static const Color filledDestructiveBg = Color(0xFFB42318);
  static const Color filledDestructiveFg = Color(0xFFFFFFFF);
  static const Color filledDestructivePressed = Color(0xFF912018);

  // ── Success ink & soft bg ─────────────────────────────────────────────────
  static const Color successInkLight = Color(0xFF166534);
  static const Color successInkDark = Color(0xFF86EFAC);
  static const Color successSoftBgLight = Color(0xFFE8F5EC);
  static const Color successSoftBgDark = Color(0xFF173426);

  // ── Warning ink & soft bg ─────────────────────────────────────────────────
  static const Color warningInkLight = Color(0xFF854D0E);
  static const Color warningInkDark = Color(0xFFFDE68A);
  static const Color warningSoftBgLight = Color(0xFFFFF3CD);
  static const Color warningSoftBgDark = Color(0xFF3B301B);

  // ── Helpers ───────────────────────────────────────────────────────────────
  static Color errorSoftBg(bool isDark) => isDark ? errorSoftBgDark : errorSoftBgLight;
  static Color errorInk(bool isDark) => isDark ? errorInkDark : errorInkLight;
  static Color successSoftBg(bool isDark) => isDark ? successSoftBgDark : successSoftBgLight;
  static Color successInk(bool isDark) => isDark ? successInkDark : successInkLight;
  static Color switchTrackOff(bool isDark) => isDark ? switchTrackOffDark : switchTrackOffLight;
  static Color disabledBg(bool isDark) => isDark ? disabledBgDark : disabledBgLight;
  static Color disabledFg(bool isDark) => isDark ? disabledFgDark : disabledFgLight;
}
