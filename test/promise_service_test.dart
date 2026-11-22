import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/promises/promise_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Nudger implements PromiseNudger {
  final scheduled = <int, DateTime>{};
  @override
  Future<void> schedule(int id, String title, String body, DateTime at) async =>
      scheduled[id] = at;
  @override
  Future<void> cancel(int id) async => scheduled.remove(id);
}

PromiseRow _row({int? length = 21, DateTime? start}) => PromiseRow(
  id: 'p',
  title: 'Walk',
  startDay: start ?? DateTime(2026, 11, 1),
  lengthDays: length,
  status: 'active',
  createdAt: DateTime(2026, 11, 1),
  updatedAt: DateTime(2026, 11, 1),
);

PromiseCheckInRow _c(int day, String result) => PromiseCheckInRow(
  id: '$day',
  promiseId: 'p',
  day: DateTime(2026, 11, day),
  result: result,
  createdAt: DateTime(2026, 11, day),
  updatedAt: DateTime(2026, 11, day),
);

void main() {
  group('progress', () {
    test('day one, nothing answered', () {
      final p = promiseProgress(_row(), const [], DateTime(2026, 11, 1, 9));
      expect(p.dayNumber, 1);
      expect(p.daysLeft, 20);
      expect(p.days.first, DayMark.open);
      expect(p.days.skip(1), everyElement(DayMark.future));
      expect(p.yesterdayOpen, isFalse);
      expect(p.graceAllowance, 3);
    });

    test('a kept run builds the streak', () {
      final p = promiseProgress(_row(), [
        for (var d = 1; d <= 5; d++) _c(d, 'kept'),
      ], DateTime(2026, 11, 5, 21));
      expect(p.streak, 5);
      expect(p.best, 5);
      expect(p.keptToday, isTrue);
      expect(p.dayNumber, 5);
    });

    test('a missed day uses grace and keeps the streak', () {
      final p = promiseProgress(_row(), [
        _c(1, 'kept'),
        _c(2, 'kept'),
        _c(3, 'missed'),
        _c(4, 'kept'),
      ], DateTime(2026, 11, 4, 21));
      expect(p.days.take(4), [
        DayMark.kept,
        DayMark.kept,
        DayMark.grace,
        DayMark.kept,
      ]);
      expect(p.streak, 3);
      expect(p.graceLeft, 2);
    });

    test('with no grace left a miss restarts the streak', () {
      final row = _row(length: 7); // one grace
      final p = promiseProgress(row, [
        _c(1, 'kept'),
        _c(2, 'missed'),
        _c(3, 'kept'),
        _c(4, 'missed'),
        _c(5, 'kept'),
      ], DateTime(2026, 11, 5, 21));
      expect(p.days[1], DayMark.grace);
      expect(p.days[3], DayMark.missed);
      expect(p.streak, 1);
      expect(p.best, 2);
      expect(p.graceLeft, 0);
    });

    test('yesterday stays open; older silence counts as missed', () {
      final p = promiseProgress(_row(), [
        _c(1, 'kept'),
      ], DateTime(2026, 11, 5, 9));
      // Days 2 and 3 were never answered, 4 is yesterday, 5 is today.
      expect(p.days.take(5), [
        DayMark.kept,
        DayMark.grace,
        DayMark.grace,
        DayMark.open,
        DayMark.open,
      ]);
      expect(p.yesterdayOpen, isTrue);
    });

    test('finishes after the last day', () {
      final row = _row(length: 3);
      final all = [_c(1, 'kept'), _c(2, 'kept'), _c(3, 'kept')];
      expect(
        promiseProgress(row, all, DateTime(2026, 11, 3, 21)).finished,
        isTrue,
      );
      expect(
        promiseProgress(
          row,
          all.take(2).toList(),
          DateTime(2026, 11, 3, 9),
        ).finished,
        isFalse,
      );
      final after = promiseProgress(row, all, DateTime(2026, 11, 9));
      expect(after.finished, isTrue);
      expect(after.dayNumber, 3);
      expect(after.days, hasLength(3));
    });

    test('ongoing promises grow day by day', () {
      final p = promiseProgress(_row(length: null), [
        _c(1, 'kept'),
      ], DateTime(2026, 11, 10, 9));
      expect(p.days, hasLength(10));
      expect(p.daysLeft, isNull);
      expect(p.finished, isFalse);
    });
  });

  group('service', () {
    late AppDatabase db;
    late _Nudger nudger;
    var now = DateTime(2026, 11, 2, 9);
    late PromiseService service;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      nudger = _Nudger();
      now = DateTime(2026, 11, 2, 9);
      service = PromiseService(db, clock: () => now, nudger: nudger);
    });
    tearDown(() => db.close());

    test(
      'create needs only a title, cleans it, and schedules a nudge',
      () async {
        final id = await service.create(
          title: '  i promise to walk 20 minutes ',
          nudgeMinute: 21 * 60,
        );
        final view = (await service.get(id))!;
        expect(view.title, 'Walk 20 minutes');
        expect(view.promise.lengthDays, 21);
        expect(view.promise.startDay, DateTime(2026, 11, 2));
        expect(
          nudger.scheduled[PromiseService.nudgeId(id)],
          DateTime(2026, 11, 2, 21),
        );
        expect(() => service.create(title: '   '), throwsArgumentError);
      },
    );

    test(
      'checking in moves the nudge to tomorrow; undo brings it back',
      () async {
        final id = await service.create(title: 'Read', nudgeMinute: 21 * 60);
        await service.checkIn(id, 'kept');
        expect((await service.get(id))!.progress.keptToday, isTrue);
        expect(
          nudger.scheduled[PromiseService.nudgeId(id)],
          DateTime(2026, 11, 3, 21),
        );
        await service.clearCheckIn(id, now);
        expect((await service.get(id))!.progress.answeredToday, isFalse);
        expect(
          nudger.scheduled[PromiseService.nudgeId(id)],
          DateTime(2026, 11, 2, 21),
        );
      },
    );

    test('answering again replaces the answer', () async {
      final id = await service.create(title: 'Read');
      await service.checkIn(id, 'missed');
      await service.checkIn(id, 'kept');
      final view = (await service.get(id))!;
      expect(view.checkIns, hasLength(1));
      expect(view.progress.keptToday, isTrue);
    });

    test('yesterday can be answered, older days cannot', () async {
      final id = await service.create(title: 'Read');
      now = DateTime(2026, 11, 3, 9);
      await service.checkIn(id, 'kept', day: DateTime(2026, 11, 2));
      expect((await service.get(id))!.progress.yesterdayOpen, isFalse);
      now = DateTime(2026, 11, 5, 9);
      expect(
        () => service.checkIn(id, 'kept', day: DateTime(2026, 11, 2)),
        throwsArgumentError,
      );
    });

    test('the last answer finishes the promise; undo reopens it', () async {
      final id = await service.create(title: 'Read', lengthDays: 2);
      await service.checkIn(id, 'kept');
      now = DateTime(2026, 11, 3, 20);
      await service.checkIn(id, 'kept');
      expect((await service.get(id))!.promise.status, 'done');
      await service.clearCheckIn(id, now);
      expect((await service.get(id))!.promise.status, 'active');
    });

    test('release, renew, delete and restore', () async {
      final id = await service.create(title: 'Read', nudgeMinute: 1200);
      await service.release(id);
      expect((await service.get(id))!.promise.status, 'released');
      expect(nudger.scheduled, isEmpty);

      final again = await service.renew(id);
      expect(again, isNot(id));
      expect((await service.get(again))!.title, 'Read');
      expect((await service.get(again))!.promise.nudgeMinute, 1200);

      await service.checkIn(again, 'kept');
      await service.delete(again);
      expect(await service.get(again), isNull);
      expect(nudger.scheduled[PromiseService.nudgeId(again)], isNull);
      final deletedAt = now;
      await service.restore(again, deletedAt);
      final back = (await service.get(again))!;
      expect(back.progress.keptToday, isTrue);
    });

    test('watchAll updates on check-ins', () async {
      final id = await service.create(title: 'Read');
      final stream = service.watchAll();
      final first = await stream.first;
      expect(first.single.progress.answeredToday, isFalse);
      await service.checkIn(id, 'kept');
      final next = await service.watchAll().first;
      expect(next.single.progress.keptToday, isTrue);
    });

    test('100 promises load without trouble', () async {
      for (var i = 0; i < 100; i++) {
        await service.create(title: 'Promise $i');
      }
      expect(await service.loadAll(), hasLength(100));
    });
  });
}
