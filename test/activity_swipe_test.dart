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

TodayActivityItem _row(
  int taskId,
  String title, {
  DateTime? planned,
  String source = 'task',
  bool linked = true,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
}) => TodayActivityItem(
  id: linked ? 'task_$taskId' : 'session_$taskId',
  title: title,
  sourceType: source,
  status: status,
  elapsedSecondsToday: 0,
  categoryTag: 'Task',
  linkedTaskId: linked ? taskId : null,
  plannedDate: planned,
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
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester, List<TodayActivityItem> rows) async {
    tester.view.physicalSize = const Size(390, 844);
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
          todayActivitiesProvider.overrideWith((ref) => Stream.value(rows)),
          upcomingThingsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const ThingsHubScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));
  }

  Finder rowOf(String id) => find.byKey(ValueKey('activity_dismiss_$id'));

  Future<void> swipe(WidgetTester tester, String id, double dx) async {
    await tester.drag(rowOf(id), Offset(dx, 0));
    await settle(tester);
  }

  Future<int> insert(String title, {DateTime? planned}) =>
      db.taskDao.insertTask(
        TaskTableCompanion.insert(title: title, plannedDate: Value(planned)),
      );

  testWidgets('swipe right completes without a dialog, Undo reopens', (
    tester,
  ) async {
    final id = await insert('Water plants', planned: _day(0));
    await pump(tester, [_row(id, 'Water plants', planned: _day(0))]);

    await swipe(tester, 'task_$id', 300);
    expect(find.byType(AlertDialog), findsNothing);
    expect((await db.taskDao.getTaskById(id))!.actualCompletedDate, isNotNull);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await db.taskDao.getTaskById(id))!.actualCompletedDate, isNull);
    await unmount(tester);
  });

  testWidgets('swipe left → Move to tomorrow, Undo puts it back', (
    tester,
  ) async {
    final nineToday = _day(0).add(const Duration(hours: 9));
    final id = await insert('Call bank', planned: nineToday);
    await pump(tester, [_row(id, 'Call bank', planned: nineToday)]);

    await swipe(tester, 'task_$id', -300);
    expect(find.text('Move to tomorrow'), findsOneWidget);
    expect(find.text('Pick a day'), findsOneWidget);
    await tester.tap(find.text('Move to tomorrow'));
    await settle(tester);

    expect(
      (await db.taskDao.getTaskById(id))!.plannedDate,
      _day(1).add(const Duration(hours: 9)),
      reason: 'keeps its time of day',
    );
    expect(find.text('Moved “Call bank” to tomorrow'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await db.taskDao.getTaskById(id))!.plannedDate, nineToday);
    await unmount(tester);
  });

  testWidgets('moving an anytime thing and undoing leaves it undated', (
    tester,
  ) async {
    final id = await insert('Sort photos');
    await pump(tester, [_row(id, 'Sort photos')]);
    await tester.tap(find.byKey(const ValueKey('things_segment_anytime')));
    await settle(tester);

    await swipe(tester, 'task_$id', -300);
    await tester.tap(find.text('Move to tomorrow'));
    await settle(tester);
    expect(
      DateUtils.isSameDay(
        (await db.taskDao.getTaskById(id))!.plannedDate,
        _day(1),
      ),
      isTrue,
    );
    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await db.taskDao.getTaskById(id))!.plannedDate, isNull);
    await unmount(tester);
  });

  testWidgets('swipe left → Delete needs no confirmation and can be undone', (
    tester,
  ) async {
    final id = await insert('Old errand', planned: _day(0));
    await pump(tester, [_row(id, 'Old errand', planned: _day(0))]);

    await swipe(tester, 'task_$id', -300);
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(find.text('Delete activity?'), findsNothing);
    expect(await db.taskDao.getTaskById(id), isNull);
    expect(find.text('Deleted “Old errand”'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await db.taskDao.getTaskById(id), isNotNull);
    await unmount(tester);
  });

  testWidgets('cancelling the swipe-left menu changes nothing', (tester) async {
    final id = await insert('Keep me', planned: _day(0));
    await pump(tester, [_row(id, 'Keep me', planned: _day(0))]);
    await swipe(tester, 'task_$id', -300);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect((await db.taskDao.getTaskById(id))!.plannedDate, _day(0));
    expect(find.text('Keep me'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('things without a task can only be removed from today', (
    tester,
  ) async {
    await pump(tester, [
      _row(7, 'Focus session', source: 'session', linked: false),
    ]);
    await swipe(tester, 'session_7', 300);
    expect(find.text('Focus session'), findsOneWidget, reason: 'no complete');

    await swipe(tester, 'session_7', -300);
    expect(find.text('Move to tomorrow'), findsNothing);
    expect(find.text('Remove from today'), findsOneWidget);
    await tester.tap(find.text('Remove from today'));
    await settle(tester);
    expect(find.text('Removed “Focus session” from today'), findsOneWidget);
    await unmount(tester);
  });
}
