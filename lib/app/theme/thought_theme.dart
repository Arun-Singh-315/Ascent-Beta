import 'package:flutter/material.dart';

import 'glass_theme.dart';
import 'surface_tokens.dart';

/// Visual hierarchy role for thought cards across Ascent.
enum ThoughtCardRole {
  hero,
  standard,
  compact,
}

/// Local colour treatment for thought spaces, including nested surface tokens.
/// Keeping both token sets aligned prevents day surfaces reverting to white.
class ThoughtTheme {
  // Luminous backgrounds blended with white:
  // "clay dont paint its shade and ink like background use shade with white not whole screen of same colour"
  static const clayCanvas = Color(0xFFF5EFE6);
  static const claySurface = Color(0xFFFFFDFB);

  // "same with frozen sky dont blue it whole yr shade and white blue effect in background with bubble transparent keep bordr hard man"
  static const frozenCanvas = Color(0xFFF3F7FB);
  static const frozenSurface = Color(0xFFF8FAFD);

  // Matte Charcoal + Premium Glass foundation in dark mode:
  static const darkCanvas = Color(0xFF111317);
  static const darkSurface = Color(0xFF171A21);
  static const darkCardBorder = Color(0xFF282C37);
  static const darkInk = Color(0xFFF1F3F5);
  static const darkMuted = Color(0xFF8B92A0);

  static ThemeData from(ThemeData parent) {
    final glass = parent.extension<AscentGlass>();
    if (glass == null) return parent;

    final isDark = parent.brightness == Brightness.dark;
    if (isDark) {
      final surfaces = parent.extension<AppSurfaces>() ?? AppSurfaces.night;
      return parent.copyWith(
        scaffoldBackgroundColor: darkCanvas,
        extensions: [
          ...parent.extensions.values.where(
            (extension) =>
                extension is! AscentGlass && extension is! AppSurfaces,
          ),
          glass.copyWith(
            bg: darkCanvas,
            fill: darkSurface,
            ink: darkInk,
            inkMuted: darkMuted,
            edge: darkCardBorder,
            line: const Color(0x1AFFFFFF),
            glow1: Colors.transparent,
            glow2: Colors.transparent,
          ),
          surfaces.copyWith(
            cardFill: darkSurface,
            tintFill: darkSurface,
            cardBorderColor: darkCardBorder,
            pillBorderColor: darkCardBorder,
            ink: darkInk,
            mutedText: darkMuted,
            shadow: Colors.black.withValues(alpha: 0.40),
          ),
        ],
      );
    }

    if (glass.merlot) {
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
