import '../database/app_database.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
  factory ReminderAlertSync.device(AppDatabase db) => ReminderAlertSync(
    db,
    enabled: NotificationService.instance.areNotificationsEnabled,
    schedule: (r) =>
        NotificationService.instance.scheduleReminderNotificationChecked(
          id: r.id,
          title: r.title,
          scheduledAt: r.scheduledAt,
          alarmEnabled: r.alarmEnabled,
          scheduleFollowUp: false,
        ),
    reset: NotificationService.instance.cancelAllChecked,
  );
  final AppDatabase db;
  final Future<bool> Function() enabled, reset;
  final Future<bool> Function(Reminder) schedule;
  Future<ReminderAlertSyncResult> sync({bool replaceAll = false}) async {
    final reminders = (await db.reminderDao.watchAllReminders().first)
        .where((r) => r.isActive && r.scheduledAt.isAfter(DateTime.now()))
        .toList();
    if (replaceAll && !await reset()) {
      return ReminderAlertSyncResult(
        reminders.length,
        0,
        resetSucceeded: false,
      );
    }
    if (!await enabled()) return ReminderAlertSyncResult(reminders.length, 0);
    var count = 0;
    for (final reminder in reminders) {
      try {
        if (await schedule(reminder)) count++;
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
