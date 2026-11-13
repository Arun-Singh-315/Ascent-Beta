import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/shared/widgets/ascent_action_menu.dart';
import 'package:ascent/shared/widgets/ascent_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final dark in [false, true]) {
    testWidgets('action menu scrolls at 320px with large text, dark=$dark', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      String? selected;
      await t.pumpWidget(
        MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Actions'),
                onPressed: () async {
                  selected = await showAscentActionMenu<String>(
                    context: context,
                    title:
                        'A gentle morning with a little more space for yourself',
                    actions: const [
                      AscentAction(
                        'view',
                        'View details',
                        Icons.open_in_new_rounded,
                      ),
                      AscentAction(
                        'edit',
                        'Edit activity',
                        Icons.edit_outlined,
                      ),
                      AscentAction(
                        'star',
                        'Mark important',
                        Icons.star_border_rounded,
                      ),
                      AscentAction(
                        'tomorrow',
                        'Move to tomorrow',
                        Icons.next_plan_outlined,
                      ),
                      AscentAction(
                        'delete',
                        'Delete from Today',
                        Icons.delete_outline_rounded,
                        destructive: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Actions'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(selected, isNull);
      await t.ensureVisible(find.text('Delete from Today'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await t.tap(find.text('Delete from Today'));
      await t.pumpAndSettle();
      expect(selected, 'delete');
      expect(find.byTooltip('Close actions'), findsNothing);
    });
  }
  testWidgets('confirmation cancellation returns false with reduced motion', (
    t,
  ) async {
    bool? result;
    await t.pumpWidget(
      MaterialApp(
        theme: AscentTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await AscentDialog.confirm(
                  context: context,
                  title: 'Delete this thought?',
                  content: 'You can undo this after deleting.',
                  confirmLabel: 'Delete',
                  cancelLabel: 'Keep thought',
                  isDestructive: true,
                );
              },
              child: const Text('Confirm'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Confirm'));
    await t.pumpAndSettle();
    await t.tap(find.text('Keep thought'));
    await t.pumpAndSettle();
    expect(result, isFalse);
    expect(t.takeException(), isNull);
  });
}
