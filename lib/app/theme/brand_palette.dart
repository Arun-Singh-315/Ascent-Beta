import 'package:flutter/material.dart';

import 'calm_blue_palette.dart';
import 'shared_control_tokens.dart';

/// Brand colours used outside the role tokens: the assistant gradient
/// (CLAUDE.md §3.1) and pillar tints.
abstract final class BrandPalette {
  static const assistantIndigo = Color(0xFF5E5CE6);
  static const assistantViolet = Color(0xFFBF5AF2);
  static const assistantPink = Color(0xFFFF6482);

  /// Pillar tints (CLAUDE.md §3.1) for small icon marks: Plan blue, Think
  /// purple, Live pink, water cyan, money green, Grow orange, assistant
  /// indigo. Never full-screen fills.
  static Color pillarTint(String id, {required bool dark}) {
    final c = switch (id) {
      'today' ||
      'things' ||
      'reminders' ||
      'plans' ||
      'travel' => dark ? CalmBluePalette.darkAction : CalmBluePalette.action,
      'thought-wall' ||
      'mind' => dark ? const Color(0xFF6CCBC3) : const Color(0xFF2F8F8A),
      'hydration' ||
      'health' => dark ? PillarTints.waterDark : PillarTints.water,
      'medicine' ||
      'walk' ||
      'chai-break' => dark ? const Color(0xFFFF375F) : const Color(0xFFFF2D55),
      'money' => dark ? PillarTints.moneyDark : PillarTints.money,
      'promises' ||
      'promise' => dark ? PillarTints.promiseDark : PillarTints.promise,
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
