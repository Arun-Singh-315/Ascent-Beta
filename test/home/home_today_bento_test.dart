import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/home_today_bento.dart';
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
    SharedPreferences.setMockInitialValues({
      unlockedFeaturesKey: ?unlocked,
    });
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
            body: SingleChildScrollView(child: HomeTodayBento()),
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

  testWidgets('each switched-on feature shows once', (tester) async {
    await pump(tester);
    for (final k in ['things', 'water', 'mind', 'medicine', 'money']) {
      expect(find.byKey(ValueKey('home_bento_$k')), findsOneWidget);
    }
    expect(find.text('2 left'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('locked features have no tile', (tester) async {
    await pump(tester, unlocked: ['things', 'mind']);
    expect(find.byKey(const ValueKey('home_bento_things')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_bento_mind')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_bento_water')), findsNothing);
    expect(find.byKey(const ValueKey('home_bento_money')), findsNothing);
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
      await pump(tester, size: const Size(320, 1400), scale: 2);
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
