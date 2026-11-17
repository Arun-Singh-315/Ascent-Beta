import 'package:flutter/material.dart';

/// Centralized semantic radius tokens across Ascent.
class AppRadius {
  static const sm = 6.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const header = 28.0;
  static const chip = 999.0;
  static const iconChip = 10.0;

  /// Unified radius for thought bubbles across Home and Thought Wall.
  static const bubble = 16.0;
}

/// Centralized spacing tokens across Ascent.
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

/// Centralized elevation and shadow tokens.
class AppElevation {
  static const List<BoxShadow> none = [];

  static List<BoxShadow> soft(Color color, {bool dark = false}) => [
        BoxShadow(
          color: (dark ? const Color(0xFF1F1B18) : color).withValues(alpha: dark ? 0.20 : 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> raised(Color color, {bool dark = false}) => [
        BoxShadow(
          color: (dark ? const Color(0xFF1F1B18) : color).withValues(alpha: dark ? 0.30 : 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

/// Centralized border definitions.
class AppBorder {
  static const hairline = 1.0;
  static const focus = 2.0;

  static Border all(Color color, {double width = hairline}) =>
      Border.all(color: color, width: width);

  static Border bottom(Color color, {double width = hairline}) =>
      Border(bottom: BorderSide(color: color, width: width));
}

/// Backward compatibility aliases for existing codebase references.
class Sp {
  static const xs = AppSpacing.xs;
  static const s = AppSpacing.sm;
  static const m = AppSpacing.md;
  static const l = AppSpacing.lg;
  static const xl = AppSpacing.xl;
  static const xxl = AppSpacing.xxl;
}

class Rd {
  static const chip = AppRadius.chip;
  static const field = 14.0;
  static const iconChip = 10.0;
  static const bubble = AppRadius.bubble;
  static const card = AppRadius.xl;
  static const header = AppRadius.header;
  static const nav = 24.0;
}
