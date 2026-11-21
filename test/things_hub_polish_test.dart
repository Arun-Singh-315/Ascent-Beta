import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/today/models/things_sections.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:ascent/features/today/things_providers.dart';
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
  ActivityKind kind = ActivityKind.todo,
  int? minutes,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
}) => TodayActivityItem(
  id: 'task_$taskId',
  title: title,
  sourceType: 'task',
  status: status,
  elapsedSecondsToday: 0,
  categoryTag: 'Task',
  linkedTaskId: taskId,
  plannedDate: planned,
  kind: kind,
  targetMinutes: minutes,
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

  Future<void> pump(
    WidgetTester tester,
    List<TodayActivityItem> rows, {
    String? tab,
  }) async {
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

  testWidgets('idle timed row has one inline play button, no second line', (
    tester,
  ) async {
    await pump(tester, [
      _row(
        2,
        'Morning run',
        planned: _day(0),
        kind: ActivityKind.duration,
        minutes: 30,
      ),
    ]);
    final play = find.byKey(const ValueKey('activity_action_task_2'));
    expect(play, findsOneWidget);
    expect(find.bySemanticsLabel('Start Morning run'), findsOneWidget);
    // The old pill said "Start" on its own line below the title.
    expect(find.text('Start'), findsNothing);
    // Inline: the play button sits on the same row as the title.
    final titleY = tester.getCenter(find.text('Morning run')).dy;
    expect((tester.getCenter(play).dy - titleY).abs(), lessThan(24));
    await unmount(tester);
  });

  testWidgets('Today progress ignores undated Anytime things', (tester) async {
    await pump(tester, [
      _row(1, 'Buy groceries', planned: _day(0)),
      _row(
        2,
        'Water plants',
        planned: _day(0),
        status: TodayActivityStatus.done,
      ),
      _row(3, 'Renew passport'),
    ]);
    expect(find.text('1 left · 1 done'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Anytime capture saves a thing with no date', (tester) async {
    await pump(tester, const [], tab: 'anytime');
    await tester.enterText(
      find
          .descendant(
            of: find.byKey(const ValueKey('things_anytime_field')),
            matching: find.byType(EditableText),
          )
          .first,
      'Renew passport',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('things_anytime_send')));
    await settle(tester);
    final tasks = await tester.runAsync(() => db.select(db.taskTable).get());
    expect(tasks!.single.title, 'Renew passport');
    expect(tasks.single.plannedDate, isNull);
    expect(isAnytimeThing(_row(tasks.single.id, 'x')), isTrue);
    await unmount(tester);
  });

  testWidgets('Upcoming quick add defaults to tomorrow', (tester) async {
    await pump(tester, const [], tab: 'upcoming');
    final field = find.descendant(
      of: find.byKey(const ValueKey('activity_quick_input')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(field.first, 'Pay rent');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    var tasks = await tester.runAsync(() => db.select(db.taskTable).get());
    if (tasks!.isEmpty) {
      await tester.tap(find.byTooltip('Add activity').first);
      await settle(tester);
      tasks = await tester.runAsync(() => db.select(db.taskTable).get());
    }
    final planned = tasks!.single.plannedDate!;
    expect(DateTime(planned.year, planned.month, planned.day), _day(1));
    await unmount(tester);
  });

  group('early completion', () {
    TodayActivityItem later({
      String source = 'task',
      ActivityKind kind = ActivityKind.todo,
    }) => TodayActivityItem(
      id: 'task_9',
      title: 'Call mom',
      sourceType: source,
      status: TodayActivityStatus.notStarted,
      elapsedSecondsToday: 0,
      categoryTag: 'Task',
      linkedTaskId: 9,
      kind: kind,
      plannedDate: _day(0),
      scheduledTime: DateTime.now().add(const Duration(hours: 3)),
    );

    test('a later to-do is not locked; doses and timers still wait', () {
      expect(later().isScheduledInFuture, isTrue);
      expect(later().isLockedUntilScheduled, isFalse);
      expect(later(source: 'medicine').isLockedUntilScheduled, isTrue);
      expect(later(kind: ActivityKind.duration).isLockedUntilScheduled, isTrue);
    });

    testWidgets('a later to-do shows a checkbox and can be ticked off', (
      tester,
    ) async {
      final id = await tester.runAsync(
        () =>
            db.taskDao.insertTask(TaskTableCompanion.insert(title: 'Call mom')),
      );
      final row = TodayActivityItem(
        id: 'task_$id',
        title: 'Call mom',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Task',
        linkedTaskId: id,
        plannedDate: _day(0),
        scheduledTime: DateTime.now().add(const Duration(hours: 3)),
      );
      await pump(tester, [row]);
      final box = find.byKey(ValueKey('activity_action_task_$id'));
      expect(box, findsOneWidget);
      await tester.tap(box);
      await settle(tester);
      final task = await tester.runAsync(() => db.taskDao.getTaskById(id!));
      expect(task!.actualCompletedDate, isNotNull);
      expect(find.textContaining('once that time arrives'), findsNothing);
      await unmount(tester);
    });
  });
}
