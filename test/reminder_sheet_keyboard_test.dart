import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/reminders/widgets/ios_reminder_dialog.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Future<void> open(
    WidgetTester tester, {
    required ThemeData theme,
    double keyboard = 0,
    Size size = const Size(390, 760),
    double textScale = 1,
  }) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showIOSReminderDialog(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('title field stays above the keyboard', (tester) async {
    const keyboard = 340.0;
    await open(tester, theme: AscentTheme.light(), keyboard: keyboard);
    final field = find.byKey(const ValueKey('ios_reminder_title_field'));
    expect(field, findsOneWidget);
    final rect = tester.getRect(field);
    expect(rect.bottom, lessThanOrEqualTo(760 - keyboard));
    expect(rect.top, greaterThanOrEqualTo(0));
    // The save action in the header is visible too.
    final save = tester.getRect(
      find.byKey(const ValueKey('ios_reminder_save_button')),
    );
    expect(save.bottom, lessThanOrEqualTo(760 - keyboard));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add enables with only a title', (tester) async {
    await open(tester, theme: AscentTheme.light());
    AscentButton save() => tester.widget<AscentButton>(
      find.byKey(const ValueKey('ios_reminder_save_button')),
    );
    expect(save().onPressed, isNull);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('ios_reminder_title_field')),
        matching: find.byType(EditableText),
      ),
      'Call mom',
    );
    await tester.pump();
    expect(save().onPressed, isNotNull);
    expect(find.text('New reminder'), findsOneWidget);
  });

  testWidgets('no overflow in dark at 320 px and text scale 2', (tester) async {
    await open(
      tester,
      theme: AscentTheme.dark(),
      size: const Size(320, 640),
      textScale: 2,
      keyboard: 260,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Ring as an alarm'), findsOneWidget);
  });
}
