import 'dart:io';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settleDb(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  test(
    'schema 19 upgrade adds the custom category registry without changing thoughts',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'thought-category-upgrade-',
      );
      final file = File('${dir.path}/workspace.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Existing reflection'),
        );
        await db.customStatement('DROP TABLE thought_categories');
        await db.customStatement('PRAGMA user_version = 19');
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        expect(
          await db.thoughtDao.watchCategories().first,
          ThoughtDao.builtInCategories,
        );
        expect(
          (await db.thoughtDao.getThoughtById(id))!.content,
          'Existing reflection',
        );
        expect(await db.select(db.thoughtCategoryTable).get(), isEmpty);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'custom categories persist across restart and reuse normalized names',
    () async {
      final dir = await Directory.systemTemp.createTemp('thought-folders-');
      final file = File('${dir.path}/workspace.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final first = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Learn'),
        );
        final second = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Practise'),
        );
        final category = await db.thoughtDao.createCategoryAndMove(
          '  Work   ideas  ',
          [first],
        );
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        expect(
          (await db.thoughtDao.watchCategories().first)[category],
          'Work ideas',
        );
        expect(
          await db.thoughtDao.createCategoryAndMove('work ideas', [second]),
          category,
        );
        expect(await db.select(db.thoughtCategoryTable).get(), hasLength(1));
        expect((await db.thoughtDao.getThoughtById(first))!.category, category);
        expect(
          (await db.thoughtDao.getThoughtById(second))!.category,
          category,
        );
        expect(
          await db.thoughtDao.createCategoryAndMove(' LIFE goals ', [second]),
          'life_goals',
        );
        await expectLater(
          db.thoughtDao.createCategoryAndMove('  ', [first]),
          throwsArgumentError,
        );
        await expectLater(
          db.thoughtDao.createCategoryAndMove('x' * 51, [first]),
          throwsArgumentError,
        );
        expect((await db.thoughtDao.getThoughtById(first))!.category, category);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'creating a category and moving thoughts rolls back together on failure',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Keep me'),
        );
        await db.customStatement(
          "CREATE TRIGGER reject_category BEFORE UPDATE OF category ON thoughts BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
        );
        await expectLater(
          db.thoughtDao.createCategoryAndMove('Rejected', [id]),
          throwsA(anything),
        );
        expect(await db.select(db.thoughtCategoryTable).get(), isEmpty);
        expect((await db.thoughtDao.getThoughtById(id))!.category, 'general');
      } finally {
        await db.close();
      }
    },
  );

  testWidgets(
    'long thoughts use Read more, retain actions and respect large text',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final content = List.filled(
        15,
        'A long reflection about learning and growing.',
      ).join('\n');
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: content),
      );
      final thought = (await db.thoughtDao.getThoughtById(id))!;
      Future<void> mount(double scale) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: ThoughtCardBubble(
                    key: ValueKey(scale),
                    thought: thought,
                    index: 0,
                    compact: true,
                    categoryLabel: 'Learning',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      try {
        await mount(1);
        await tester.pumpAndSettle();
        final height = tester.getSize(find.byType(ThoughtCardBubble)).height;
        final text = tester.widget<Text>(find.text(content));
        expect(text.maxLines, 5);
        expect(find.byTooltip('Expand thought'), findsNothing);
        expect(find.byTooltip('Collapse thought'), findsNothing);
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('Plan'), findsOneWidget);
        await tester.tap(find.text('Read more'));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byType(ThoughtCardBubble)).height,
          greaterThan(height),
        );
        expect(tester.widget<Text>(find.text(content)).maxLines, isNull);
        await mount(2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
    },
  );

  testWidgets(
    'create a category in the picker and immediately file selected thoughts',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Thought Wall': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      tester.view.physicalSize = const Size(500, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        final ids = <int>[];
        for (final content in ['First learning note', 'Second learning note']) {
          ids.add(
            await db.thoughtDao.insertThought(
              ThoughtTableCompanion.insert(content: content),
            ),
          );
        }
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const ThoughtWallScreen(),
            ),
          ),
        );
        await settleDb(tester);
        expect(
          find.byKey(ValueKey('thought_surface_${ids.first}_soft')),
          findsOneWidget,
        );
        await tester.longPress(find.text('First learning note'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Second learning note'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('thought_selection_actions')),
          findsOneWidget,
        );
        await tester.tap(find.text('Category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create and move'));
        await tester.pump();
        expect(find.text('Enter a category name.'), findsOneWidget);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Category name'),
          'Learning',
        );
        await tester.tap(find.text('Create and move'));
        await settleDb(tester);
        final categories = await tester.runAsync(
          () => db.thoughtDao.watchCategories().first,
        );
        final key = categories!.entries
            .singleWhere((e) => e.value == 'Learning')
            .key;
        for (final id in ids) {
          expect(
            (await tester.runAsync(
              () => db.thoughtDao.getThoughtById(id),
            ))!.category,
            key,
          );
        }
        await tester.tap(find.byTooltip('Category filter'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Learning'));
        await tester.pumpAndSettle();
        expect(find.text('First learning note'), findsOneWidget);
        expect(find.text('Second learning note'), findsOneWidget);
        await tester.tap(
          find.descendant(
            of: find.byKey(ValueKey(ids.first)),
            matching: find.byType(PopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Move to category'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('General').last);
        await settleDb(tester);
        expect(
          (await tester.runAsync(
            () => db.thoughtDao.getThoughtById(ids.first),
          ))!.category,
          'general',
        );
        expect(
          (await tester.runAsync(
            () => db.thoughtDao.getThoughtById(ids.last),
          ))!.category,
          key,
        );
        expect(find.text('First learning note'), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
      }
    },
  );
}
