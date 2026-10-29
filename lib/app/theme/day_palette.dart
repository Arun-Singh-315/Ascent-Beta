import 'package:flutter/material.dart';

/// Warm "Day" accents used by the default light theme (the one that is neither
/// Frost nor Merlot). Mirrors the structure of [FrozenPalette] and
/// [MerlotPalette] so widgets no longer inline these literals.
///
/// Values are unchanged from the literals previously hardcoded in Home.
class DayPalette {
  DayPalette._();

  /// Soft warm surface for small controls (e.g. theme toggle).
  static const surface = Color(0xFFFFF7ED);

  /// Warm hairline border.
  static const line = Color(0xFFFDBA74);

  /// Warm action tone; also the base of control shadows.
  static const action = Color(0xFFF97316);

  /// Avatar gradient start (lighter).
  static const gradientStart = Color(0xFFFFEDD5);

  /// Avatar gradient end (deeper).
  static const gradientEnd = Color(0xFFFED7AA);

  /// Deep warm ink for text on the warm gradient.
  static const deepInk = Color(0xFF9A3412);

  /// Sun icon tone (shown in dark mode to switch to light).
  static const sun = Color(0xFFF59E0B);

  /// Moon icon tone (shown in light mode to switch to dark).
  static const moon = Color(0xFF6366F1);

  /// Neutral slate pill/chip fill for cards on the default light theme.
  static const pillSoft = Color(0xFFF1F5F9);

  /// Cool water-card surface (quick water buttons).
  static const waterSurface = Color(0xFFF0F7FB);

  /// Cool water-card hairline border.
  static const waterLine = Color(0xFFD2E3F1);

  /// Cool water-icon background tint.
  static const waterTint = Color(0xFFE0EFF8);

  /// Cool water-icon foreground.
  static const waterAction = Color(0xFF0284C7);

  /// Very soft water-card shadow.
  static const waterShadow = Color.fromRGBO(2, 132, 199, 0.04);
}
