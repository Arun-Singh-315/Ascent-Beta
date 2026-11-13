import 'dart:io';
import 'package:ascent/app/theme/home_design.dart';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_shortcut_editor.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
import 'package:ascent/features/home/widgets/home_shortcut_summary.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/features/money/add_transaction_sheet.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'package:ascent/features/thought_wall/drop_thought_sheet.dart';
import 'package:ascent/features/promises/widgets/promise_chat_composer.dart';
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
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        homeShortcutSummaryProvider.overrideWith(
          (ref, id) => id == 'vault' ? 'Locked' : '12 today',
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(
    WidgetTester tester, {
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
  }) async {
    tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: capture,
          child: MaterialApp(
            theme: HomeTheme.from(
              dark ? AscentTheme.dark() : AscentTheme.light(),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: HomeShortcutPanel(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester, String action) async {
    await tester.tap(find.byTooltip('Your space actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add something'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final pic =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await pic.toByteData(format: ui.ImageByteFormat.png);
      await Directory(
        '/tmp/ascent-shortcut-visibility',
      ).create(recursive: true);
      await File(
        '/tmp/ascent-shortcut-visibility/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      pic.dispose();
    });
  }

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Expense from Home has an opaque form and readable dropdown: dark=$dark scale=$scale',
        (tester) async {
          final key = GlobalKey();
          await mount(tester, dark: dark, scale: scale, capture: key);
          expect(
            find.byKey(const ValueKey('shortcut_badge_vault')),
            findsNothing,
          );
          final badge = tester.widget<Text>(
            find.byKey(const ValueKey('shortcut_badge_focus')),
          );
          expect(
            badge.style!.color,
            (dark ? const HomeDesign.night() : const HomeDesign.day())
                .primaryText,
          );
          await add(tester, 'Expense');
          expect(find.byType(AddTransactionSheet), findsOneWidget);
          final pane = tester.widget<Material>(
            find
                .ancestor(
                  of: find.byType(AddTransactionSheet),
                  matching: find.byType(Material),
                )
                .first,
          );
          expect(pane.color!.a, 1);
          await capture(
            tester,
            key,
            'expense-${dark ? 'dark' : 'light'}-$scale',
          );
          await tester.tap(find.text('Details'));
          await tester.pumpAndSettle();
          final category = find.byType(DropdownButtonFormField<String>).first;
          await tester.ensureVisible(category);
          await tester.tap(category);
          await tester.pumpAndSettle();
          expect(find.text('Food & Groceries'), findsWidgets);
          final dropdown = tester.widget<DropdownButton<String>>(
            find.descendant(
              of: category,
              matching: find.byType(DropdownButton<String>),
            ),
          );
          expect(dropdown.dropdownColor!.a, 1);
          await capture(
            tester,
            key,
            'dropdown-${dark ? 'dark' : 'light'}-$scale',
          );
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(8, 8));
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byTooltip('Close'));
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
          expect(
            await tester.runAsync(
              () => db.select(db.financeTransactionTable).get(),
            ),
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  testWidgets(
    'All shortcut choices remain selectable and saving Money persists only preferences',
    (tester) async {
      await container
          .read(homeLayoutProvider.notifier)
          .save(HomeLayout.defaults().copyWith(shortcuts: []));
      await mount(tester);
      final context = tester.element(find.byType(HomeShortcutPanel));
      showHomeShortcutEditor(context);
      await tester.pumpAndSettle();
      final surface = find.byKey(
        const ValueKey('home_shortcut_editor_surface'),
      );
      expect(tester.widget<Material>(surface).color!.a, 1);
      for (final entry in homeShortcutRoutes.entries) {
        final choice = find.descendant(
          of: surface,
          matching: find.text(entry.value),
        );
        await tester.ensureVisible(choice);
        await tester.tap(choice);
        await tester.pumpAndSettle();
        expect(
          find.text('Remove a shortcut before adding another.'),
          findsNothing,
        );
        await tester.tap(choice);
        await tester.pumpAndSettle();
      }
      final money = find.descendant(of: surface, matching: find.text('Money'));
      await tester.ensureVisible(money);
      await tester.tap(money);
      final save = find.text('Save shortcuts');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(container.read(homeLayoutProvider).shortcuts, ['money']);
      expect(
        await tester.runAsync(
          () => db.select(db.financeTransactionTable).get(),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Expense captured from Home saves one transaction and closes', (
    tester,
  ) async {
    await mount(tester);
    await add(tester, 'Expense');
    final fields = find.descendant(
      of: find.byType(AddTransactionSheet),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), '125.50');
    await tester.enterText(fields.at(1), 'Visibility regression expense');
    await tester.tap(find.text('Save transaction'));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final rows = await tester.runAsync(
      () => db.select(db.financeTransactionTable).get(),
    );
    expect(rows, hasLength(1));
    expect(rows!.single.amount, 125.50);
    expect(rows.single.title, 'Visibility regression expense');
    expect(find.byType(AddTransactionSheet), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  for (final entry in [
    ('Activity', AddActivitySheet),
    ('Thought', DropThoughtSheet),
    ('Commitment', PromiseChatComposer),
  ]) {
    testWidgets('${entry.$1} opens from Home with an opaque surface', (
      tester,
    ) async {
      await mount(tester);
      await add(tester, entry.$1);
      final form = find.byType(entry.$2);
      expect(form, findsOneWidget);
      // Each composer owns a painted pane, never bare fields above Home.
      final panes = find.descendant(
        of: form,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Material && w.color?.a == 1 ||
              w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration as BoxDecoration).color?.a == 1,
        ),
      );
      expect(panes, findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
