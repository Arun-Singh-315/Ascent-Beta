import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/day_glass_material.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Merlot Home Cards Wine Touch & Distinction Tests', () {
    test(
      '1. Merlot card surface and gradient colors provide a luxurious off-white gradual effect',
      () {
        expect(MerlotPalette.surface, const Color(0xFFFFFFFF));
        expect(MerlotPalette.surfaceBottom, const Color(0xFFFAF5EE));

        // Surface bottom must be warmer than top (gradual warmth)
        expect(
          MerlotPalette.surfaceBottom.r,
          greaterThan(MerlotPalette.surfaceBottom.b),
        );

        // Line border has wine rim definition
        expect(MerlotPalette.line, const Color(0x2E581825));
      },
    );

    testWidgets(
      '2. GlassSurface applies shared translucent daylight gradient and reflective rim',
      (tester) async {
        final theme = AscentTheme.light(preset: DayThemePreset.merlotLinen);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: const Scaffold(
              body: GlassSurface(child: Text('Test Wine Touch Card')),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final containerFinder = find.byType(Container).first;
        expect(containerFinder, findsOneWidget);
        final container = tester.widget<Container>(containerFinder);
        final decoration = container.decoration as BoxDecoration;

        expect(decoration.gradient, isNotNull);
        final gradient = decoration.gradient as LinearGradient;
        final material = theme.extension<DayGlassMaterial>()!;
        expect(
          gradient.colors.first,
          MerlotPalette.surface.withValues(alpha: material.topOpacity),
        );
        expect(
          gradient.colors.last,
          MerlotPalette.surface.withValues(alpha: material.bottomOpacity),
        );

        final border = decoration.border as Border;
        expect(border, material.rim);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      '3. Card interior text contrast against off-white surface passes WCAG AAA',
      () {
        double luminance(Color c) {
          double channel(double v) => v <= 0.03928
              ? v / 12.92
              : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
          final r = channel(c.r);
          final g = channel(c.g);
          final b = channel(c.b);
          return 0.2126 * r + 0.7152 * g + 0.0722 * b;
        }

        final lCardInk = luminance(MerlotPalette.cardInk);
        final lCardSecInk = luminance(MerlotPalette.cardSecondaryInk);
        final lSurface = luminance(MerlotPalette.surface);

        final contrastInk = (lSurface + 0.05) / (lCardInk + 0.05);
        final contrastSecInk = (lSurface + 0.05) / (lCardSecInk + 0.05);

        // Must exceed 15:1 for primary card ink and 10:1 for secondary card ink
        expect(contrastInk, greaterThan(15.0));
        expect(contrastSecInk, greaterThan(10.0));
      },
    );
  });
}
