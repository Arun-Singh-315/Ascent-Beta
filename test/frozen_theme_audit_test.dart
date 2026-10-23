import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/text_styles.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Frozen Sky (Nordic Sky) Palette & Token Audit', () {
    test('verifies FrozenPalette tokens meet serene arctic design spec', () {
      expect(FrozenPalette.canvas, const Color(0xFFEEF4F9));
      expect(FrozenPalette.surface, const Color(0xFFF3F7FB));
      expect(FrozenPalette.pillSoft, const Color(0xFFEAF2F8));
      expect(FrozenPalette.elevated, const Color(0xFFE1ECF5));
      expect(FrozenPalette.line, const Color(0xFFBACFE2));
      expect(FrozenPalette.lineSubtle, const Color(0xFFD2E3F1));
      expect(FrozenPalette.action, const Color(0xFF1D64B4));
      expect(FrozenPalette.ink, const Color(0xFF1E293B));
      expect(FrozenPalette.secondaryInk, const Color(0xFF475569));
      expect(FrozenPalette.mutedInk, const Color(0xFF58687E));
      expect(FrozenPalette.spark, const Color(0xFFF5A524));
    });

    test('verifies WCAG AAA contrast ratio for primary ink on canvas and surface', () {
      double luminance(Color c) {
        double channel(double v) =>
            v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
        final r = channel(c.r);
        final g = channel(c.g);
        final b = channel(c.b);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
      }

      final lInk = luminance(FrozenPalette.ink);
      final lCanvas = luminance(FrozenPalette.canvas);
      final lSurface = luminance(FrozenPalette.surface);
      final contrastCanvas = (lCanvas + 0.05) / (lInk + 0.05);
      final contrastSurface = (lSurface + 0.05) / (lInk + 0.05);

      // Contrast must comfortably exceed WCAG AAA threshold of 7.0:1
      expect(contrastCanvas, greaterThan(7.0));
      expect(contrastSurface, greaterThan(7.0));
    });

    test('verifies AppSurfaces.nordicSky has non-transparent cardFill and 1.0 hairline border', () {
      final surfaces = AppSurfaces.nordicSky;
      expect(surfaces.cardFill, equals(const Color.fromRGBO(243, 247, 251, 0.78)));
      expect(surfaces.cardBorderColor, equals(FrozenPalette.line));
      expect(surfaces.pillBorderColor, equals(FrozenPalette.lineSubtle));
      expect(surfaces.tintFill, equals(FrozenPalette.pillSoft));
      expect(surfaces.cardBorderWidth, equals(1.0));
      expect(surfaces.pillBorderWidth, equals(0.75));
    });

    test('verifies AscentGlass.nordicSky glass fills and navigation use porcelain tokens', () {
      final glass = AscentGlass.nordicSky;
      expect(glass.frozen, isTrue);
      expect(glass.bg, equals(FrozenPalette.canvas));
      expect(glass.fill, equals(const Color.fromRGBO(243, 247, 251, 0.78)));
      expect(glass.nav, equals(const Color.fromRGBO(243, 247, 251, 0.90)));
      expect(glass.edge, equals(FrozenPalette.line));
      expect(glass.line, equals(FrozenPalette.lineSubtle));
      expect(glass.track, equals(FrozenPalette.pillSoft));
    });

    test('verifies theme independence: Merlot and Frozen Sky packages do not cross-contaminate', () {
      // Ensure Merlot remains on Cashmere Linen & Porcelain
      expect(MerlotPalette.canvas, const Color(0xFFF8F5EE));
      expect(MerlotPalette.surface, const Color(0xFFF8F4EC));
      expect(MerlotPalette.pillSoft, const Color(0xFFF7F3EB));
      expect(MerlotPalette.action, const Color(0xFF581825));

      // Ensure Frozen Sky remains on Fjord Ice & Frosted Porcelain
      expect(FrozenPalette.canvas, const Color(0xFFEEF4F9));
      expect(FrozenPalette.surface, const Color(0xFFF3F7FB));
      expect(FrozenPalette.pillSoft, const Color(0xFFEAF2F8));
      expect(FrozenPalette.action, const Color(0xFF1D64B4));

      // Assert they are completely independent palettes
      expect(FrozenPalette.surface, isNot(equals(MerlotPalette.surface)));
      expect(FrozenPalette.canvas, isNot(equals(MerlotPalette.canvas)));
      expect(FrozenPalette.action, isNot(equals(MerlotPalette.action)));
    });

    test('verifies non-heading typography metrics have optimal readability and tracking', () {
      final bodyLarge = AscentTextStyles.bodyLarge;
      expect(bodyLarge.height, equals(1.45));
      expect(bodyLarge.letterSpacing, equals(-0.15));

      final bodyMedium = AscentTextStyles.bodyMedium;
      expect(bodyMedium.height, equals(1.45));
      expect(bodyMedium.letterSpacing, equals(-0.12));

      final thoughtStyle = AppTypography.plusJakartaSans14W60071();
      expect(thoughtStyle.fontWeight, equals(FontWeight.w500));
      expect(thoughtStyle.height, equals(1.45));
      expect(thoughtStyle.letterSpacing, equals(-0.12));

      final previewThoughtStyle = AppTypography.plusJakartaSans14W600116();
      expect(previewThoughtStyle.fontWeight, equals(FontWeight.w500));
      expect(previewThoughtStyle.height, equals(1.45));
      expect(previewThoughtStyle.letterSpacing, equals(-0.12));
    });

    test('verifies hairline subtle border tokens for Nordic Sky bottom navigation and cards', () {
      expect(FrozenPalette.lineSubtle, const Color(0xFFD2E3F1));
      expect(FrozenPalette.darkLineSubtle, const Color(0xFF1E314D));
      expect(AppSurfaces.nordicSky.dividerColor, equals(FrozenPalette.lineSubtle));
      expect(AppSurfaces.nordicSky.cardBorderWidth, equals(1.0));
    });
  });
}

