part of '../app_database.dart';

@DriftAccessor(tables: [ReminderTable])
class ReminderDao extends DatabaseAccessor<AppDatabase>
    with _$ReminderDaoMixin {
  ReminderDao(super.db);
  final _deletedReminders = <int, (Reminder, List<int>)>{};
  void clearDeletionUndo() => _deletedReminders.clear();

  /// Watch all reminders ordered by scheduledAt asc.
  Stream<List<Reminder>> watchAllReminders() {
    return (select(
      reminderTable,
    )..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)])).watch();
  }

  /// Watch active upcoming reminders from now onwards.
  Stream<List<Reminder>> watchUpcomingReminders() {
    final now = DateTime.now();
    return (select(reminderTable)
          ..where(
            (r) =>
                r.isActive.equals(true) &
                r.scheduledAt.isBiggerOrEqualValue(now),
          )
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)]))
        .watch();
  }

  /// Get active reminders that are overdue (scheduledAt before now).
  /// Acknowledge only the version actually sent to the OS. Never replace a
  /// newer edit with a stale full-row snapshot after an asynchronous effect.
  Future<bool> acknowledgeAlertSync(Reminder snapshot) async {
    final changed =
        await (update(reminderTable)..where(
              (r) =>
                  r.id.equals(snapshot.id) &
                  r.title.equals(snapshot.title) &
                  r.scheduledAt.equals(snapshot.scheduledAt) &
                  r.isActive.equals(snapshot.isActive) &
                  r.alarmEnabled.equals(snapshot.alarmEnabled),
            ))
            .write(
              const ReminderTableCompanion(alertSyncPending: Value(false)),
            );
    return changed == 1;
  }

  Future<List<Reminder>> getOverdueActiveReminders() {
    final now = DateTime.now();
    return (select(reminderTable)
          ..where(
            (r) =>
                r.isActive.equals(true) & r.scheduledAt.isSmallerThanValue(now),
          )
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)]))
        .get();
  }

  /// Watch the single next upcoming active reminder.
  Stream<Reminder?> watchNextReminder() {
    final now = DateTime.now();
    return (select(reminderTable)
          ..where(
            (r) =>
                r.isActive.equals(true) &
                r.scheduledAt.isBiggerOrEqualValue(now),
          )
          ..orderBy([(r) => OrderingTerm.asc(r.scheduledAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Get reminder by ID.
  Future<Reminder?> getReminderById(int id) {
    return (select(
      reminderTable,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
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
  Future<int> deleteReminder(int id) => db.transaction(() async {
    final original = await getReminderById(id);
    if (original != null) {
      _deletedReminders[id] = (original, await getLinkedThoughtIds(id));
      if (_deletedReminders.length > 20) {
        _deletedReminders.remove(_deletedReminders.keys.first);
      }
      await db
          .into(db.aiCommandTable)
          .insert(
            AiCommandTableCompanion.insert(
              requestId:
                  'native.reminder.delete:$id:${DateTime.now().microsecondsSinceEpoch}',
              capability: 'reminders.delete-effect',
              argumentsJson: jsonEncode({'id': id}),
              resultJson: jsonEncode({
                'cancelReminderIds': [id],
                'alertEffectsPending': true,
              }),
            ),
          );
    }
    await (db.delete(
      db.thoughtReminderLinkTable,
    )..where((l) => l.reminderId.equals(id))).go();
    return (delete(reminderTable)..where((r) => r.id.equals(id))).go();
  });

  Future<List<int>> getLinkedThoughtIds(int id) async =>
      (await (db.select(
            db.thoughtReminderLinkTable,
          )..where((l) => l.reminderId.equals(id))).get())
          .map((l) => l.thoughtId)
          .toList();

  Future<bool> restoreDeletedReminder(
    Reminder original,
    List<int> thoughtIds,
  ) => db.transaction(() async {
    if (await getReminderById(original.id) != null) return false;
    final saved = _deletedReminders[original.id];
    if (saved == null) return false;
    original = saved.$1;
    thoughtIds = saved.$2;
    final task = original.linkedTaskId == null
        ? null
        : await db.taskDao.getTaskById(original.linkedTaskId!);
    final taskExists = original.linkedTaskId == null || task != null;
    await into(reminderTable).insert(
      original
          .toCompanion(true)
          .copyWith(
            isActive: Value(
              original.isActive && task?.actualCompletedDate == null,
            ),
            linkedTaskId: taskExists
                ? Value(original.linkedTaskId)
                : const Value(null),
            alertSyncPending: const Value(true),
          ),
    );
    for (final id in thoughtIds) {
      if (await db.thoughtDao.getThoughtById(id) != null) {
        await db
            .into(db.thoughtReminderLinkTable)
            .insert(
              ThoughtReminderLinkTableCompanion.insert(
                thoughtId: id,
                reminderId: original.id,
              ),
            );
      }
    }
    _deletedReminders.remove(original.id);
    return true;
  });

  /// Get reminders linked to a specific task ID.
  Future<List<Reminder>> getRemindersByTaskId(int taskId) {
    return (select(
      reminderTable,
    )..where((r) => r.linkedTaskId.equals(taskId))).get();
  }

  /// Delete reminders linked to a specific task ID.
  Future<int> deleteRemindersByTaskId(int taskId) => db.transaction(() async {
    final reminders = await getRemindersByTaskId(taskId);
    for (final reminder in reminders) {
      await deleteReminder(reminder.id);
    }
    return reminders.length;
  });
}
