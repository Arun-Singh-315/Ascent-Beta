import 'package:ascent/core/theme/app_colors.dart';
import 'package:ascent/shared/widgets/ascent_action_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  double textScale = 1.0,
  Size size = const Size(390, 844),
}) {
  final colors = brightness == Brightness.dark
      ? AppColors.dark
      : AppColors.light;
  return MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      extensions: [colors],
      useMaterial3: true,
    ),
    home: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: SizedBox(width: size.width, child: child),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ThoughtExcerpt Inline Expansion Tests', () {

  });

  group('showAscentActionMenu Centered Dialog Tests', () {
    testWidgets(
      'Renders as a centered dialog with title and actions, returning selected value',
      (tester) async {
        String? selectedResult;

        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selectedResult = await showAscentActionMenu<String>(
                      context: context,
                      title: 'Note Actions',
                      actions: const [
                        AscentAction(
                          'pin',
                          'Pin to top',
                          Icons.push_pin_outlined,
                        ),
                        AscentAction('copy', 'Copy text', Icons.copy_rounded),
                        AscentAction(
                          'delete',
                          'Delete note',
                          Icons.delete_outline,
                          destructive: true,
                        ),
                      ],
                    );
                  },
                  child: const Text('Open Menu'),
                );
              },
            ),
          ),
        );

        // Tap button to open menu
        await tester.tap(find.text('Open Menu'));
        await tester.pumpAndSettle();

        // Verify centered dialog rendered
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('Note Actions'), findsOneWidget);
        expect(find.text('Pin to top'), findsOneWidget);
        expect(find.text('Copy text'), findsOneWidget);
        expect(find.text('Delete note'), findsOneWidget);

        // Verify close button exists
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Tap an action
        await tester.tap(find.text('Copy text'));
        await tester.pumpAndSettle();

        // Dialog is dismissed and result returned
        expect(find.byType(Dialog), findsNothing);
        expect(selectedResult, 'copy');
      },
    );

    testWidgets('Dismisses without selection when close button is tapped', (
      tester,
    ) async {
      String? selectedResult = 'initial';

      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  selectedResult = await showAscentActionMenu<String>(
                    context: context,
                    title: 'Actions',
                    actions: const [AscentAction('edit', 'Edit', Icons.edit)],
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(selectedResult, isNull);
    });
  });

  group('Rule 13 Accessibility Safeguard (320px width @ 2.0x text scale)', () {

    testWidgets(
      'showAscentActionMenu renders with zero overflows at 320px width and 2.0x scale',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showAscentActionMenu<String>(
                      context: context,
                      title: 'Mindspace Actions and Options',
                      actions: const [
                        AscentAction(
                          '1',
                          'Convert to Today Priority Task',
                          Icons.task_alt,
                        ),
                        AscentAction(
                          '2',
                          'Move to Dedicated Knowledge Collection',
                          Icons.folder_outlined,
                        ),
                        AscentAction(
                          '3',
                          'Delete this thought permanently',
                          Icons.delete,
                          destructive: true,
                        ),
                      ],
                    );
                  },
                  child: const Text('Open'),
                );
              },
            ),
            size: const Size(320, 600),
            textScale: 2.0,
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        final error = tester.takeException();
        expect(error, isNull);
        expect(find.byType(Dialog), findsOneWidget);
      },
    );
  });
}
