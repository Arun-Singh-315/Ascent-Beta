import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:ascent/features/today/things_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleTimer extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _NoStreak extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 0,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

TodayActivityItem _item(
  String title, {
  int? taskId,
  DateTime? planned,
  bool overdue = false,
  bool daily = false,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
}) => TodayActivityItem(
  id: 'task_${taskId ?? title.hashCode}',
  title: title,
  sourceType: 'task',
  status: status,
  elapsedSecondsToday: 0,
  categoryTag: 'Task',
  linkedTaskId: taskId ?? title.hashCode,
  plannedDate: planned,
  isOverdue: overdue,
  isDailyStanding: daily,
  completedAt: status == TodayActivityStatus.done ? DateTime.now() : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpHub(
    WidgetTester tester, {
    List<TodayActivityItem> today = const [],
    List<TodayActivityItem> upcoming = const [],
    String? tab,
    bool dark = false,
    double scale = 1,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(_IdleTimer.new),
          studyStreakProvider.overrideWith(_NoStreak.new),
          todayActivitiesProvider.overrideWith((ref) => Stream.value(today)),
          upcomingThingsProvider.overrideWith((ref) => Stream.value(upcoming)),
        ],
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ThingsHubScreen(initialTab: tab),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('shows the four segments and switches between them', (
    tester,
  ) async {
    await pumpHub(
      tester,
      today: [
        _item('Pay rent', planned: _day(0)),
        _item('Buy stamps'),
        _item('Stretch', daily: true),
      ],
      upcoming: [_item('Dentist', planned: _day(1))],
    );
    for (final label in ['Today', 'Upcoming', 'Anytime', 'Routines']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Pay rent'), findsOneWidget);
    expect(find.text('Buy stamps'), findsNothing, reason: 'anytime only');

    await tester.tap(find.byKey(const ValueKey('things_segment_upcoming')));
    await settle(tester);
    expect(find.text('Tomorrow · 1'), findsOneWidget);
    expect(find.text('Dentist'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('things_segment_anytime')));
    await settle(tester);
    expect(find.text('Buy stamps'), findsOneWidget);
    expect(find.text('Pay rent'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('things_segment_routines')));
    await settle(tester);
    expect(find.text('Stretch'), findsOneWidget);
    expect(find.text('Plans and routines'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('legacy deep links open the matching segment', (tester) async {
    await pumpHub(
      tester,
      tab: 'done',
      today: [_item('Finished it', status: TodayActivityStatus.done)],
    );
    expect(find.text('Completed · 1'), findsOneWidget);
    expect(find.text('Finished it'), findsOneWidget, reason: 'done expands');
    await unmount(tester);

    await pumpHub(tester, tab: 'plans');
    expect(find.text('Plans and routines'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('completed things stay collapsed until opened', (tester) async {
    await pumpHub(
      tester,
      today: [
        _item('Still to do', planned: _day(0)),
        _item('Already done', status: TodayActivityStatus.done),
      ],
    );
    expect(find.text('Completed · 1'), findsOneWidget);
    expect(find.text('Already done'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('things_completed_toggle')));
    await settle(tester);
    expect(find.text('Already done'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('"Move all to today" moves overdue tasks and Undo restores', (
    tester,
  ) async {
    final twoDaysAgo = _day(-2).add(const Duration(hours: 9));
    final id = await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Renew passport',
        plannedDate: Value(twoDaysAgo),
      ),
    );
    await pumpHub(
      tester,
      today: [
        _item('Renew passport', taskId: id, planned: twoDaysAgo, overdue: true),
      ],
    );
    expect(find.text('Overdue · 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('things_move_overdue')));
    await settle(tester);

    var task = await db.taskDao.getTaskById(id);
    expect(task!.plannedDate, _day(0).add(const Duration(hours: 9)));
    expect(find.text('Moved 1 thing to today'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    task = await db.taskDao.getTaskById(id);
    expect(task!.plannedDate, twoDaysAgo);
    await unmount(tester);
  });

  testWidgets('wrap-up moves what is left to tomorrow with Undo', (
    tester,
  ) async {
    final id = await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Email Sam',
        plannedDate: Value(_day(0)),
      ),
    );
    final anytime = await db.taskDao.insertTask(
      TaskTableCompanion.insert(title: 'Someday book'),
    );
    // Wrap-up mode is opened by the evening deep link.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(_IdleTimer.new),
          studyStreakProvider.overrideWith(_NoStreak.new),
          todayActivitiesProvider.overrideWith(
            (ref) => Stream.value([
              _item('Email Sam', taskId: id, planned: _day(0)),
            ]),
          ),
          upcomingThingsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const ThingsHubScreen(initialMode: 'wrapup'),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('things_carry_over')));
    await settle(tester);
    expect((await db.taskDao.getTaskById(id))!.plannedDate, _day(1));
    expect(
      (await db.taskDao.getTaskById(anytime))!.plannedDate,
      isNull,
      reason: 'undated things are never given a date',
    );
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await db.taskDao.getTaskById(id))!.plannedDate, _day(0));
    await unmount(tester);
  });

  testWidgets('an empty day offers starters that create real to-dos', (
    tester,
  ) async {
    await pumpHub(tester);
    expect(find.text('Your day is wide open'), findsOneWidget);
    await tester.tap(find.text('Plan tomorrow'));
    await settle(tester);
    final tasks = await db.select(db.taskTable).get();
    expect(tasks.single.title, 'Plan tomorrow');
    expect(tasks.single.plannedDate, _day(0));
    await unmount(tester);
  });

  testWidgets('search filters the current segment and can be cleared', (
    tester,
  ) async {
    await pumpHub(
      tester,
      today: [
        _item('Call mom', planned: _day(0)),
        _item('Groceries', planned: _day(0)),
      ],
    );
    await tester.tap(find.byTooltip('Search things'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'mom');
    await settle(tester);
    expect(find.text('Call mom'), findsOneWidget);
    expect(find.text('Groceries'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'zzz');
    await settle(tester);
    expect(find.text('No things match “zzz”'), findsOneWidget);
    await tester.tap(find.text('Clear search'));
    await settle(tester);
    expect(find.text('Groceries'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('1000 things render lazily', (tester) async {
    await pumpHub(
      tester,
      today: [
        for (var i = 0; i < 1000; i++)
          _item('Thing $i', taskId: i + 1, planned: _day(0)),
      ],
    );
    expect(find.text('Today · 1000'), findsOneWidget);
    expect(find.text('Thing 0'), findsOneWidget);
    expect(find.text('Thing 999'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  for (final dark in [false, true]) {
    testWidgets('fits 320 px at 2.0x text (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pumpHub(
        tester,
        dark: dark,
        scale: 2,
        size: const Size(320, 800),
        today: [
          _item('An overdue thing', planned: _day(-1), overdue: true),
          _item('A thing for today with a long title', planned: _day(0)),
          _item('Done already', status: TodayActivityStatus.done),
        ],
      );
      expect(tester.takeException(), isNull);
      for (final segment in ['upcoming', 'anytime', 'routines']) {
        await tester.tap(find.byKey(ValueKey('things_segment_$segment')));
        await settle(tester);
        expect(tester.takeException(), isNull, reason: segment);
      }
      await unmount(tester);
    });
  }

  test('upcoming skips today, routines and undated tasks', () async {
    for (final (title, planned, daily) in [
      ('today', _day(0), false),
      ('tomorrow', _day(1), false),
      ('in three days', _day(3), false),
      ('routine', _day(2), true),
      ('beyond window', _day(upcomingWindowDays + 5), false),
    ]) {
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: title,
          plannedDate: Value(planned),
          isDailyStanding: Value(daily),
        ),
      );
    }
    await db.taskDao.insertTask(TaskTableCompanion.insert(title: 'undated'));
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    // Riverpod pauses providers nobody listens to, so keep one listener open.
    final sub = container.listen(upcomingThingsProvider.future, (_, _) {});
    final items = await sub.read();
    expect(items.map((a) => a.title), ['tomorrow', 'in three days']);
  });
}
