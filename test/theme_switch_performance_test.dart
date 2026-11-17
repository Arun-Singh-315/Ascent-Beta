import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeData.lerp between light and dark across all presets', () {
    for (final preset in DayThemePreset.values) {
      final light = AscentTheme.light(preset: preset);
      final dark = AscentTheme.dark(preset: preset);

      final homeLight = HomeTheme.from(light);
      final homeDark = HomeTheme.from(dark);

      for (double t = 0.0; t <= 1.0; t += 0.1) {
        final lerpedDirect = ThemeData.lerp(light, dark, t);
        expect(lerpedDirect.extension<AscentGlass>(), isNotNull);
        expect(lerpedDirect.extension<AppSurfaces>(), isNotNull);

        final lerpedHome = ThemeData.lerp(homeLight, homeDark, t);
        expect(lerpedHome.extension<AscentGlass>(), isNotNull);
        expect(lerpedHome.extension<AppSurfaces>(), isNotNull);
      }
    }
  });

  testWidgets('Theme toggle does not throw exceptions or render error screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    SharedPreferences.setMockInitialValues({
      'ascent_quick_start_v1': true,
      'user_profile_name': 'Tester',
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.into(db.userProfileTable).insert(
      UserProfileTableCompanion.insert(
        name: 'Tester',
        onboardingComplete: const Value(true),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final themeMode = ref.watch(themeModeProvider);
            return MaterialApp(
              theme: AscentTheme.light(),
              darkTheme: AscentTheme.dark(),
              themeMode: themeMode,
              home: const HomeScreen(),
            );
          },
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    // Tap theme toggle button
    final toggleFinder = find.byKey(const ValueKey('home_theme_toggle_btn'));
    expect(toggleFinder, findsOneWidget);

    await tester.tap(toggleFinder);

    // Pump intermediate frames during the 320ms AnimatedTheme transition
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull, reason: 'Frame $i of theme switch threw exception');
      expect(find.byType(ErrorWidget), findsNothing, reason: 'ErrorWidget shown at frame $i');
    }

    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    // Toggle back to light mode
    await tester.tap(toggleFinder);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 40));
      expect(tester.takeException(), isNull, reason: 'Frame $i of light switch threw exception');
      expect(find.byType(ErrorWidget), findsNothing, reason: 'ErrorWidget shown at frame $i');
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);

    await db.close();
  });
}
