import 'dart:io';
import 'package:ascent/app/theme/home_design.dart';
import 'package:drift/drift.dart' show Value;
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/monochrome_surfaces.dart';
import 'package:ascent/shared/widgets/ascent_calendar_day.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/local_day_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_calendar.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  final today = DateTime(2026, 11, 9);
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Reminders & Alerts': true,
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        localDayProvider.overrideWithValue(today),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app({
    bool dark = false,
    bool neutralHome = true,
    double scale = 1,
    GlobalKey? capture,
    GoRouter? router,
  }) {
    final base = dark ? AscentTheme.dark() : AscentTheme.light();
    final theme = neutralHome ? HomeTheme.from(base) : base;
    Widget builder(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    );
    return UncontrolledProviderScope(
      container: container,
      child: RepaintBoundary(
        key: capture,
        child: router != null
            ? MaterialApp.router(
                debugShowCheckedModeBanner: false,
                theme: theme,
                routerConfig: router,
                builder: builder,
              )
            : MaterialApp(
                theme: theme,
                debugShowCheckedModeBanner: false,
                builder: builder,
                home: const Scaffold(
                  body: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: HomeCalendar(),
                  ),
                ),
              ),
      ),
    );
  }

  testWidgets(
    'Today and scheduled content remain distinct without selecting Home dates',
    (t) async {
      final semantics = t.ensureSemantics();
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Morning review',
          scheduledAt: today.add(const Duration(hours: 9)),
        ),
      );
      await t.pumpWidget(app());
      await settle(t);
      final todayTile = find.byKey(
        const ValueKey('home_calendar_day_2026-11-09'),
      );
      final presentation = t.widget<AscentCalendarDay>(todayTile);
      expect(presentation.today, isTrue);
      expect(presentation.selected, isFalse);
      expect(presentation.hasScheduledItems, isTrue);
      expect(
        find.bySemanticsLabel(
          RegExp('Monday, November 9, 2026, Today, Has scheduled items'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tap a date to see your day.'), findsNothing);
      final disc = t.getSize(
        find.byKey(const ValueKey('calendar_disc_2026_11_9')),
      );
      final tile = t.getSize(todayTile);
      expect(disc.width, lessThan(tile.width));
      expect(disc.height, lessThan(tile.height / 2));
      semantics.dispose();
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Calendar fits mobile and large text: dark=$dark scale=$scale',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(scale == 1 ? 390 : 320, 1000);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.view.resetPhysicalSize);
          final capture = GlobalKey();
          await t.pumpWidget(app(dark: dark, scale: scale, capture: capture));
          await settle(t);
          expect(
            find.byKey(const ValueKey('home_calendar_open')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('home_calendar_day_2026-11-09')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await t.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final out = File(
              'build/qa/home-calendar/${dark ? 'dark' : 'light'}-$scale.png',
            );
            await out.parent.create(recursive: true);
            await out.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await t.tap(find.byTooltip('Previous week'));
          await settle(t);
          expect(
            find.byKey(const ValueKey('home_calendar_day_2026-11-02')),
            findsOneWidget,
          );
          await t.tap(find.text('Back to today'));
          await settle(t);
          expect(
            find.byKey(const ValueKey('home_calendar_day_2026-11-09')),
            findsOneWidget,
          );
          for (var i = 0; i < 4; i++) {
            await t.tap(find.byTooltip('Next week'));
            await settle(t);
          }
          expect(
            find.byKey(const ValueKey('home_calendar_day_2026-12-07')),
            findsOneWidget,
          );
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Full calendar is readable and selection preserves data: dark=$dark scale=$scale',
        (t) async {
          t.view.devicePixelRatio = 1;
          t.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          addTearDown(t.view.resetDevicePixelRatio);
          addTearDown(t.view.resetPhysicalSize);
          final now = DateTime.now();
          final day = DateTime(now.year, now.month, now.day);
          final reminderId = await db.reminderDao.insertReminder(
            ReminderTableCompanion.insert(
              title: 'Read-only calendar review',
              scheduledAt: day.add(const Duration(hours: 23)),
            ),
          );
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => RemindersScreen(
                  openCalendar: true,
                  calendarOnly: true,
                  initialCalendarDate: day,
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          final capture = GlobalKey();
          await t.pumpWidget(
            app(
              dark: dark,
              scale: scale,
              capture: capture,
              router: router,
              neutralHome: false,
            ),
          );
          await settle(t);
          final calendar = find.byKey(
            const ValueKey('reminders_calendar_card'),
          );
          expect(calendar, findsOneWidget);
          final scoped = Theme.of(t.element(calendar));
          expect(scoped.extension<MonochromeSurfaces>(), isNotNull);
          expect(
            scoped.scaffoldBackgroundColor,
            (dark ? const HomeDesign.night() : const HomeDesign.day()).canvas,
          );
          final todayKey = ValueKey(
            'calendar_day_${day.year}_${day.month}_${day.day}',
          );
          final current = t.widget<AscentCalendarDay>(find.byKey(todayKey));
          expect(current.today, isTrue);
          expect(current.selected, isTrue);
          expect(current.hasScheduledItems, isTrue);
          expect(
            find.byKey(const ValueKey('calendar_accessible_week')),
            scale == 2 ? findsOneWidget : findsNothing,
          );
          await t.runAsync(() async {
            final image =
                await (capture.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final out = File(
              'build/qa/monochrome-calendar/${dark ? 'dark' : 'light'}-$scale.png',
            );
            await out.parent.create(recursive: true);
            await out.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          if (scale == 1) {
            await t.tap(find.byKey(const ValueKey('calendar_expand_toggle')));
            await settle(t);
            await t.tap(find.byKey(const ValueKey('calendar_next_month')));
            await settle(t);
            final firstNextMonth = DateTime(day.year, day.month + 1, 1);
            expect(
              find.byKey(
                ValueKey(
                  'calendar_day_${firstNextMonth.year}_${firstNextMonth.month}_1',
                ),
              ),
              findsOneWidget,
            );
            await t.tap(find.byKey(const ValueKey('calendar_today_button')));
            await settle(t);
          }
          final other = DateTime(
            day.year,
            day.month,
            day.day + (day.weekday == 7 ? -1 : 1),
          );
          final otherKey = ValueKey(
            'calendar_day_${other.year}_${other.month}_${other.day}',
          );
          await t.ensureVisible(find.byKey(otherKey));
          await settle(t);
          await t.tap(find.byKey(otherKey));
          await settle(t);
          expect(
            t.widget<AscentCalendarDay>(find.byKey(otherKey)).selected,
            isTrue,
          );
          expect(
            t.widget<AscentCalendarDay>(find.byKey(todayKey)).selected,
            isFalse,
          );
          expect(
            t.widget<AscentCalendarDay>(find.byKey(todayKey)).today,
            isTrue,
          );
          await t.ensureVisible(
            find.byKey(const ValueKey('calendar_next_month')),
          );
          await settle(t);
          await t.tap(find.byKey(const ValueKey('calendar_next_month')));
          await settle(t);
          final next = DateTime(day.year, day.month + 1, 1);
          final nextDate = find.byKey(
            ValueKey('calendar_day_${next.year}_${next.month}_1'),
          );
          expect(nextDate, findsOneWidget);
          await t.ensureVisible(nextDate);
          await settle(t);
          await t.tap(nextDate);
          await settle(t);
          expect(t.widget<AscentCalendarDay>(nextDate).selected, isTrue);
          await t.ensureVisible(
            find.byKey(const ValueKey('calendar_today_button')),
          );
          await settle(t);
          await t.tap(find.byKey(const ValueKey('calendar_today_button')));
          await settle(t);
          expect(
            t.widget<AscentCalendarDay>(find.byKey(todayKey)).selected,
            isTrue,
          );
          if (scale == 2) {
            await t.tap(find.byKey(const ValueKey('calendar_next_week')));
            await settle(t);
            final nextWeek = DateTime(day.year, day.month, day.day + 7);
            expect(
              t
                  .widget<AscentCalendarDay>(
                    find.byKey(
                      ValueKey(
                        'calendar_day_${nextWeek.year}_${nextWeek.month}_${nextWeek.day}',
                      ),
                    ),
                  )
                  .selected,
              isTrue,
            );
          }
          expect(
            find.byKey(const ValueKey('reminders_view_mode_toggle')),
            findsNothing,
          );
          expect(
            find.byKey(const ValueKey('calendar_month_summary')),
            findsOneWidget,
          );
          final saved = await t.runAsync(
            () => db.reminderDao.getReminderById(reminderId),
          );
          expect(saved!.isActive, isTrue);
          expect(saved.title, 'Read-only calendar review');
          expect(t.takeException(), isNull);
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets(
    'Things scope excludes reminders, keeps future tasks, and adds on the selected day',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final date = DateTime(2026, 11, 12);
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Future thing',
          plannedDate: Value(date),
        ),
      );
      final reminderId = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Separate reminder',
          scheduledAt: date,
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => RemindersScreen(
              calendarOnly: true,
              openCalendar: true,
              thingsOnly: true,
              initialCalendarDate: date,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await t.pumpWidget(app(router: router));
      await settle(t);
      expect(
        find.byKey(ValueKey('calendar_reminder_tile_$reminderId')),
        findsNothing,
      );
      await t.scrollUntilVisible(
        find.byKey(ValueKey('calendar_task_tile_$taskId')),
        180,
      );
      expect(find.text('Future thing'), findsOneWidget);
      expect(find.text('Separate reminder'), findsNothing);
      await t.ensureVisible(find.text('Add'));
      await t.tap(find.text('Add'));
      await settle(t);
      expect(
        t.widget<AddActivitySheet>(find.byType(AddActivitySheet)).initialDate,
        date,
      );
      expect(
        (await t.runAsync(() => db.select(db.taskTable).get()))!.length,
        1,
      );
      expect(
        (await t.runAsync(() => db.select(db.reminderTable).get()))!.length,
        1,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('A Home date opens its full calendar and actual saved agenda', (
    t,
  ) async {
    await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Review the week',
        scheduledAt: DateTime(2026, 11, 12, 14),
      ),
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: HomeCalendar()),
        ),
        GoRoute(
          path: '/calendar',
          builder: (_, state) => RemindersScreen(
            openCalendar: true,
            calendarOnly: true,
            initialCalendarDate: DateTime.tryParse(
              state.uri.queryParameters['date'] ?? '',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await t.pumpWidget(app(router: router));
    await settle(t);
    expect(
      find.bySemanticsLabel(
        RegExp('Thursday, November 12, 2026, Has scheduled items'),
      ),
      findsOneWidget,
    );
    await t.tap(find.byKey(const ValueKey('home_calendar_day_2026-11-12')));
    await settle(t);
    expect(
      GoRouterState.of(
        t.element(find.byType(RemindersScreen)),
      ).uri.queryParameters['date'],
      '2026-11-12',
    );
    expect(
      find.byKey(const ValueKey('reminders_calendar_card')),
      findsOneWidget,
    );
    expect(find.text('Review the week'), findsOneWidget);
    expect(t.takeException(), isNull);
    router.pop();
    await settle(t);
    expect(find.byKey(const ValueKey('home_calendar')), findsOneWidget);
    expect(
      (await t.runAsync(() => db.select(db.reminderTable).get()))!.length,
      1,
    );
    await t.pumpWidget(const SizedBox());
  });
}
