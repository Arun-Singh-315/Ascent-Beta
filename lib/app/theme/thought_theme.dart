import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
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
  // Toned down soothing parchment & linen backgrounds:
  static const clayCanvas = Color(0xFFEFECE6);
  static const claySurface = Color(0xFFF7F5F0);

  // Soft misty sky:
  static const frozenCanvas = Color(0xFFE8EEF5);
  static const frozenSurface = Color(0xFFF2F6FA);

  // Matte Charcoal + Premium Glass foundation in dark mode:
  static const darkCanvas = Color(0xFF0F1115);
  static const darkSurface = Color(0xFF16181F);
  static const darkCardBorder = Color(0xFF262933);
  static const darkInk = Color(0xFFF8FAFC);
  static const darkMuted = Color(0xFF94A3B8);

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
                extension is! AscentGlass &&
                extension is! AppSurfaces &&
                extension is! AppColors,
          ),
          AppColors.dark,
          glass.copyWith(
            bg: darkCanvas,
            fill: darkSurface,
            ink: darkInk,
            inkMuted: darkMuted,
            edge: darkCardBorder,
            line: darkCardBorder,
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
