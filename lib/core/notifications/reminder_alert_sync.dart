import '../database/app_database.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> scheduleReminderOnDevice(AppDatabase db, Reminder r) async {
  if (!r.alarmEnabled) {
    final dose =
        await (db.select(db.medicineLogTable)
              ..where((l) => l.linkedReminderId.equals(r.id))
              ..limit(1))
            .getSingleOrNull();
    final medicine = dose == null
        ? null
        : await db.medicineDao.getMedicineById(dose.medicineId);
    if (medicine != null) {
      return NotificationService.instance.scheduleMedicineReminderChecked(
        id: r.id,
        medicineName: medicine.name,
        dosage: medicine.dosage,
        instructions: medicine.instructions,
        scheduledAt: r.scheduledAt,
      );
    }
  }
  return NotificationService.instance.scheduleReminderNotificationChecked(
    id: r.id,
    title: r.title,
    scheduledAt: r.scheduledAt,
    alarmEnabled: r.alarmEnabled,
    scheduleFollowUp: false,
  );
}

class ReminderAlertSyncResult {
  const ReminderAlertSyncResult(
    this.total,
    this.scheduled, {
    this.resetSucceeded = true,
  });
  final int total, scheduled;
  final bool resetSucceeded;
  bool get complete => resetSucceeded && total == scheduled;
  String get message => complete
      ? '$scheduled upcoming reminder alerts scheduled.'
      : '$scheduled of $total reminder alerts scheduled. Check notification permissions and retry.';
}

class ReminderAlertSync {
  ReminderAlertSync(
    this.db, {
    required this.enabled,
    required this.schedule,
    required this.reset,
    this.cancel,
  });
  factory ReminderAlertSync.device(AppDatabase db) => ReminderAlertSync(
    db,
    enabled: NotificationService.instance.areNotificationsEnabled,
    schedule: (r) => scheduleReminderOnDevice(db, r),
    reset: NotificationService.instance.cancelAllChecked,
    cancel: NotificationService.instance.cancelChecked,
  );
  final AppDatabase db;
  final Future<bool> Function() enabled, reset;
  final Future<bool> Function(Reminder) schedule;
  final Future<bool> Function(int)? cancel;
  Future<ReminderAlertSyncResult> sync({
    bool replaceAll = false,
    bool onlyPending = false,
    List<int>? ids,
  }) async {
    final reminders = (await db.reminderDao.watchAllReminders().first)
        .where(
          (r) =>
              (ids == null || ids.contains(r.id)) &&
              (onlyPending
                  ? r.alertSyncPending
                  : r.isActive && r.scheduledAt.isAfter(DateTime.now())),
        )
        .toList();
    if (replaceAll && !await reset()) {
      return ReminderAlertSyncResult(
        reminders.length,
        0,
        resetSucceeded: false,
      );
    }
    final permitted = await enabled();
    var count = 0;
    for (final reminder in reminders) {
      try {
        final succeeded =
            !reminder.isActive || !reminder.scheduledAt.isAfter(DateTime.now())
            ? await (cancel?.call(reminder.id) ?? Future.value(false))
            : permitted && await schedule(reminder);
        if (succeeded) {
          if (reminder.alertSyncPending) {
            if (!await db.reminderDao.acknowledgeAlertSync(reminder)) continue;
          }
          count++;
        }
      } catch (_) {}
    }
    return ReminderAlertSyncResult(reminders.length, count);
  }
}

Future<String> finishRestoredAlerts(
  AppDatabase db,
  SharedPreferences prefs,
) async {
  final result = await ReminderAlertSync.device(db).sync(replaceAll: true);
  if (result.complete) await prefs.remove('ascent_restore_alert_sync_v1');
  final message = 'Workspace restored. ${result.message}';
  await prefs.setString('ascent_restore_notice_v1', message);
  return message;
}
