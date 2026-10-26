import 'package:flutter/material.dart';

import 'glass_theme.dart';
import 'surface_tokens.dart';

/// Local colour treatment for thought spaces, including nested surface tokens.
/// Keeping both token sets aligned prevents day surfaces reverting to white.
class ThoughtTheme {
  // Luminous backgrounds blended with white:
  // "clay dont paint its shade and ink like background use shade with white not whole screen of same colour"
  static const clayCanvas = Color(0xFFF8F8FA);
  static const claySurface = Color(0xFFFFFFFF);

  // "same with frozen sky dont blue it whole yr shade and white blue effect in background with bubble transparent keep bordr hard man"
  static const frozenCanvas = Color(0xFFF3F7FB);
  static const frozenSurface = Color(0xFFF8FAFD);

  static ThemeData from(ThemeData parent) {
    final glass = parent.extension<AscentGlass>();
    if (glass == null || glass.merlot || parent.brightness == Brightness.dark) {
      return parent;
    }
    final canvas = glass.frozen ? frozenCanvas : clayCanvas;
    final surface = glass.frozen ? frozenSurface : claySurface;
    final ink = glass.frozen ? glass.ink : const Color(0xFF2E1C14);
    final muted = glass.frozen
        ? const Color(0xFF3B556E)
        : const Color(0xFF6B554B);
    final surfaces = parent.extension<AppSurfaces>() ?? AppSurfaces.day;
    return parent.copyWith(
      scaffoldBackgroundColor: canvas,
      extensions: [
        ...parent.extensions.values.where(
          (extension) => extension is! AscentGlass && extension is! AppSurfaces,
        ),
        glass.copyWith(
          bg: canvas,
          fill: surface,
          ink: ink,
          inkMuted: muted,
        ),
        surfaces.copyWith(
          cardFill: surface,
          tintFill: surface,
          cardBorderColor: glass.frozen
              ? const Color(0xFFA5C8ED)
              : const Color(0xFFD9C5BB),
          pillBorderColor: glass.frozen
              ? const Color(0xFFBFDBFE)
              : const Color(0xFFD9C5BB),
          ink: ink,
          mutedText: muted,
        ),
      ],
    );
  }
}
