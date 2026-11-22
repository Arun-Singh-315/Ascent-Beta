import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/home_feed_cards.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem _a(int id, {bool done = false}) => TodayActivityItem(
  id: 'task_$id',
  title: 'Thing $id',
  sourceType: 'task',
  status: done ? TodayActivityStatus.done : TodayActivityStatus.notStarted,
  elapsedSecondsToday: 0,
  categoryTag: 'Task',
  linkedTaskId: id,
  plannedDate: DateTime.now(),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<AppDatabase> pump(
    WidgetTester tester, {
    List<String>? unlocked,
    Size size = const Size(390, 900),
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({unlockedFeaturesKey: ?unlocked});
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
          todayActivitiesProvider.overrideWith(
            (ref) => Stream.value([_a(1), _a(2), _a(3, done: true)]),
          ),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [HomeThingsCard(), HomeMindCard(), HomeLifeTiles()],
              ),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    return db;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Things and Mind are hero cards with their own input', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('home_things_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_mind_card')), findsOneWidget);
    expect(find.text('Thing 1'), findsOneWidget);
    expect(find.text('2 left · 1 done'), findsOneWidget);
    // New items come in through the Capture card; no inputs here.
    expect(find.byKey(const ValueKey('activity_quick_input')), findsNothing);
    expect(find.byKey(const ValueKey('home_mind_field')), findsNothing);
    expect(find.byKey(const ValueKey('home_mind_empty')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_day_card')), findsOneWidget);
    for (final k in ['water', 'medicine', 'money', 'focus']) {
      expect(find.byKey(ValueKey('home_bento_$k')), findsOneWidget);
    }
    await unmount(tester);
  });

  testWidgets('a saved thought shows as a bubble with when it was', (
    tester,
  ) async {
    final db = await pump(tester);
    await tester.runAsync(
      () => db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Buy basil'),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Buy basil'), findsOneWidget);
    expect(find.text('Just now'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('a checklist thought shows ticks, not raw markdown', (
    tester,
  ) async {
    final db = await pump(tester);
    await tester.runAsync(
      () => db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: '- [x] Lemon tea\n- [ ] Study 45m\n- [ ] Walk',
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Lemon tea'), findsOneWidget);
    expect(find.textContaining('[x]'), findsNothing);
    expect(find.textContaining('1/3 done'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Your day is a bordered card with outlined icons', (
    tester,
  ) async {
    await pump(tester);
    final box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey('home_day_card')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final deco = box.decoration as BoxDecoration;
    expect(deco.border, isNotNull);
    expect(deco.gradient, isNull);
    await unmount(tester);
  });

  testWidgets('locked features have no card', (tester) async {
    await pump(tester, unlocked: ['things']);
    expect(find.byKey(const ValueKey('home_things_card')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_mind_card')), findsNothing);
    expect(find.byKey(const ValueKey('home_bento_water')), findsNothing);
    await unmount(tester);
  });

  testWidgets('water plus logs 250 ml in one tap', (tester) async {
    final db = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('home_bento_water_add')));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final logs = await tester.runAsync(() => db.select(db.waterLogTable).get());
    expect(logs!.single.amountMl, 250);
    await unmount(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('320 px at 2x text has no overflow (dark=$dark)', (
      tester,
    ) async {
      await pump(tester, size: const Size(320, 2600), scale: 2);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
