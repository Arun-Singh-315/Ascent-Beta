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

  /// Checks if a reminder is protected by a managed plan or recurring routine.
  Future<PlanChildRestriction?> getReminderProtection(int reminderId) async {
    // 1. Check if linked to OccurrenceAlertLinkTable
    final link = await db.planDao.getAlertLinkForReminder(reminderId);
    if (link != null) {
      final occ = await db.planDao.getOccurrenceById(link.occurrenceId);
      if (occ != null) {
        final plan = await db.planDao.getPlanById(occ.planId);
        if (plan != null && plan.status != 'ended') {
          final isRoutine = plan.recurrenceRule != 'once';
          final isStart = link.role == 'start';
          return PlanChildRestriction(
            planId: plan.id,
            planTitle: plan.title,
            occurrenceId: occ.id,
            targetType: isStart ? 'start_reminder' : 'checkin_reminder',
            isRoutine: isRoutine,
            allowedActions: isRoutine
                ? (isStart
                    ? const ['turn_off_reminder', 'open_routine']
                    : const ['stop_asking', 'open_routine'])
                : (isStart
                    ? const ['turn_off_reminder', 'open_plan']
                    : const ['stop_asking', 'open_plan']),
            occurrenceDate: occ.eligibleLocalDate,
          );
        }
      }
    }

    // 2. Check if linked to one-time managed plan via AiCommandTable
    final receipts = await (db.select(db.aiCommandTable)
          ..where((r) => r.capability.equals(HomeCaptureService.capability)))
        .get();
    for (final receipt in receipts) {
      try {
        final args = jsonDecode(receipt.argumentsJson) as Map;
        if (args['reminderId'] == reminderId || args['checkInId'] == reminderId) {
          final isStart = args['reminderId'] == reminderId;
          return PlanChildRestriction(
            planId: receipt.requestId,
            planTitle: (args['title'] as String?) ?? 'Managed Plan',
            targetType: isStart ? 'start_reminder' : 'checkin_reminder',
            isRoutine: false,
            allowedActions: isStart
                ? const ['turn_off_reminder', 'open_plan']
                : const ['stop_asking', 'open_plan'],
          );
        }
      } catch (_) {}
    }
    return null;
  }

  /// Delete reminder by id.
  /// Plan-owned reminders reject raw deletion and throw [PlanChildProtectionException].
  Future<int> deleteReminder(int id, {bool bypassProtection = false}) =>
      db.transaction(() async {
        if (!bypassProtection) {
          final protection = await getReminderProtection(id);
          if (protection != null) {
            throw PlanChildProtectionException(protection);
          }
        }
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
