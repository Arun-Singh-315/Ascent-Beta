import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/ai/riya_productivity.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/promises/promise_providers.dart';
import 'package:ascent/core/promises/promise_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/promises/promise_sheet.dart';
import 'package:ascent/features/promises/promises_screen.dart';
import 'package:ascent/features/promises/widgets/home_promise_card.dart';
import 'package:drift/drift.dart' show Value;
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
  late PromiseService service;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        promiseNudgerProvider.overrideWithValue(null),
      ],
    );
    service = PromiseService(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app({
    Widget child = const HomePromiseCard(),
    bool dark = false,
    double scale = 1,
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: dark ? AscentTheme.dark() : AscentTheme.light(),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: c!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('no promises: an invitation whose starters create one', (
    t,
  ) async {
    await t.pumpWidget(app());
    await flush(t);
    expect(find.text('Make a promise to yourself'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('promise_starter_Read 10 pages')));
    await flush(t);
    expect(find.text('Read 10 pages'), findsOneWidget);
    expect(find.byKey(const ValueKey('promise_kept')), findsOneWidget);
    expect(find.text('Promise · Day 1 of 21'), findsOneWidget);
  });

  testWidgets('Kept it fills today, and Undo opens it again', (t) async {
    await t.runAsync(() => service.create(title: 'Walk 20 minutes'));
    await t.pumpWidget(app());
    await flush(t);
    await t.tap(find.byKey(const ValueKey('promise_kept')));
    await flush(t);
    expect(find.text('Kept today. See you tomorrow.'), findsOneWidget);
    final view = (await t.runAsync(() => service.loadAll()))!.single;
    expect(view.progress.keptToday, isTrue);
    await t.tap(find.byKey(const ValueKey('promise_undo')));
    await flush(t);
    expect(find.byKey(const ValueKey('promise_kept')), findsOneWidget);
  });

  testWidgets('Not today is gentle and uses a grace day', (t) async {
    await t.runAsync(() => service.create(title: 'Walk'));
    await t.pumpWidget(app());
    await flush(t);
    await t.tap(find.byKey(const ValueKey('promise_missed')));
    await flush(t);
    expect(
      find.text('Not today. A grace day keeps your streak safe.'),
      findsOneWidget,
    );
  });

  testWidgets('yesterday can be answered the next day', (t) async {
    final id = await t.runAsync(() => service.create(title: 'Walk'));
    await t.runAsync(
      () => (db.update(db.promiseTable)..where((p) => p.id.equals(id!))).write(
        PromiseTableCompanion(
          startDay: Value(
            dayOf(DateTime.now().subtract(const Duration(days: 1))),
          ),
        ),
      ),
    );
    await t.pumpWidget(app());
    await flush(t);
    expect(find.text('How did yesterday go?'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('promise_yesterday_kept')));
    await flush(t);
    expect(find.byKey(const ValueKey('promise_kept')), findsOneWidget);
    expect(find.text('Promise · Day 2 of 21'), findsOneWidget);
  });

  testWidgets('more promises show as compact rows with a round check', (
    t,
  ) async {
    await t.runAsync(() async {
      await service.create(title: 'Walk');
      await service.create(title: 'Read');
      await service.create(title: 'Sleep by 11');
    });
    await t.pumpWidget(app());
    await flush(t);
    expect(find.text('Walk'), findsOneWidget);
    final rows = (await t.runAsync(() => service.loadAll()))!;
    final read = rows.firstWhere((p) => p.title == 'Read');
    await t.tap(find.byKey(ValueKey('promise_check_${read.id}')));
    await flush(t);
    expect(
      (await t.runAsync(() => service.get(read.id)))!.progress.keptToday,
      isTrue,
    );
  });

  testWidgets('more than four promises offer Show all', (t) async {
    await t.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await service.create(title: 'Promise $i');
      }
    });
    await t.pumpWidget(app());
    await flush(t);
    expect(find.text('Show all 6'), findsOneWidget);
  });

  testWidgets('the sheet makes a promise from one field', (t) async {
    await t.pumpWidget(app());
    await flush(t);
    await t.tap(find.byKey(const ValueKey('promise_make')));
    await flush(t);
    await t.enterText(
      find.byKey(const ValueKey('promise_title')),
      'I promise to stretch',
    );
    await t.tap(find.byKey(const ValueKey('promise_length_7')));
    await t.tap(find.byKey(const ValueKey('promise_save')));
    await flush(t);
    expect(find.byType(PromiseSheet), findsNothing);
    final view = (await t.runAsync(() => service.loadAll()))!.single;
    expect(view.title, 'Stretch');
    expect(view.promise.lengthDays, 7);
    expect(find.text('Promise · Day 1 of 7'), findsOneWidget);
  });

  testWidgets('the detail opens from the card', (t) async {
    final id = await t.runAsync(() => service.create(title: 'Walk'));
    await t.pumpWidget(app());
    await flush(t);
    await t.tap(find.byKey(ValueKey('promise_open_$id')));
    await flush(t);
    expect(find.byType(PromiseDetailSheet), findsOneWidget);
    expect(find.text('Best streak'), findsOneWidget);
    expect(find.text('Every day'), findsOneWidget);
  });

  testWidgets('the Promises screen lists active and past', (t) async {
    await t.runAsync(() async {
      await service.create(title: 'Walk');
      final old = await service.create(title: 'Read');
      await service.release(old);
    });
    await t.pumpWidget(
      app(child: const SizedBox(height: 900, child: PromisesScreen())),
    );
    await flush(t);
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Past'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('fits 320 px at text scale 2 (${dark ? 'dark' : 'light'})', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 1400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.runAsync(() async {
        await service.create(
          title: 'No phone after 10 pm and read a real book instead',
        );
        await service.create(title: 'Walk 20 minutes');
      });
      await t.pumpWidget(app(dark: dark, scale: 2));
      await flush(t);
      expect(t.takeException(), isNull);
    });
  }

  group('assistant', () {
    test('makes and lists promises', () async {
      final actions = RiyaPromiseActions(db, DateTime.now);
      final made = await actions.run(
        const RiyaCommand('promises.create', {
          'title': 'walk daily',
          'lengthDays': 30,
        }),
      );
      expect(made.route, '/promises');
      final listed = await actions.run(const RiyaCommand('promises.list', {}));
      expect(listed.message, contains('Walk daily: day 1 of 30'));
      expect(riyaPromiseCapabilities.map((c) => c.id), [
        'promises.create',
        'promises.list',
      ]);
    });
  });
}
