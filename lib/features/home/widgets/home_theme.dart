import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';

/// Home-only day treatment; other routes keep their existing presentation.
class HomeTheme {
  static ThemeData from(ThemeData parent) {
    final isDark = parent.brightness == Brightness.dark;
    final parentGlass = parent.extension<AscentGlass>() ??
        (isDark ? AscentGlass.dark : AscentGlass.light);
    final isNordic = parentGlass.frozen;

    if (isDark) {
      final glass = isNordic
          ? (AscentGlass.nordicSkyDark.copyWith(
              fill: const Color(0x1F223548),
              edge: const Color(0x385EA0F0),
              line: const Color(0x245EA0F0),
            ) as AscentGlass)
          : (AscentGlass.dark.copyWith(
              bg: const Color(0xFF12100E),
              fill: const Color(0x14FFFFFF),
              edge: const Color(0x2BFFFFFF),
              line: const Color(0x1AFFFFFF),
              glow1: const Color(0x38D6785C),
              glow2: const Color(0x2EC1A17C),
              ink: const Color(0xFFECEAF2),
              inkSecondary: const Color(0xFFB4B7C6),
              inkMuted: const Color(0xFF9094A4),
            ) as AscentGlass);

      return parent.copyWith(
        scaffoldBackgroundColor: glass.bg,
        extensions: [
          ...parent.extensions.values.where(
            (extension) =>
                extension is! AscentGlass && extension is! AppSurfaces,
          ),
          glass,
          (isNordic ? AppSurfaces.legacyNordicSky : AppSurfaces.night).copyWith(
            blur: 0,
            cardFill: glass.fill,
            cardBorderColor: glass.edge,
            pillBorderColor: glass.edge,
            dividerColor: glass.line,
            shadow: Colors.black.withValues(alpha: 0.35),
          ),
        ],
      );
    }

    final glass = isNordic
        ? AscentGlass.nordicSky
        : (AscentGlass.light.copyWith(
                bg: const Color(0xFFF4F3F8),
                fill: const Color(0x1AFFFFFF),
                ink: const Color(0xFF242323),
                inkSecondary: const Color(0xFF62616B),
                inkMuted: const Color(0xFF73727B),
                edge: const Color(0x242B221B),
                line: const Color(0x182B221B),
                nav: const Color(0xE6F7F6F3),
                shadow: Colors.transparent,
                glow1: const Color(0x1FE29878),
                glow2: const Color(0x19C1A17C),
              )
              as AscentGlass);

    return parent.copyWith(
      scaffoldBackgroundColor: glass.bg,
      extensions: [
        ...parent.extensions.values.where(
          (extension) => extension is! AscentGlass && extension is! AppSurfaces,
        ),
        glass,
        (isNordic ? AppSurfaces.legacyNordicSky : AppSurfaces.legacyLight)
            .copyWith(blur: 0, shadow: Colors.transparent),
      ],
    );
  }
}
