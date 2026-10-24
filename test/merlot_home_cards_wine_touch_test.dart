import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Merlot Home Cards Wine Touch & Distinction Tests', () {
    test('1. Merlot card surface and gradient colors have distinct wine red tones', () {
      // Surface must be warm wine-rose porcelain (Red channel significantly dominates Green/Blue)
      expect(MerlotPalette.surface.r, greaterThan(MerlotPalette.surface.g));
      expect(MerlotPalette.surface.r, greaterThan(MerlotPalette.surface.b));

      // Surface bottom must be deeper wine rose stop
      expect(MerlotPalette.surfaceBottom.r, greaterThan(MerlotPalette.surfaceBottom.g));
      expect(MerlotPalette.surfaceBottom.r, greaterThan(MerlotPalette.surfaceBottom.b));

      // Line border must be deep vintage wine red
      expect(MerlotPalette.line.r, greaterThan(MerlotPalette.line.g));
      expect(MerlotPalette.line.r, greaterThan(MerlotPalette.line.b));
      expect(MerlotPalette.line.a, greaterThan(0.20)); // Stronger definition than faint 0.10
    });

    testWidgets('2. GlassSurface automatically applies wine micro-gradient and MerlotPalette.line border', (tester) async {
      final theme = AscentTheme.light(preset: DayThemePreset.merlotLinen);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: GlassSurface(
              child: Text('Test Wine Touch Card'),
            ),
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
      expect(gradient.colors.first, equals(MerlotPalette.surface));
      expect(gradient.colors.last, equals(MerlotPalette.surfaceBottom));

      final border = decoration.border as Border;
      expect(border.top.color, equals(MerlotPalette.line));
      expect(tester.takeException(), isNull);
    });

    test('3. Text contrast against wine-rose porcelain surface passes WCAG AAA', () {
      double luminance(Color c) {
        double channel(double v) =>
            v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
        final r = channel(c.r);
        final g = channel(c.g);
        final b = channel(c.b);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
      }

      final lInk = luminance(MerlotPalette.ink);
      final lSecInk = luminance(MerlotPalette.secondaryInk);
      final lSurface = luminance(MerlotPalette.surface);

      final contrastInk = (lSurface + 0.05) / (lInk + 0.05);
      final contrastSecInk = (lSurface + 0.05) / (lSecInk + 0.05);

      // Must exceed 15:1 for primary ink and 9:1 for secondary ink
      expect(contrastInk, greaterThan(15.0));
      expect(contrastSecInk, greaterThan(9.0));
    });
  });
}
