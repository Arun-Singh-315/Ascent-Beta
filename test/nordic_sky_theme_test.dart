import 'package:ascent/app/theme/aurora_palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'support/returning_user_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DayThemePreset provider & persistence', () {
    test('defaults to auroraCalm when no value is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(dayThemePresetProvider),
        DayThemePreset.auroraCalm,
      );
    });

    test(
      'persists nordicSky selection to SharedPreferences and updates state',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await container
            .read(dayThemePresetProvider.notifier)
            .setPreset(DayThemePreset.nordicSky);

        expect(
          container.read(dayThemePresetProvider),
          DayThemePreset.nordicSky,
        );
        expect(prefs.getString('ascent_day_theme_preset'), 'nordicSky');
      },
    );

    test('reads stored nordicSky preset on startup', () async {
      SharedPreferences.setMockInitialValues({
        'ascent_day_theme_preset': 'nordicSky',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(dayThemePresetProvider), DayThemePreset.nordicSky);
    });
  });

  group('AscentTheme daylight presets', () {
    test('auroraCalm preset applies Royal Indigo & Aurora Cyan palette', () {
      final theme = AscentTheme.light(preset: DayThemePreset.auroraCalm);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AuroraPalette.action);
      expect(theme.scaffoldBackgroundColor, AuroraPalette.canvas);
      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.clay, AuroraPalette.action);
      expect(glass.slate, AuroraPalette.actionCyan);
      expect(glass.ink, AuroraPalette.ink);
    });

    test('classicClay preset applies signature terracotta & linen palette', () {
      final theme = AscentTheme.light(preset: DayThemePreset.classicClay);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFFA4523A));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8F9FA));
      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.clay, const Color(0xFFA4523A));
    });

    test(
      'nordicSky preset applies frosted canvas, teal actions and charcoal ink',
      () {
        final theme = AscentTheme.light(preset: DayThemePreset.nordicSky);

        expect(theme.brightness, Brightness.light);
        expect(theme.colorScheme.primary, FrozenPalette.action);
        expect(theme.scaffoldBackgroundColor, FrozenPalette.canvas);
        expect(theme.colorScheme.onSurface, FrozenPalette.ink);
        expect(theme.colorScheme.onSurfaceVariant, FrozenPalette.mutedInk);

        final glass = theme.extension<AscentGlass>();
        expect(glass, isNotNull);
        expect(glass!.bg, FrozenPalette.canvas);
        expect(glass.clay, FrozenPalette.accent);
        expect(glass.slate, FrozenPalette.secondary);
        expect(glass.ink, FrozenPalette.ink);
      },
    );

    test(
      'switchTheme in nordicSky has high-contrast selected (teal/white) and unselected states',
      () {
        final theme = AscentTheme.light(preset: DayThemePreset.nordicSky);
        final switchTheme = theme.switchTheme;

        expect(switchTheme.thumbColor, isNotNull);
        expect(switchTheme.trackColor, isNotNull);

        final selectedThumb = switchTheme.thumbColor!.resolve({
          WidgetState.selected,
        });
        final unselectedThumb = switchTheme.thumbColor!.resolve({});
        final selectedTrack = switchTheme.trackColor!.resolve({
          WidgetState.selected,
        });
        final unselectedTrack = switchTheme.trackColor!.resolve({});

        expect(selectedThumb, const Color(0xFFFFFFFF));
        expect(selectedTrack, FrozenPalette.action);
        expect(unselectedThumb, FrozenPalette.secondaryInk);
        expect(unselectedTrack, FrozenPalette.line);
      },
    );

    test(
      'switchTheme in auroraCalm has high-contrast selected (cyan/indigo) states',
      () {
        final theme = AscentTheme.light(preset: DayThemePreset.auroraCalm);
        final switchTheme = theme.switchTheme;

        expect(switchTheme.thumbColor, isNotNull);
        expect(switchTheme.trackColor, isNotNull);

        final selectedThumb = switchTheme.thumbColor!.resolve({
          WidgetState.selected,
        });
        final selectedTrack = switchTheme.trackColor!.resolve({
          WidgetState.selected,
        });

        expect(selectedThumb, Colors.white);
        expect(selectedTrack, AuroraPalette.action);
      },
    );

    test(
      'outlined and text buttons have Clear Sky action interactive blue foreground',
      () {
        final theme = AscentTheme.light(preset: DayThemePreset.nordicSky);
        final outlinedFg = theme.outlinedButtonTheme.style?.foregroundColor
            ?.resolve({});
        final textFg = theme.textButtonTheme.style?.foregroundColor?.resolve(
          {},
        );

        expect(outlinedFg, FrozenPalette.action);
        expect(textFg, FrozenPalette.action);
      },
    );
  });

  group('SettingsScreen Day Theme Selector & Toggles', () {
    testWidgets(
      'shows Aurora, Classic Clay and Frozen Sky with Aurora selected by default',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
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
            child: const MaterialApp(home: SettingsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Check Appearance & Theme section
        expect(find.text('Appearance & Theme'), findsOneWidget);
        expect(find.text('Daylight Style'), findsOneWidget);
        expect(find.text('Aurora'), findsOneWidget);
        expect(find.text('Classic Clay'), findsOneWidget);
        expect(find.text('Frozen Sky'), findsOneWidget);

        // Default is Aurora
        expect(
          container.read(dayThemePresetProvider),
          DayThemePreset.auroraCalm,
        );

        // Tap Nordic Sky
        await tester.ensureVisible(find.text('Frozen Sky'));
        await tester.tap(find.text('Frozen Sky'));
        await tester.pumpAndSettle();

        expect(
          container.read(dayThemePresetProvider),
          DayThemePreset.nordicSky,
        );
        expect(prefs.getString('ascent_day_theme_preset'), 'nordicSky');
      },
    );

    testWidgets(
      'ThemeOption toggle renders white text when selected and obsidian ink when unselected',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({
          'ascent_day_theme_preset': 'nordicSky',
          ...returningUserGuidePrefs,
        });
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
              home: const SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // By default themeMode is system: "System Auto" toggle is selected (white text)
        final systemAutoText = tester.widget<Text>(
          find.text('System Auto').last,
        );
        expect(systemAutoText.style?.color, Colors.white);

        // "Day / Light" is unselected, should have dark ink color, NOT blue!
        final dayLightTextBefore = tester.widget<Text>(
          find.text('Day / Light'),
        );
        expect(dayLightTextBefore.style?.color, FrozenPalette.ink);

        // Tap "Day / Light" to select it
        await tester.ensureVisible(find.text('Day / Light'));
        await tester.tap(find.text('Day / Light'));
        await tester.pumpAndSettle();

        // Now "Day / Light" is selected (white text)
        final dayLightTextAfter = tester.widget<Text>(find.text('Day / Light'));
        expect(dayLightTextAfter.style?.color, Colors.white);

        // "Night / Dark" is unselected, should have dark ink color, NOT blue!
        final nightDarkText = tester.widget<Text>(find.text('Night / Dark'));
        expect(nightDarkText.style?.color, FrozenPalette.ink);

        // Nordic Sky preset was stored in prefs: "Nordic Sky" toggle text is white
        final nordicSkyText = tester.widget<Text>(find.text('Frozen Sky').last);
        expect(nordicSkyText.style?.color, Colors.white);

        // "Classic Clay" is unselected: text is dark ink, NOT blue!
        final classicClayText = tester.widget<Text>(
          find.text('Classic Clay').last,
        );
        expect(classicClayText.style?.color, FrozenPalette.ink);
      },
    );
  });
}
