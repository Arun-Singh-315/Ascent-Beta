import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/thought_wall/board/thought_board_screen.dart';
import 'package:ascent/features/thought_wall/board/thought_space_screen.dart';
import 'package:ascent/features/thought_wall/board/board_cards.dart';
import 'package:ascent/features/thought_wall/board/board_background.dart';
import 'package:ascent/features/thought_wall/board/board_logic.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late AppDatabase db;
  late ProviderContainer container;
  final privateIds = <int>{};
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    privateIds.clear();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        privatePromiseIdsProvider.overrideWith((ref) => privateIds),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app(
    Widget screen, {
    bool dark = false,
    double scale = 1,
    double keyboard = 0,
    GlobalKey? capture,
  }) => UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: screen,
          ),
        ),
      ),
    ),
  );
  Future<void> shot(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/ascent-board-$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  void phone(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'Background choice persists and detail actions stay behind disclosure',
    (tester) async {
      phone(tester, 390);
      await tester.runAsync(() async {
        await container
            .read(boardBackdropProvider.notifier)
            .set(BoardBackdrop.dusk);
      });
      container.invalidate(boardBackdropProvider);
      expect(container.read(boardBackdropProvider), BoardBackdrop.dusk);
      late int id;
      await tester.runAsync(() async {
        id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'An evening thought'),
        );
      });
      final capture = GlobalKey();
      await tester.pumpWidget(
        app(const ThoughtBoardScreen(), capture: capture),
      );
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('board_hero_$id')));
      await settle(tester);
      expect(
        find.byKey(const ValueKey('detail_edit')).hitTestable(),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('detail_delete')).hitTestable(),
        findsNothing,
      );
      await shot(tester, capture, 'detail-premium');
      await tester.tap(find.byKey(const ValueKey('detail_more')));
      await settle(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('detail_copy')));
      expect(
        find.byKey(const ValueKey('detail_copy')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Board saves tagged capture into its space and opens normal cards in details',
    (tester) async {
      phone(tester, 390);
      late String movies;
      late int id;
      await tester.runAsync(() async {
        movies = await db.thoughtDao.createCategoryAndMove('Movies', []);
        id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'A quiet thought'),
        );
      });
      await tester.pumpWidget(app(const ThoughtBoardScreen()));
      await settle(tester);
      await tester.tap(find.byKey(ValueKey('board_hero_$id')));
      await settle(tester);
      expect(find.byKey(const ValueKey('detail_edit')), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, '#movies Inception');
      await tester.pump();
      await tester.tap(find.byTooltip('Send message'));
      await settle(tester);
      await tester.runAsync(() async {
        final notes = await db.thoughtDao.watchAllThoughts().first;
        expect(
          notes.singleWhere((n) => n.content == 'Inception').category,
          movies,
        );
      });
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Selection supports move, archive Undo and completion without card buttons',
    (tester) async {
      phone(tester, 390);
      late int id;
      await tester.runAsync(() async {
        id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Select this note'),
        );
      });
      await tester.pumpWidget(app(const ThoughtBoardScreen()));
      await settle(tester);
      await tester.longPress(find.byKey(ValueKey('board_hero_$id')));
      await settle(tester);
      for (final action in ['move', 'done', 'archive', 'delete', 'more']) {
        expect(find.byKey(ValueKey('select_$action')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('select_archive')));
      await settle(tester);
      await tester.tap(find.text('Undo'));
      await settle(tester);
      await tester.runAsync(() async {
        expect((await db.thoughtDao.getThoughtById(id))!.isArchived, false);
      });
      await tester.tap(find.byKey(ValueKey('board_hero_$id')));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(ValueKey('board_hero_$id')));
      await settle(tester);
      await tester.runAsync(() async {
        expect((await db.thoughtDao.getThoughtById(id))!.isCompleted, true);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Locked explicit home thought never becomes a visible hero or batch share',
    (tester) async {
      phone(tester, 390);
      late int id;
      await tester.runAsync(() async {
        id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'SECRET PRIVATE TEXT',
            mood: const drift.Value('promise'),
          ),
        );
      });
      privateIds.add(id);
      await tester.pumpWidget(app(ThoughtBoardScreen(initialThoughtId: id)));
      await settle(tester);
      expect(find.textContaining('SECRET PRIVATE'), findsNothing);
      expect(find.byType(BoardHeroCard), findsNothing);
      await tester.longPress(find.byKey(ValueKey('board_card_$id')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('select_more')));
      await settle(tester);
      expect(find.byKey(const ValueKey('select_share')), findsNothing);
      expect(find.textContaining('SECRET PRIVATE'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Space repeated capture, bulk paste, watched filtering and highlighted home entry',
    (tester) async {
      phone(tester, 390);
      late String movies;
      late List<int> ids;
      await tester.runAsync(() async {
        movies = await db.thoughtDao.createCategoryAndMove('Movies', []);
        ids = await db.thoughtDao.insertEntries(['Arrival', 'Dune'], movies);
        await db.thoughtDao.toggleCompleted(ids.first);
      });
      await tester.pumpWidget(
        app(ThoughtSpaceScreen(spaceKey: movies, initialThoughtId: ids.first)),
      );
      await settle(tester);
      expect(find.text('Arrival'), findsOneWidget);
      for (final title in ['Heat', 'Inception']) {
        await tester.enterText(
          find.byKey(const ValueKey('space_add_field')),
          title,
        );
        await tester.tap(find.byKey(const ValueKey('space_add_button')));
        await settle(tester);
      }
      await tester.tap(find.byKey(const ValueKey('space_paste_button')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('space_paste_field')),
        '1. Interstellar\n- Moon',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('space_paste_save')));
      await settle(tester);
      await tester.runAsync(() async {
        expect((await db.thoughtDao.watchAllThoughts().first).length, 6);
      });
      await tester.tap(find.byKey(const ValueKey('space_tab_done')));
      await settle(tester);
      expect(find.text('Arrival'), findsOneWidget);
      expect(find.text('Dune'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Select All excludes completed thoughts hidden behind the Done disclosure',
    (tester) async {
      phone(tester, 390);
      late List<int> ids;
      await tester.runAsync(() async {
        ids = await db.thoughtDao.insertEntries([
          'Visible note',
          'Hidden completed note',
        ], wallCategoryKey);
        await db.thoughtDao.toggleCompleted(ids.last);
      });
      await tester.pumpWidget(app(const ThoughtBoardScreen()));
      await settle(tester);
      await tester.longPress(find.byKey(ValueKey('board_hero_${ids.first}')));
      await settle(tester);
      // All toggles the one visible selected note off; hidden Done stays unselected.
      expect(find.text('None'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('select_delete')));
      await settle(tester);
      await tester.runAsync(() async {
        expect(await db.thoughtDao.getThoughtById(ids.first), isNull);
        expect(
          (await db.thoughtDao.getThoughtById(ids.last))!.isCompleted,
          true,
        );
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Bulk delete rolls back the entire selection when one record fails',
    (tester) async {
      phone(tester, 390);
      late List<int> ids;
      await tester.runAsync(() async {
        ids = await db.thoughtDao.insertEntries([
          'Keep first',
          'Keep second',
        ], wallCategoryKey);
        await db.customStatement(
          "CREATE TRIGGER reject_second BEFORE DELETE ON thoughts WHEN OLD.id = ${ids.last} BEGIN SELECT RAISE(ABORT, 'test failure'); END",
        );
      });
      await tester.pumpWidget(app(const ThoughtBoardScreen()));
      await settle(tester);
      await tester.longPress(find.byKey(ValueKey('board_hero_${ids.first}')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('select_all')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('select_delete')));
      await settle(tester);
      await tester.runAsync(() async {
        expect((await db.select(db.thoughtTable).get()).length, 2);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Oversized paste stays editable and quick-add drafts survive reopen',
    (tester) async {
      phone(tester, 390);
      late String books;
      await tester.runAsync(() async {
        books = await db.thoughtDao.createCategoryAndMove('Books', []);
      });
      await tester.pumpWidget(app(ThoughtSpaceScreen(spaceKey: books)));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('space_add_field')),
        'Unfinished entry',
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('space_paste_button')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('space_paste_field')),
        List.generate(101, (i) => 'Entry $i').join('\n'),
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('space_paste_save')),
            )
            .onPressed,
        isNull,
      );
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await settle(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(app(ThoughtSpaceScreen(spaceKey: books)));
      await settle(tester);
      expect(find.text('Unfinished entry'), findsOneWidget);
      await tester.runAsync(() async {
        expect(await db.select(db.thoughtTable).get(), isEmpty);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Space menu renames and switches poster view without losing entries',
    (tester) async {
      phone(tester, 390);
      late String movies;
      await tester.runAsync(() async {
        movies = await db.thoughtDao.createCategoryAndMove('Movies', []);
        await db.thoughtDao.insertEntries(['Arrival'], movies);
      });
      await tester.pumpWidget(app(ThoughtSpaceScreen(spaceKey: movies)));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('space_menu')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('space_rename')));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('space_rename_field')),
        'Films',
      );
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Films'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('space_menu')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('space_view_toggle')));
      await settle(tester);
      expect(find.text('Arrival'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Both new screens fit narrow phones, large text, keyboard and poster mode',
    (tester) async {
      phone(tester, 320);
      late String movies;
      await tester.runAsync(() async {
        movies = await db.thoughtDao.createCategoryAndMove('Movies', []);
        await db.thoughtDao.insertEntries([
          'Arrival',
          'A very long movie title to wrap across several lines',
        ], movies);
        await db.thoughtDao.insertEntries([
          'A short note',
          '- One\n- Two',
          'A long reflection. ' * 30,
          'Another note',
        ], wallCategoryKey);
      });
      for (final width in [320.0, 390.0]) {
        tester.view.physicalSize = Size(width, 844);
        for (final dark in [false, true]) {
          for (final scale in [1.0, 2.0]) {
            for (final keyboard in [0.0, 300.0]) {
              for (final screen in [
                const ThoughtBoardScreen(),
                ThoughtSpaceScreen(spaceKey: movies),
              ]) {
                await tester.pumpWidget(const SizedBox());
                final key = GlobalKey();
                await tester.pumpWidget(
                  app(
                    screen,
                    dark: dark,
                    scale: scale,
                    keyboard: keyboard,
                    capture: key,
                  ),
                );
                await settle(tester);
                expect(tester.takeException(), isNull);
                if (scale == 1 && keyboard == 0) {
                  await shot(
                    tester,
                    key,
                    '${screen is ThoughtBoardScreen ? 'wall' : 'space'}-${dark ? 'dark' : 'light'}-${width.toInt()}',
                  );
                }
              }
            }
          }
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
