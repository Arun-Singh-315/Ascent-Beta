import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../notifications/notification_service.dart';

class MedicineService {
  final AppDatabase db;

  MedicineService(this.db);

  /// Adds a new medicine schedule with complete cascading generation:
  /// - Automatically creates tasks in [TaskTable] for all [durationDays] days.
  /// - Automatically creates reminders in [ReminderTable] for all scheduled times.
  /// - Schedules push notifications via [NotificationService].
  /// - Populates [MedicineLogTable] for daily tracking and compliance.
  Future<int> addMedicine({
    required String name,
    required String dosage,
    required List<String> scheduledTimes,
    required int durationDays,
    required DateTime startDate,
    String instructions = 'After food',
    String type = 'tablet',
  }) async {
    // 1. Insert medicine record
    final medId = await db.medicineDao.insertMedicine(
      MedicineTableCompanion.insert(
        name: name.trim(),
        dosage: dosage.trim(),
        scheduledTimes: jsonEncode(scheduledTimes),
        durationDays: Value(durationDays),
        startDate: startDate,
        instructions: Value(instructions),
        type: Value(type),
        isActive: const Value(true),
      ),
    );

    // 2. Loop through durationDays and create tasks + reminders + logs
    final normalizedStart = DateTime(startDate.year, startDate.month, startDate.day);

    for (int dayIndex = 0; dayIndex < durationDays; dayIndex++) {
      final currentDay = normalizedStart.add(Duration(days: dayIndex));
      final dateStr = DateFormat('yyyy-MM-dd').format(currentDay);

      for (final timeStr in scheduledTimes) {
        final timeParts = timeStr.split(':');
        final hour = int.tryParse(timeParts[0]) ?? 8;
        final minute = timeParts.length > 1 ? (int.tryParse(timeParts[1]) ?? 0) : 0;
        final scheduledDateTime = DateTime(currentDay.year, currentDay.month, currentDay.day, hour, minute);
        final timeLabel = DateFormat('h:mm a').format(scheduledDateTime);

        // a. Insert Task (Simple To-Do without estimated minutes per GEMINI.md Rule 9)
        final taskId = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: '$name (medicine) ($dosage) — $timeLabel',
            notes: Value('$instructions • Medicine prescription for ${DateFormat('EEE, MMM d').format(currentDay)}'),
            plannedDate: Value(currentDay),
            priority: const Value('high'),
          ),
        );

        // b. Insert Reminder in SQLite
        final reminderId = await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: 'Time for $name ($dosage)',
            scheduledAt: scheduledDateTime,
            linkedTaskId: Value(taskId),
          ),
        );

        // c. Schedule push notification if scheduled in the future
        if (scheduledDateTime.isAfter(DateTime.now())) {
          await NotificationService.instance.scheduleMedicineReminder(
            id: reminderId,
            medicineName: name,
            dosage: dosage,
            instructions: instructions,
            scheduledAt: scheduledDateTime,
          );
        }

        // d. Record MedicineLog entry
        await db.medicineDao.insertMedicineLog(
          MedicineLogTableCompanion.insert(
            medicineId: medId,
            dateStr: dateStr,
            timeSlot: timeStr,
            linkedTaskId: Value(taskId),
            linkedReminderId: Value(reminderId),
            isTaken: const Value(false),
          ),
        );
      }
    }

    return medId;
  }

  /// Mark or unmark a dose as taken.
  /// Automatically syncs with the linked Task in Today Activities.
  Future<void> toggleDose(int logId, bool taken) async {
    await db.medicineDao.setDoseTaken(logId, taken);
  }

  /// Delete a medicine with clean cascading deletion across all modules:
  /// Cancels all scheduled notifications, deletes reminders, deletes tasks, and clears logs.
  Future<void> deleteMedicine(int id) async {
    final logs = await db.medicineDao.watchLogsForMedicine(id).first;
    for (final log in logs) {
      if (log.linkedReminderId != null) {
        try {
          await NotificationService.instance.cancel(log.linkedReminderId!);
        } catch (_) {}
      }
    }
    await db.medicineDao.deleteMedicine(id);
  }

  /// Format time slot string '08:00' to human-readable '8:00 AM'
  static String formatTimeSlot(String timeSlot) {
    try {
      final parts = timeSlot.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2026, 1, 1, hour, minute);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return timeSlot;
    }
  }
}
