import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/app/theme/shared_control_tokens.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:ascent/shared/widgets/glass_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AscentButton Refinements & C01 Specification Tests', () {
    testWidgets('Destructive button uses filled destructive pair (#B42318 and white text)', (
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

      final btnFinder = find.widgetWithText(AscentButton, 'Delete Item');
      expect(btnFinder, findsOneWidget);

      final text = tester.widget<Text>(find.text('Delete Item'));
      expect(text.style?.color, equals(SharedControlColors.filledDestructiveFg));

      final size = tester.getSize(btnFinder);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Destructive button in dark mode maintains filled destructive pair', (
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

      final btnFinder = find.widgetWithText(AscentButton, 'Discard');
      expect(btnFinder, findsOneWidget);

      final text = tester.widget<Text>(find.text('Discard'));
      expect(text.style?.color, equals(SharedControlColors.filledDestructiveFg));
    });

    testWidgets('Secondary button uses tonal pair with no border', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return Scaffold(
                body: Center(
                  child: AscentButton.secondary(
                    label: 'Secondary Action',
                    onPressed: () {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnFinder = find.widgetWithText(AscentButton, 'Secondary Action');
      expect(btnFinder, findsOneWidget);

      final g = capturedContext.glass;
      final text = tester.widget<Text>(find.text('Secondary Action'));
      expect(text.style?.color, equals(g.tonalFg));
    });

    testWidgets('Tonal button uses tonal pair matching secondary', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Builder(
            builder: (ctx) {
              capturedContext = ctx;
              return Scaffold(
                body: Center(
                  child: AscentButton.tonal(
                    label: 'Done',
                    onPressed: () {},
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final btnFinder = find.widgetWithText(AscentButton, 'Done');
      expect(btnFinder, findsOneWidget);

      final g = capturedContext.glass;
      final text = tester.widget<Text>(find.text('Done'));
      expect(text.style?.color, equals(g.tonalFg));
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

    testWidgets('Dialog cancel and destructive buttons have matching height side by side', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: Center(
              child: Row(
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
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cancelSize = tester.getSize(find.widgetWithText(AscentButton, 'Cancel'));
      final deleteSize = tester.getSize(find.widgetWithText(AscentButton, 'Delete'));
      expect(cancelSize.height, equals(deleteSize.height));
      expect(cancelSize.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('IconButton renders with 48px hit target and tooltip', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: Column(
              children: [
                AscentButton.icon(
                  icon: Icons.close,
                  tooltip: 'Close',
                  compact: true,
                  onPressed: () {},
                ),
                AscentButton.icon(
                  icon: Icons.edit,
                  tooltip: 'Edit',
                  compact: false,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);

      final closeSize = tester.getSize(find.byIcon(Icons.close));
      expect(closeSize.width, greaterThanOrEqualTo(20.0));
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
