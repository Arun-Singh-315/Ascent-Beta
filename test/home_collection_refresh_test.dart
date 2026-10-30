import 'dart:io';
import 'dart:ui' as ui;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
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
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
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
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app(
    Widget child, {
    GlobalKey? capture,
    double scale = 1,
    bool dark = false,
    double keyboardInset = 0,
  }) => UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: capture,
      child: MaterialApp(
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: child,
        ),
      ),
    ),
  );

  Future<void> capture(WidgetTester tester, GlobalKey key, String path) async {
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(path).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Collection opens all dates and repeated capture stays in its category',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late String movies;
      await tester.runAsync(() async {
        movies = await db.thoughtDao.createCategoryAndMove('Movies', []);
        await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Watch Arrival',
            category: drift.Value(movies),
            createdAt: drift.Value(
              DateTime.now().subtract(const Duration(days: 8)),
            ),
          ),
        );
      });
      final key = GlobalKey();
      await tester.pumpWidget(app(const ThoughtWallScreen(), capture: key));
      await settle(tester);
      await tester.tap(
        find.byKey(const ValueKey('browse_thought_collections')),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.text('Movies'),
        180,
        scrollable: find.byType(Scrollable).last,
      );
      final card = find
          .ancestor(of: find.text('Movies'), matching: find.byType(Column))
          .first;
      final view = find.descendant(of: card, matching: find.text('View ›'));
      await tester.ensureVisible(view);
      await settle(tester);
      await capture(tester, key, '/tmp/ascent-collections.png');
      await tester.tap(view);
      await settle(tester);
      expect(find.text('Watch Arrival'), findsOneWidget);
      expect(find.text('Add to Movies...'), findsOneWidget);
      for (final title in ['Watch Dune', 'Watch Interstellar']) {
        await tester.enterText(find.byType(TextField).last, title);
        await tester.pump();
        await tester.tap(find.byTooltip('Send message'));
        await settle(tester);
      }
      await tester.runAsync(() async {
        final notes = await db.thoughtDao.watchAllThoughts().first;
        expect(notes.where((n) => n.category == movies).length, 3);
      });
      await capture(tester, key, '/tmp/ascent-collection-entries.png');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Empty shortcuts remain editable and save directly from the card',
    (tester) async {
      await container
          .read(homeLayoutProvider.notifier)
          .save(HomeLayout.defaults().copyWith(shortcuts: []));
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: HomeShortcutPanel(
                  shortcuts: ref.watch(homeLayoutProvider).shortcuts,
                  badgeCounts: const {},
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('edit_home_shortcuts')));
      await settle(tester);
      await tester.tap(find.text('Focus'));
      await tester.tap(find.text('Save shortcuts'));
      await settle(tester);
      expect(container.read(homeLayoutProvider).shortcuts, ['focus']);
      expect(find.byKey(const ValueKey('shortcut_focus')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Category capture keeps the composer usable above the keyboard at large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(const ThoughtWallScreen(), scale: 2, keyboardInset: 300),
      );
      await settle(tester);
      expect(find.byType(TextField), findsOneWidget);
      expect(
        tester.getBottomRight(find.byType(TextField)).dy,
        lessThanOrEqualTo(544),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Shortcut editor actions sit above shell navigation', (tester) async {
    await tester.pumpWidget(app(Scaffold(body: Stack(children: [
      Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => Scaffold(
        body: Padding(padding: const EdgeInsets.all(24),
          child: HomeShortcutPanel(shortcuts: const [], badgeCounts: const {})),
      ))),
      Align(alignment: Alignment.bottomCenter, child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: const SizedBox(height: 160, width: double.infinity,
          child: ColoredBox(color: Colors.grey)),
      )),
    ]))));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('edit_home_shortcuts')));
    await settle(tester);
    await tester.tap(find.text('Save shortcuts'));
    await settle(tester);
    expect(find.text('Your shortcuts'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Collections fit a narrow phone with enlarged text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          app(const ThoughtWallScreen(), scale: 2, dark: dark),
        );
        await settle(tester);
        await tester.tap(
          find.byKey(const ValueKey('browse_thought_collections')),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
