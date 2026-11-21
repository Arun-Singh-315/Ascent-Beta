import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/day_glass_material.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/shared/widgets/ascent_atmosphere.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  {
    for (final preset in GlassTranslucencyPreset.values) {
      test(
        'Calm Blue / $preset has readable ink over effective frosted backgrounds',
        () {
          final theme = AscentTheme.light(translucency: preset);
          final material = theme.extension<DayGlassMaterial>()!;
          final glass = theme.extension<AscentGlass>()!;
          expect(theme.scaffoldBackgroundColor, material.canvas);
          expect(
            theme.scaffoldBackgroundColor.computeLuminance(),
            lessThan(.95),
          );
          expect(theme.extension<AppSurfaces>()!.blur, material.blur);
          expect(HomeTheme.from(theme), same(theme));
          expect(AscentTheme.assistant(theme), same(theme));
          final underlying = Color.alphaBlend(
            AscentAtmosphereBackground.softenGlow(glass.glow2, maxAlpha: .025),
            material.canvas,
          );
          final effective = Color.alphaBlend(
            glass.fill.withValues(alpha: material.bottomOpacity),
            underlying,
          );
          for (final ink in [glass.ink, glass.inkSecondary, glass.inkMuted]) {
            final contrast =
                (effective.computeLuminance() + .05) /
                (ink.computeLuminance() + .05);
            expect(
              contrast,
              greaterThanOrEqualTo(4.5),
              reason: '$preset contrast for $ink',
            );
          }
        },
      );
    }
  }

  test(
    'translucency presets change actual opacity and retain the night theme',
    () {
      final subtle = AscentTheme.light(
        translucency: GlassTranslucencyPreset.subtleFrosted,
      ).extension<DayGlassMaterial>()!;
      final balanced = AscentTheme.light().extension<DayGlassMaterial>()!;
      final contrast = AscentTheme.light(
        translucency: GlassTranslucencyPreset.highContrast,
      ).extension<DayGlassMaterial>()!;
      expect(subtle.bottomOpacity, lessThan(balanced.bottomOpacity));
      expect(balanced.bottomOpacity, lessThan(contrast.bottomOpacity));
      expect(contrast.bottomOpacity, greaterThanOrEqualTo(.9));
      expect(AscentTheme.dark().extension<DayGlassMaterial>(), isNull);
    },
  );
}
