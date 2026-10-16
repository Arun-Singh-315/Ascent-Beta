import 'dart:convert';
import 'dart:async';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/actions/checkin_actions.dart';
import 'package:ascent/core/actions/expense_actions.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_catalog.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/daily_checkin_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late SharedPreferences prefs;
  late ProviderContainer container;
  int ticks = 0;
  Course course(String id) => Course(
    id: id,
    title: id,
    modules: [
      CourseModule(
        id: 1,
        title: 'Module',
        lectures: [
          const Lecture(
            id: 1,
            moduleId: 1,
            moduleTitle: 'Module',
            title: 'Existing',
            durationSeconds: 100,
          ),
        ],
      ),
    ],
  );
  setUp(() async {
    ticks = 0;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      learningCatalogPreferenceKey: jsonEncode([
        course('a').toJson(),
        course('b').toJson(),
      ]),
      'ascent_learning_hub_active_course_v3': 'a',
    });
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        learningElapsedClockProvider.overrideWithValue(() => ticks),
      ],
    );
    await container.read(learningHubProvider.notifier).ready;
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'SQLite wins over stale cache; deleted courses stay deleted after restart',
    () async {
      final catalog = LearningCatalog(db, prefs);
      await catalog.saveCourses([course('b')]);
      container.invalidate(learningHubProvider);
      await container.read(learningHubProvider.notifier).ready;
      expect(container.read(learningHubProvider).courses.map((c) => c.id), [
        'b',
      ]);
      expect(container.read(learningHubProvider).activeCourseId, 'b');
      await catalog.saveCourses([]);
      container.invalidate(learningHubProvider);
      await container.read(learningHubProvider.notifier).ready;
      expect(container.read(learningHubProvider).courses, isEmpty);
      container.read(learningHubProvider.notifier).play();
      expect(container.read(learningHubProvider).isPlaying, isFalse);
    },
  );

  test(
    'Seeking and paused time never earn study credit; monotonic active time does',
    () async {
      final notifier = container.read(learningHubProvider.notifier);
      notifier.seekTo(1);
      expect(container.read(learningHubProvider).activeLecture.studySeconds, 0);
      notifier.play();
      ticks += 10 * Duration.microsecondsPerSecond;
      notifier.pause(updateNotification: false);
      expect(
        container.read(learningHubProvider).activeLecture.studySeconds,
        10,
      );
      ticks += 1000 * Duration.microsecondsPerSecond;
      notifier.play();
      ticks += 5 * Duration.microsecondsPerSecond;
      notifier.pause(updateNotification: false);
      expect(
        container.read(learningHubProvider).activeLecture.studySeconds,
        15,
      );
      expect(await notifier.markLectureCompleted(1), isFalse);
      expect(
        container.read(learningHubProvider).course.totalWatchedSeconds,
        15,
      );
    },
  );

  test(
    'Rapid play/pause retains early study seconds in one lecture session',
    () async {
      final notifier = container.read(learningHubProvider.notifier);
      notifier.play();
      ticks += 2 * Duration.microsecondsPerSecond;
      notifier.pause(updateNotification: false);
      notifier.play();
      ticks += 3 * Duration.microsecondsPerSecond;
      notifier.pause(updateNotification: false);
      await notifier.settled;
      final sessions = await (db.select(
        db.timeSessionTable,
      )..where((s) => s.activityRefType.equals('lecture'))).get();
      expect(sessions, hasLength(1));
      expect(sessions.single.status, 'paused');
      expect(sessions.single.durationSeconds, 5);
      expect(container.read(learningHubProvider).activeLecture.studySeconds, 5);
    },
  );

  test(
    'Activity conversion preserves identity and history, replays once, and uses lecture gate',
    () async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Study SQL',
          estimatedMinutes: const d.Value(1),
          plannedDate: d.Value(DateTime.now()),
        ),
      );
      final sessionId = await db.timeSessionDao.startSession(
        label: 'Study SQL',
        categoryId: 1,
        linkedTaskId: taskId,
        activityRefType: 'task',
      );
      await db.timeSessionDao.completeSession(sessionId);
      await db.timeSessionDao.heartbeat(sessionId, 90);
      final notifier = container.read(learningHubProvider.notifier);
      final created = await notifier.saveLectureActivity(
        requestId: 'convert',
        courseId: 'a',
        moduleId: 1,
        plannedDate: DateTime.now(),
        taskId: taskId,
        title: 'Study SQL',
        durationSeconds: 60,
      );
      final replay = await notifier.saveLectureActivity(
        requestId: 'convert',
        courseId: 'a',
        moduleId: 1,
        plannedDate: DateTime.now(),
        taskId: taskId,
        title: 'Study SQL',
        durationSeconds: 60,
      );
      expect(replay.id, created.id);
      expect(container.read(learningHubProvider).course.totalLectures, 2);
      expect(created.studySeconds, 0);
      expect(
        (await db.taskDao.getTaskById(taskId))!.learningLectureId,
        created.id,
      );
      final session = await (db.select(
        db.timeSessionTable,
      )..where((s) => s.id.equals(sessionId))).getSingleOrNull();
      expect(session!.durationSeconds, 90);
      expect(session.learningCourseId, 'a');
      expect(await db.taskDao.markComplete(taskId), isFalse);
      expect(await db.taskDao.completeTimedTaskAfterFocus(taskId), isFalse);
      final rows = await _activities(container);
      expect(rows.where((r) => r.linkedTaskId == taskId), hasLength(1));
      expect(
        rows.singleWhere((r) => r.linkedTaskId == taskId).learningCourseId,
        'a',
      );
      final before = await db.select(db.timeSessionTable).get();
      await deleteTodayActivity(
        container,
        rows.singleWhere((r) => r.linkedTaskId == taskId),
      );
      expect(await db.taskDao.getTaskById(taskId), isNotNull);
      expect(await db.select(db.timeSessionTable).get(), before);
    },
  );

  test(
    'Failed session linkage rolls back the new lecture and task association',
    () async {
      final task = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Rollback'),
      );
      await db.timeSessionDao.startSession(
        label: 'Rollback',
        categoryId: 1,
        linkedTaskId: task,
      );
      await db.customStatement(
        "CREATE TRIGGER fail_lecture_link BEFORE UPDATE ON time_sessions BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      final notifier = container.read(learningHubProvider.notifier);
      await expectLater(
        notifier.saveLectureActivity(
          requestId: 'failed',
          courseId: 'a',
          moduleId: 1,
          plannedDate: DateTime.now(),
          taskId: task,
          title: 'Rollback',
          durationSeconds: 60,
        ),
        throwsA(anything),
      );
      expect(container.read(learningHubProvider).course.totalLectures, 1);
      expect((await db.taskDao.getTaskById(task))!.learningCourseId, isNull);
      final loaded = await LearningCatalog(db, prefs).loadOrImport([]);
      expect(loaded.first.totalLectures, 1);
    },
  );

  test(
    'Course-scoped IDs do not collide, and dismissing another lecture does not pause the active one',
    () async {
      final notifier = container.read(learningHubProvider.notifier);
      for (final id in ['a', 'b']) {
        await notifier.saveLectureActivity(
          requestId: 'plan:$id',
          courseId: id,
          moduleId: 1,
          existingLectureId: 1,
          plannedDate: DateTime.now(),
        );
      }
      final rows = await _activities(container);
      expect(rows.map((r) => r.id).toSet(), hasLength(2));
      notifier.play();
      await deleteTodayActivity(
        container,
        rows.singleWhere((r) => r.learningCourseId == 'b'),
      );
      expect(container.read(learningHubProvider).isPlaying, isTrue);
      notifier.pause(updateNotification: false);
    },
  );

  test(
    'Water receipt survives preference failure and concurrent retry; skip logs nothing',
    () async {
      final actions = CheckInActions(db);
      final ids = await Future.wait([
        actions.saveWater(period: 'day:qa', amountMl: 250),
        actions.saveWater(period: 'day:qa', amountMl: 500),
      ]);
      expect(ids[0], ids[1]);
      expect(await db.select(db.waterLogTable).get(), hasLength(1));
      expect(await actions.waterSaved('day:qa'), isTrue);
      expect(
        const DailyCheckInSettings().due(DateTime(2026, 10, 13, 20)),
        isFalse,
      );
      final settings = const DailyCheckInSettings(
        enabled: true,
        water: true,
        weekly: true,
      );
      expect(
        settings.period(DateTime(2026, 10, 18)),
        settings.period(DateTime(2026, 10, 13)),
      );
      expect(
        settings
            .copyWith(dismissedPeriod: settings.period(DateTime(2026, 10, 13)))
            .due(DateTime(2026, 10, 13, 20)),
        isFalse,
      );
      expect(await db.select(db.waterLogTable).get(), hasLength(1));
    },
  );

  test(
    'Expense concurrent retry writes once; invalid amounts and changed receipt payload reject',
    () async {
      final actions = ExpenseActions(db);
      final date = DateTime(2026, 10, 13);
      final ids = await Future.wait([
        for (var i = 0; i < 2; i++)
          actions.save(
            requestId: 'expense',
            title: 'Tea',
            amount: 20,
            date: date,
          ),
      ]);
      expect(ids[0], ids[1]);
      await expectLater(
        actions.save(
          requestId: 'expense',
          title: 'Tea',
          amount: 30,
          date: date,
        ),
        throwsStateError,
      );
      for (final amount in [double.nan, double.infinity, 0.0, -1.0]) {
        await expectLater(
          actions.save(
            requestId: 'invalid',
            title: 'Tea',
            amount: amount,
            date: date,
          ),
          throwsArgumentError,
        );
      }
      expect(await db.select(db.financeTransactionTable).get(), hasLength(1));
    },
  );

  test(
    'An alert finishing after a reminder edit cannot overwrite the newer record',
    () async {
      final id = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Old',
          scheduledAt: DateTime.now().add(const Duration(days: 1)),
          alertSyncPending: const d.Value(true),
        ),
      );
      final sync = ReminderAlertSync(
        db,
        enabled: () async => true,
        reset: () async => true,
        schedule: (snapshot) async {
          await db.reminderDao.updateReminder(
            snapshot
                .toCompanion(true)
                .copyWith(
                  title: const d.Value('New'),
                  alertSyncPending: const d.Value(true),
                ),
          );
          return true;
        },
      );
      expect((await sync.sync(onlyPending: true)).complete, isFalse);
      final latest = await db.reminderDao.getReminderById(id);
      expect(latest!.title, 'New');
      expect(latest.alertSyncPending, isTrue);
    },
  );

  test('Native cancellation can finish with notifications denied', () async {
    final id = await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Finished',
        scheduledAt: DateTime.now(),
        isActive: const d.Value(false),
        alertSyncPending: const d.Value(true),
      ),
    );
    final cancelled = <int>[];
    final sync = ReminderAlertSync(
      db,
      enabled: () async => false,
      reset: () async => true,
      schedule: (_) async => false,
      cancel: (id) async {
        cancelled.add(id);
        return true;
      },
    );
    expect((await sync.sync(onlyPending: true)).complete, isTrue);
    expect(cancelled, [id]);
    expect(
      (await db.reminderDao.getReminderById(id))!.alertSyncPending,
      isFalse,
    );
  });
}

Future<List<TodayActivityItem>> _activities(ProviderContainer container) async {
  final completer = Completer<List<TodayActivityItem>>();
  final sub = container.listen(todayActivitiesProvider, (_, next) {
    if (next.hasValue && !completer.isCompleted) {
      completer.complete(next.value!);
    }
    if (next.hasError && !completer.isCompleted) {
      completer.completeError(next.error!, next.stackTrace);
    }
  }, fireImmediately: true);
  try {
    return await completer.future.timeout(const Duration(seconds: 5));
  } finally {
    sub.close();
  }
}
