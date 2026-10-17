import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as d;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/backup/workspace_backup_service.dart';

class MemoryBackupPreferences implements BackupPreferences {
  Map<String, Object> values = {};
  bool fail = false;
  @override
  Map<String, Object> snapshot() => Map.of(values);
  @override
  Future<void> replace(Map<String, Object> next) async {
    if (fail) throw StateError('preference storage unavailable');
    values = Map.of(next);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory documents;
  late MemoryBackupPreferences prefs;
  late WorkspaceBackupService service;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    documents = await Directory.systemTemp.createTemp('ascent-backup-test');
    prefs = MemoryBackupPreferences();
    service = WorkspaceBackupService(db, prefs, documents);
  });
  tearDown(() async {
    await db.close();
    await documents.delete(recursive: true);
  });

  test('schema 14 workspace backups upgrade to quiet reminders', () async {
    await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Existing reminder',
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      ),
    );
    final envelope = jsonDecode(await service.export()) as Map<String, dynamic>;
    final payload = envelope['payload'] as Map<String, dynamic>;
    payload['schema'] = 14;
    final legacyTables = payload['tables'] as Map;
    legacyTables.remove('thought_reminder_links');
    legacyTables.remove('thought_merge_sources');
    legacyTables.remove('plan_definitions');
    legacyTables.remove('plan_occurrences');
    legacyTables.remove('occurrence_alert_links');
    for (final row in legacyTables['tasks'] as List) {
      (row as Map)
        ..remove('linked_thought_id')
        ..remove('learning_course_id')
        ..remove('learning_lecture_id');
    }
    for (final row in legacyTables['time_sessions'] as List) {
      (row as Map)
        ..remove('learning_course_id')
        ..remove('learning_lecture_id');
    }
    for (final row in legacyTables['reminders'] as List) {
      (row as Map).remove('alert_sync_pending');
    }
    for (final row in payload['tables']['reminders'] as List) {
      (row as Map).remove('alarm_enabled');
    }
    Object? canonical(Object? value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return {for (final k in keys) k: canonical(value[k])};
      }
      if (value is List) return value.map(canonical).toList();
      return value;
    }

    envelope['sha256'] = sha256
        .convert(utf8.encode(jsonEncode(canonical(payload))))
        .toString();
    await service.restore(jsonEncode(envelope), confirmed: true);
    expect(
      (await db.reminderDao.watchAllReminders().first).single.alarmEnabled,
      false,
    );
  });
  test(
    'round trip covers all public tables, IDs, relations and every preference type',
    () async {
      final task = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Revision',
          estimatedMinutes: const d.Value(25),
        ),
      );
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Keep this thought'),
      );
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Revision',
          scheduledAt: DateTime(2027),
          linkedTaskId: d.Value(task),
        ),
      );
      prefs.values = {
        'theme': 'light',
        'enabled': true,
        'goal': 12,
        'amount': 1.5,
        'companies': ['One', 'Two'],
        'draft': 'unsent',
      };
      final original = prefs.snapshot();
      final raw = await service.export();
      final preview = await service.inspect(raw);
      expect(
        preview.tableCounts.keys.toSet(),
        db.allTables
            .where((t) => t.actualTableName != 'backup_restore_state')
            .map((t) => t.actualTableName)
            .toSet(),
      );
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Replace this'),
      );
      prefs.values = {'new': 'discard'};
      await service.restore(raw, confirmed: true);
      expect(await db.taskDao.watchAllTasks().first, hasLength(1));
      expect(
        (await db.thoughtDao.watchAllThoughts().first).single.content,
        'Keep this thought',
      );
      expect(
        (await db.reminderDao.watchAllReminders().first).single.linkedTaskId,
        task,
      );
      expect(prefs.values..remove('ascent_restore_alert_sync_v1'), original);
    },
  );
  test(
    'confirmation is required and a corrupt checksum never changes records',
    () async {
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Untouched'),
      );
      final raw = await service.export();
      await expectLater(service.restore(raw), throwsStateError);
      final corrupt = jsonDecode(raw) as Map<String, dynamic>;
      corrupt['payload']['tables']['tasks'][0]['title'] = 'Altered';
      await expectLater(
        service.restore(jsonEncode(corrupt), confirmed: true),
        throwsFormatException,
      );
      expect(
        (await db.taskDao.watchAllTasks().first).single.title,
        'Untouched',
      );
    },
  );
  test(
    'managed resume files survive restore into a new directory with remapped paths',
    () async {
      final resume = File('${documents.path}/resume.pdf');
      await resume.writeAsBytes([37, 80, 68, 70]);
      await db.resumeDao.insertResume(
        ResumeTableCompanion.insert(versionLabel: 'CV', filePath: resume.path),
      );
      final raw = await service.export();
      final target = await Directory.systemTemp.createTemp('ascent-restored');
      try {
        await WorkspaceBackupService(
          db,
          prefs,
          target,
        ).restore(raw, confirmed: true);
        final restored = (await db.resumeDao.watchAllResumes().first).single;
        expect(restored.filePath.startsWith(target.path), isTrue);
        expect(await File(restored.filePath).readAsBytes(), [37, 80, 68, 70]);
        expect(await resume.exists(), isTrue);
      } finally {
        await target.delete(recursive: true);
      }
    },
  );
  test(
    'missing resume files block export rather than claiming a complete backup',
    () async {
      await db.resumeDao.insertResume(
        ResumeTableCompanion.insert(
          versionLabel: 'Missing',
          filePath: '${documents.path}/missing.pdf',
        ),
      );
      await expectLater(service.export(), throwsStateError);
    },
  );
  test(
    'interrupted preference restore recovers from the durable database journal',
    () async {
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Recovered'),
      );
      prefs.values = {'draft': 'remember me'};
      final raw = await service.export();
      prefs.values = {};
      prefs.fail = true;
      await expectLater(
        service.restore(raw, confirmed: true),
        throwsA(isA<RestoreRecoveryRequired>()),
      );
      prefs.fail = false;
      final restarted = WorkspaceBackupService(db, prefs, documents);
      expect(await restarted.recoverPreferences(), isTrue);
      expect(prefs.values['draft'], 'remember me');
      expect(await restarted.recoverPreferences(), isFalse);
    },
  );
  test(
    'legacy partial exports are rejected without pretending to restore everything',
    () async {
      await expectLater(
        service.inspect('{"version":"1.0.0","profile":{"name":"Someone"}}'),
        throwsFormatException,
      );
    },
  );
  test('restore can repair a missing current resume', () async {
    final file = File('${documents.path}/repair.pdf');
    await file.writeAsBytes([1, 2, 3]);
    await db.resumeDao.insertResume(
      ResumeTableCompanion.insert(versionLabel: 'Repair', filePath: file.path),
    );
    final raw = await service.export();
    await file.delete();
    await service.restore(raw, confirmed: true);
    expect(
      await File(
        (await db.resumeDao.watchAllResumes().first).single.filePath,
      ).readAsBytes(),
      [1, 2, 3],
    );
  });
  test('broken foreign keys roll back the entire replacement', () async {
    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Keep',
        linkedApplicationId: const d.Value(999),
      ),
    );
    final raw = await service.export();
    await expectLater(
      service.restore(raw, confirmed: true),
      throwsFormatException,
    );
    expect((await db.taskDao.watchAllTasks().first).single.title, 'Keep');
  });
  test('restored running Focus and walking remain paused', () async {
    await db.timeSessionDao.ensureDefaultCategories();
    final category = (await db.timeSessionDao.getCategoryByName('Study'))!;
    final start = DateTime.now().subtract(const Duration(minutes: 5));
    final id = await db.timeSessionDao.startSession(
      label: 'Revision',
      categoryId: category.id,
      startedAt: start,
    );
    await db.timeSessionDao.heartbeat(id, 300);
    prefs.values = {
      'ascent_active_walk_is_active': true,
      'ascent_active_walk_is_paused': false,
      'ascent_active_walk_start_time': start.millisecondsSinceEpoch,
    };
    final raw = await service.export();
    await service.restore(raw, confirmed: true);
    final restored = (await db.timeSessionDao.getActiveFocusSession())!;
    expect(restored.status, 'paused');
    expect(jsonDecode(restored.pausedIntervals), isNotEmpty);
    expect(prefs.values['ascent_active_walk_is_paused'], true);
  });
}
