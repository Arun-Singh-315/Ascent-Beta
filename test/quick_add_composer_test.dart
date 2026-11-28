import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

const _input = ValueKey('activity_quick_input');

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> mount(
    WidgetTester tester, {
    double scale = 1,
    bool dark = false,
  }) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final base = dark ? AscentTheme.dark() : AscentTheme.light();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: base,
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: ActivityComposer(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<List<Task>> tasks(WidgetTester tester) async =>
      (await tester.runAsync(() => db.select(db.taskTable).get()))!;

  testWidgets('typed details show as chips and are saved', (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(_input), 'gym 7am tomorrow 45m');
    await tester.pump();

    expect(find.byKey(const ValueKey('quick_add_chip_day')), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('7:00 AM'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);

    await tester.tap(find.byTooltip('Add activity'));
    await _settle(tester);

    final saved = (await tasks(tester)).single;
    expect(saved.title, 'gym');
    expect(saved.plannedDate, _day(1).add(const Duration(hours: 7)));
    expect(saved.estimatedMinutes, 45);
    expect(find.textContaining('Added “gym” for Tomorrow'), findsOneWidget);
  });

  testWidgets('Undo removes what quick add created', (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(_input), 'water plants tomorrow');
    await tester.pump();
    await tester.tap(find.byTooltip('Add activity'));
    await _settle(tester);
    expect(await tasks(tester), hasLength(1));

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(await tasks(tester), isEmpty);
  });

  testWidgets('removing a chip keeps its words in the title', (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(_input), 'buy tickets tomorrow');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quick_add_chip_day')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick_add_chip_day')), findsNothing);

    await tester.tap(find.byTooltip('Add activity'));
    await _settle(tester);
    final saved = (await tasks(tester)).single;
    expect(saved.title, 'buy tickets tomorrow');
    expect(DateUtils.isSameDay(saved.plannedDate, DateTime.now()), isTrue);
  });

  testWidgets('a plain title still saves with one tap for today', (
    tester,
  ) async {
    await mount(tester);
    await tester.enterText(find.byKey(_input), 'Buy milk');
    await tester.pump();
    expect(find.byKey(const ValueKey('quick_add_chip_day')), findsNothing);
    await tester.tap(find.byTooltip('Add activity'));
    await _settle(tester);
    final saved = (await tasks(tester)).single;
    expect(saved.title, 'Buy milk');
    expect(saved.estimatedMinutes, isNull);
    expect(DateUtils.isSameDay(saved.plannedDate, DateTime.now()), isTrue);
  });

  testWidgets('"!" stars the to-do', (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(_input), 'file taxes !');
    await tester.pump();
    expect(find.text('Starred'), findsOneWidget);
    await tester.tap(find.byTooltip('Add activity'));
    await _settle(tester);
    final saved = (await tasks(tester)).single;
    expect(saved.title, 'file taxes');
    expect(saved.priority, 'high');
  });

  testWidgets('lists are saved as separate plain to-dos', (tester) async {
    await mount(tester);
    await tester.enterText(find.byKey(_input), '- eggs tomorrow\n- bread');
    await tester.pump();
    expect(find.byKey(const ValueKey('quick_add_chip_day')), findsNothing);
    await tester.tap(find.byTooltip('Add activity'));
    await _settle(tester);
    final titles = (await tasks(tester)).map((t) => t.title).toList();
    expect(titles, containsAll(['eggs tomorrow', 'bread']));
  });

  for (final dark in [false, true]) {
    testWidgets('chips fit 320 px at 2.0x text (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await mount(tester, scale: 2, dark: dark);
      await tester.enterText(
        find.byKey(_input),
        'long planning session next friday 9:30am 1h 30m remind me !',
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('1 h 30 min'), findsOneWidget);
    });
  }
}
