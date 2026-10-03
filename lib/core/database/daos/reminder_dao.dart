part of '../app_database.dart';

@DriftAccessor(tables: [ReminderTable])
class ReminderDao extends DatabaseAccessor<AppDatabase>
    with _$ReminderDaoMixin {
  ReminderDao(super.db);

  /// Watch all reminders ordered by scheduledAt asc.
  Stream<List<Reminder>> watchAllReminders() {
    return (select(reminderTable)
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)]))
        .watch();
  }

  /// Watch active upcoming reminders from now onwards.
  Stream<List<Reminder>> watchUpcomingReminders() {
    final now = DateTime.now();
    return (select(reminderTable)
          ..where((r) => r.isActive.equals(true) & r.scheduledAt.isBiggerOrEqualValue(now))
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)]))
        .watch();
  }

  /// Watch the single next upcoming active reminder.
  Stream<Reminder?> watchNextReminder() {
    final now = DateTime.now();
    return (select(reminderTable)
          ..where((r) => r.isActive.equals(true) & r.scheduledAt.isBiggerOrEqualValue(now))
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Get reminder by ID.
  Future<Reminder?> getReminderById(int id) {
    return (select(reminderTable)..where((r) => r.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new reminder.
  Future<int> insertReminder(ReminderTableCompanion reminder) {
    return into(reminderTable).insert(reminder);
  }

  /// Update an existing reminder.
  Future<bool> updateReminder(ReminderTableCompanion reminder) {
    return update(reminderTable).replace(reminder);
  }

  /// Delete reminder by id.
  Future<int> deleteReminder(int id) {
    return (delete(reminderTable)..where((r) => r.id.equals(id))).go();
  }
}
