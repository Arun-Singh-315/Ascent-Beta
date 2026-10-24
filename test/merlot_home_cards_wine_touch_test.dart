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
      // Surface must be light shade of Ask Jarvis float wine (Red channel significantly dominates Green/Blue)
      expect(MerlotPalette.surface.r, greaterThan(MerlotPalette.surface.g));
      expect(MerlotPalette.surface.r, greaterThan(MerlotPalette.surface.b));
      expect(MerlotPalette.surface, const Color(0xFFEED2DA));

      // Surface bottom must be deeper light wine stop
      expect(MerlotPalette.surfaceBottom.r, greaterThan(MerlotPalette.surfaceBottom.g));
      expect(MerlotPalette.surfaceBottom.r, greaterThan(MerlotPalette.surfaceBottom.b));
      expect(MerlotPalette.surfaceBottom, const Color(0xFFE8C4CE));

      // Line border has distinct wine rim definition
      expect(MerlotPalette.line.a, greaterThan(0.20));
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

    test('3. Card interior text contrast against light wine surface passes WCAG AAA', () {
      double luminance(Color c) {
        double channel(double v) =>
            v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
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

      // Must exceed 11:1 for primary card ink and 7:1 for secondary card ink
      expect(contrastInk, greaterThan(11.0));
      expect(contrastSecInk, greaterThan(7.0));
    });
  });
}
