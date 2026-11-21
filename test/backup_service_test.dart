import 'dart:io';

import 'package:ascent/core/backup/backup_service.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(
    () => drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true,
  );

  late Directory docs;
  late AppDatabase db;
  late SharedPreferences prefs;
  late BackupService service;
  var now = DateTime(2026, 11, 21, 21);

  setUp(() async {
    docs = Directory.systemTemp.createTempSync('ascent_backup_test');
    SharedPreferences.setMockInitialValues({
      'ascent_theme_mode': 'dark',
      'ascent_unlocked_features_v1': ['things', 'mind'],
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(content: 'Keep this safe'),
    );
    await db.taskDao.insertTask(TaskTableCompanion.insert(title: 'Pay rent'));
    now = DateTime(2026, 11, 21, 21);
    service = BackupService(
      db,
      prefs,
      documents: () async => docs,
      clock: () => now,
    );
  });

  tearDown(() async {
    await db.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  test('a backup holds the data and settings', () async {
    final file = await service.create();
    expect(file.existsSync(), isTrue);
    expect(p.extension(file.path), BackupService.extension);
    expect(BackupService.isEncrypted(file), isFalse);
    final (plain, summary) = await service.open(file);
    expect(summary.counts['thoughts'], 1);
    expect(summary.counts['things'], 1);
    expect(summary.createdAt, now);
    expect(summary.schemaVersion, db.schemaVersion);
    expect(service.lastBackupAt, now);
    await plain.delete();
  });

  test('a protected backup needs its password', () async {
    final file = await service.create(password: 'mango42');
    expect(BackupService.isEncrypted(file), isTrue);
    await expectLater(service.open(file), throwsA(isA<BackupException>()));
    await expectLater(
      service.open(file, password: 'wrong'),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('password'),
        ),
      ),
    );
    final (plain, summary) = await service.open(file, password: 'mango42');
    expect(summary.counts['thoughts'], 1);
    await plain.delete();
  });

  test('other files and newer backups are refused', () async {
    final junk = File(p.join(docs.path, 'notes.txt'))
      ..writeAsStringSync('hello');
    await expectLater(service.open(junk), throwsA(isA<BackupException>()));

    final file = await service.create();
    final newer = sql.sqlite3.open(file.path);
    newer.execute('PRAGMA user_version = 999');
    newer.close();
    await expectLater(
      service.open(file),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('newer version'),
        ),
      ),
    );
  });

  test('restore swaps the data in at launch and keeps a safety copy', () async {
    final file = await service.create();
    // Change things after the backup.
    await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(content: 'Added later'),
    );
    await prefs.setString('ascent_theme_mode', 'light');

    final (plain, _) = await service.open(file);
    now = now.add(const Duration(minutes: 5));
    await service.stageRestore(plain);
    expect(prefs.getBool(BackupService.pendingRestoreKey), isTrue);
    final safety = (await service.list()).where(
      (b) => p.basename(b.file.path).startsWith('before-restore'),
    );
    expect(safety, hasLength(1));

    final restored = await BackupService.applyPendingRestore(
      prefs,
      documents: () async => docs,
    );
    expect(restored, isTrue);
    expect(prefs.getBool(BackupService.pendingRestoreKey), isNull);
    expect(prefs.getString('ascent_theme_mode'), 'dark');
    expect(prefs.getString(BackupService.restoredNoticeKey), isNotNull);

    final live = sql.sqlite3.open(p.join(docs.path, BackupService.dbFileName));
    final thoughts = live.select('SELECT content FROM thoughts');
    expect(thoughts.map((r) => r['content']), ['Keep this safe']);
    expect(live.select('SELECT * FROM backup_restore_state'), isEmpty);
    live.close();
  });

  test('daily backups keep the last 7 and wait a day', () async {
    for (var i = 0; i < 9; i++) {
      now = now.add(const Duration(days: 1));
      await service.create(auto: true);
      // Distinct modification times for ordering.
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    final autos = (await service.list()).where((b) => b.auto).toList();
    expect(autos, hasLength(BackupService.keepAuto));
    expect(await service.runAutoIfDue(), isNull);
    now = now.add(const Duration(hours: 25));
    expect(await service.runAutoIfDue(), isNotNull);
    await service.setAutoEnabled(false);
    now = now.add(const Duration(days: 2));
    expect(await service.runAutoIfDue(), isNull);
  });
}
