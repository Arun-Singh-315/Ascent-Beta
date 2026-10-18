import 'dart:convert';
import 'package:ascent/core/services/home_capture_service.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/activity_entry_service.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2030, 10, 17, 12);
  final day = DateTime(2030, 10, 17);
  late AppDatabase db;
  late ActivityEntryService service;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = ActivityEntryService(db, clock: () => now);
  });
  tearDown(() => db.close());
  Future<int> create({int? minutes, String title = 'Read a chapter'}) async =>
      (await service.save(
        title: title,
        date: day,
        estimatedMinutes: minutes,
      )).taskId;
  Future<int> session(int task, String status, {int seconds = 600}) async {
    await db.timeSessionDao.ensureDefaultCategories();
    final category = (await db.timeSessionDao.getAllCategories()).first.id;
    return db
        .into(db.timeSessionTable)
        .insert(
          TimeSessionTableCompanion.insert(
            label: 'Read a chapter',
            categoryId: category,
            startedAt: now,
            linkedTaskId: d.Value(task),
            status: d.Value(status),
            durationSeconds: d.Value(seconds),
          ),
        );
  }

  test(
    'trimmed quick entry creates a medium To-do today without reminders or timers',
    () async {
      final id = await create(title: '  Read a chapter  ');
      final task = (await db.taskDao.getTaskById(id))!;
      expect(task.title, 'Read a chapter');
      expect(task.plannedDate, day);
      expect(task.estimatedMinutes, isNull);
      expect(task.priority, 'medium');
      expect(await db.select(db.reminderTable).get(), isEmpty);
      expect(await db.select(db.timeSessionTable).get(), isEmpty);
    },
  );
  test(
    'tomorrow and future dates retain explicit choice; timer creation never starts it',
    () async {
      final future = day.add(const Duration(days: 12));
      final result = await service.save(
        title: 'Practice',
        date: future,
        estimatedMinutes: 30,
      );
      expect(
        (await db.taskDao.getTaskById(result.taskId))!.plannedDate,
        future,
      );
      expect(
        (await db.taskDao.getTaskById(result.taskId))!.estimatedMinutes,
        30,
      );
      expect(await db.select(db.timeSessionTable).get(), isEmpty);
    },
  );
  for (final title in ['', '   ', List.filled(301, 'x').join()]) {
    test('invalid title ${title.length} leaves no partial records', () async {
      await expectLater(
        service.save(title: title, date: day),
        throwsStateError,
      );
      expect(await db.select(db.taskTable).get(), isEmpty);
    });
  }
  for (final minutes in [0, -2, 1441]) {
    test('invalid target $minutes is rejected', () async {
      await expectLater(create(minutes: minutes), throwsStateError);
      expect(await db.select(db.taskTable).get(), isEmpty);
    });
  }
  for (final minutes in [1, 1440, -1]) {
    test('valid target boundary $minutes persists', () async {
      final id = await create(minutes: minutes);
      expect((await db.taskDao.getTaskById(id))!.estimatedMinutes, minutes);
    });
  }
  test(
    'reminder opt-in creates one linked pending quiet notification',
    () async {
      final at = now.add(const Duration(hours: 2));
      final result = await service.save(
        title: 'Call',
        date: day,
        reminderAt: at,
      );
      final r = (await db.reminderDao.getRemindersByTaskId(
        result.taskId,
      )).single;
      expect(r.scheduledAt, at);
      expect(r.alertSyncPending, isTrue);
      expect(r.alarmEnabled, isFalse);
      expect(r.isActive, isTrue);
      expect(result.reminderIds, [r.id]);
    },
  );
  for (final at in [now, now.subtract(const Duration(minutes: 1))]) {
    test(
      'past or current reminder $at is rejected without rolling its date',
      () async {
        await expectLater(
          service.save(title: 'Call', date: day, reminderAt: at),
          throwsStateError,
        );
        expect(await db.select(db.taskTable).get(), isEmpty);
        expect(await db.select(db.reminderTable).get(), isEmpty);
      },
    );
  }
  for (final from in [null, 30, -1]) {
    for (final to in [null, 45, -1]) {
      if (from == to) continue;
      test(
        'idle conversion $from to $to keeps task identity and completion unset',
        () async {
          final id = await create(minutes: from);
          await service.save(
            taskId: id,
            title: 'Read a chapter',
            date: day,
            estimatedMinutes: to,
            replaceReminders: false,
          );
          final task = (await db.taskDao.getTaskById(id))!;
          expect(task.estimatedMinutes, to);
          expect(task.actualCompletedDate, isNull);
          expect((await db.select(db.taskTable).get()).length, 1);
        },
      );
    }
  }
  for (final status in ['running', 'paused']) {
    test(
      '$status session blocks conversion and target edits even through direct DAO writes',
      () async {
        final id = await create(minutes: 30);
        final sid = await session(id, status);
        for (final to in [null, -1, 45]) {
          await expectLater(
            service.save(
              taskId: id,
              title: 'Read a chapter',
              date: day,
              estimatedMinutes: to,
              replaceReminders: false,
            ),
            throwsStateError,
          );
          expect(
            await db.taskDao.updateTask(
              TaskTableCompanion(
                id: d.Value(id),
                estimatedMinutes: d.Value(to),
              ),
            ),
            isFalse,
          );
        }
        expect((await db.taskDao.getTaskById(id))!.estimatedMinutes, 30);
        expect(
          (await (db.select(
            db.timeSessionTable,
          )..where((s) => s.id.equals(sid))).getSingle()).status,
          status,
        );
        // Non-type edits can still be saved without interrupting the session.
        await service.save(
          taskId: id,
          title: 'Read carefully',
          date: day,
          estimatedMinutes: 30,
          replaceReminders: false,
        );
        expect((await db.taskDao.getTaskById(id))!.title, 'Read carefully');
      },
    );
  }
  test('completed and lecture-linked activities cannot change kind', () async {
    final id = await create();
    expect(await db.taskDao.markComplete(id), isTrue);
    await expectLater(
      service.save(
        taskId: id,
        title: 'Read a chapter',
        date: day,
        estimatedMinutes: 30,
        replaceReminders: false,
      ),
      throwsStateError,
    );
    final lecture = await create();
    await db.taskDao.updateTask(
      TaskTableCompanion(
        id: d.Value(lecture),
        learningCourseId: const d.Value('course'),
        learningLectureId: const d.Value(1),
      ),
    );
    await expectLater(
      service.save(
        taskId: lecture,
        title: 'Read a chapter',
        date: day,
        estimatedMinutes: 30,
        replaceReminders: false,
      ),
      throwsStateError,
    );
  });
  test(
    'finished session history, logged minutes and linked reminders survive round-trip conversion',
    () async {
      final id = await create(minutes: 30);
      final sid = await session(id, 'completed');
      await db.taskDao.updateTask(
        TaskTableCompanion(
          id: d.Value(id),
          actualMinutes: const d.Value(10),
          notes: const d.Value('Notes'),
        ),
      );
      final rid = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Read a chapter',
          scheduledAt: now.add(const Duration(hours: 1)),
          linkedTaskId: d.Value(id),
        ),
      );
      await service.save(
        taskId: id,
        title: 'Read a chapter',
        date: day,
        notes: 'Notes',
        replaceReminders: false,
      );
      expect((await db.taskDao.getTaskById(id))!.actualCompletedDate, isNull);
      await service.save(
        taskId: id,
        title: 'Read a chapter',
        date: day,
        estimatedMinutes: 20,
        notes: 'Notes',
        replaceReminders: false,
      );
      final task = (await db.taskDao.getTaskById(id))!;
      expect(task.actualMinutes, 10);
      expect(task.notes, 'Notes');
      expect(task.estimatedMinutes, 20);
      expect((await db.select(db.timeSessionTable).get()).single.id, sid);
      expect((await db.reminderDao.getReminderById(rid))!.isActive, isTrue);
    },
  );
  test('new timer cannot be equal to or shorter than logged time', () async {
    final id = await create();
    await session(id, 'completed', seconds: 600);
    for (final minutes in [5, 10]) {
      await expectLater(
        service.save(
          taskId: id,
          title: 'Read a chapter',
          date: day,
          estimatedMinutes: minutes,
          replaceReminders: false,
        ),
        throwsStateError,
      );
    }
    await service.save(
      taskId: id,
      title: 'Read a chapter',
      date: day,
      estimatedMinutes: 11,
      replaceReminders: false,
    );
  });
  test(
    'reminder edits retain ID; same-title unrelated reminders remain untouched',
    () async {
      final a = await service.save(
        title: 'Call',
        date: day,
        reminderAt: now.add(const Duration(hours: 1)),
      );
      final b = await service.save(
        title: 'Call',
        date: day,
        reminderAt: now.add(const Duration(hours: 2)),
      );
      final rid = a.reminderIds.single;
      await service.save(
        taskId: a.taskId,
        title: 'Call',
        date: day,
        reminderAt: now.add(const Duration(hours: 3)),
      );
      expect(
        (await db.reminderDao.getRemindersByTaskId(a.taskId)).single.id,
        rid,
      );
      expect(
        (await db.reminderDao.getReminderById(
          b.reminderIds.single,
        ))!.scheduledAt,
        now.add(const Duration(hours: 2)),
      );
      await service.save(taskId: a.taskId, title: 'Call', date: day);
      final off = (await db.reminderDao.getReminderById(rid))!;
      expect(off.isActive, isFalse);
      expect(off.alertSyncPending, isTrue);
      expect(
        (await db.reminderDao.getReminderById(b.reminderIds.single))!.isActive,
        isTrue,
      );
    },
  );
  test('deleted task cannot be resurrected by a stale editor', () async {
    final id = await create();
    await db.taskDao.deleteTask(id);
    await expectLater(
      service.save(taskId: id, title: 'Read a chapter', date: day),
      throwsStateError,
    );
    expect(await db.select(db.taskTable).get(), isEmpty);
  });
  test('reminder insertion failure rolls back activity creation', () async {
    await db.customStatement(
      "CREATE TRIGGER fail_reminder BEFORE INSERT ON reminders BEGIN SELECT RAISE(ABORT, 'test failure'); END;",
    );
    await expectLater(
      service.save(
        title: 'Call',
        date: day,
        reminderAt: now.add(const Duration(hours: 1)),
      ),
      throwsA(anything),
    );
    expect(await db.select(db.taskTable).get(), isEmpty);
  });
  test(
    'past creation date is rejected rather than silently reinterpreted',
    () async {
      await expectLater(
        service.save(title: 'Old', date: day.subtract(const Duration(days: 1))),
        throwsStateError,
      );
      expect(await db.select(db.taskTable).get(), isEmpty);
    },
  );
  test(
    'conversion preserves notes, priority and parent linkage without explicit overrides',
    () async {
      final parent = await create();
      final task = await service.save(
        title: 'Child',
        date: day,
        notes: 'Keep me',
        priority: 'high',
        parentTaskId: parent,
      );
      await service.save(
        taskId: task.taskId,
        title: 'Child',
        date: day,
        estimatedMinutes: 30,
        replaceReminders: false,
      );
      final saved = (await db.taskDao.getTaskById(task.taskId))!;
      expect(saved.notes, 'Keep me');
      expect(saved.priority, 'high');
      expect(saved.parentTaskId, parent);
    },
  );
  test(
    'a different activity running does not block an idle activity conversion',
    () async {
      final running = await create();
      await session(running, 'running');
      final idle = await create();
      await service.save(
        taskId: idle,
        title: 'Read a chapter',
        date: day,
        estimatedMinutes: 30,
        replaceReminders: false,
      );
      expect((await db.taskDao.getTaskById(idle))!.estimatedMinutes, 30);
    },
  );
  test(
    'Home scheduled plan conversion keeps reminder/check-in IDs; schedule changes use plan controls',
    () async {
      final noteId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Plan'),
      );
      final thought = (await db.thoughtDao.getThoughtById(noteId))!;
      final at = now.add(const Duration(hours: 1));
      final plan = await HomeCaptureService(db, clock: () => now).schedule(
        source: thought,
        title: 'Plan',
        at: at,
        checkInAt: at.add(const Duration(hours: 1)),
        linkedTodo: true,
      );
      await service.save(
        taskId: plan.task!.id,
        title: 'Plan',
        date: at,
        estimatedMinutes: 30,
        replaceReminders: false,
      );
      expect(
        (await db.reminderDao.getRemindersByTaskId(
          plan.task!.id,
        )).map((r) => r.id),
        containsAll([plan.reminder.id, plan.checkIn!.id]),
      );
      expect(
        (await db.select(db.aiCommandTable).get()).single.argumentsJson,
        contains('taskId'),
      );
      final args =
          jsonDecode(
                (await db.select(db.aiCommandTable).get()).single.argumentsJson,
              )
              as Map;
      expect(args['reminderId'], plan.reminder.id);
      await expectLater(
        service.save(
          taskId: plan.task!.id,
          title: 'Plan',
          date: at,
          estimatedMinutes: 30,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'denied device alerts remain pending; retry acknowledges without creating another task',
    () async {
      final result = await service.save(
        title: 'Call',
        date: day,
        reminderAt: now.add(const Duration(hours: 1)),
      );
      var allowed = false;
      final sync = ReminderAlertSync(
        db,
        enabled: () async => allowed,
        schedule: (_) async => true,
        reset: () async => true,
      );
      expect(
        (await sync.sync(ids: result.reminderIds, onlyPending: true)).complete,
        isFalse,
      );
      expect(
        (await db.reminderDao.getReminderById(
          result.reminderIds.single,
        ))!.alertSyncPending,
        isTrue,
      );
      allowed = true;
      expect(
        (await sync.sync(ids: result.reminderIds, onlyPending: true)).complete,
        isTrue,
      );
      expect(
        (await db.reminderDao.getReminderById(
          result.reminderIds.single,
        ))!.alertSyncPending,
        isFalse,
      );
      expect(await db.select(db.taskTable).get(), hasLength(1));
    },
  );
}
