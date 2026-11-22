import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/quick_capture_service.dart';
import 'package:ascent/features/capture/capture_button.dart';
import 'package:ascent/features/capture/capture_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  late AppDatabase db;
  late ProviderContainer container;

  Future<void> setUpWith(Map<String, Object> prefsValues) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  }

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  Widget app({
    bool dark = false,
    double scale = 1,
    Widget body = const SizedBox.shrink(),
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: dark ? AscentTheme.dark() : AscentTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: body,
        floatingActionButton: const CaptureButton.fab(),
      ),
    ),
  );

  Future<void> open(WidgetTester t) async {
    await t.tap(find.byKey(const ValueKey('capture_fab')));
    await flush(t);
    expect(find.byType(CaptureSheet), findsOneWidget);
  }

  Future<void> type(WidgetTester t, String text) async {
    await t.enterText(find.byKey(const ValueKey('capture_input')), text);
    await t.pump();
  }

  testWidgets('empty sheet teaches with tappable examples', (t) async {
    await setUpWith({});
    await t.pumpWidget(app());
    await open(t);
    expect(find.text('Type naturally, one thing per line. Try:'), findsOne);
    await t.tap(find.byKey(const ValueKey('capture_hint_Spent 250 on lunch')));
    await t.pump();
    expect(find.byKey(const ValueKey('capture_preview_0')), findsOneWidget);
    expect(find.text('Expense · Money'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('one preview per line, routed without prefixes', (t) async {
    await setUpWith({});
    await t.pumpWidget(app());
    await open(t);
    await type(
      t,
      'buy milk\nspent 80 on chai\nidea: plant app\n2 glasses of water',
    );
    expect(find.byKey(const ValueKey('capture_preview_3')), findsOneWidget);
    expect(find.text('To-do · Things'), findsOneWidget);
    expect(find.text('Expense · Money'), findsOneWidget);
    expect(find.text('Thought · Mindspace'), findsOneWidget);
    expect(find.text('Water · Hydration'), findsOneWidget);
    expect(find.text('500 ml'), findsOneWidget);
    expect(find.text('Save 4'), findsOneWidget);
  });

  testWidgets('save creates the records, and Undo removes them', (t) async {
    await setUpWith({});
    await t.pumpWidget(app());
    await open(t);
    await type(t, 'buy milk\nspent 80 on chai\nidea: plant app');
    await t.tap(find.byKey(const ValueKey('capture_save')));
    await flush(t);
    expect(find.byType(CaptureSheet), findsNothing);
    expect(find.text('3 items saved'), findsOneWidget);
    expect(await t.runAsync(() => db.select(db.taskTable).get()), hasLength(1));
    expect(
      await t.runAsync(() => db.select(db.financeTransactionTable).get()),
      hasLength(1),
    );
    expect(
      await t.runAsync(() => db.select(db.thoughtTable).get()),
      hasLength(1),
    );

    await t.tap(find.text('Undo'));
    await flush(t);
    expect(await t.runAsync(() => db.select(db.taskTable).get()), isEmpty);
    expect(
      await t.runAsync(() => db.select(db.financeTransactionTable).get()),
      isEmpty,
    );
    expect(await t.runAsync(() => db.select(db.thoughtTable).get()), isEmpty);
  });

  testWidgets('one tap switches an unsure guess', (t) async {
    await setUpWith({});
    await t.pumpWidget(app());
    await open(t);
    await type(t, 'maybe learn the guitar');
    expect(find.text('Thought · Mindspace'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('capture_alternative')));
    await t.pump();
    expect(find.text('To-do · Things'), findsOneWidget);
    expect(find.byKey(const ValueKey('capture_alternative')), findsNothing);
  });

  testWidgets('the kind menu changes what a line becomes', (t) async {
    await setUpWith({});
    await t.pumpWidget(app());
    await open(t);
    await type(t, 'plant app');
    await t.tap(find.byKey(const ValueKey('capture_kind')));
    await flush(t);
    await t.tap(find.text('Thought').last);
    await flush(t);
    expect(find.text('Thought · Mindspace'), findsOneWidget);
  });

  testWidgets('switched-off features are not offered', (t) async {
    await setUpWith({
      unlockedFeaturesKey: [AscentFeature.things.name, AscentFeature.mind.name],
    });
    expect(
      container.read(unlockedFeaturesProvider),
      isNot(contains(AscentFeature.money)),
    );
    await t.pumpWidget(app());
    await open(t);
    await type(t, 'spent 250 on lunch');
    expect(find.text('Expense · Money'), findsNothing);
    expect(find.text('To-do · Things'), findsOneWidget);
    expect(
      allowedCaptureKinds({AscentFeature.things}),
      isNot(contains(CaptureKind.expense)),
    );
  });

  for (final dark in [false, true]) {
    testWidgets(
      'no overflow at 320 px and text scale 2 (${dark ? 'dark' : 'light'})',
      (t) async {
        await setUpWith({});
        t.view.physicalSize = const Size(320, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(app(dark: dark, scale: 2));
        await open(t);
        await type(
          t,
          'book flight to Goa tomorrow at 3pm and pack the bags\n'
          'spent ₹1,200 on groceries\nmaybe learn the guitar',
        );
        await t.pump();
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('100 lines are capped at 30 previews', (t) async {
    await setUpWith({});
    await t.pumpWidget(app());
    await open(t);
    await type(t, List.generate(100, (i) => 'thing $i').join('\n'));
    expect(find.textContaining('Save 30'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
