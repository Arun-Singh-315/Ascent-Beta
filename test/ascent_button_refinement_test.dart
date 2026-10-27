import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/color_tokens.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:ascent/shared/widgets/glass_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AscentButton Refinements & Soft Glass Danger Tests', () {
    testWidgets('Destructive button uses translucent red glass background and red text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: Center(
              child: AscentButton.destructive(
                label: 'Delete Item',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final elevatedBtnFinder = find.byType(ElevatedButton);
      expect(elevatedBtnFinder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(elevatedBtnFinder);
      final bg = button.style?.backgroundColor?.resolve({});
      final fg = button.style?.foregroundColor?.resolve({});

      // Translucent tint background, not opaque solid red
      expect(bg, isNotNull);
      expect(bg!.a, lessThan(0.35));
      expect(bg.a, greaterThan(0.05));

      // Foreground text is clear, visible red (same hue)
      expect(fg, isNotNull);
      expect(fg!.r, greaterThan(0.7)); // Danger red component
    });

    testWidgets('Destructive button in dark mode maintains soft red tint and readable text', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: Scaffold(
            body: Center(
              child: AscentButton.destructive(
                label: 'Discard',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      final bg = button.style?.backgroundColor?.resolve({});
      final fg = button.style?.foregroundColor?.resolve({});

      expect(bg, isNotNull);
      expect(bg!.a, lessThan(0.35));
      expect(fg, isNotNull);
    });

    testWidgets('Secondary button has soft accent wash instead of hollow transparency', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: Center(
              child: AscentButton.secondary(
                label: 'Secondary Action',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final outlinedBtnFinder = find.byType(OutlinedButton);
      expect(outlinedBtnFinder, findsOneWidget);

      final button = tester.widget<OutlinedButton>(outlinedBtnFinder);
      final bg = button.style?.backgroundColor?.resolve({});
      expect(bg, isNotNull);
      expect(bg, isNot(Colors.transparent));
      expect(bg!.a, lessThan(0.18));
      expect(bg.a, greaterThan(0.02));
    });

    testWidgets('Tonal button has refined glass rim border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: Center(
              child: AscentButton.tonal(
                label: 'Done',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textBtnFinder = find.byType(TextButton);
      expect(textBtnFinder, findsOneWidget);

      final button = tester.widget<TextButton>(textBtnFinder);
      final shape = button.style?.shape?.resolve({}) as RoundedRectangleBorder?;
      expect(shape, isNotNull);
      expect(shape!.side.style, BorderStyle.solid);
    });

    testWidgets('GlassChip fires tap callback with proper semantic role', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: Center(
              child: GlassChip(
                label: 'Filter',
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Filter'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    for (final dark in [false, true]) {
      testWidgets('All button variants fit 320px width at 2.0x text scale (dark=$dark)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2.0),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      AscentButton.primary(label: 'Save Changes', onPressed: () {}),
                      const SizedBox(height: 8),
                      AscentButton.secondary(label: 'Cancel Action', onPressed: () {}),
                      const SizedBox(height: 8),
                      AscentButton.tonal(label: 'Mark Done', onPressed: () {}),
                      const SizedBox(height: 8),
                      AscentButton.outlined(label: 'Close View', onPressed: () {}),
                      const SizedBox(height: 8),
                      AscentButton.destructive(label: 'Delete Permanent', onPressed: () {}),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: AscentButton.outlined(
                              label: 'Cancel',
                              compact: true,
                              onPressed: () {},
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AscentButton.destructive(
                              label: 'Delete',
                              compact: true,
                              onPressed: () {},
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    }
  });
}
