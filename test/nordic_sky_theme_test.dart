import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'support/returning_user_guides.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DayThemePreset provider & persistence', () {
    test('defaults to classicClay (brown) when no value is stored', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(dayThemePresetProvider), DayThemePreset.classicClay);
    });

    test('persists nordicSky selection to SharedPreferences and updates state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(dayThemePresetProvider.notifier)
          .setPreset(DayThemePreset.nordicSky);

      expect(container.read(dayThemePresetProvider), DayThemePreset.nordicSky);
      expect(prefs.getString('ascent_day_theme_preset'), 'nordicSky');
    });

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
    test('classicClay preset applies signature terracotta & linen palette', () {
      final theme = AscentTheme.light(preset: DayThemePreset.classicClay);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFFA4523A));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF8F9FA));
      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.clay, const Color(0xFFA4523A));
    });

    test('nordicSky preset applies ice blue canvas, cobalt accent, warm copper clay, and midnight obsidian ink', () {
      final theme = AscentTheme.light(preset: DayThemePreset.nordicSky);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFF0284C7));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF0F4F9));
      expect(theme.colorScheme.onSurface, const Color(0xFF0F172A));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF64748B));

      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.bg, const Color(0xFFF0F4F9));
      expect(glass.clay, const Color(0xFFC05621));
      expect(glass.slate, const Color(0xFF0284C7));
      expect(glass.ink, const Color(0xFF0F172A));
    });

    test('switchTheme in nordicSky has high-contrast selected (cobalt/white) and unselected states', () {
      final theme = AscentTheme.light(preset: DayThemePreset.nordicSky);
      final switchTheme = theme.switchTheme;

      expect(switchTheme.thumbColor, isNotNull);
      expect(switchTheme.trackColor, isNotNull);

      final selectedThumb = switchTheme.thumbColor!.resolve({WidgetState.selected});
      final unselectedThumb = switchTheme.thumbColor!.resolve({});
      final selectedTrack = switchTheme.trackColor!.resolve({WidgetState.selected});
      final unselectedTrack = switchTheme.trackColor!.resolve({});

      expect(selectedThumb, const Color(0xFFFFFFFF));
      expect(selectedTrack, const Color(0xFF0284C7));
      expect(unselectedThumb, const Color(0xFF475569));
      expect(unselectedTrack, const Color(0xFFCBD5E1));
    });

    test('outlined and text buttons have high contrast ink/cerulean without washed-out light blue', () {
      final theme = AscentTheme.light(preset: DayThemePreset.nordicSky);
      final outlinedFg = theme.outlinedButtonTheme.style?.foregroundColor?.resolve({});
      final textFg = theme.textButtonTheme.style?.foregroundColor?.resolve({});

      expect(outlinedFg, const Color(0xFF0F172A));
      expect(textFg, const Color(0xFF0369A1));
    });
  });

  group('SettingsScreen Day Theme Selector & Toggles', () {
    testWidgets('shows both Classic Clay and Nordic Frosted Sky with Classic Clay selected by default', (tester) async {
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
      expect(find.text('Classic Clay'), findsOneWidget);
      expect(find.text('Nordic Sky'), findsOneWidget);

      // Default is Classic Clay
      expect(container.read(dayThemePresetProvider), DayThemePreset.classicClay);

      // Tap Nordic Sky
      await tester.ensureVisible(find.text('Nordic Sky'));
      await tester.tap(find.text('Nordic Sky'));
      await tester.pumpAndSettle();

      expect(container.read(dayThemePresetProvider), DayThemePreset.nordicSky);
      expect(prefs.getString('ascent_day_theme_preset'), 'nordicSky');
    });

    testWidgets('ThemeOption toggle renders white text when selected and obsidian ink when unselected', (tester) async {
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
      final systemAutoText = tester.widget<Text>(find.text('System Auto').last);
      expect(systemAutoText.style?.color, Colors.white);

      // "Day / Light" is unselected, should have dark ink color, NOT blue!
      final dayLightTextBefore = tester.widget<Text>(find.text('Day / Light'));
      expect(dayLightTextBefore.style?.color, const Color(0xFF0F172A));

      // Tap "Day / Light" to select it
      await tester.ensureVisible(find.text('Day / Light'));
      await tester.tap(find.text('Day / Light'));
      await tester.pumpAndSettle();

      // Now "Day / Light" is selected (white text)
      final dayLightTextAfter = tester.widget<Text>(find.text('Day / Light'));
      expect(dayLightTextAfter.style?.color, Colors.white);

      // "Night / Dark" is unselected, should have dark ink color, NOT blue!
      final nightDarkText = tester.widget<Text>(find.text('Night / Dark'));
      expect(nightDarkText.style?.color, const Color(0xFF0F172A));

      // Nordic Sky preset was stored in prefs: "Nordic Sky" toggle text is white
      final nordicSkyText = tester.widget<Text>(find.text('Nordic Sky').last);
      expect(nordicSkyText.style?.color, Colors.white);

      // "Classic Clay" is unselected: text is dark ink, NOT blue!
      final classicClayText = tester.widget<Text>(find.text('Classic Clay').last);
      expect(classicClayText.style?.color, const Color(0xFF0F172A));
    });
  });
}
