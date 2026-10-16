part of '../app_database.dart';

@DriftAccessor(
  tables: [MedicineTable, MedicineLogTable, TaskTable, ReminderTable],
)
class MedicineDao extends DatabaseAccessor<AppDatabase>
    with _$MedicineDaoMixin {
  MedicineDao(super.db);

  /// Watch all active medicines ordered by creation time descending.
  Stream<List<Medicine>> watchActiveMedicines() {
    return (select(medicineTable)
          ..where((m) => m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .watch();
  }

  /// Watch all medicines (both active and completed).
  Stream<List<Medicine>> watchAllMedicines() {
    return (select(
      medicineTable,
    )..orderBy([(m) => OrderingTerm.desc(m.createdAt)])).watch();
  }

  /// Single fetch medicine by ID.
  Future<Medicine?> getMedicineById(int id) {
    return (select(
      medicineTable,
    )..where((m) => m.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new medicine.
  Future<int> insertMedicine(MedicineTableCompanion entry) {
    return into(medicineTable).insert(entry);
  }

  /// Update an existing medicine (supports partial field updates).
  Future<bool> updateMedicine(MedicineTableCompanion entry) {
    if (entry.id.present) {
      return (update(medicineTable)..where((m) => m.id.equals(entry.id.value)))
          .write(entry)
          .then((count) => count > 0);
    }
    return update(medicineTable).replace(entry);
  }

  /// Watch today's medicine logs ordered by time slot.
  Stream<List<MedicineLog>> watchTodayMedicineLogs() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return watchLogsForDate(todayStr);
  }

  /// Watch logs for a specific calendar date.
  Stream<List<MedicineLog>> watchLogsForDate(String dateStr) {
    return (select(medicineLogTable)
          ..where((l) => l.dateStr.equals(dateStr))
          ..orderBy([(l) => OrderingTerm.asc(l.timeSlot)]))
        .watch();
  }

  /// Watch all logs for a specific medicine across all days.
  Stream<List<MedicineLog>> watchLogsForMedicine(int medicineId) {
    return (select(medicineLogTable)
          ..where((l) => l.medicineId.equals(medicineId))
          ..orderBy([
            (l) => OrderingTerm.asc(l.dateStr),
            (l) => OrderingTerm.asc(l.timeSlot),
          ]))
        .watch();
  }

  /// Insert a single medicine dose log.
  Future<int> insertMedicineLog(MedicineLogTableCompanion entry) {
    return into(medicineLogTable).insert(entry);
  }

  /// Mark or unmark a dose as taken, syncing with the linked Task in TaskTable.
  Future<void> setDoseTaken(int logId, bool taken) => db.transaction(() async {
    final log = await (select(
      medicineLogTable,
    )..where((l) => l.id.equals(logId))).getSingleOrNull();
    if (log == null) throw StateError('This dose no longer exists');
    if (log.isTaken == taken) return;
    await (update(medicineLogTable)..where((l) => l.id.equals(logId))).write(
      MedicineLogTableCompanion(
        isTaken: Value(taken),
        takenAt: Value(taken ? DateTime.now() : null),
      ),
    );
    if (log.linkedTaskId != null) {
      if (!await db.taskDao.syncCompletionFromMedicineDose(
        log.linkedTaskId!,
        completed: taken,
      )) {
        throw StateError('The linked dose task cannot be updated');
      }
    }
    await _syncDoseAlert(log, taken);
  });

  Future<void> _syncDoseAlert(MedicineLog log, bool taken) async {
    if (log.linkedReminderId == null) return;
    final medicine = await getMedicineById(log.medicineId);
    await (db.update(
      db.reminderTable,
    )..where((r) => r.id.equals(log.linkedReminderId!))).write(
      ReminderTableCompanion(
        isActive: Value(!taken && medicine?.isActive == true),
        alertSyncPending: const Value(true),
      ),
    );
  }

  /// Sync dose status when task is updated from outside.
  Future<void> syncDoseFromTask(int taskId, bool completed) async {
    final log = await (select(
      medicineLogTable,
    )..where((l) => l.linkedTaskId.equals(taskId))).getSingleOrNull();
    if (log != null && log.isTaken != completed) {
      await (update(medicineLogTable)..where((l) => l.id.equals(log.id))).write(
        MedicineLogTableCompanion(
          isTaken: Value(completed),
          takenAt: Value(completed ? DateTime.now() : null),
        ),
      );
      await _syncDoseAlert(log, completed);
    }
  }

  /// Cascading Deletion (User Rule 8):
  /// Deleting a medicine cancels all scheduled notifications, deletes linked reminders,
  /// deletes linked tasks, deletes all medicine logs, and deletes the medicine record.
  Future<void> deleteMedicine(int id) => db.transaction(() async {
    final logs = await (select(
      medicineLogTable,
    )..where((l) => l.medicineId.equals(id))).get();
    await (delete(
      medicineLogTable,
    )..where((l) => l.medicineId.equals(id))).go();
    for (final log in logs) {
      if (log.linkedReminderId != null) {
        await db.reminderDao.deleteReminder(log.linkedReminderId!);
      }
      if (log.linkedTaskId != null) {
        await db.taskDao.deleteTask(log.linkedTaskId!);
      }
    }
    await (delete(medicineTable)..where((m) => m.id.equals(id))).go();
  });
}
