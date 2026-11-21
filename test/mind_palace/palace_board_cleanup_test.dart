import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/board/thought_board_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ThoughtBoardScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<int> add(String text, {DateTime? createdAt}) =>
      db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: text,
          createdAt: createdAt == null
              ? const drift.Value.absent()
              : drift.Value(createdAt),
        ),
      );

  testWidgets('an empty Today offers prompts that start a thought', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Nothing for today yet'), findsOneWidget);
    expect(find.text('e.g. Idea for the weekend trip'), findsOneWidget);

    await tester.tap(find.text('An idea I don’t want to lose'));
    await settle(tester);
    final field = tester.widget<TextField>(find.byType(TextField).last);
    expect(field.controller!.text, 'An idea I don’t want to lose: ');
    expect(
      await db.select(db.thoughtTable).get(),
      isEmpty,
      reason: 'nothing is saved until the user sends it',
    );
    await unmount(tester);
  });

  testWidgets('"Bring all" moves earlier thoughts at once and Undo restores', (
    tester,
  ) async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
    final a = await add('Call the plumber', createdAt: twoDaysAgo);
    await add('Plan the reunion', createdAt: twoDaysAgo);
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('earlier_bring_all')));
    await settle(tester);
    expect(find.byType(AlertDialog), findsNothing, reason: 'Undo-first');
    expect(find.text('2 thoughts brought to Today'), findsOneWidget);
    expect((await db.thoughtDao.getThoughtById(a))!.carriedOn, isNotNull);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await db.thoughtDao.getThoughtById(a))!.carriedOn, isNull);
    await unmount(tester);
  });

  testWidgets('deleting a thought needs no confirmation and can be undone', (
    tester,
  ) async {
    final id = await add('Old shopping list');
    await pump(tester);

    await tester.longPress(find.text('Old shopping list'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('select_more')));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(find.text('Delete this thought?'), findsNothing);
    expect(await db.thoughtDao.getThoughtById(id), isNull);
    expect(find.text('Thought deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await db.thoughtDao.getThoughtById(id), isNotNull);
    await unmount(tester);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'empty Today fits 320 px at 2.0x text (${dark ? 'dark' : 'light'})',
      (tester) async {
        await pump(tester, dark: dark, scale: 2, size: const Size(320, 800));
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
  }
}
