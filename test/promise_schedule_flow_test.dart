import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:ascent/features/promises/services/promise_intent_parser.dart';
import 'package:drift/native.dart';
import 'package:ascent/core/services/promise_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PromiseRepository repo;
  late DateTime now;
  late List<DateTime> alerts;
  setUp(() async {
    now = DateTime(2026, 10, 19, 7);
    alerts = [];
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = PromiseRepository(
      db,
      clock: () => now,
      cancelNotification: (_) async {},
      scheduleNotification: (_, title, body, at) async {
        alerts.add(at);
        return true;
      },
    );
    await repo.initialize();
  });
  tearDown(() async => db.close());
  Future<PromiseModel> create({
    PromiseRepeat repeat = PromiseRepeat.daily,
    PromiseTrackingType type = PromiseTrackingType.completion,
    double target = 1,
    List<int> days = const [1, 2, 3, 4, 5, 6, 7],
    String? reminder,
  }) => repo.createPromise(
    title: 'A small daily step',
    intention: 'For myself',
    category: 'personal',
    trackingType: type,
    targetValue: target,
    frequencyPerWeek: type == PromiseTrackingType.frequency ? 3 : 0,
    schedule: PromiseSchedule(
      startDate: promiseDay(now),
      repeat: repeat,
      days: days,
    ),
    reminderTime: reminder,
  );
  test('daily tap is idempotent, remains active, resets next day', () async {
    final p = await create();
    await repo.markDayDone(p.id);
    await repo.markDayDone(p.id);
    var live = (await repo.getPromiseById(p.id))!;
    expect(live.isDoneToday, true);
    expect(live.isActive, true);
    expect((await repo.getProgressEvents(p.id)).length, 1);
    now = DateTime(2026, 10, 20, 8);
    live = (await repo.getPromiseById(p.id))!;
    expect(live.isDoneToday, false);
    expect(live.currentValue, 0);
    expect(live.canActAt(now), true);
    final calendar = await repo.calendar(p.id, now);
    expect(calendar[18].state, PromiseDayState.done);
    expect(calendar[19].state, PromiseDayState.pending);
    expect(calendar[20].state, PromiseDayState.upcoming);
  });
  test(
    'weekly progress resets Monday and duplicate day cannot inflate it',
    () async {
      final p = await create(
        repeat: PromiseRepeat.weekly,
        type: PromiseTrackingType.frequency,
        target: 3,
      );
      await repo.markDayDone(p.id);
      await repo.markDayDone(p.id);
      now = DateTime(2026, 10, 21);
      await repo.markDayDone(p.id);
      expect((await repo.getPromiseById(p.id))!.currentValue, 2);
      now = DateTime(2026, 10, 26);
      expect((await repo.getPromiseById(p.id))!.currentValue, 0);
    },
  );
  test('calendar distinguishes missed, off, paused and future dates', () async {
    final p = await create(repeat: PromiseRepeat.selectedDays, days: [1, 3, 5]);
    now = DateTime(2026, 10, 21);
    await repo.setPromiseStatus(p.id, PromiseStatus.paused);
    now = DateTime(2026, 10, 23);
    await repo.setPromiseStatus(p.id, PromiseStatus.active);
    final c = await repo.calendar(p.id, now);
    expect(c[18].state, PromiseDayState.missed);
    expect(c[19].state, PromiseDayState.off);
    expect(c[20].state, PromiseDayState.paused);
    expect(c[22].state, PromiseDayState.pending);
    expect(c[25].state, PromiseDayState.upcoming);
  });
  test(
    'schedule edits preserve earlier planned dates and target snapshots',
    () async {
      final p = await create(type: PromiseTrackingType.duration, target: 20);
      await repo.recordProgress(
        promiseId: p.id,
        eventType: PromiseEventType.durationSession,
        amount: 10,
      );
      now = DateTime(2026, 10, 21);
      await repo.updatePromise(
        p.copyWith(
          targetValue: 40,
          schedule: p.schedule!.copyWith(
            repeat: PromiseRepeat.selectedDays,
            days: [3],
          ),
        ),
      );
      await repo.markDayDone(p.id, date: DateTime(2026, 10, 19));
      final c = await repo.calendar(p.id, now);
      expect(c[18].target, 20);
      expect(c[18].amount, 20);
      expect(c[18].state, PromiseDayState.done);
      expect(c[19].state, PromiseDayState.missed);
      expect(c[20].target, 40);
    },
  );
  test('undo while paused retains pause and history', () async {
    final p = await create();
    await repo.markDayDone(p.id);
    await repo.setPromiseStatus(p.id, PromiseStatus.paused);
    await repo.undoDay(p.id, now);
    expect((await repo.getPromiseById(p.id))!.isPaused, true);
    expect(
      (await repo.getProgressEvents(
        p.id,
      )).map((e) => e.amount).reduce((a, b) => a + b),
      0,
    );
  });
  test('reject future, before-start and paused day logging', () async {
    final p = await create();
    await expectLater(
      repo.markDayDone(p.id, date: DateTime(2026, 10, 20)),
      throwsArgumentError,
    );
    await expectLater(
      repo.markDayDone(p.id, date: DateTime(2026, 10, 18)),
      throwsArgumentError,
    );
    await repo.setPromiseStatus(p.id, PromiseStatus.paused);
    await expectLater(
      repo.recordProgress(
        promiseId: p.id,
        eventType: PromiseEventType.completion,
      ),
      throwsStateError,
    );
  });
  test('private reminders follow chosen weekdays and start/end', () async {
    final p = await repo.createPromise(
      title: 'Confidential title',
      intention: '',
      category: 'personal',
      trackingType: PromiseTrackingType.completion,
      isPrivate: true,
      reminderTime: '09:00',
      schedule: PromiseSchedule(
        startDate: DateTime(2026, 10, 21),
        endDate: DateTime(2026, 10, 26),
        repeat: PromiseRepeat.selectedDays,
        days: [1, 3],
      ),
    );
    expect(alerts, [DateTime(2026, 10, 21, 9), DateTime(2026, 10, 26, 9)]);
    await repo.setPromiseStatus(p.id, PromiseStatus.paused);
    expect((await repo.getPromiseById(p.id))!.reminderIssue, isNull);
  });
  test('denied reminders save commitment and report issue', () async {
    final denied = PromiseRepository(
      db,
      clock: () => now,
      cancelNotification: (_) async {},
      scheduleNotification: (_, title, body, at) async => false,
    );
    final p = await denied.createPromise(
      title: 'Keep trying',
      intention: '',
      category: 'personal',
      trackingType: PromiseTrackingType.completion,
      reminderTime: '09:00',
      schedule: PromiseSchedule(startDate: now, repeat: PromiseRepeat.daily),
    );
    expect(p.reminderIssue, isNotNull);
    expect(p.isActive, true);
  });
  test(
    'natural wording keeps exact date, clock optional, no default reminder',
    () {
      final p = PromiseIntentParser.parse(
        'Read for 20 minutes every day until 25 November 2026 at 8 pm',
        now: now,
      );
      expect(p.schedule!.endDate, DateTime(2026, 11, 25));
      expect(p.schedule!.plannedTime, '20:00');
      expect(p.schedule!.repeat, PromiseRepeat.daily);
      expect(p.reminderTime, isNull);
      expect(p.targetValue, 20);
    },
  );
  test('managed private promises never leak into legacy bundle', () async {
    final p = await create(reminder: '09:00');
    final messages = <String>[];
    final legacy = PromiseService(
      db,
      clock: () => now,
      cancelNotification: (_) async {},
      scheduleNotification: (_, copy, at) async {
        messages.add(copy);
      },
    );
    await legacy.syncCheckIns();
    expect(messages, isEmpty);
    await legacy.create(content: 'Legacy promise still works');
    expect(messages, isNotEmpty);
    expect(messages.join(), isNot(contains(p.title)));
  });
  test('live observers refresh after pause and dated progress', () async {
    final p = await create();
    final paused = repo.watchPausedPromises().firstWhere(
      (items) => items.any((item) => item.id == p.id),
    );
    await repo.setPromiseStatus(p.id, PromiseStatus.paused);
    expect(await paused, hasLength(1));
    await repo.setPromiseStatus(p.id, PromiseStatus.active);
    final done = repo.watchActivePromises().firstWhere(
      (items) => items.any((item) => item.id == p.id && item.isDoneToday),
    );
    await repo.markDayDone(p.id);
    expect((await done).single.isDoneToday, true);
  });
  test(
    'new dated progress retains earlier legacy events on the same day',
    () async {
      final p = await create(type: PromiseTrackingType.duration, target: 20);
      await db.customStatement(
        'INSERT INTO promise_progress_events(promise_id,event_type,amount,occurred_at,note) VALUES(?,?,?,?,?)',
        [
          p.id,
          'durationSession',
          5,
          now.millisecondsSinceEpoch,
          'Earlier practice',
        ],
      );
      await db.customStatement(
        'UPDATE promise_metadata SET current_value=5 WHERE promise_id=?',
        [p.id],
      );
      await repo.recordProgress(
        promiseId: p.id,
        eventType: PromiseEventType.durationSession,
        amount: 5,
      );
      expect((await repo.calendar(p.id, now))[now.day - 1].amount, 10);
      await repo.markDayDone(p.id);
      expect((await repo.calendar(p.id, now))[now.day - 1].amount, 20);
      expect((await repo.getPromiseById(p.id))!.currentValue, 20);
    },
  );
}
