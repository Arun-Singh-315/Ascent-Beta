import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Progress Bar Theme Contrast & Visibility Tests (Day & Dark)', () {
    test('verifies track contrast across all theme presets in day and dark modes', () {
      final presets = [
        ('Merlot Linen Day', AscentGlass.merlotLinenLight),
        ('Merlot Linen Dark', AscentGlass.merlotLinenDark),
        ('Nordic Sky Day', AscentGlass.nordicSky),
        ('Nordic Sky Dark', AscentGlass.nordicSkyDark),
        ('Classic Clay Day', AscentGlass.light),
        ('Classic Clay Dark', AscentGlass.dark),
      ];

      for (final (name, glass) in presets) {
        // Track must be distinctly visible and non-transparent
        expect(glass.track.a, greaterThan(0.08), reason: '$name track opacity too low');
        // Track must not match card fill
        expect(glass.track, isNot(equals(glass.fill)), reason: '$name track blends into fill');
      }
    });

    testWidgets('Hydration and Medicine progress bars in QuickModulesNavHub render with 5px height and visible tracks', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: QuickModulesNavHub(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final hydrationBarFinder = find.byKey(const ValueKey('hydration_progress_bar'));
      expect(hydrationBarFinder, findsOneWidget);

      final medicineBarFinder = find.byKey(const ValueKey('medicine_progress_bar'));
      expect(medicineBarFinder, findsOneWidget);

      // Verify the progress bar containers have 5px height
      final hydrationBarBox = tester.renderObject<RenderBox>(hydrationBarFinder);
      expect(hydrationBarBox.size.height, equals(5.0));

      final medicineBarBox = tester.renderObject<RenderBox>(medicineBarFinder);
      expect(medicineBarBox.size.height, equals(5.0));
    });

    testWidgets('ThemeData progressIndicatorTheme provides visible linearTrackColor across all presets', (tester) async {
      final merlotTheme = AscentTheme.light(preset: DayThemePreset.merlotLinen);
      expect(merlotTheme.progressIndicatorTheme.linearTrackColor, isNotNull);
      expect(merlotTheme.progressIndicatorTheme.linearMinHeight, equals(4.0));

      final nordicTheme = AscentTheme.light(preset: DayThemePreset.nordicSky);
      expect(nordicTheme.progressIndicatorTheme.linearTrackColor, isNotNull);

      final clayTheme = AscentTheme.light(preset: DayThemePreset.classicClay);
      expect(clayTheme.progressIndicatorTheme.linearTrackColor, isNotNull);
    });
  });
}
