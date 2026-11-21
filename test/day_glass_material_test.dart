import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/day_glass_material.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  test('Calm Blue light cards are solid with readable ink', () {
    final theme = AscentTheme.light();
    final material = theme.extension<DayGlassMaterial>()!;
    final glass = theme.extension<AscentGlass>()!;
    expect(theme.scaffoldBackgroundColor, material.canvas);
    expect(material.topOpacity, 1);
    expect(material.bottomOpacity, 1);
    expect(material.blur, 0);
    expect(theme.extension<AppSurfaces>()!.cardFill.a, 1);
    expect(HomeTheme.from(theme), same(theme));
    expect(AscentTheme.assistant(theme), same(theme));
    for (final ink in [glass.ink, glass.inkSecondary, glass.inkMuted]) {
      final contrast =
          (glass.fill.computeLuminance() + .05) / (ink.computeLuminance() + .05);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: '$ink');
    }
    expect(AscentTheme.dark().extension<DayGlassMaterial>(), isNull);
  });
}
