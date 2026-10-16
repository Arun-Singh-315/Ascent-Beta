import 'dart:convert';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());
  test(
    'Task Undo restores original IDs, descendants, typed note links, reminders and timer history',
    () async {
      final note = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Source'),
      );
      final root = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Checklist'),
      );
      final child = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Child',
          parentTaskId: d.Value(root),
          linkedThoughtId: d.Value(note),
        ),
      );
      final reminder = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Child reminder',
          linkedTaskId: d.Value(child),
          scheduledAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      await db
          .into(db.thoughtReminderLinkTable)
          .insert(
            ThoughtReminderLinkTableCompanion.insert(
              thoughtId: note,
              reminderId: reminder,
            ),
          );
      final started = DateTime.now().subtract(const Duration(hours: 2));
      final session = await db.timeSessionDao.startSession(
        startedAt: started,
        label: 'Child',
        categoryId: 1,
        linkedTaskId: child,
      );
      await db.timeSessionDao.heartbeat(session, 30);
      await db.taskDao.deleteTask(root);
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
      expect(await db.taskDao.restoreDeletedTask(root), true);
      expect((await db.taskDao.getTaskById(child))!.parentTaskId, root);
      expect((await db.taskDao.getTaskById(child))!.linkedThoughtId, note);
      expect(
        (await db.reminderDao.getReminderById(reminder))!.linkedTaskId,
        child,
      );
      expect(
        (await db.reminderDao.getReminderById(reminder))!.alertSyncPending,
        true,
      );
      expect(await db.select(db.thoughtReminderLinkTable).get(), hasLength(1));
      final restored = (await db.select(db.timeSessionTable).get()).single;
      expect(restored.id, session);
      expect(restored.status, 'paused');
      expect(restored.durationSeconds, 30);
      final pauses = jsonDecode(restored.pausedIntervals) as List;
      final boundary = DateTime.parse(pauses.last['pausedAt']);
      expect(boundary.difference(restored.startedAt).inSeconds, 30);
      expect(pauses.last['resumedAt'], isNull);
    },
  );
  test(
    'Undo preserves a newer note association and never overwrites a reused task ID',
    () async {
      final note = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Source'),
      );
      final old = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Old', linkedThoughtId: d.Value(note)),
      );
      await db.taskDao.deleteTask(old);
      final newer = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'New', linkedThoughtId: d.Value(note)),
      );
      expect(await db.taskDao.restoreDeletedTask(old), true);
      expect((await db.taskDao.getTaskById(old))!.linkedThoughtId, isNull);
      expect((await db.taskDao.getTaskById(newer))!.linkedThoughtId, note);
      await db.taskDao.deleteTask(old);
      await db
          .into(db.taskTable)
          .insert(
            TaskTableCompanion.insert(
              id: d.Value(old),
              title: 'Reused by newer work',
            ),
          );
      expect(await db.taskDao.restoreDeletedTask(old), false);
      expect(
        (await db.taskDao.getTaskById(old))!.title,
        'Reused by newer work',
      );
    },
  );
  test(
    'Workspace replacement invalidates old task, thought and reminder Undo actions',
    () async {
      final note = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Old note'),
      );
      final original = (await db.thoughtDao.getThoughtById(note))!;
      final task = await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Old task'),
      );
      final reminder = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Old reminder',
          scheduledAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
      final oldReminder = (await db.reminderDao.getReminderById(reminder))!;
      await db.taskDao.deleteTask(task);
      await db.thoughtDao.deleteThought(note);
      await db.reminderDao.deleteReminder(reminder);
      db.clearDeletionUndo();
      expect(await db.taskDao.restoreDeletedTask(task), false);
      await db.thoughtDao.restoreDeletedThought(original);
      expect(await db.thoughtDao.getThoughtById(note), isNull);
      expect(
        await db.reminderDao.restoreDeletedReminder(oldReminder, []),
        false,
      );
    },
  );
}
