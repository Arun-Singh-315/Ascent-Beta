import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/aurora_palette.dart';

/// Home-only day treatment; other routes keep their existing presentation.
class HomeTheme {
  static ThemeData from(ThemeData parent) {
    final isDark = parent.brightness == Brightness.dark;
    final parentGlass = parent.extension<AscentGlass>() ??
        (isDark ? AscentGlass.dark : AscentGlass.light);
    final isNordic = parentGlass.frozen;
    final isAurora = parentGlass.aurora;

    if (isDark) {
      final glass = isAurora
          ? (AscentGlass.auroraCalmDark.copyWith(
              bg: AuroraPalette.darkCanvas,
              fill: const Color.fromRGBO(19, 27, 46, 0.70),
              edge: const Color.fromRGBO(39, 53, 78, 0.85),
              line: const Color.fromRGBO(39, 53, 78, 0.50),
              glow1: AuroraPalette.darkAction.withValues(alpha: 0.18),
              glow2: AuroraPalette.darkActionCyan.withValues(alpha: 0.14),
              ink: AuroraPalette.darkInk,
              inkSecondary: AuroraPalette.darkSecondaryInk,
              inkMuted: AuroraPalette.darkMutedInk,
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
          (isAurora
                  ? AppSurfaces.legacyAuroraCalm
                  : (isNordic
                      ? AppSurfaces.legacyNordicSky
                      : AppSurfaces.night))
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

    final glass = isAurora
        ? (AscentGlass.auroraCalmLight.copyWith(
            bg: AuroraPalette.canvas,
            fill: Colors.white,
            ink: AuroraPalette.ink,
            inkSecondary: AuroraPalette.secondaryInk,
            inkMuted: AuroraPalette.mutedInk,
            edge: AuroraPalette.line,
            line: AuroraPalette.line.withValues(alpha: 0.70),
            nav: const Color.fromRGBO(252, 253, 255, 0.96),
            shadow: const Color.fromRGBO(79, 70, 229, 0.05),
            glow1: const Color.fromRGBO(99, 102, 241, 0.14),
            glow2: const Color.fromRGBO(6, 182, 212, 0.10),
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
        (isAurora
                ? AppSurfaces.auroraCalm
                : (isNordic
                    ? AppSurfaces.legacyNordicSky
                    : AppSurfaces.legacyLight))
            .copyWith(
              blur: 0,
              cardFill: Colors.white,
              cardBorderColor: glass.edge,
              shadow: isAurora
                  ? const Color.fromRGBO(79, 70, 229, 0.05)
                  : const Color.fromRGBO(15, 23, 42, 0.08),
            ),
      ],
    );
  }
}
