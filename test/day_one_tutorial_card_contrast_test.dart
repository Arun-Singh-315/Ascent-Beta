import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/color_tokens.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  double calculateLuminance(Color color) {
    return color.computeLuminance();
  }

  double calculateContrast(Color c1, Color c2) {
    final l1 = calculateLuminance(c1);
    final l2 = calculateLuminance(c2);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  group('DayOneTutorialCard button contrast tests', () {
    testWidgets('Light mode: Add First Activity button preserves white foreground on dark clay background', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.classicClay),
            home: const Scaffold(
              body: DayOneTutorialCard(userName: 'Arun'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Add First Activity 🚀');
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(buttonFinder);
      final style = button.style!;
      final bg = style.backgroundColor?.resolve({}) ?? Colors.transparent;
      final fg = style.foregroundColor?.resolve({}) ?? Colors.transparent;

      expect(bg, equals(AscentGlass.light.clay));
      expect(fg, equals(AppPalette.white));

      final contrast = calculateContrast(bg, fg);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: 'WCAG AA requires >= 4.5:1 contrast');
    });

    testWidgets('Dark mode: Add First Activity button has high contrast foreground on peach clay background', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const Scaffold(
              body: DayOneTutorialCard(userName: 'Arun'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Add First Activity 🚀');
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(buttonFinder);
      final style = button.style!;
      final bg = style.backgroundColor?.resolve({}) ?? Colors.transparent;
      final fg = style.foregroundColor?.resolve({}) ?? Colors.transparent;

      expect(bg, equals(AscentGlass.dark.clay));
      expect(fg, equals(AscentColors.textOnPrimaryDark));

      final contrast = calculateContrast(bg, fg);
      expect(contrast, greaterThanOrEqualTo(4.5), reason: 'WCAG AA requires >= 4.5:1 contrast');
      expect(contrast, greaterThanOrEqualTo(7.0), reason: 'WCAG AAA requires >= 7.0:1 contrast');
    });

    testWidgets('Disabled state colors provide accessible disabled contrast without crashing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const Scaffold(
              body: DayOneTutorialCard(userName: 'Arun'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, 'Add First Activity 🚀');
      final button = tester.widget<ElevatedButton>(buttonFinder);
      final style = button.style!;

      final disabledBg = style.backgroundColor?.resolve({WidgetState.disabled});
      final disabledFg = style.foregroundColor?.resolve({WidgetState.disabled});

      expect(disabledBg, isNotNull);
      expect(disabledFg, isNotNull);
    });
  });
}
