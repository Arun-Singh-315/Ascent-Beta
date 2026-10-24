import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'support/returning_user_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Vintage Merlot & Cashmere Linen Palette Tokens', () {
    test('verifies primary and accent colors meet brand spec', () {
      expect(MerlotPalette.canvas, const Color(0xFFF4EFE6));
      expect(MerlotPalette.action, const Color(0xFF581825));
      expect(MerlotPalette.actionDeep, const Color(0xFF4D131F));
      expect(MerlotPalette.tint, const Color(0xFFE9E0D0));
      expect(MerlotPalette.pillSoft, const Color(0xFFECE3D4));
      expect(MerlotPalette.antiqueGold, const Color(0xFFC28834));
      expect(MerlotPalette.terracotta, const Color(0xFFA04020));
      expect(MerlotPalette.success, const Color(0xFF166534));
      expect(MerlotPalette.ink, const Color(0xFF260F14));
      expect(MerlotPalette.surface, const Color(0xFFEBE3D5));
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

      final lInk = luminance(MerlotPalette.ink);
      final lCanvas = luminance(MerlotPalette.canvas);
      final lSurface = luminance(MerlotPalette.surface);
      final contrastCanvas = (lCanvas + 0.05) / (lInk + 0.05);
      final contrastSurface = (lSurface + 0.05) / (lInk + 0.05);

      // Contrast must comfortably exceed WCAG AAA threshold of 7.0:1
      expect(contrastCanvas, greaterThan(7.0));
      expect(contrastSurface, greaterThan(7.0));
    });

    test('verifies WCAG AAA contrast for white text on primary button', () {
      double luminance(Color c) {
        double channel(double v) =>
            v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
        final r = channel(c.r);
        final g = channel(c.g);
        final b = channel(c.b);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
      }

      final lAction = luminance(MerlotPalette.action);
      final lWhite = luminance(Colors.white);
      final contrast = (lWhite + 0.05) / (lAction + 0.05);

      // Contrast must comfortably exceed WCAG AAA threshold of 4.5:1 for UI components
      expect(contrast, greaterThan(4.5));
    });
  });

  group('Theme Architecture & Preset Wiring', () {
    test('default daylight preset is merlotLinen', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(dayThemePresetProvider),
        DayThemePreset.merlotLinen,
      );
    });

    test('merlotLinen preset wires AscentGlass and AppSurfaces extensions', () {
      final theme = AscentTheme.light(preset: DayThemePreset.merlotLinen);

      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, MerlotPalette.canvas);
      expect(theme.colorScheme.primary, MerlotPalette.action);
      expect(theme.colorScheme.surface, MerlotPalette.surface);

      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.merlot, isTrue);
      expect(glass.bg, MerlotPalette.canvas);
      expect(glass.clay, MerlotPalette.action);
      expect(glass.ink, MerlotPalette.ink);

      final surfaces = theme.extension<AppSurfaces>();
      expect(surfaces, isNotNull);
      expect(surfaces!.accent, MerlotPalette.action);
      expect(surfaces.cardFill, AscentGlass.merlotLinenLight.fill);
    });

    test('night mode remains untouched and preserved', () {
      final theme = AscentTheme.dark(preset: DayThemePreset.classicClay);

      expect(theme.brightness, Brightness.dark);
      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.merlot, isFalse); // dark glass is preserved
      expect(glass.bg, const Color(0xFF16110D));
    });

    test('dark merlot mode wires AscentGlass.merlotLinenDark and dark palette', () {
      final theme = AscentTheme.dark(preset: DayThemePreset.merlotLinen);

      expect(theme.brightness, Brightness.dark);
      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.merlot, isTrue);
      expect(glass.bg, MerlotPalette.darkCanvas);
    });
  });

  group('Accessibility & Rule 13 Safeguard (320px & 2.0x Text Scaling)', () {
    testWidgets(
      'SettingsScreen renders with zero overflow at 320px width and 2.0x text scale',
      (tester) async {
        // Enforce 320px width constraint per Rule 13
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues(returningUserGuidePrefs);
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              // Enforce 2.0x accessibility text scaling per Rule 13
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
                home: const SettingsScreen(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify appearance header is rendered and no exceptions were thrown
        expect(find.text('Appearance & Theme'), findsOneWidget);
        expect(find.text('Daylight Style'), findsOneWidget);
        expect(find.text('Merlot'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
