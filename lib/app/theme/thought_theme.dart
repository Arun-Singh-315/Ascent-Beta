import 'package:flutter/material.dart';

import 'glass_theme.dart';
import 'surface_tokens.dart';

/// Local colour treatment for thought spaces, including nested surface tokens.
/// Keeping both token sets aligned prevents day surfaces reverting to white.
class ThoughtTheme {
  static const clayCanvas = Color(0xFFF3E2D9);
  static const claySurface = Color(0xFFEFD9CD);
  static const frozenCanvas = Color(0xFFDCEBF8);
  static const frozenSurface = Color(0xFFCFE2F3);

  static ThemeData from(ThemeData parent) {
    final glass = parent.extension<AscentGlass>();
    if (glass == null || glass.merlot || parent.brightness == Brightness.dark) {
      return parent;
    }
    final canvas = glass.frozen ? frozenCanvas : clayCanvas;
    final surface = glass.frozen ? frozenSurface : claySurface;
    final ink = glass.frozen ? glass.ink : const Color(0xFF392A24);
    final muted = glass.frozen
        ? const Color(0xFF48596F)
        : const Color(0xFF685247);
    final surfaces = parent.extension<AppSurfaces>() ?? AppSurfaces.day;
    return parent.copyWith(
      scaffoldBackgroundColor: canvas,
      extensions: [
        ...parent.extensions.values.where(
          (extension) => extension is! AscentGlass && extension is! AppSurfaces,
        ),
        glass.copyWith(bg: canvas, fill: surface, ink: ink, inkMuted: muted),
        surfaces.copyWith(
          cardFill: surface,
          tintFill: surface,
          ink: ink,
          mutedText: muted,
        ),
      ],
    );
  }
}
