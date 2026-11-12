import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/daily_briefing_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/daily_welcome_service.dart';
import 'package:ascent/features/home/widgets/daily_welcome_dialog.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _BriefingRefreshTick extends Notifier<int> {
  @override
  int build() => 0;
  void tick() => state++;
}

final _refreshTickProvider = NotifierProvider<_BriefingRefreshTick, int>(
  _BriefingRefreshTick.new,
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final day = DateTime(2026, 11, 9);
  final now = DateTime(2026, 11, 9, 8, 30);
  late AppDatabase db;
  late SharedPreferences prefs;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      dailyWelcomeSeenKey: day.toIso8601String(),
    });
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() async => db.close());

  Future<DailyBriefing> records() async {
    for (final row in [
      ('Review the API proposal', day, null, 25),
      ('Prepare interview notes', day.add(const Duration(hours: 14)), null, 40),
      (
        'Reply to the recruiter',
        day.subtract(const Duration(days: 1)),
        null,
        10,
      ),
      ('Read a chapter', null, null, 20),
      (
        'Finish the routing fix',
        day.subtract(const Duration(days: 1)),
        day.subtract(const Duration(hours: 12)),
        30,
      ),
    ]) {
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: row.$1,
          plannedDate: drift.Value(row.$2),
          actualCompletedDate: drift.Value(row.$3),
          estimatedMinutes: drift.Value(row.$4),
        ),
      );
    }
    await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Team catch-up',
        scheduledAt: day.add(const Duration(hours: 10, minutes: 30)),
      ),
    );
    return DailyBriefing.fromRecords(
      day: day,
      now: now,
      tasks: await db.taskDao.watchAllTasks().first,
      sessions: const [],
      reminders: await db.reminderDao.watchAllReminders().first,
    );
  }

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> snapshot(WidgetTester t, GlobalKey key, String name) async {
    await t.runAsync(() async {
      final img =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/qa/morning-brief/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      img.dispose();
    });
  }

  Widget app(
    DailyBriefing b, {
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
    GoRouter? router,
  }) {
    final theme = dark ? AscentTheme.dark() : AscentTheme.light();
    Widget builder(BuildContext context, Widget? child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    );
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        dailyBriefingProvider.overrideWith((ref, d) async => b),
      ],
      child: RepaintBoundary(
        key: capture,
        child: router != null
            ? MaterialApp.router(
                theme: theme,
                routerConfig: router,
                builder: builder,
              )
            : MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: builder,
                home: Builder(
                  builder: (host) => Scaffold(
                    body: DailyWelcomeDialog(
                      day: day,
                      now: now,
                      name: 'Arun Singh',
                      host: host,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  test(
    'briefing chooses real pending tasks, filters archives and schedules the next active reminder',
    () async {
      final b = await records();
      final tasks = await db.taskDao.watchAllTasks().first;
      final reminders = await db.reminderDao.watchAllReminders().first;
      final result = DailyBriefing.fromRecords(
        day: day,
        now: now,
        sessions: [],
        tasks: [
          tasks.first.copyWith(id: 999, isArchived: true),
          ...tasks.reversed,
        ],
        reminders: [
          reminders.first.copyWith(
            id: 77,
            scheduledAt: day.add(const Duration(hours: 7)),
          ),
          reminders.first.copyWith(
            id: 78,
            isActive: false,
            scheduledAt: day.add(const Duration(hours: 9)),
          ),
          reminders.first.copyWith(
            id: 79,
            scheduledAt: day.add(const Duration(days: 1)),
          ),
          ...reminders,
        ],
      );
      expect(result.dueToday, 2);
      expect(result.overdue, 1);
      expect(result.unscheduled, 1);
      expect(result.nextTask, 'Review the API proposal');
      expect(result.nextTaskId, b.nextTaskId);
      expect(result.focusTasks.map((t) => t.title), [
        'Review the API proposal',
        'Prepare interview notes',
        'Reply to the recruiter',
      ]);
      expect(result.firstOverdueTaskId, isNotNull);
      expect(result.firstUnscheduledTaskId, isNotNull);
      expect(result.remindersToday, 2);
      expect(result.nextReminder?.title, 'Team catch-up');
      final later = DailyBriefing.fromRecords(
        day: day,
        now: day.add(const Duration(hours: 23)),
        tasks: tasks,
        reminders: reminders,
        sessions: [],
      );
      expect(later.nextReminder, isNull);
      expect(later.remindersToday, 1);
    },
  );

  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('All three cards fit mobile, dark=$dark scale=$scale', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(
          scale == 1 ? 390 : 320,
          scale == 1 ? 844 : 780,
        );
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        final b = (await t.runAsync(records))!;
        final key = GlobalKey();
        await t.pumpWidget(app(b, dark: dark, scale: scale, capture: key));
        await settle(t);
        expect(
          find.text(
            scale == 1 ? 'Good morning,\nArun.' : 'Good morning\nArun.',
          ),
          findsOneWidget,
        );
        expect(find.text('Tasks due today'), findsOneWidget);
        await snapshot(t, key, 'overview-${dark ? 'dark' : 'light'}-$scale');
        for (final (tab, title) in [
          ('focus', 'One thing first.'),
          ('reset', 'A lighter plan.'),
        ]) {
          await t.tap(find.byKey(ValueKey('brief_tab_$tab')));
          await settle(t);
          expect(find.text(title), findsOneWidget);
          expect(t.takeException(), isNull);
          await snapshot(t, key, '$tab-${dark ? 'dark' : 'light'}-$scale');
        }
        await t.tap(find.byTooltip('Previous briefing card'));
        await settle(t);
        expect(find.text('One thing first.'), findsOneWidget);
        await t.drag(find.byType(PageView), const Offset(250, 0));
        await settle(t);
        expect(
          find.text(
            scale == 1 ? 'Good morning,\nArun.' : 'Good morning\nArun.',
          ),
          findsOneWidget,
        );
        expect(t.takeException(), isNull);
        expect(prefs.getString(dailyWelcomeSeenKey), day.toIso8601String());
        expect(
          (await t.runAsync(() => db.select(db.taskTable).get()))!.length,
          5,
        );
        await t.pumpWidget(const SizedBox());
        await t.pump();
      });
    }
  }
  testWidgets(
    'Empty brief offers a real first step without invented progress',
    (t) async {
      final b = DailyBriefing.fromRecords(day: day, tasks: [], sessions: []);
      final key = GlobalKey();
      await t.pumpWidget(app(b, capture: key));
      await settle(t);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
      expect(find.text('Rest'), findsNothing);
      expect(find.text('Recharged'), findsNothing);
      await t.tap(find.byKey(const ValueKey('brief_tab_focus')));
      await settle(t);
      expect(find.text('Add a task'), findsOneWidget);
      await snapshot(t, key, 'empty-focus');
      await t.tap(find.byKey(const ValueKey('brief_tab_reset')));
      await settle(t);
      expect(
        find.textContaining('No completed tasks or focus time recorded.'),
        findsOneWidget,
      );
      expect(find.text('Capture something'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );

  for (final action in ['task', 'reminder', 'calendar', 'carryover']) {
    testWidgets(
      'Brief $action action closes the popup and opens its actual target',
      (t) async {
        final b = (await t.runAsync(records))!;
        late BuildContext host;
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (ctx, _) {
                host = ctx;
                return Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        DailyWelcomeDialog.show(host, day: day, name: 'Arun'),
                    child: const Text('open'),
                  ),
                );
              },
            ),
            GoRoute(
              path: '/today',
              builder: (_, state) => Scaffold(
                body: Text('Task ${state.uri.queryParameters['task']}'),
              ),
            ),
            GoRoute(
              path: '/reminders',
              builder: (_, state) => Scaffold(
                body: Text(
                  'Reminder ${state.uri.queryParameters['reminder']} Calendar ${state.uri.queryParameters['view']}',
                ),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await t.pumpWidget(app(b, router: router));
        await t.tap(find.text('open'));
        await settle(t);
        if (action == 'task') {
          await t.tap(find.byKey(const ValueKey('brief_tab_focus')));
          await settle(t);
          await t.ensureVisible(find.text('Open this task'));
          await t.tap(find.text('Open this task'));
          await settle(t);
          expect(find.text('Task ${b.nextTaskId}'), findsOneWidget);
        } else if (action == 'carryover') {
          await t.tap(find.byKey(const ValueKey('brief_tab_reset')));
          await settle(t);
          await t.ensureVisible(find.text('1 carried-over task'));
          await t.tap(find.text('1 carried-over task'));
          await settle(t);
          expect(find.text('Task ${b.firstOverdueTaskId}'), findsOneWidget);
        } else if (action == 'reminder') {
          await t.ensureVisible(find.text('View reminder'));
          await t.tap(find.text('View reminder'));
          await settle(t);
          expect(
            find.text('Reminder ${b.nextReminder!.id} Calendar null'),
            findsOneWidget,
          );
        } else {
          await t.ensureVisible(find.text('Reminders today'));
          await t.tap(find.text('Reminders today'));
          await settle(t);
          expect(find.text('Reminder null Calendar calendar'), findsOneWidget);
        }
        expect(find.byType(DailyWelcomeDialog), findsNothing);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Live updates keep the selected card through reload and retry', (
    t,
  ) async {
    final b = (await t.runAsync(records))!;
    Completer<DailyBriefing>? gate;
    final container = ProviderContainer(
      overrides: [
        dailyBriefingProvider.overrideWith((ref, d) {
          ref.watch(_refreshTickProvider);
          return gate?.future ?? Future.value(b);
        }),
      ],
    );
    addTearDown(container.dispose);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: Builder(
            builder: (host) => Scaffold(
              body: DailyWelcomeDialog(
                day: day,
                now: now,
                name: 'Arun',
                host: host,
              ),
            ),
          ),
        ),
      ),
    );
    await settle(t);
    await t.tap(find.byKey(const ValueKey('brief_tab_focus')));
    await settle(t);
    expect(find.text('One thing first.'), findsOneWidget);
    await t.drag(
      find.byKey(const PageStorageKey('daily_brief_card_1')),
      const Offset(0, -120),
    );
    await settle(t);
    gate = Completer<DailyBriefing>();
    container.read(_refreshTickProvider.notifier).tick();
    await t.pump();
    expect(find.text('One thing first.'), findsOneWidget);
    gate.complete(
      DailyBriefing.fromRecords(
        day: day,
        sessions: [],
        tasks: b.focusTasks
            .map(
              (task) => task.id == b.nextTaskId
                  ? task.copyWith(title: 'Updated next step')
                  : task,
            )
            .toList(),
      ),
    );
    await settle(t);
    expect(find.text('Updated next step'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    gate = Completer<DailyBriefing>();
    container.read(_refreshTickProvider.notifier).tick();
    await t.pump();
    gate.completeError(StateError('reload failed'));
    await settle(t);
    expect(find.text('Retry'), findsOneWidget);
    gate = null;
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.text('One thing first.'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(
      t.widget<PageView>(find.byType(PageView)).controller!.page,
      closeTo(1, .01),
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('Failed brief exposes Retry and recovers without fake counters', (
    t,
  ) async {
    var tries = 0;
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          dailyBriefingProvider.overrideWith((ref, d) async {
            if (tries++ == 0) throw StateError('read failed');
            return DailyBriefing.fromRecords(day: day, tasks: [], sessions: []);
          }),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: Builder(
            builder: (host) => Scaffold(
              body: DailyWelcomeDialog(day: day, name: '', host: host),
            ),
          ),
        ),
      ),
    );
    await settle(t);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Tasks due today'), findsNothing);
    await t.tap(find.text('Retry'));
    await settle(t);
    expect(find.text('Tasks due today'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
  });
}
