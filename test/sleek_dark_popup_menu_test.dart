import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/frozen_palette.dart';
import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/shared/widgets/ascent_popup_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Sleek Dark Obsidian Popup Menu Theme', () {
    test('Light theme has sleek dark obsidian popupMenuTheme with 100% opacity', () {
      final lightTheme = AscentTheme.light(preset: DayThemePreset.merlotLinen);

      expect(lightTheme.popupMenuTheme.shape, isA<RoundedRectangleBorder>());
      final shape = lightTheme.popupMenuTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, equals(BorderRadius.circular(18)));
      expect(shape.side.color, equals(MerlotPalette.darkLine));
      expect(lightTheme.popupMenuTheme.elevation, equals(8));

      // Sleek dark obsidian background even in light theme
      expect(lightTheme.popupMenuTheme.color, equals(MerlotPalette.darkElevated));
      // Zero transparency - 100% opaque to eliminate text bleed-through
      expect((lightTheme.popupMenuTheme.color!.a * 255.0).round(), equals(255));

      // Crisp cashmere text styling for high contrast
      expect(lightTheme.popupMenuTheme.textStyle?.color, equals(MerlotPalette.darkInk));
      final labelStyle = lightTheme.popupMenuTheme.labelTextStyle?.resolve({});
      expect(labelStyle?.color, equals(MerlotPalette.darkInk));
    });

    test('Dark theme has matching sleek dark obsidian popupMenuTheme', () {
      final darkTheme = AscentTheme.dark(preset: DayThemePreset.merlotLinen);

      expect(darkTheme.popupMenuTheme.shape, isA<RoundedRectangleBorder>());
      final shape = darkTheme.popupMenuTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, equals(BorderRadius.circular(18)));
      expect(shape.side.color, equals(MerlotPalette.darkLine));
      expect(darkTheme.popupMenuTheme.elevation, equals(8));

      expect(darkTheme.popupMenuTheme.color, equals(MerlotPalette.darkElevated));
      expect((darkTheme.popupMenuTheme.color!.a * 255.0).round(), equals(255));
      expect(darkTheme.popupMenuTheme.textStyle?.color, equals(MerlotPalette.darkInk));
    });

    test('NordicSky preset has sapphire dark obsidian popupMenuTheme', () {
      final lightTheme = AscentTheme.light(preset: DayThemePreset.nordicSky);
      final darkTheme = AscentTheme.dark(preset: DayThemePreset.nordicSky);

      expect(lightTheme.popupMenuTheme.color, equals(FrozenPalette.darkElevated));
      expect((lightTheme.popupMenuTheme.color!.a * 255.0).round(), equals(255));
      expect(lightTheme.popupMenuTheme.textStyle?.color, equals(FrozenPalette.darkInk));

      expect(darkTheme.popupMenuTheme.color, equals(FrozenPalette.darkElevated));
      expect((darkTheme.popupMenuTheme.color!.a * 255.0).round(), equals(255));
      expect(darkTheme.popupMenuTheme.textStyle?.color, equals(FrozenPalette.darkInk));
    });
  });

  group('AscentPopupMenuButton Widget', () {
    testWidgets('renders AscentPopupMenuButton and exposes child icons in crisp contrasting theme', (tester) async {
      String? selectedVal;

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
          home: Scaffold(
            body: Center(
              child: AscentPopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (val) => selectedVal = val,
                itemBuilder: (context) => [
                  ascentPopupItem(
                    value: 'edit',
                    icon: Icons.edit_outlined,
                    label: 'Edit thought',
                  ),
                  ascentPopupItem(
                    value: 'copy',
                    icon: Icons.copy_rounded,
                    label: 'Copy text',
                  ),
                  ascentPopupDestructiveItem(
                    value: 'delete',
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete thought',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify button is rendered
      expect(find.byType(AscentPopupMenuButton<String>), findsOneWidget);

      // Tap button to open popup
      await tester.tap(find.byType(AscentPopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Verify menu items are present
      expect(find.text('Edit thought'), findsOneWidget);
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Delete thought'), findsOneWidget);

      // Verify icon presence
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Tap an item and verify callback fires
      await tester.tap(find.text('Edit thought'));
      await tester.pumpAndSettle();

      expect(selectedVal, equals('edit'));
    });

    testWidgets('AscentPopupMenuButton handles 320px width and 2.0x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(preset: DayThemePreset.merlotLinen),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2.0),
            ),
            child: Scaffold(
              body: Center(
                child: AscentPopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded),
                  itemBuilder: (context) => [
                    ascentPopupItem(
                      value: 'item1',
                      icon: Icons.folder_outlined,
                      label: 'Move to category with very long label',
                    ),
                    ascentPopupDestructiveItem(
                      value: 'delete',
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete thought immediately',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AscentPopupMenuButton<String>));
      await tester.pumpAndSettle();

      // No RenderFlex overflow
      expect(tester.takeException(), isNull);
    });
  });
}
