import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/merlot_palette.dart';

/// Home-only day treatment; other routes keep their existing presentation.
class HomeTheme {
  static ThemeData from(ThemeData parent) {
    final isDark = parent.brightness == Brightness.dark;
    final parentGlass = parent.extension<AscentGlass>() ??
        (isDark ? AscentGlass.dark : AscentGlass.light);
    final isNordic = parentGlass.frozen;
    final isMerlot = parentGlass.merlot;

    if (isDark) {
      final glass = isMerlot
          ? (AscentGlass.merlotLinenDark.copyWith(
              bg: MerlotPalette.darkCanvas,
              fill: const Color.fromRGBO(255, 255, 255, 0.07),
              edge: MerlotPalette.darkLine,
              line: MerlotPalette.darkLineSubtle,
              ink: MerlotPalette.darkInk,
              inkSecondary: MerlotPalette.darkSecondaryInk,
              inkMuted: MerlotPalette.darkMutedInk,
            ) as AscentGlass)
          : isNordic
          ? (AscentGlass.nordicSkyDark.copyWith(
              fill: const Color.fromRGBO(34, 53, 72, 0.12),
              edge: const Color.fromRGBO(94, 160, 240, 0.22),
              line: const Color.fromRGBO(94, 160, 240, 0.14),
            ) as AscentGlass)
          : (AscentGlass.dark.copyWith(
              bg: AscentColors.bgBaseDark,
              fill: const Color.fromRGBO(255, 255, 255, 0.08),
              edge: const Color.fromRGBO(255, 255, 255, 0.17),
              line: const Color.fromRGBO(255, 255, 255, 0.10),
              glow1: AscentGlass.dark.glow1,
              glow2: AscentGlass.dark.glow2,
              ink: AscentColors.textPrimaryDark,
              inkSecondary: AscentColors.textSecondaryDark,
              inkMuted: AscentColors.textMutedDark,
            ) as AscentGlass);

      return parent.copyWith(
        scaffoldBackgroundColor: glass.bg,
        extensions: [
          ...parent.extensions.values.where(
            (extension) =>
                extension is! AscentGlass && extension is! AppSurfaces,
          ),
          glass,
          (isMerlot
                  ? AppSurfaces.legacyMerlotLinenDark
                  : isNordic
                  ? AppSurfaces.legacyNordicSky
                  : AppSurfaces.night)
              .copyWith(
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

    final glass = isMerlot
        ? (AscentGlass.merlotLinenLight.copyWith(
            bg: MerlotPalette.canvas,
            fill: MerlotPalette.surface,
            ink: MerlotPalette.ink,
            inkSecondary: MerlotPalette.secondaryInk,
            inkMuted: MerlotPalette.mutedInk,
            edge: MerlotPalette.line,
            line: MerlotPalette.lineSubtle,
            nav: const Color.fromRGBO(250, 247, 242, 0.96),
            shadow: MerlotPalette.shadowAmbient,
            glow1: const Color(0x29C28834),
            glow2: const Color(0x1F581825),
          ) as AscentGlass)
        : isNordic
        ? AscentGlass.nordicSky
        : (AscentGlass.light.copyWith(
                bg: AscentColors.bgBase,
                fill: Colors.white,
                ink: AscentColors.textPrimary,
                inkSecondary: AscentColors.textSecondary,
                inkMuted: AscentColors.textMuted,
                edge: AscentGlass.light.edge,
                line: AscentGlass.light.line,
                nav: AscentGlass.light.nav,
                shadow: const Color.fromRGBO(15, 23, 42, 0.08),
                glow1: AscentGlass.light.glow1,
                glow2: AscentGlass.light.glow2,
              )
              as AscentGlass);

    return parent.copyWith(
      scaffoldBackgroundColor: glass.bg,
      extensions: [
        ...parent.extensions.values.where(
          (extension) => extension is! AscentGlass && extension is! AppSurfaces,
        ),
        glass,
        (isMerlot
                ? AppSurfaces.merlotLinen
                : (isNordic
                    ? AppSurfaces.legacyNordicSky
                    : AppSurfaces.legacyLight))
            .copyWith(
              blur: 0,
              cardFill: isMerlot ? MerlotPalette.surface : Colors.white,
              cardBorderColor: glass.edge,
              shadow: isMerlot
                  ? MerlotPalette.shadowAmbient
                  : const Color.fromRGBO(15, 23, 42, 0.08),
            ),
      ],
    );
  }
}
