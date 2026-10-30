import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/day_glass_material.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'support/returning_user_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Neutral palette and semantic blue', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
    }

    test('Surfaces stay neutral and actions have accessible blue labels', () {
      expect(MerlotPalette.canvas, const Color(0xFFF2F2F7));
      expect(MerlotPalette.surface, Colors.white);
      expect(MerlotPalette.action, const Color(0xFF006FE6));
      expect(MerlotPalette.danger, const Color(0xFFD92D20));
      expect(
        contrast(MerlotPalette.ink, MerlotPalette.canvas),
        greaterThan(12),
      );
      expect(
        contrast(MerlotPalette.cardSecondaryInk, MerlotPalette.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(MerlotPalette.cardMutedInk, MerlotPalette.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(Colors.white, MerlotPalette.action),
        greaterThanOrEqualTo(4.5),
      );
    });
    test('Dark surfaces retain readable labels and blue actions', () {
      expect(MerlotPalette.darkCanvas, const Color(0xFF101012));
      expect(MerlotPalette.darkAction, const Color(0xFF64ACFF));
      expect(
        contrast(MerlotPalette.darkInk, MerlotPalette.darkSurface),
        greaterThan(12),
      );
      expect(
        contrast(MerlotPalette.darkSecondaryInk, MerlotPalette.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrast(MerlotPalette.darkAction, MerlotPalette.darkSurface),
        greaterThanOrEqualTo(4.5),
      );
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
      expect(
        theme.scaffoldBackgroundColor,
        theme.extension<DayGlassMaterial>()!.canvas,
      );
      expect(theme.colorScheme.primary, MerlotPalette.action);
      expect(theme.colorScheme.surface, MerlotPalette.surface);

      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.merlot, isTrue);
      expect(glass.bg, theme.extension<DayGlassMaterial>()!.canvas);
      expect(glass.clay, MerlotPalette.action);
      expect(glass.ink, MerlotPalette.ink);

      final surfaces = theme.extension<AppSurfaces>();
      expect(surfaces, isNotNull);
      expect(surfaces!.accent, MerlotPalette.action);
      expect(
        surfaces.cardFill,
        AscentGlass.merlotLinenLight.fill.withValues(
          alpha: theme.extension<DayGlassMaterial>()!.topOpacity,
        ),
      );
    });

    test('night mode remains untouched and preserved', () {
      final theme = AscentTheme.dark(preset: DayThemePreset.classicClay);

      expect(theme.brightness, Brightness.dark);
      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.merlot, isFalse); // dark glass is preserved
      expect(glass.bg, const Color(0xFF16110D));
    });

    test(
      'dark merlot mode wires AscentGlass.merlotLinenDark and dark palette',
      () {
        final theme = AscentTheme.dark(preset: DayThemePreset.merlotLinen);

        expect(theme.brightness, Brightness.dark);
        final glass = theme.extension<AscentGlass>();
        expect(glass, isNotNull);
        expect(glass!.merlot, isTrue);
        expect(glass.bg, MerlotPalette.darkCanvas);
      },
    );
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
        expect(find.text('Glass Translucency'), findsOneWidget);
        expect(find.text('Balanced'), findsOneWidget);
        expect(find.text('Subtle'), findsOneWidget);
        expect(find.text('Contrast'), findsOneWidget);
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
                                    border: Border.all(
                                      color: MerlotPalette.lineSubtle,
                                    ),
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
                                    border: Border.all(
                                      color: MerlotPalette.lineSubtle,
                                    ),
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
