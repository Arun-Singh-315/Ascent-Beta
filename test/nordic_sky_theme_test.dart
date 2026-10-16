import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/settings/settings_screen.dart';
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

    test('nordicSky preset applies ice blue, calm sky blue accent, and midnight slate ink', () {
      final theme = AscentTheme.light(preset: DayThemePreset.nordicSky);

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, const Color(0xFF0EA5E9));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF0F4F9));
      expect(theme.colorScheme.onSurface, const Color(0xFF0F172A));
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF64748B));

      final glass = theme.extension<AscentGlass>();
      expect(glass, isNotNull);
      expect(glass!.bg, const Color(0xFFF0F4F9));
      expect(glass.clay, const Color(0xFF0EA5E9));
      expect(glass.ink, const Color(0xFF0F172A));
    });

    test('switchTheme in nordicSky has high-contrast selected and unselected states', () {
      final theme = AscentTheme.light(preset: DayThemePreset.nordicSky);
      final switchTheme = theme.switchTheme;

      expect(switchTheme.thumbColor, isNotNull);
      expect(switchTheme.trackColor, isNotNull);

      final selectedThumb = switchTheme.thumbColor!.resolve({WidgetState.selected});
      final unselectedThumb = switchTheme.thumbColor!.resolve({});
      final selectedTrack = switchTheme.trackColor!.resolve({WidgetState.selected});
      final unselectedTrack = switchTheme.trackColor!.resolve({});

      expect(selectedThumb, const Color(0xFFFFFFFF));
      expect(selectedTrack, const Color(0xFF38BDF8));
      expect(unselectedThumb, const Color(0xFF475569));
      expect(unselectedTrack, const Color(0xFFCBD5E1));
    });
  });

  group('SettingsScreen Day Theme Selector', () {
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
  });
}
