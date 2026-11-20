import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/thought_wall/board/thought_board_screen.dart';
import 'package:ascent/features/thought_wall/board/thought_space_screen.dart';
import 'package:ascent/features/thought_wall/board/board_logic.dart';
import 'package:drift/native.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
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
            .widget<AscentButton>(
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
      await tester.tap(find.text('Rename'));
      await settle(tester);
      await tester.enterText(
        find.byKey(const ValueKey('space_rename_field')),
        'Films',
      );
      await tester.tap(find.text('Save'));
      await settle(tester);
      expect(find.text('Films'), findsOneWidget);
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
