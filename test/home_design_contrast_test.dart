import 'package:ascent/app/theme/home_design.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/monochrome_surfaces.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

double contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  return (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test(
    'Shared controls retain Home materials throughout a theme transition',
    () {
      final day = HomeTheme.from(ThemeData.light());
      final night = HomeTheme.from(ThemeData.dark());
      for (final progress in [0.0, .25, .5, .75, 1.0]) {
        final theme = ThemeData.lerp(day, night, progress);
        final design = theme.extension<HomeDesign>()!;
        expect(theme.extension<MonochromeSurfaces>()!.surface, design.surface);
        expect(theme.extension<AscentGlass>()!.elevated, design.elevated);
        expect(theme.extension<AscentGlass>()!.tonalBg, design.groupedFill);
      }
    },
  );
  for (final design in [const HomeDesign.day(), const HomeDesign.night()]) {
    test(
      'Home reading and accent roles meet AA at darkness ${design.darkness}',
      () {
        for (final background in [
          design.canvas,
          design.surface,
          design.elevated,
          design.mindTint,
          design.workTint,
          design.wellnessTint,
          design.wellnessEnd,
        ]) {
          expect(
            contrast(design.primaryText, background),
            greaterThanOrEqualTo(4.5),
          );
          expect(
            contrast(design.secondaryText, background),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(
          contrast(design.wellnessInk, design.wellnessTint),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(design.learningInk, design.learningTint),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrast(design.action, design.surface),
          greaterThanOrEqualTo(4.5),
        );
      },
    );
  }
}
