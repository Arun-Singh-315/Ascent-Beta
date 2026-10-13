import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';

void main() {
  late AppDatabase db;
  late MedicineService service;
  final now = DateTime(2027, 1, 31, 10);
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = MedicineService(db, syncAlerts: false, clock: () => now);
  });
  tearDown(() async => db.close());
  Future<int> create() => service.addMedicine(
    name: 'User schedule',
    dosage: '1 tablet',
    scheduledTimes: ['08:00', '20:00'],
    durationDays: 3,
    startDate: DateTime(2027, 1, 31),
  );
  test(
    'Invalid schedules and mid-generation failures roll back every related row',
    () async {
      await expectLater(
        service.addMedicine(
          name: 'Test',
          dosage: '1',
          scheduledTimes: ['25:00'],
          durationDays: 3,
          startDate: now,
        ),
        throwsArgumentError,
      );
      await db.customStatement(
        "CREATE TRIGGER fail_dose BEFORE INSERT ON medicine_logs BEGIN SELECT RAISE(ABORT, 'disk failure'); END;",
      );
      await expectLater(create(), throwsA(anything));
      expect(await db.select(db.medicineTable).get(), isEmpty);
      expect(await db.select(db.medicineLogTable).get(), isEmpty);
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
    },
  );
  test(
    'Editing preserves taken evidence and historical slots, replacing only future pending doses',
    () async {
      final id = await create();
      final logs = await db.medicineDao.watchLogsForMedicine(id).first;
      final taken = logs.firstWhere(
        (l) => l.dateStr == '2027-02-01' && l.timeSlot == '08:00',
      );
      await service.toggleDose(taken.id, true);
      final takenAt = (await db.medicineDao.watchLogsForMedicine(id).first)
          .firstWhere((l) => l.id == taken.id)
          .takenAt;
      await service.updateMedicine(
        id,
        name: 'Renamed',
        scheduledTimes: ['09:00'],
        durationDays: 4,
      );
      final next = await db.medicineDao.watchLogsForMedicine(id).first;
      expect(
        next.any((l) => l.id == logs.first.id),
        true,
      ); // Historical missed slot.
      final preserved = next.firstWhere((l) => l.id == taken.id);
      expect(preserved.takenAt, takenAt);
      expect(preserved.linkedTaskId, taken.linkedTaskId);
      expect(
        next
            .where((l) => !l.isTaken && l.dateStr.compareTo('2027-02-01') >= 0)
            .map((l) => l.timeSlot)
            .toSet(),
        {'09:00'},
      );
      expect((await db.select(db.medicineTable).get()), hasLength(1));
      expect(
        (await db.taskDao.getTaskById(taken.linkedTaskId!))!.title,
        contains('User schedule'),
      );
      expect(
        (await db.select(db.aiCommandTable).get()).any(
          (r) => r.capability == 'reminders.delete-effect',
        ),
        true,
      );
      expect(
        (await db.select(db.reminderTable).get())
            .where((r) => r.isActive)
            .every((r) => r.alertSyncPending),
        true,
      );
    },
  );
  test(
    'Unchanged schedule metadata edits retain IDs; dose logging is idempotent and reversible',
    () async {
      final id = await create();
      final initial = await db.medicineDao.watchLogsForMedicine(id).first;
      await service.updateMedicine(
        id,
        name: 'New label',
        scheduledTimes: ['20:00', '08:00'],
        durationDays: 3,
        startDate: DateTime(2027, 1, 31),
      );
      expect(
        (await db.medicineDao.watchLogsForMedicine(id).first).map((l) => l.id),
        initial.map((l) => l.id),
      );
      final log = initial.last;
      await service.toggleDose(log.id, true);
      final timestamp =
          (await db.medicineDao.watchLogsForMedicine(id).first).last.takenAt;
      await service.toggleDose(log.id, true);
      expect(
        (await db.medicineDao.watchLogsForMedicine(id).first).last.takenAt,
        timestamp,
      );
      expect(
        (await db.reminderDao.getReminderById(log.linkedReminderId!))!.isActive,
        false,
      );
      await service.toggleDose(log.id, false);
      expect(
        (await db.taskDao.getTaskById(log.linkedTaskId!))!.actualCompletedDate,
        isNull,
      );
      expect(
        (await db.reminderDao.getReminderById(log.linkedReminderId!))!.isActive,
        true,
      );
      await service.updateMedicine(id, active: false);
      expect(
        (await db.reminderDao.getReminderById(log.linkedReminderId!))!.isActive,
        false,
      );
    },
  );
  test(
    'A blocked linked task rolls back dose evidence and reminder state',
    () async {
      await create();
      final dose = (await db.select(db.medicineLogTable).get()).last;
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Unfinished linked step',
          parentTaskId: Value(dose.linkedTaskId!),
        ),
      );
      await expectLater(service.toggleDose(dose.id, true), throwsStateError);
      final unchanged = await (db.select(
        db.medicineLogTable,
      )..where((l) => l.id.equals(dose.id))).getSingle();
      expect(unchanged.isTaken, false);
      expect(unchanged.takenAt, isNull);
      expect(
        (await db.taskDao.getTaskById(dose.linkedTaskId!))!.actualCompletedDate,
        isNull,
      );
      expect(
        (await db.reminderDao.getReminderById(
          dose.linkedReminderId!,
        ))!.isActive,
        true,
      );
    },
  );
  test(
    'Failed edit preserves original catalog and projections; deletion has durable cancellation',
    () async {
      final id = await create();
      final before = await db.medicineDao.watchLogsForMedicine(id).first;
      await db.customStatement(
        "CREATE TRIGGER fail_new_dose BEFORE INSERT ON medicine_logs BEGIN SELECT RAISE(ABORT, 'disk failure'); END;",
      );
      await expectLater(
        service.updateMedicine(id, name: 'Failed', scheduledTimes: ['21:00']),
        throwsA(anything),
      );
      expect((await db.medicineDao.getMedicineById(id))!.name, 'User schedule');
      expect(
        (await db.medicineDao.watchLogsForMedicine(id).first).map((l) => l.id),
        before.map((l) => l.id),
      );
      expect(await db.select(db.aiCommandTable).get(), isEmpty);
      await service.deleteMedicine(id);
      expect(await db.select(db.medicineTable).get(), isEmpty);
      expect(await db.select(db.medicineLogTable).get(), isEmpty);
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
      expect(
        (await db.select(db.aiCommandTable).get()).where(
          (r) => r.capability == 'reminders.delete-effect',
        ),
        hasLength(6),
      );
    },
  );
}
