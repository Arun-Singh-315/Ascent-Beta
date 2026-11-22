import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/quick_capture_service.dart';
import 'package:ascent/features/capture/capture_card.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  Future<AppDatabase> pump(
    WidgetTester tester, {
    ThemeData? theme,
    Size size = const Size(390, 800),
    double textScale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: theme ?? AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: CaptureCard(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return db;
  }

  Finder field() => find.descendant(
    of: find.byKey(const ValueKey('capture_card_field')),
    matching: find.byType(EditableText),
  );

  Future<T> settle<T>(WidgetTester tester, Future<T> Function() query) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    return (await tester.runAsync(query)) as T;
  }

  testWidgets('shows the type toggles and a live route preview', (
    tester,
  ) async {
    await pump(tester);
    for (final k in ['auto', 'thing', 'reminder', 'thought', 'money']) {
      expect(find.byKey(ValueKey('capture_toggle_$k')), findsOneWidget);
    }
    await tester.enterText(field(), '₹250 lunch');
    await tester.pump();
    expect(find.textContaining('Money'), findsWidgets);
  });

  testWidgets('Enter routes several lines, then Undo removes one', (
    tester,
  ) async {
    final db = await pump(tester);
    await tester.enterText(field(), 'Send report\nidea: walk more');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    final thoughts = await settle(
      tester,
      () => db.select(db.thoughtTable).get(),
    );
    expect(thoughts.map((t) => t.content), ['Walk more']);
    expect(
      await settle(tester, () => db.select(db.taskTable).get()),
      hasLength(1),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Send report'), findsOneWidget);
    expect(find.text('Walk more'), findsOneWidget);

    await tester.tap(find.text('Undo').first);
    await settle(tester, () async => null);
    await tester.pump(const Duration(milliseconds: 300));
    final left =
        (await settle(tester, () => db.select(db.taskTable).get())).length +
        (await settle(tester, () => db.select(db.thoughtTable).get())).length;
    expect(left, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('a forced Money toggle asks for an amount instead of guessing', (
    tester,
  ) async {
    final db = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('capture_toggle_money')));
    await tester.pump();
    await tester.enterText(field(), 'lunch');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byKey(const ValueKey('capture_card_error')), findsOneWidget);
    expect(
      await settle(tester, () => db.select(db.financeTransactionTable).get()),
      isEmpty,
    );
  });

  testWidgets('no overflow in dark at 320 px and text scale 2', (
    tester,
  ) async {
    await pump(
      tester,
      theme: AscentTheme.dark(),
      size: const Size(320, 900),
      textScale: 2,
    );
    await tester.enterText(field(), 'Call mom at 6pm');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  test('toggles force the type; Auto routes by meaning', () {
    final now = DateTime(2026, 11, 2, 9);
    expect(
      cardDrafts('₹250 lunch\nidea: calmer Home', now).map((d) => d.kind),
      [CaptureKind.expense, CaptureKind.thought],
    );
    final forced = cardDrafts(
      'Water the plants',
      now,
      force: CaptureTarget.reminder,
    ).single;
    expect(forced.kind, CaptureKind.reminder);
    expect(forced.validate(now), isNull);
    expect(
      cardDrafts('Gym 7am', now, force: CaptureTarget.thought).single.kind,
      CaptureKind.thought,
    );
  });
}
