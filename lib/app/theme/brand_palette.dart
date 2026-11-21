import 'package:flutter/material.dart';

/// Brand colours used outside the role tokens: the assistant gradient
/// (CLAUDE.md §3.1) and the swatches that preview each day theme.
abstract final class BrandPalette {
  static const assistantIndigo = Color(0xFF5E5CE6);
  static const assistantViolet = Color(0xFFBF5AF2);
  static const assistantPink = Color(0xFFFF6482);

  static const merlotSwatch = [Color(0xFF7A2E3B), Color(0xFFF4EDE4)];
  static const claySwatch = [Color(0xFFA4523A), Color(0xFFF7F1EA)];
  static const skySwatch = [Color(0xFF2F6FED), Color(0xFFEFF4FB)];

  /// Pillar tints (CLAUDE.md §3.1) for small icon marks: Plan blue, Think
  /// purple, Live pink, water cyan, money green, Grow orange, assistant
  /// indigo. Never full-screen fills.
  static Color pillarTint(String id, {required bool dark}) {
    final c = switch (id) {
      'today' ||
      'things' ||
      'reminders' ||
      'plans' => dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF),
      'thought-wall' ||
      'mind' ||
      'promises' => dark ? const Color(0xFFBF5AF2) : const Color(0xFFAF52DE),
      'hydration' ||
      'health' => dark ? const Color(0xFF64D2FF) : const Color(0xFF32ADE6),
      'medicine' ||
      'walk' ||
      'chai-break' => dark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55),
      'money' => dark ? const Color(0xFF30D158) : const Color(0xFF34C759),
      'focus' ||
      'learning' ||
      'momentum' ||
      'challenge' => dark ? const Color(0xFFFF9F0A) : const Color(0xFFFF9500),
      'assistant' => dark ? const Color(0xFF7D7AFF) : assistantIndigo,
      _ => dark ? const Color(0xFF98989D) : const Color(0xFF636366),
    };
    return c;
  }
}
