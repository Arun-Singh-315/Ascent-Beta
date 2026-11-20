import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/promise_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late DateTime now;
  late PromiseService service;
  late Map<int, String> alerts;
  late List<DateTime> times;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 24, 11);
    alerts = {};
    times = [];
    service = PromiseService(
      db,
      clock: () => now,
      scheduleNotification: (id, copy, at) async {
        alerts[id] = copy;
        times.add(at);
      },
      cancelNotification: (id) async {
        alerts.remove(id);
      },
    );
  });
  tearDown(() => db.close());

  test(
    'many promises share remaining daily alerts and personalize the whole list',
    () async {
      await db.userProfileDao.upsertProfile(
        UserProfileTableCompanion.insert(name: 'Arun Singh'),
      );
      final ids = await service.createBatch([
        'Go for a walk',
        'Read a chapter',
      ]);
      expect(ids, hasLength(2));
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
      expect(alerts, hasLength(3));
      expect(times.map((at) => at.hour), [14, 18, 21]);
      expect(
        alerts.values.every(
          (copy) =>
              copy.contains('Hey Arun') &&
              copy.contains('1. Go for a walk') &&
              copy.contains('2. Read a chapter'),
        ),
        isTrue,
      );
      await service.update(thoughtId: ids.first, content: 'Walk slowly');
      expect(
        alerts.values.every(
          (copy) =>
              copy.contains('Walk slowly') && !copy.contains('Go for a walk'),
        ),
        isTrue,
      );
      await db.thoughtDao.setCompleted(ids.first, true);
      await service.syncCheckIns();
      expect(
        alerts.values.every((copy) => !copy.contains('Walk slowly')),
        isTrue,
      );
      await db.thoughtDao.archiveThought(ids.last);
      await service.syncCheckIns();
      expect(alerts, isEmpty);
    },
  );

  test(
    'invalid batches never partially save and yesterday never gets new check-ins',
    () async {
      await expectLater(
        service.createBatch(['Valid', '']),
        throwsArgumentError,
      );
      expect(await db.select(db.thoughtTable).get(), isEmpty);
      await service.create(content: 'Yesterday’s promise');
      now = DateTime(2026, 10, 25, 8);
      await service.syncCheckIns();
      expect(alerts, isEmpty);
      expect(await db.select(db.thoughtTable).get(), hasLength(1));
    },
  );

  test(
    'notification failure preserves promises and a later sync retries',
    () async {
      var unavailable = true;
      final retry = PromiseService(
        db,
        clock: () => now,
        cancelNotification: (_) async {},
        scheduleNotification: (id, copy, at) async {
          if (unavailable) throw StateError('denied');
          alerts[id] = copy;
        },
      );
      await retry.create(content: 'A small step');
      expect(await db.select(db.thoughtTable).get(), hasLength(1));
      expect(alerts, isEmpty);
      unavailable = false;
      expect(await retry.syncCheckIns(), isTrue);
      expect(alerts, hasLength(3));
    },
  );

}
