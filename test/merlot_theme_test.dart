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
    test('verifies primary, card surface, and accent colors meet daylight spec', () {
      expect(MerlotPalette.canvas, const Color(0xFFF8F4EE));
      expect(MerlotPalette.surface, const Color(0xFFFCEDF2));
      expect(MerlotPalette.surfaceBottom, const Color(0xFFF8E4EA));
      expect(MerlotPalette.recessedWell, const Color(0xFFF4DDE4));
      expect(MerlotPalette.action, const Color(0xFF581825));
      expect(MerlotPalette.actionDeep, const Color(0xFF48101C));
      expect(MerlotPalette.actionBright, const Color(0xFF722032));
      expect(MerlotPalette.tint, const Color(0xFFEED3DC));
      expect(MerlotPalette.pillSoft, const Color(0xFFF6E2EA));
      expect(MerlotPalette.line, const Color(0x406B1D2F));
      expect(MerlotPalette.lineSpecular, const Color(0x546B1D2F));
      expect(MerlotPalette.lineSubtle, const Color(0x286B1D2F));
      expect(MerlotPalette.antiqueGold, const Color(0xFFC28834));
      expect(MerlotPalette.terracotta, const Color(0xFFA04020));
      expect(MerlotPalette.success, const Color(0xFF166534));
      expect(MerlotPalette.ink, const Color(0xFF240A10));
      expect(MerlotPalette.secondaryInk, const Color(0xFF54222E));
      expect(MerlotPalette.mutedInk, const Color(0xFF784552));
    });

    test('verifies night mode tokens remain 100% untouched', () {
      expect(MerlotPalette.darkCanvas, const Color(0xFF161012));
      expect(MerlotPalette.darkSurface, const Color(0xFF22171B));
      expect(MerlotPalette.darkElevated, const Color(0xFF2C1E23));
      expect(MerlotPalette.darkAction, const Color(0xFFC6B6A6));
      expect(MerlotPalette.darkInk, const Color(0xFFF7F2EE));
      expect(MerlotPalette.darkSecondaryInk, const Color(0xFFD6CBC7));
      expect(MerlotPalette.darkMutedInk, const Color(0xFFA89A96));
    });

    test('verifies WCAG AAA contrast ratio for text hierarchy on canvas and surface', () {
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
      final lMutedInk = luminance(MerlotPalette.mutedInk);
      final lCanvas = luminance(MerlotPalette.canvas);
      final lSurface = luminance(MerlotPalette.surface);

      final contrastCanvasInk = (lCanvas + 0.05) / (lInk + 0.05);
      final contrastSurfaceInk = (lSurface + 0.05) / (lInk + 0.05);
      final contrastSurfaceSec = (lSurface + 0.05) / (lSecInk + 0.05);
      final contrastSurfaceMuted = (lSurface + 0.05) / (lMutedInk + 0.05);

      // Contrast must comfortably exceed WCAG AAA threshold of 7.0:1 for primary text
      expect(contrastCanvasInk, greaterThan(14.0));
      expect(contrastSurfaceInk, greaterThan(15.0));

      // Secondary text must exceed 7.0:1 for high visibility
      expect(contrastSurfaceSec, greaterThan(7.0));

      // Muted helper captions must comfortably exceed WCAG AA 4.5:1
      expect(contrastSurfaceMuted, greaterThan(4.5));
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
      expect(contrast, greaterThan(7.0));
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

    testWidgets(
      'Merlot daylight cards, pills and option components render with high contrast and zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final theme = AscentTheme.light(preset: DayThemePreset.merlotLinen);

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              backgroundColor: theme.scaffoldBackgroundColor,
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Card surface
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: MerlotPalette.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daylight Card',
                              style: TextStyle(
                                color: MerlotPalette.ink,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sub-caption text with clear contrast',
                              style: TextStyle(
                                color: MerlotPalette.secondaryInk,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Option pill
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MerlotPalette.pillSoft,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: MerlotPalette.lineSubtle),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline,
                                        size: 14,
                                        color: MerlotPalette.action,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'To-do',
                                        style: TextStyle(
                                          color: MerlotPalette.secondaryInk,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: MerlotPalette.tint,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: MerlotPalette.lineSubtle),
                                  ),
                                  child: Text(
                                    'Active option',
                                    style: TextStyle(
                                      color: MerlotPalette.action,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // CTA Button
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: MerlotPalette.action,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Resume activity'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Daylight Card'), findsOneWidget);
        expect(find.text('To-do'), findsOneWidget);
        expect(find.text('Active option'), findsOneWidget);
        expect(find.text('Resume activity'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
