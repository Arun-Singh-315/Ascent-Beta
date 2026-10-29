import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/color_tokens.dart';
import 'package:ascent/app/theme/day_glass_material.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_models.dart';
import 'package:ascent/features/home/widgets/study_streak_meter_card.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:ascent/shared/widgets/ascent_card.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  for (final palette in DayThemePreset.values) {
    for (final preset in GlassTranslucencyPreset.values) {
      test(
        '$palette / $preset has readable ink over effective frosted backgrounds',
        () {
          final theme = AscentTheme.light(
            preset: palette,
            translucency: preset,
          );
          final material = theme.extension<DayGlassMaterial>()!;
          final glass = theme.extension<AscentGlass>()!;
          expect(theme.scaffoldBackgroundColor, material.canvas);
          expect(
            theme.scaffoldBackgroundColor.computeLuminance(),
            lessThan(.85),
          );
          expect(theme.extension<AppSurfaces>()!.blur, material.blur);
          expect(HomeTheme.from(theme), same(theme));
          expect(AscentTheme.assistant(theme), same(theme));
          final underlying = Color.alphaBlend(glass.glow2, material.canvas);
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
              reason: '$palette / $preset contrast for $ink',
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

  testWidgets(
    'shared card families blur in daylight and feedback can retain a denser backing',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  GlassSurface(child: Text('Shared glass')),
                  AppCard(child: Text('Grouped card')),
                  AscentCard(child: Text('Feature card')),
                  StudyStreakMeterCard(
                    status: StudyStreakStatus(todaySeconds: 0),
                  ),
                  GlassSurface(
                    minimumOpacity: .94,
                    child: Text('Readable feedback'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNWidgets(5));
      final context = tester.element(find.text('Shared glass'));
      expect(
        context.bgBase,
        Theme.of(context).extension<DayGlassMaterial>()!.canvas,
      );
      final feedback = find
          .ancestor(
            of: find.text('Readable feedback'),
            matching: find.byType(Container),
          )
          .first;
      final decoration =
          tester.widget<Container>(feedback).decoration! as BoxDecoration;
      expect(
        (decoration.gradient! as LinearGradient).colors.every(
          (c) => c.a >= .94 - .004,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
