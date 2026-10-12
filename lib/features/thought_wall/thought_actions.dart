import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';

class ThoughtActions {
  ThoughtActions(this.db);
  final AppDatabase db;

  Future<List<int>> addToTodo(List<Thought> thoughts, {DateTime? now}) =>
      db.transaction(() async {
        final ids = <int>[];
        for (final thought in thoughts.where((t) => !t.isCompleted)) {
          final existing = await db.taskDao.getTaskLinkedToThought(thought.id);
          ids.add(
            existing?.id ??
                await db.taskDao.insertTask(
                  TaskTableCompanion.insert(
                    title: thought.content.trim(),
                    plannedDate: drift.Value(now ?? DateTime.now()),
                    notes: drift.Value(
                      'thought_id:${thought.id} • Converted from Thought Wall',
                    ),
                  ),
                ),
          );
        }
        return ids;
      });

  Future<List<Reminder>> remind(
    List<Thought> thoughts,
    DateTime at, {
    bool asList = false,
  }) async {
    if (!at.isAfter(DateTime.now())) {
      throw ArgumentError('Choose a future time.');
    }
    if (thoughts.isEmpty) return [];
    return db.transaction(() async {
      final result = <Reminder>[];
      if (asList) {
        final id = await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: thoughts
                .asMap()
                .entries
                .map((e) => '${e.key + 1}. ${e.value.content.trim()}')
                .join('\n'),
            scheduledAt: at,
          ),
        );
        result.add((await db.reminderDao.getReminderById(id))!);
      } else {
        for (final thought in thoughts) {
          final task = await db.taskDao.getTaskLinkedToThought(thought.id);
          final id = await db.reminderDao.insertReminder(
            ReminderTableCompanion.insert(
              title: thought.content.trim(),
              scheduledAt: at,
              linkedTaskId: drift.Value(task?.id),
            ),
          );
          result.add((await db.reminderDao.getReminderById(id))!);
        }
      }
      return result;
    });
  }
}

Future<void> scheduleThoughtReminders(
  List<Reminder> reminders,
  Future<void> Function(Reminder) schedule,
) async {
  for (final reminder in reminders) {
    await schedule(reminder);
  }
}
