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
}
