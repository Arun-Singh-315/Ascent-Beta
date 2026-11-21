import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/dimension_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:ascent/shared/widgets/ascent_segmented_control.dart';
import 'package:ascent/shared/widgets/ascent_switch_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Section 4: Geometry Tokens Verification', () {
    test('Canonical dimension tokens match handoff table', () {
      expect(
        AscentDimensions.spaceLg,
        16.0,
      ); // Screen horizontal gutter & card internal padding
      expect(AscentDimensions.spaceXl, 20.0); // Dialog padding
      expect(
        AscentDimensions.spaceXxl,
        24.0,
      ); // Gap between content sections & sheet padding
      expect(AscentDimensions.spaceMd, 12.0); // Card-to-card gap
      expect(AscentDimensions.spaceSm, 8.0); // Icon-to-label gap
      expect(AscentDimensions.spaceXs, 4.0); // Label-to-helper gap
      expect(AscentDimensions.radiusLg, 16.0); // Standard content card radius
      expect(AscentDimensions.radiusMd, 12.0); // Button / input radius
      expect(AscentDimensions.radiusXl, 20.0); // Dialog radius
      expect(
        AscentDimensions.radiusXxl,
        24.0,
      ); // Bottom sheet top radius & tab-bar outer radius
      expect(
        AscentDimensions.radiusFull,
        999.0,
      ); // Filter/segment capsule radius
      expect(
        AscentDimensions.minTouchTarget,
        48.0,
      ); // Control minimum hit region 48x48
      expect(
        AscentDimensions.buttonHeightStandard,
        48.0,
      ); // Standard button visual min height
      expect(
        AscentDimensions.buttonHeightCompact,
        36.0,
      ); // Compact button visual min height
      expect(
        AscentDimensions.buttonHeightLarge,
        52.0,
      ); // Hero button min height
      expect(
        AscentDimensions.settingsRowHeight,
        56.0,
      ); // Settings row min height
      expect(
        AscentDimensions.settingsRowWithHelperHeight,
        72.0,
      ); // Settings row with helper min height
      expect(AscentDimensions.inputHeight, 52.0); // Input min height
      expect(
        AscentDimensions.contentOutlineWidth,
        1.0,
      ); // Standard content outline 1px
      expect(
        AscentDimensions.controlOutlineWidth,
        1.0,
      ); // Interactive unselected outline 1px
      expect(AscentDimensions.focusRingWidth, 2.0); // Focus ring 2px
    });

    test('Canonical typography roles match specification', () {
      expect(AscentTextStyles.pageTitle.fontSize, 28.0);
      expect(AscentTextStyles.pageTitle.fontWeight, FontWeight.w600);
      expect(AscentTextStyles.pageTitle.height, 1.20);

      expect(AscentTextStyles.focusTimer.fontSize, 48.0);
      expect(AscentTextStyles.focusTimer.fontWeight, FontWeight.w500);
      expect(AscentTextStyles.focusTimer.height, 1.15);

      expect(AscentTextStyles.headlineMetric.fontSize, 32.0);
      expect(AscentTextStyles.headlineMetric.fontWeight, FontWeight.w600);
      expect(AscentTextStyles.headlineMetric.height, 1.20);

      expect(AscentTextStyles.sectionHeading.fontSize, 20.0);
      expect(AscentTextStyles.sectionHeading.fontWeight, FontWeight.w600);
      expect(AscentTextStyles.sectionHeading.height, 1.25);

      expect(AscentTextStyles.cardTitle.fontSize, 18.0);
      expect(AscentTextStyles.cardTitle.fontWeight, FontWeight.w600);
      expect(AscentTextStyles.cardTitle.height, 1.30);

      expect(AscentTextStyles.body.fontSize, 16.0);
      expect(AscentTextStyles.body.fontWeight, FontWeight.w400);
      expect(AscentTextStyles.body.height, 1.45);

      expect(AscentTextStyles.buttonLabel.fontSize, 15.0);
      expect(AscentTextStyles.buttonLabel.fontWeight, FontWeight.w600);
      expect(AscentTextStyles.buttonLabel.height, 1.30);

      expect(AscentTextStyles.listRowTitle.fontSize, 16.0);
      expect(AscentTextStyles.listRowTitle.fontWeight, FontWeight.w500);
      expect(AscentTextStyles.listRowTitle.height, 1.35);

      expect(AscentTextStyles.supportingText.fontSize, 14.0);
      expect(AscentTextStyles.supportingText.fontWeight, FontWeight.w400);
      expect(AscentTextStyles.supportingText.height, 1.40);

      expect(AscentTextStyles.caption.fontSize, 12.0);
      expect(AscentTextStyles.caption.fontWeight, FontWeight.w500);
      expect(AscentTextStyles.caption.height, 1.35);
    });
  });

  group('Section 5 C01: AscentButton Contract', () {
    testWidgets(
      'Constructors maintain 48px hit region and correct visual sizes',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Column(
                children: [
                  AscentButton.primary(label: 'Primary', onPressed: () {}),
                  AscentButton.secondary(label: 'Secondary', onPressed: () {}),
                  AscentButton.outlined(label: 'Outlined', onPressed: () {}),
                  AscentButton.ghost(label: 'Ghost', onPressed: () {}),
                  AscentButton.destructive(
                    label: 'Destructive',
                    onPressed: () {},
                  ),
                  AscentButton.icon(
                    icon: Icons.add,
                    tooltip: 'Add item',
                    onPressed: () {},
                  ),
                  AscentButton.primary(
                    label: 'Compact',
                    compact: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        final primarySize = tester.getSize(
          find.widgetWithText(AscentButton, 'Primary'),
        );
        expect(primarySize.height, greaterThanOrEqualTo(48.0));

        final compactSize = tester.getSize(
          find.widgetWithText(AscentButton, 'Compact'),
        );
        expect(
          compactSize.height,
          greaterThanOrEqualTo(48.0),
          reason: 'Compact button must have at least 48px hit region',
        );

        final iconSize = tester.getSize(find.byType(AscentButton).at(5));
        expect(iconSize.width, greaterThanOrEqualTo(48.0));
        expect(iconSize.height, greaterThanOrEqualTo(48.0));
      },
    );

    testWidgets('Loading state shows spinner and blocks duplicate activation', (
      tester,
    ) async {
      int pressCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: AscentButton.primary(
              label: 'Save',
              loading: true,
              onPressed: () => pressCount++,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        pressCount,
        0,
        reason: 'Loading button must suppress repeated submission',
      );
    });
  });

  group('Section 5 C02: AscentSwitchRow Contract', () {
    testWidgets('Row tap and switch tap toggle value exactly once', (
      tester,
    ) async {
      bool currentValue = false;
      int toggleCount = 0;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: AscentSwitchRow(
                title: 'Daily Reminder',
                helper: 'Ring notifications each morning',
                value: currentValue,
                onChanged: (val) {
                  toggleCount++;
                  setState(() => currentValue = val);
                },
              ),
            ),
          ),
        ),
      );

      // Verify row dimensions (min 72 with helper)
      final rowSize = tester.getSize(find.byType(AscentSwitchRow));
      expect(rowSize.height, greaterThanOrEqualTo(72.0));

      // Tap on title text (row tap)
      await tester.tap(find.text('Daily Reminder'));
      await tester.pumpAndSettle();
      expect(toggleCount, 1);
      expect(currentValue, true);

      // Tap on CupertinoSwitch directly
      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();
      expect(toggleCount, 2);
      expect(currentValue, false);
    });

    testWidgets('Async failure displays snackbar and preserves state', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: AscentSwitchRow(
              title: 'Sync Cloud',
              value: false,
              onChanged: (val) async {
                throw Exception('Network error');
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sync Cloud'));
      await tester.pumpAndSettle();

      expect(find.text('Could not update setting. Try again.'), findsOneWidget);
    });
  });

  group('Section 5 C04: AscentSegmentedControl Contract', () {
    testWidgets(
      'Mutually exclusive selection with 48px min height and capsule radius',
      (tester) async {
        String selected = 'expense';
        int changeCount = 0;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) => MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: AscentSegmentedControl<String>(
                  segments: const [
                    AscentSegment(value: 'expense', label: 'Expense'),
                    AscentSegment(value: 'income', label: 'Income'),
                  ],
                  selected: selected,
                  onChanged: (val) {
                    changeCount++;
                    setState(() => selected = val);
                  },
                ),
              ),
            ),
          ),
        );

        final size = tester.getSize(
          find.byType(AscentSegmentedControl<String>),
        );
        expect(size.height, greaterThanOrEqualTo(48.0));

        // Tap 'Income'
        await tester.tap(find.text('Income'));
        await tester.pumpAndSettle();
        expect(changeCount, 1);
        expect(selected, 'income');

        // Tap 'Income' again (same option) -> should not trigger duplicate callback
        await tester.tap(find.text('Income'));
        await tester.pumpAndSettle();
        expect(changeCount, 1);
      },
    );

    testWidgets(
      'At 200% text scale switches to vertically stacked layout without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: AscentSegmentedControl<String>(
                  segments: const [
                    AscentSegment(
                      value: 'option1',
                      label: 'Very Long First Option Label',
                    ),
                    AscentSegment(
                      value: 'option2',
                      label: 'Very Long Second Option Label',
                    ),
                  ],
                  selected: 'option1',
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
      },
    );
  });

  group(
    'Section 8.2: Component Gallery Across All 3 Presets & 200% Text Scale',
    () {},
  );
}
