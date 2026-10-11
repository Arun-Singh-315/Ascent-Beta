import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';
import '../notifications/notification_service.dart';

/// Creates the linked Thought Wall, Todo, and reminder records for a promise.
/// The local records are committed together so users never get a partial promise.
class PromiseService {
  PromiseService(
    this._db, {
    Future<void> Function(int, String, DateTime)? scheduleNotification,
  }) : _scheduleNotification = scheduleNotification ?? _scheduleReminder;

  final AppDatabase _db;
  final Future<void> Function(int, String, DateTime) _scheduleNotification;

  static Future<void> _scheduleReminder(int id, String title, DateTime at) {
    return NotificationService.instance.scheduleReminderNotification(
      id: id,
      title: title,
      scheduledAt: at,
      scheduleFollowUp: false,
    );
  }

  Future<int> create({
    required String content,
    required int validityDays,
    String? promptQuestion,
  }) async {
    final text = content.trim();
    if (text.isEmpty) throw ArgumentError.value(content, 'content');
    if (text.length > 300) {
      throw RangeError('Promise text must be 300 characters or fewer.');
    }
    if (validityDays < 1 || validityDays > 365) {
      throw RangeError.range(validityDays, 1, 365, 'validityDays');
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextNineAm = DateTime(now.year, now.month, now.day, 9);
    final firstDayOffset = nextNineAm.isAfter(now) ? 0 : 1;
    final dueDate = today.add(
      Duration(days: firstDayOffset + validityDays - 1),
    );
    final reminderEntries = <({int id, DateTime at, String title})>[];
    late final int taskId;

    await _db.transaction(() async {
      final thoughtId = await _db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: text,
          mood: const drift.Value('promise'),
          colorHex: const drift.Value('#7C3AED'),
          promptQuestion: drift.Value(promptQuestion),
        ),
      );
      taskId = await _db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: text,
          // Put the promise in Today immediately. Its due date is kept in notes
          // so it remains visible while the daily reminders run.
          plannedDate: drift.Value(today),
          notes: drift.Value(
            'thought_id:$thoughtId • promise_duration_days:$validityDays • promise_due_date:${dueDate.toIso8601String()}',
          ),
        ),
      );

      final reminderTitle = _reminderTitle(text);
      for (var index = 0; index < validityDays; index++) {
        final at = DateTime(
          now.year,
          now.month,
          now.day + firstDayOffset + index,
          9,
        );
        final id = await _db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: reminderTitle,
            linkedTaskId: drift.Value(taskId),
            scheduledAt: at,
          ),
        );
        reminderEntries.add((id: id, at: at, title: reminderTitle));
      }
    });

    for (final reminder in reminderEntries) {
      await _scheduleNotification(reminder.id, reminder.title, reminder.at);
    }
    return taskId;
  }

  /// Updates the Thought Wall text and every task/reminder linked to it.
  Future<void> update({required int thoughtId, required String content}) async {
    final text = content.trim();
    if (text.isEmpty || text.length > 300) {
      throw ArgumentError.value(content, 'content', 'Use 1 to 300 characters.');
    }
    late final int linkedTaskId;
    await _db.transaction(() async {
      final thought = await _db.thoughtDao.getThoughtById(thoughtId);
      if (thought == null || thought.mood != 'promise') {
        throw StateError('The linked promise no longer exists.');
      }
      await _db.thoughtDao.updateThought(
        thought.toCompanion(true).copyWith(content: drift.Value(text)),
      );
      final task =
          await (_db.select(_db.taskTable)
                ..where((row) => row.notes.like('%thought_id:$thoughtId •%'))
                ..limit(1))
              .getSingleOrNull();
      if (task == null) {
        throw StateError('The promise Todo could not be found.');
      }
      linkedTaskId = task.id;
      await (_db.update(_db.taskTable)..where((row) => row.id.equals(task.id)))
          .write(TaskTableCompanion(title: drift.Value(text)));
      await (_db.update(
        _db.reminderTable,
      )..where((row) => row.linkedTaskId.equals(task.id))).write(
        ReminderTableCompanion(title: drift.Value(_reminderTitle(text))),
      );
    });
    final reminders = await _db.reminderDao.getRemindersByTaskId(linkedTaskId);
    for (final reminder in reminders.where((entry) => entry.isActive)) {
      await NotificationService.instance.cancel(reminder.id);
      await _scheduleNotification(
        reminder.id,
        _reminderTitle(text),
        reminder.scheduledAt,
      );
    }
  }

  String _reminderTitle(String text) =>
      'Promise: ${text.length > 291 ? '${text.substring(0, 288)}…' : text}';
}
