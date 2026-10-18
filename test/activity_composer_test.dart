import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> settleDatabase(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  Future<void> mount(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: HomeTheme.from(
            AscentTheme.light(preset: DayThemePreset.nordicSky),
          ),
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

  testWidgets(
    'type and send defaults to To-do today, no reminder; rapid send creates one record',
    (tester) async {
      await mount(tester);
      expect(
        tester.widget<IconButton>(find.byType(IconButton)).onPressed,
        isNull,
      );
      expect(find.text('To-do'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Reminder off'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('activity_quick_input')),
        '  Quick task  ',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Add activity'));
      await tester.tap(find.byTooltip('Add activity'));
      await settleDatabase(tester);
      final tasks = await tester.runAsync(() => db.select(db.taskTable).get());
      expect(tasks, hasLength(1));
      expect(tasks!.single.title, 'Quick task');
      expect(tasks.single.estimatedMinutes, isNull);
      expect(
        DateUtils.isSameDay(tasks.single.plannedDate, DateTime.now()),
        isTrue,
      );
      expect(
        await tester.runAsync(() => db.select(db.reminderTable).get()),
        isEmpty,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('activity_quick_input')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'timer choice reveals duration; cancelled/invalid duration stays safe; tomorrow persists',
    (tester) async {
      await mount(tester);
      await tester.tap(find.byTooltip('Activity type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timer').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('30 min'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('Enter 1–1440 minutes.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('30 min'), findsOneWidget);
      await tester.tap(find.byTooltip('Activity date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tomorrow').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('activity_quick_input')),
        'Practice',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Add activity'));
      await settleDatabase(tester);
      final tasks = await tester.runAsync(() => db.select(db.taskTable).get());
      expect(tasks!.single.estimatedMinutes, 30);
      expect(
        DateUtils.isSameDay(
          tasks.single.plannedDate,
          DateTime.now().add(const Duration(days: 1)),
        ),
        isTrue,
      );
      expect(find.text('To-do'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Reminder off'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets('cancelled reminder stays off; options fit at 2x text', (
    tester,
  ) async {
    await mount(tester, scale: 2);
    await tester.tap(find.byTooltip('Activity reminder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reminder off'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('failed save retains text and retry creates exactly one activity', (
    tester,
  ) async {
    await tester.runAsync(
      () => db.customStatement(
        "CREATE TRIGGER fail_task BEFORE INSERT ON tasks BEGIN SELECT RAISE(ABORT, 'test failure'); END;",
      ),
    );
    await mount(tester);
    await tester.enterText(
      find.byKey(const ValueKey('activity_quick_input')),
      'Retry me',
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Add activity'));
    await settleDatabase(tester);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('activity_quick_input')))
          .controller!
          .text,
      'Retry me',
    );
    expect(find.textContaining('Your text is still here'), findsOneWidget);
    expect(await tester.runAsync(() => db.select(db.taskTable).get()), isEmpty);
    await tester.runAsync(() => db.customStatement('DROP TRIGGER fail_task'));
    await tester.tap(find.byTooltip('Add activity'));
    await settleDatabase(tester);
    expect(
      await tester.runAsync(() => db.select(db.taskTable).get()),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
