import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';

/// Home-only day treatment; other routes keep their existing presentation.
class HomeTheme {
  static ThemeData from(ThemeData parent) {
    if (parent.brightness == Brightness.dark) return parent;
    final parentGlass = parent.extension<AscentGlass>() ?? AscentGlass.light;
    final isNordic = parentGlass.frozen;
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
