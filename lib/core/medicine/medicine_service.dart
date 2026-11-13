import 'dart:convert';
import '../history/history_ledger.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../notifications/reminder_alert_sync.dart';
import '../ai/riya_alert_effects.dart';

/// Shared persisted schedule lifecycle. Platform work runs after commit and can
/// be disabled by receipt-owning callers such as Riya.
class MedicineService {
  MedicineService(this.db, {this.syncAlerts = true, DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final bool syncAlerts;
  final DateTime Function() clock;

  void _validate(
    String name,
    String dosage,
    List<String> times,
    int days,
    String instructions,
    String type,
  ) {
    if (name.trim().isEmpty ||
        name.trim().length > 200 ||
        dosage.trim().isEmpty ||
        dosage.trim().length > 100 ||
        instructions.length > 2000 ||
        days < 1 ||
        days > 366 ||
        !{'tablet', 'capsule', 'syrup', 'drops', 'injection'}.contains(type) ||
        times.isEmpty ||
        times.length > 10 ||
        times.toSet().length != times.length ||
        times.any((t) => !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(t))) {
      throw ArgumentError(
        'Use a name, dosage, 1–366 days and unique times in HH:mm format',
      );
    }
  }

  Future<void> _validateCare(int? planId, String purpose) async {
    if (purpose.length > 1000) {
      throw ArgumentError('Purpose is limited to 1000 characters');
    }
    if (planId != null &&
        await (db.select(
              db.carePlanTable,
            )..where((p) => p.id.equals(planId))).getSingleOrNull() ==
            null) {
      throw StateError('Care plan no longer exists');
    }
  }

  String _bounded(String text) =>
      text.length <= 300 ? text : '${text.substring(0, 297)}…';
  Future<void> _alerts() async {
    if (!syncAlerts) return;
    try {
      await RiyaAlertEffects.device(db).syncPending();
      await ReminderAlertSync.device(db).sync(onlyPending: true);
    } catch (_) {
      /* Durable pending work is retried by the root coordinator. */
    }
  }

  Future<void> _generate(
    int id,
    String name,
    String dosage,
    List<String> times,
    int days,
    DateTime start,
    String instructions,
    bool active, {
    DateTime? futureOnly,
    Set<String> preserved = const {},
  }) async {
    for (var dayIndex = 0; dayIndex < days; dayIndex++) {
      final day = DateTime(start.year, start.month, start.day + dayIndex);
      final date = DateFormat('yyyy-MM-dd').format(day);
      for (final time in times) {
        final parts = time.split(':');
        final at = DateTime(
          day.year,
          day.month,
          day.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (futureOnly != null && !at.isAfter(futureOnly) ||
            preserved.contains('$date/$time')) {
          continue;
        }
        final task = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: _bounded(
              '$name (medicine) ($dosage) — ${DateFormat('h:mm a').format(at)}',
            ),
            notes: Value(
              '$instructions • Medicine schedule for ${DateFormat('EEE, MMM d').format(day)}',
            ),
            plannedDate: Value(day),
            priority: const Value('high'),
          ),
        );
        final reminder = await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: _bounded('Time for $name ($dosage) · $instructions'),
            scheduledAt: at,
            linkedTaskId: Value(task),
            isActive: Value(active),
            alertSyncPending: const Value(true),
          ),
        );
        await db.medicineDao.insertMedicineLog(
          MedicineLogTableCompanion.insert(
            medicineId: id,
            dateStr: date,
            timeSlot: time,
            linkedTaskId: Value(task),
            linkedReminderId: Value(reminder),
          ),
        );
      }
    }
  }

  Future<int> addMedicine({
    required String name,
    required String dosage,
    required List<String> scheduledTimes,
    required int durationDays,
    required DateTime startDate,
    String instructions = 'After food',
    String type = 'tablet',
    int? carePlanId,
    String purpose = '',
  }) async {
    _validate(name, dosage, scheduledTimes, durationDays, instructions, type);
    final times = [...scheduledTimes]..sort();
    final id = await db.transaction(() async {
      await _validateCare(carePlanId, purpose);
      final id = await db.medicineDao.insertMedicine(
        MedicineTableCompanion.insert(
          carePlanId: Value(carePlanId),
          purpose: Value(purpose.trim()),
          name: name.trim(),
          dosage: dosage.trim(),
          scheduledTimes: jsonEncode(times),
          durationDays: Value(durationDays),
          startDate: DateTime(startDate.year, startDate.month, startDate.day),
          instructions: Value(instructions),
          type: Value(type),
        ),
      );
      await _generate(
        id,
        name.trim(),
        dosage.trim(),
        times,
        durationDays,
        startDate,
        instructions,
        true,
      );
      return id;
    });
    await _alerts();
    return id;
  }

  /// Replaces future pending slots. Completed and historical dose evidence is
  /// retained, including the original task/reminder IDs and taken timestamp.
  Future<void> updateMedicine(
    int id, {
    String? name,
    String? dosage,
    List<String>? scheduledTimes,
    int? durationDays,
    DateTime? startDate,
    String? instructions,
    String? type,
    bool? active,
    Value<int?> carePlanId = const Value.absent(),
    String? purpose,
  }) async {
    await db.transaction(() async {
      final old = await db.medicineDao.getMedicineById(id);
      if (old == null) {
        throw StateError('This medicine schedule no longer exists');
      }
      await _validateCare(
        carePlanId.present ? carePlanId.value : old.carePlanId,
        purpose ?? old.purpose,
      );
      final nextName = name?.trim() ?? old.name,
          nextDosage = dosage?.trim() ?? old.dosage;
      final times =
          scheduledTimes ??
          (jsonDecode(old.scheduledTimes) as List).cast<String>();
      final days = durationDays ?? old.durationDays,
          start = startDate ?? old.startDate;
      final text = instructions ?? old.instructions,
          form = type ?? old.type,
          isActive = active ?? old.isActive;
      _validate(nextName, nextDosage, times, days, text, form);
      final sorted = [...times]..sort();
      final oldTimes = (jsonDecode(old.scheduledTimes) as List).cast<String>()
        ..sort();
      final scheduleChanged =
          jsonEncode(sorted) != jsonEncode(oldTimes) ||
          days != old.durationDays ||
          DateTime(start.year, start.month, start.day) != old.startDate;
      final logs = await db.medicineDao.watchLogsForMedicine(id).first;
      final preserved = <String>{};
      final now = clock();
      for (final log in logs) {
        final day = DateTime.parse(log.dateStr),
            parts = log.timeSlot.split(':');
        final at = DateTime(
          day.year,
          day.month,
          day.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
        if (log.isTaken || !at.isAfter(now)) {
          preserved.add('${log.dateStr}/${log.timeSlot}');
          continue;
        }
        if (scheduleChanged) {
          await (db.delete(
            db.medicineLogTable,
          )..where((r) => r.id.equals(log.id))).go();
          if (log.linkedReminderId != null) {
            await db.reminderDao.deleteReminder(log.linkedReminderId!);
          }
          if (log.linkedTaskId != null) {
            await db.taskDao.deleteTask(log.linkedTaskId!);
          }
        } else {
          if (log.linkedTaskId != null) {
            await (db.update(
              db.taskTable,
            )..where((r) => r.id.equals(log.linkedTaskId!))).write(
              TaskTableCompanion(
                title: Value(
                  _bounded(
                    '$nextName (medicine) ($nextDosage) — ${DateFormat('h:mm a').format(at)}',
                  ),
                ),
                notes: Value(
                  '$text • Medicine schedule for ${DateFormat('EEE, MMM d').format(day)}',
                ),
              ),
            );
          }
          if (log.linkedReminderId != null) {
            await (db.update(
              db.reminderTable,
            )..where((r) => r.id.equals(log.linkedReminderId!))).write(
              ReminderTableCompanion(
                title: Value(
                  _bounded('Time for $nextName ($nextDosage) · $text'),
                ),
                isActive: Value(isActive),
                alertSyncPending: const Value(true),
              ),
            );
          }
        }
      }
      await db.medicineDao.updateMedicine(
        MedicineTableCompanion(
          id: Value(id),
          carePlanId: carePlanId,
          purpose: purpose == null
              ? const Value.absent()
              : Value(purpose.trim()),
          name: Value(nextName),
          dosage: Value(nextDosage),
          scheduledTimes: Value(jsonEncode(sorted)),
          durationDays: Value(days),
          startDate: Value(DateTime(start.year, start.month, start.day)),
          instructions: Value(text),
          type: Value(form),
          isActive: Value(isActive),
        ),
      );
      if (scheduleChanged) {
        await _generate(
          id,
          nextName,
          nextDosage,
          sorted,
          days,
          start,
          text,
          isActive,
          futureOnly: now,
          preserved: preserved,
        );
      }
    });
    await _alerts();
  }

  Future<void> toggleDose(int logId, bool taken) async {
    await db.medicineDao.setDoseTaken(logId, taken);
    await _alerts();
  }

  Future<void> deleteMedicine(int id) async {
    await db.medicineDao.deleteMedicine(id);
    await _alerts();
  }

  /// A one-use receipt keeps exact IDs and original dose evidence during Undo.
  /// A workspace restore invalidates it so old records cannot enter a new workspace.
  Future<Future<void> Function()> removeWithUndo(int id) async {
    final revision = db.workspaceRevision;
    late Medicine medicine;
    late List<MedicineLog> logs;
    late List<Task> tasks;
    late List<Reminder> reminders;
    late List<ThoughtReminderLink> thoughtLinks;
    late List<TimeSession> sessions;
    late List<HistoryEvent> history;
    await db.transaction(() async {
      final row = await db.medicineDao.getMedicineById(id);
      if (row == null) throw StateError('Medicine no longer exists');
      medicine = row;
      logs = await db.medicineDao.watchLogsForMedicine(id).first;
      tasks =
          await (db.select(db.taskTable)..where(
                (t) =>
                    t.id.isIn(logs.map((l) => l.linkedTaskId).whereType<int>()),
              ))
              .get();
      // Dose tasks can acquire descendants, extra reminders or focus history.
      // Capture the entire connected tree instead of relying on bounded DAO caches.
      tasks = [...tasks];
      final taskIds = tasks.map((t) => t.id).toSet();
      var frontier = taskIds.toList();
      while (frontier.isNotEmpty) {
        final children = await (db.select(
          db.taskTable,
        )..where((t) => t.parentTaskId.isIn(frontier))).get();
        final fresh = children.where((t) => taskIds.add(t.id)).toList();
        tasks.addAll(fresh);
        frontier = fresh.map((t) => t.id).toList();
      }
      reminders =
          await (db.select(db.reminderTable)..where(
                (r) =>
                    r.linkedTaskId.isIn(taskIds) |
                    r.id.isIn(
                      logs.map((l) => l.linkedReminderId).whereType<int>(),
                    ),
              ))
              .get();
      thoughtLinks = await (db.select(
        db.thoughtReminderLinkTable,
      )..where((l) => l.reminderId.isIn(reminders.map((r) => r.id)))).get();
      sessions = await (db.select(
        db.timeSessionTable,
      )..where((s) => s.linkedTaskId.isIn(taskIds))).get();
      history =
          await (db.select(db.historyEventTable)..where(
                (e) =>
                    (e.module.equals('medicines') & e.entityId.equals('$id')) |
                    (e.module.equals('medicine_doses') &
                        e.entityId.isIn(logs.map((l) => '${l.id}'))) |
                    (e.module.equals('tasks') &
                        e.entityId.isIn(tasks.map((t) => '${t.id}'))),
              ))
              .get();
      await db.medicineDao.deleteMedicine(id);
      await (db.delete(db.historyEventTable)..where(
            (e) =>
                e.module.equals('tasks') &
                e.entityId.isIn(taskIds.map((id) => '$id')),
          ))
          .go();
    });
    await _alerts();
    var restored = false;
    return () async {
      if (restored) return;
      if (revision != db.workspaceRevision) {
        throw StateError('Workspace changed');
      }
      await db.transaction(() async {
        await HistoryLedger.capture(db, false);
        await db.into(db.medicineTable).insert(medicine.toCompanion(true));
        for (final task in tasks) {
          await db.into(db.taskTable).insert(task.toCompanion(true));
        }
        for (final reminder in reminders) {
          await db
              .into(db.reminderTable)
              .insert(
                reminder
                    .toCompanion(true)
                    .copyWith(alertSyncPending: const Value(true)),
              );
        }
        for (final log in logs) {
          await db.into(db.medicineLogTable).insert(log.toCompanion(true));
        }
        for (final link in thoughtLinks) {
          if (await db.thoughtDao.getThoughtById(link.thoughtId) != null) {
            await db
                .into(db.thoughtReminderLinkTable)
                .insert(link.toCompanion(true));
          }
        }
        for (final session in sessions) {
          await (db.update(db.timeSessionTable)..where(
                (s) => s.id.equals(session.id) & s.linkedTaskId.isNull(),
              ))
              .write(
                TimeSessionTableCompanion(
                  linkedTaskId: Value(session.linkedTaskId),
                ),
              );
        }
        for (final event in history) {
          await db
              .into(db.historyEventTable)
              .insert(event.toCompanion(true), mode: InsertMode.insertOrIgnore);
        }
        await HistoryLedger.capture(db, true);
      });
      restored = true;
      await _alerts();
    };
  }

  static String formatTimeSlot(String timeSlot) {
    if (!RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(timeSlot)) {
      return timeSlot;
    }
    final parts = timeSlot.split(':');
    return DateFormat(
      'h:mm a',
    ).format(DateTime(2026, 1, 1, int.parse(parts[0]), int.parse(parts[1])));
  }
}
