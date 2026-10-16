import 'dart:convert';
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
  }) async {
    _validate(name, dosage, scheduledTimes, durationDays, instructions, type);
    final times = [...scheduledTimes]..sort();
    final id = await db.transaction(() async {
      final id = await db.medicineDao.insertMedicine(
        MedicineTableCompanion.insert(
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
  }) async {
    await db.transaction(() async {
      final old = await db.medicineDao.getMedicineById(id);
      if (old == null) {
        throw StateError('This medicine schedule no longer exists');
      }
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
