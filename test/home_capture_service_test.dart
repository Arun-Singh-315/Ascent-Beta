import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/home_capture_service.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/ai/riya_alert_effects.dart';
import 'package:ascent/core/backup/workspace_backup_service.dart';

class _Prefs implements BackupPreferences {
  Map<String, Object> values = {};
  @override
  Map<String, Object> snapshot() => values;
  @override
  Future<void> replace(Map<String, Object> next) async {
    values = next;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2030, 10, 16, 12);
  final at = now.add(const Duration(days: 1));
  late AppDatabase db;
  late HomeCaptureService service;
  Future<Thought> note() async {
    final id = await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(
        content:
            'Tomorrow at 7 pm practise interviews for 30 minutes. Remind me and ask afterwards.',
      ),
    );
    return (await db.thoughtDao.getThoughtById(id))!;
  }

  Future<HomePlan> schedule(Thought source, {bool linked = true}) =>
      service.schedule(
        source: source,
        title: 'Practise interviews',
        at: at,
        checkInAt: at.add(const Duration(minutes: 40)),
        linkedTodo: linked,
      );
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = HomeCaptureService(db, clock: () => now);
  });
  tearDown(() async => db.close());

  test(
    'local interpretation proposes absolute time and duration without writing',
    () {
      final p = HomeCaptureProposal.parse(
        'Tomorrow at 7 pm practise interviews for 30 minutes. Remind me and ask afterwards.',
        now,
      );
      expect(p.scheduledIntent, isTrue);
      expect(p.at, DateTime(2030, 10, 17, 19));
      expect(p.minutes, 30);
      expect(p.followUp, isTrue);
      expect(p.title, 'practise interviews');
      final direct = HomeCaptureProposal.parse(
        'Remind me to buy milk tomorrow at 7 pm',
        now,
      );
      expect(direct.title, 'buy milk');
    },
  );
  test('reflections, ambiguous dates and invalid clocks are not guessed', () {
    expect(
      HomeCaptureProposal.parse(
        'I felt tired today at 7 pm',
        now,
      ).scheduledIntent,
      isFalse,
    );
    expect(
      HomeCaptureProposal.parse('Remind me to call at 7 pm', now).at,
      isNull,
    );
    expect(
      HomeCaptureProposal.parse('Remind me today at 13 pm', now).at,
      isNull,
    );
    expect(
      HomeCaptureProposal.parse('Remind me on 2030-02-31 at 7 pm', now).at,
      isNull,
    );
    expect(
      HomeCaptureProposal.parse('Today at 12 am read', now).at,
      DateTime(2030, 10, 16),
    );
  });
  test(
    'atomic linked save and replay create one Todo and two linked reminders',
    () async {
      final source = await note();
      final first = await schedule(source);
      final replay = await schedule(source);
      expect(replay.task!.id, first.task!.id);
      expect(await db.select(db.taskTable).get(), hasLength(1));
      expect(await db.select(db.reminderTable).get(), hasLength(2));
      expect(await db.select(db.thoughtReminderLinkTable).get(), hasLength(2));
      expect(first.checkIn!.linkedTaskId, first.task!.id);
      expect(first.reminder.linkedTaskId, first.task!.id);
      expect(
        first.task!.estimatedMinutes,
        isNull,
      ); // Planned duration is not a Focus requirement.
      expect((await service.plans()), hasLength(1));
      final receipt = (await db.select(db.aiCommandTable).get()).single;
      expect(
        (jsonDecode(receipt.resultJson) as Map)['alertEffectsPending'],
        isTrue,
      );
      final updated = await service.schedule(
        source: source,
        title: 'Changed title',
        at: at,
      );
      expect(updated.reminder.title, 'Changed title');
    },
  );
  test('invalid or stale drafts leave no partial task or reminder', () async {
    final source = await note();
    await expectLater(
      service.schedule(source: source, title: 'Call', at: now),
      throwsArgumentError,
    );
    await expectLater(
      service.schedule(source: source, title: 'Call', at: at, checkInAt: at),
      throwsArgumentError,
    );
    await db.thoughtDao.updateThought(
      source.toCompanion(true).copyWith(content: const d.Value('changed')),
    );
    await expectLater(schedule(source), throwsStateError);
    expect(await db.select(db.taskTable).get(), isEmpty);
    expect(await db.select(db.reminderTable).get(), isEmpty);
    expect(await db.select(db.aiCommandTable).get(), isEmpty);
  });
  test(
    'ordinary Todo completion cancels primary and check-in; response becomes stale',
    () async {
      final plan = await schedule(await note());
      expect(await db.taskDao.markComplete(plan.task!.id), isTrue);
      final reminders = await db.reminderDao.getRemindersByTaskId(
        plan.task!.id,
      );
      expect(reminders.every((r) => !r.isActive && r.alertSyncPending), isTrue);
      expect(await service.plans(), isEmpty);
      expect(
        await service.answer(
          plan.checkIn!.id,
          plan.checkIn!.scheduledAt,
          'done',
        ),
        isFalse,
      );
    },
  );
  test(
    'Later moves only check-in, repeated stale action cannot complete Todo',
    () async {
      final plan = await schedule(await note());
      expect(
        await service.answer(
          plan.checkIn!.id,
          plan.checkIn!.scheduledAt,
          'later',
        ),
        isTrue,
      );
      final current = await db.reminderDao.getReminderById(plan.checkIn!.id);
      expect(
        current!.scheduledAt,
        plan.checkIn!.scheduledAt.add(const Duration(minutes: 30)),
      );
      expect(
        (await db.taskDao.getTaskById(plan.task!.id))!.actualCompletedDate,
        isNull,
      );
      expect(
        (await db.reminderDao.getReminderById(plan.reminder.id))!.scheduledAt,
        at,
      );
      expect(
        await service.answer(
          plan.checkIn!.id,
          plan.checkIn!.scheduledAt,
          'done',
        ),
        isFalse,
      );
      expect(
        await service.answer(current.id, current.scheduledAt, 'done'),
        isTrue,
      );
      expect(
        (await db.taskDao.getTaskById(plan.task!.id))!.actualCompletedDate,
        isNotNull,
      );
    },
  );
  test(
    'Skip keeps Todo unfinished and preserves a future primary reminder',
    () async {
      final plan = await schedule(await note());
      expect(
        await service.answer(
          plan.checkIn!.id,
          plan.checkIn!.scheduledAt,
          'skip',
        ),
        isTrue,
      );
      expect(
        (await db.taskDao.getTaskById(plan.task!.id))!.actualCompletedDate,
        isNull,
      );
      expect(await service.plans(), hasLength(1));
      expect(
        (await db.reminderDao.getReminderById(plan.reminder.id))!.isActive,
        isTrue,
      );
      expect(
        (await db.reminderDao.getReminderById(plan.checkIn!.id))!.isActive,
        isFalse,
      );
    },
  );
  test('reminder-only check-in Done does not invent a Todo', () async {
    final plan = await schedule(await note(), linked: false);
    expect(plan.task, isNull);
    expect(
      await service.answer(plan.checkIn!.id, plan.checkIn!.scheduledAt, 'done'),
      isTrue,
    );
    expect(await db.select(db.taskTable).get(), isEmpty);
    expect(await service.plans(), isEmpty);
  });
  test(
    'timed task completion contracts cannot be bypassed by check-in',
    () async {
      final plan = await schedule(await note());
      await db.taskDao.updateTask(
        TaskTableCompanion(
          id: d.Value(plan.task!.id),
          estimatedMinutes: const d.Value(30),
        ),
      );
      await expectLater(
        service.answer(plan.checkIn!.id, plan.checkIn!.scheduledAt, 'done'),
        throwsStateError,
      );
      expect(
        (await db.reminderDao.getReminderById(plan.checkIn!.id))!.isActive,
        isTrue,
      );
    },
  );
  test(
    'reschedule updates Todo and both reminders, stale snapshot fails',
    () async {
      final plan = await schedule(await note());
      final next = at.add(const Duration(days: 1));
      await service.reschedule(
        plan,
        next,
        next.add(const Duration(minutes: 40)),
      );
      expect((await db.taskDao.getTaskById(plan.task!.id))!.plannedDate, next);
      expect(
        (await db.reminderDao.getReminderById(plan.reminder.id))!.scheduledAt,
        next,
      );
      expect(
        await service.answer(
          plan.checkIn!.id,
          plan.checkIn!.scheduledAt,
          'done',
        ),
        isFalse,
      );
      await expectLater(service.reschedule(plan, next, null), throwsStateError);
    },
  );
  test(
    'denied device effects remain pending and retry uses existing IDs',
    () async {
      final plan = await schedule(await note());
      final effects = RiyaAlertEffects(
        db,
        cancel: (_) async => true,
        schedule: (_) async => false,
      );
      expect(await effects.syncRequest(plan.requestId), isFalse);
      expect(
        (await db.reminderDao.getReminderById(
          plan.reminder.id,
        ))!.alertSyncPending,
        isTrue,
      );
      final scheduled = <int>[];
      final sync = ReminderAlertSync(
        db,
        enabled: () async => true,
        reset: () async => true,
        schedule: (r) async {
          scheduled.add(r.id);
          return true;
        },
        cancel: (_) async => true,
      );
      expect((await sync.sync(onlyPending: true)).complete, isTrue);
      expect(scheduled.toSet(), {plan.reminder.id, plan.checkIn!.id});
      expect(
        (await db.reminderDao.getReminderById(
          plan.checkIn!.id,
        ))!.alertSyncPending,
        isFalse,
      );
    },
  );
  test(
    'watch stream reacts to task completion and backup restores check-in links',
    () async {
      final plan = await schedule(await note());
      final docs = await Directory.systemTemp.createTemp('home-plan-backup');
      try {
        final backup = WorkspaceBackupService(db, _Prefs(), docs);
        final raw = await backup.export();
        final updates = service.watchPlans().asBroadcastStream();
        expect(await updates.first, hasLength(1));
        final changed = updates
            .firstWhere((rows) => rows.isEmpty)
            .timeout(const Duration(seconds: 2));
        await db.taskDao.markComplete(plan.task!.id);
        expect(await changed, isEmpty);
        await backup.restore(raw, confirmed: true);
        expect(await service.plans(), hasLength(1));
        expect(
          (await service.plans()).single.checkIn!.linkedTaskId,
          plan.task!.id,
        );
        expect(
          await schedule(
            (await db.thoughtDao.getThoughtById(plan.task!.linkedThoughtId!))!,
          ),
          isA<HomePlan>(),
        );
        expect(await db.select(db.taskTable).get(), hasLength(1));
      } finally {
        await docs.delete(recursive: true);
      }
    },
  );
  test(
    'deleting just the initial reminder leaves its check-in answerable',
    () async {
      final plan = await schedule(await note());
      await db.reminderDao.deleteReminder(
        plan.reminder.id,
        bypassProtection: true,
      );
      expect(await service.plans(), hasLength(1));
      expect(
        await service.answer(
          plan.checkIn!.id,
          plan.checkIn!.scheduledAt,
          'done',
        ),
        isTrue,
      );
      expect(await service.plans(), isEmpty);
    },
  );
  test(
    'finished schedules cannot be presented as newly scheduled on replay',
    () async {
      final source = await note();
      final plan = await schedule(source);
      await db.taskDao.markComplete(plan.task!.id);
      await expectLater(schedule(source), throwsStateError);
    },
  );
  test('notification destinations validate occurrence parameters', () {
    expect(
      NotificationService.destinationForPayload(
        '/home?checkin=2&at=123&answer=done',
      ),
      '/home?checkin=2&at=123&answer=done',
    );
    expect(
      NotificationService.destinationForPayload(
        '/home?checkin=nope&answer=done',
      ),
      '/home',
    );
  });
}
