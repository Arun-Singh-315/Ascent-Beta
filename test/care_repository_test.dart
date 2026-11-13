import 'dart:convert';
import 'dart:io';
import 'package:ascent/core/backup/workspace_backup_service.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/care_repository.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter_test/flutter_test.dart';
import 'workspace_backup_test.dart' show MemoryBackupPreferences;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory folder;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    folder = await Directory.systemTemp.createTemp('ascent-care-test-');
  });
  tearDown(() async {
    await db.close();
    await folder.delete(recursive: true);
  });

  test(
    'separate concerns retain reports and medicine ownership through backup',
    () async {
      final repo = CareRepository(db);
      final first = await repo.savePlan(
        title: 'Thyroid care',
        person: 'Me',
        clinician: 'Clinic A',
        notes: 'Questions for next visit',
        nextVisit: DateTime(2027, 1, 10),
      );
      final second = await repo.savePlan(
        title: 'Recovery',
        person: 'Mum',
        clinician: '',
        notes: '',
      );
      final med = await MedicineService(db, syncAlerts: false).addMedicine(
        name: 'Prescribed medicine',
        dosage: 'Recorded dose',
        scheduledTimes: ['08:00'],
        durationDays: 2,
        startDate: DateTime.now(),
        carePlanId: first,
        purpose: 'As explained by my clinician',
      );
      final source = await File(
        '${folder.path}/original.pdf',
      ).writeAsBytes(utf8.encode('report evidence'));
      await repo.addRecord(
        planId: first,
        title: 'Earlier test',
        notes: 'Clinician notes',
        recordedAt: DateTime(2026, 10, 1),
        attachment: source,
        documents: folder,
      );
      await repo.addRecord(
        planId: first,
        title: 'Latest test',
        notes: '',
        recordedAt: DateTime(2026, 11, 1),
      );
      await source.delete();
      final records = await repo.watchRecords(first).first;
      expect(records.map((r) => r.title), ['Latest test', 'Earlier test']);
      expect(await repo.watchRecords(second).first, isEmpty);
      expect(
        await File(records.last.filePath!).readAsString(),
        'report evidence',
      );
      final alerts = await db.reminderDao.watchAllReminders().first;
      await repo.archive(first, true);
      expect((await db.medicineDao.getMedicineById(med))!.isActive, isTrue);
      expect(await db.reminderDao.watchAllReminders().first, alerts);
      await repo.addRecord(
        id: records.last.id,
        planId: first,
        title: 'Earlier test, reviewed',
        notes: 'Added visit notes',
        recordedAt: records.last.recordedAt,
      );
      expect(
        (await repo.watchRecords(first).first).last.filePath,
        records.last.filePath,
      );
      final restoreRecord = await repo.removeRecordWithUndo(records.last.id);
      expect(await repo.watchRecords(first).first, hasLength(1));
      await restoreRecord();
      await restoreRecord();
      expect(await repo.watchRecords(first).first, hasLength(2));
      final backup = WorkspaceBackupService(
        db,
        MemoryBackupPreferences(),
        folder,
      );
      final raw = await backup.export();
      expect((jsonDecode(raw)['payload']['files'] as List), hasLength(1));
      await db.delete(db.careRecordTable).go();
      await backup.restore(raw, confirmed: true);
      final restored = await repo.watchRecords(first).first;
      expect(
        await File(restored.last.filePath!).readAsString(),
        'report evidence',
      );
      expect(restored.last.filePath, isNot(records.last.filePath));
      expect((await db.medicineDao.getMedicineById(med))!.carePlanId, first);
      expect(
        (await repo.watchPlans().first)
            .singleWhere((p) => p.id == first)
            .nextVisit,
        DateTime(2027, 1, 10),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );

  test(
    'medicine deletion undo restores exact dose, task, reminder and history evidence',
    () async {
      final service = MedicineService(db, syncAlerts: false);
      final id = await service.addMedicine(
        name: 'Existing medicine',
        dosage: '1 tablet',
        scheduledTimes: ['00:00'],
        durationDays: 2,
        startDate: DateTime.now(),
      );
      final dose = (await db.medicineDao.watchLogsForMedicine(id).first).first;
      await service.toggleDose(dose.id, true);
      final logs = await db.medicineDao.watchLogsForMedicine(id).first;
      final child = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Connected detail',
          parentTaskId: d.Value(dose.linkedTaskId),
        ),
      );
      final note = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Question for doctor'),
      );
      final extraReminder = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Connected reminder',
          scheduledAt: DateTime.now().add(const Duration(days: 1)),
          linkedTaskId: d.Value(child),
        ),
      );
      await db
          .into(db.thoughtReminderLinkTable)
          .insert(
            ThoughtReminderLinkTableCompanion.insert(
              thoughtId: note,
              reminderId: extraReminder,
            ),
          );
      final session = await db.timeSessionDao.startSession(
        startedAt: DateTime.now(),
        label: 'Connected session',
        categoryId: 1,
        linkedTaskId: child,
      );
      final tasks = await db.select(db.taskTable).get();
      final reminders = await db.reminderDao.watchAllReminders().first;
      final events = await db.select(db.historyEventTable).get();
      final restore = await service.removeWithUndo(id);
      expect(await db.medicineDao.getMedicineById(id), isNull);
      expect(await db.medicineDao.watchLogsForMedicine(id).first, isEmpty);
      await restore();
      await restore();
      expect(await db.medicineDao.watchLogsForMedicine(id).first, logs);
      expect(await db.select(db.taskTable).get(), tasks);
      expect(
        (await db.select(db.thoughtReminderLinkTable).get()).single.reminderId,
        extraReminder,
      );
      expect(
        (await (db.select(
          db.timeSessionTable,
        )..where((s) => s.id.equals(session))).getSingle()).linkedTaskId,
        child,
      );
      expect(
        (await db.reminderDao.watchAllReminders().first).map((r) => r.id),
        reminders.map((r) => r.id),
      );
      expect(
        (await db.select(db.historyEventTable).get()).map((e) => e.id).toSet(),
        events.map((e) => e.id).toSet(),
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
      final stale = await service.removeWithUndo(id);
      db.markWorkspaceReplaced();
      await expectLater(stale(), throwsStateError);
    },
  );

  for (final version in [21, 23]) {
    test(
      'schema $version upgrade preserves medicine IDs and dose evidence',
      () async {
        final file = File('${folder.path}/legacy.sqlite');
        var legacy = AppDatabase.forTesting(NativeDatabase(file));
        try {
          final id = await MedicineService(legacy, syncAlerts: false)
              .addMedicine(
                name: 'Existing schedule',
                dosage: '1 tablet',
                scheduledTimes: ['08:00'],
                durationDays: 2,
                startDate: DateTime.now(),
              );
          final logs = await legacy.medicineDao.watchLogsForMedicine(id).first;
          for (final name in ['care_plans', 'care_records', 'medicines']) {
            for (final op in ['insert', 'update', 'delete']) {
              await legacy.customStatement(
                'DROP TRIGGER IF EXISTS history_${name}_$op',
              );
            }
          }
          await legacy.customStatement(
            'ALTER TABLE medicines DROP COLUMN care_plan_id',
          );
          await legacy.customStatement(
            'ALTER TABLE medicines DROP COLUMN purpose',
          );
          await legacy.customStatement('DROP TABLE care_records');
          await legacy.customStatement('DROP TABLE care_plans');
          if (version == 21) {
            final triggers = await legacy
                .customSelect(
                  "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'history_%'",
                )
                .get();
            for (final trigger in triggers) {
              await legacy.customStatement(
                'DROP TRIGGER ${trigger.read<String>('name')}',
              );
            }
            await legacy.customStatement('DROP TABLE history_events');
            await legacy.customStatement('DROP TABLE water_goal_versions');
            await legacy.customStatement(
              'ALTER TABLE tasks DROP COLUMN is_archived',
            );
            await legacy.customStatement(
              'ALTER TABLE tasks DROP COLUMN is_daily_standing',
            );
          }
          await legacy.customStatement('PRAGMA user_version = $version');
          await legacy.close();
          legacy = AppDatabase.forTesting(NativeDatabase(file));
          final medicine = (await legacy.medicineDao.getMedicineById(id))!;
          expect(medicine.name, 'Existing schedule');
          expect(medicine.carePlanId, isNull);
          expect(medicine.purpose, '');
          expect(await legacy.medicineDao.watchLogsForMedicine(id).first, logs);
          expect(await CareRepository(legacy).watchPlans().first, isEmpty);
          expect(
            await legacy.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
        } finally {
          await legacy.close();
        }
      },
    );
  }
}
