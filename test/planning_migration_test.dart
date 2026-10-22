import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/core/services/plan_service.dart';
import 'package:ascent/core/backup/workspace_backup_service.dart';
import 'workspace_backup_test.dart' show MemoryBackupPreferences;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('schema 17 upgrade retains schedules and imports once', () async {
    final folder = await Directory.systemTemp.createTemp('planning-migration-');
    final file = File('${folder.path}/workspace.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(file));
    try {
      final old = await PlanService(db).createPlan(
        title: 'Existing routine',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        localTime: '07:00',
        recurrenceRule: 'daily',
      );
      final occurrences = await db.planDao.getOccurrencesForPlan(old.id);
      final reminderIds = (await db.reminderDao.watchAllReminders().first)
          .map((r) => r.id)
          .toList();
      await db.customStatement('DROP TABLE plan_collection_items');
      await db.customStatement('DROP TABLE plan_collections');
      await db.customStatement('ALTER TABLE thoughts DROP COLUMN category');
      await db.customStatement('PRAGMA user_version = 17');
      await db.close();
      db = AppDatabase.forTesting(NativeDatabase(file));
      final service = PlanCollectionService(db);
      await service.importLegacy();
      await service.importLegacy();
      expect((await service.watchCollections().first).length, 1);
      expect(
        (await db.planDao.getOccurrencesForPlan(old.id)).map((o) => o.id),
        occurrences.map((o) => o.id),
      );
      expect(
        (await db.reminderDao.watchAllReminders().first).map((r) => r.id),
        reminderIds,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    } finally {
      await db.close();
      await folder.delete(recursive: true);
    }
  });
  test(
    'backup restores collections, completion, provenance and alert ownership',
    () async {
      final folder = await Directory.systemTemp.createTemp('planning-backup-');
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final service = PlanCollectionService(db);
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        final id = await service.save(
          title: 'Portable plan',
          requestId: 'portable',
          items: [
            const PlanItemDraft(title: 'Done'),
            PlanItemDraft(title: 'Future alarm', at: tomorrow, alert: 'alarm'),
          ],
        );
        await service.complete(
          (await service.watchItems(id).first).first,
          true,
        );
        final backup = WorkspaceBackupService(
          db,
          MemoryBackupPreferences(),
          folder,
        );
        final raw = await backup.export();
        await service.deleteCollection(id);
        await backup.restore(raw, confirmed: true);
        final restored = (await service.watchCollections().first).single;
        expect(restored.id, id);
        expect(restored.done, 1);
        expect(restored.total, 2);
        expect(
          (await db.reminderDao.watchAllReminders().first).single.alarmEnabled,
          isTrue,
        );
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await db.close();
        await folder.delete(recursive: true);
      }
    },
  );
}
