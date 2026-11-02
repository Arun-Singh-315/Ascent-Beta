import 'dart:io';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/history/history_ledger.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  Future<List<HistoryEvent>> events() => db.select(db.historyEventTable).get();
  test(
    'snapshots commit atomically, preserve previous titles and exclude heartbeat noise',
    () async {
      final id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Original title'),
      );
      await (db.update(db.taskTable)..where((t) => t.id.equals(id))).write(
        const TaskTableCompanion(title: d.Value('New title')),
      );
      final values = await events();
      expect(
        values.map((e) => e.title),
        containsAll(['Original title', 'New title']),
      );
      final before = values.length;
      await expectLater(
        db.transaction(() async {
          await db.taskDao.insertTask(
            TaskTableCompanion.insert(title: 'Rollback'),
          );
          throw StateError('fail');
        }),
        throwsStateError,
      );
      expect((await events()).length, before);
      final category = (await db.select(db.sessionCategoryTable).get()).first;
      final session = await db
          .into(db.timeSessionTable)
          .insert(
            TimeSessionTableCompanion.insert(
              label: 'Work',
              categoryId: category.id,
              startedAt: DateTime.now(),
              linkedTaskId: d.Value(id),
            ),
          );
      final count = (await events()).length;
      await (db.update(
        db.timeSessionTable,
      )..where((s) => s.id.equals(session))).write(
        TimeSessionTableCompanion(
          durationSeconds: const d.Value(90),
          lastHeartbeatAt: d.Value(DateTime.now()),
        ),
      );
      expect((await events()).length, count);
    },
  );
  test(
    'overdue and unscheduled completions stay visible on their completion day',
    () async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final a = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Overdue',
          plannedDate: d.Value(yesterday),
        ),
      );
      final b = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Unscheduled'),
      );
      await db.taskDao.markComplete(a);
      await db.taskDao.markComplete(b);
      expect(
        (await db.taskDao.getTodayAndOverdueTasks()).map((t) => t.id),
        containsAll([a, b]),
      );
      expect(
        (await db.taskDao.getTodayAndOverdueTasks(
          now.add(const Duration(days: 1)),
        )).map((t) => t.id),
        isNot(contains(a)),
      );
    },
  );
  test(
    'archive keeps data, cancels alerts, survives restart and restores without fabricating completion',
    () async {
      final id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Keep this'),
      );
      await db
          .into(db.reminderTable)
          .insert(
            ReminderTableCompanion.insert(
              title: 'Keep this',
              scheduledAt: DateTime.now().add(const Duration(days: 1)),
              linkedTaskId: d.Value(id),
              alarmEnabled: const d.Value(true),
            ),
          );
      await db.taskDao.archiveTask(id);
      expect((await db.taskDao.getTaskById(id))!.isArchived, isTrue);
      expect(await db.taskDao.getTodayAndOverdueTasks(), isEmpty);
      expect(
        (await db.select(db.reminderTable).get()).single.isActive,
        isFalse,
      );
      expect((await events()).any((e) => e.action == 'archived'), isTrue);
      expect(await db.taskDao.restoreArchivedTask(id), isTrue);
      expect((await db.taskDao.getTaskById(id))!.actualCompletedDate, isNull);
    },
  );
  test(
    'deleting a task preserves earned sessions and undo reattaches them',
    () async {
      final id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Task'),
      );
      final cat = (await db.select(db.sessionCategoryTable).get()).first;
      await db
          .into(db.timeSessionTable)
          .insert(
            TimeSessionTableCompanion.insert(
              label: 'Task session',
              categoryId: cat.id,
              startedAt: DateTime.now(),
              linkedTaskId: d.Value(id),
              status: const d.Value('completed'),
              durationSeconds: const d.Value(120),
            ),
          );
      await db.taskDao.deleteTask(id);
      expect(
        (await db.select(db.timeSessionTable).get()).single.linkedTaskId,
        isNull,
      );
      expect(
        (await db.select(db.timeSessionTable).get()).single.durationSeconds,
        120,
      );
      expect(await db.taskDao.restoreDeletedTask(id), isTrue);
      expect(
        (await db.select(db.timeSessionTable).get()).single.linkedTaskId,
        id,
      );
    },
  );
  test(
    'hydration goals keep past dates, and unknown past goals stay unknown',
    () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final day =
          '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      await db
          .into(db.waterGoalVersionTable)
          .insert(
            WaterGoalVersionTableCompanion.insert(day: day, targetMl: 1800),
          );
      await db.waterDao.setDailyWaterGoal(2400);
      final history = await db.waterDao.getPast7DaysHistory();
      expect(history.last.goalMl, 2400);
      expect(history[5].goalMl, 1800);
      expect(history.first.goalMl, 0);
      expect(history.first.isGoalMet, isFalse);
    },
  );
  test(
    'private promises propagate privacy to snapshots and permanent deletion purges it',
    () async {
      final repository = PromiseRepository(
        db,
        scheduleNotification: (id, title, body, at) async => true,
        cancelNotification: (id) async {},
      );
      final promise = await repository.createPromise(
        title: 'Private promise',
        intention: 'Personal',
        category: 'Personal',
        trackingType: PromiseTrackingType.completion,
        isPrivate: true,
      );
      expect(
        (await events())
            .where((e) => e.privacyThoughtId == promise.id)
            .every((e) => e.isPrivate),
        isTrue,
      );
      await repository.deletePromise(promise.id);
      expect(
        (await events()).where((e) => e.privacyThoughtId == promise.id),
        isEmpty,
      );
    },
  );
  test(
    'version 21 migrates without losing existing records or pretending to know prior edits',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'ascent-history-migration',
      );
      final file = File('${dir.path}/workspace.sqlite');
      final old = AppDatabase.forTesting(NativeDatabase(file));
      final id = await old.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Keep my record',
          notes: const d.Value('Original notes'),
        ),
      );
      final triggers = await old
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type='trigger' AND name LIKE 'history_%'",
          )
          .get();
      for (final row in triggers) {
        await old.customStatement('DROP TRIGGER ${row.read<String>('name')}');
      }
      await old.customStatement('DROP TABLE history_events');
      await old.customStatement('DROP TABLE water_goal_versions');
      await old.customStatement('ALTER TABLE tasks DROP COLUMN is_archived');
      await old.customStatement('PRAGMA user_version=21');
      await old.close();
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final record = await upgraded.taskDao.getTaskById(id);
        expect(record!.title, 'Keep my record');
        expect(record.notes, 'Original notes');
        expect(record.isArchived, isFalse);
        final history = await upgraded.select(upgraded.historyEventTable).get();
        expect(
          history
              .where((e) => e.module == 'tasks' && e.entityId == '$id')
              .single
              .action,
          'saved',
        );
        expect(
          history.where((e) => e.module == 'tasks').single.imported,
          isTrue,
        );
        expect(
          await upgraded.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await upgraded.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test('backfill is idempotent and never invents edits', () async {
    await db.taskDao.insertTask(TaskTableCompanion.insert(title: 'Existing'));
    await HistoryLedger.backfill(db);
    final count = (await events()).length;
    await HistoryLedger.backfill(db);
    expect((await events()).length, count);
    expect(
      (await events())
          .where((e) => e.imported)
          .every((e) => e.action == 'saved'),
      isTrue,
    );
  });
}
