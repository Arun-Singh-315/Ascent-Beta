import '../../features/promises/services/promise_repository.dart';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../notifications/notification_service.dart';
import '../notifications/reminder_alert_sync.dart';

/// OS effects are retried after the database receipt commits, including restart.
class RiyaAlertEffects {
  RiyaAlertEffects(
    this.db, {
    required this.cancel,
    required this.schedule,
    this.syncPromise,
  });
  factory RiyaAlertEffects.device(AppDatabase db) => RiyaAlertEffects(
    db,
    cancel: NotificationService.instance.cancelChecked,
    schedule: (r) => scheduleReminderOnDevice(db, r),
    syncPromise: (id) => PromiseRepository(db, cancelNotification: (notificationId) async {
      if (!await NotificationService.instance.cancelChecked(notificationId)) throw StateError('Promise alert cancellation pending');
    }).syncChatEffects(id),
  );
  final AppDatabase db;
  final Future<bool> Function(int)? syncPromise;
  final Future<bool> Function(int) cancel;
  final Future<bool> Function(Reminder) schedule;
  Future<bool> syncRequest(String requestId) async {
    final receipt = await (db.select(
      db.aiCommandTable,
    )..where((r) => r.requestId.equals(requestId))).getSingleOrNull();
    if (receipt == null) return false;
    final result = Map<String, dynamic>.from(
      jsonDecode(receipt.resultJson) as Map,
    );
    final scheduled = (result['reminderIds'] as List? ?? [])
        .cast<int>()
        .toSet();
    final cancelled = (result['cancelReminderIds'] as List? ?? [])
        .cast<int>()
        .toSet();
    bool complete = true;
    for (final id in {...scheduled, ...cancelled}) {
      try {
        final current = await db.reminderDao.getReminderById(id);
        if (current == null ||
            !current.isActive ||
            !current.scheduledAt.isAfter(DateTime.now())) {
          complete = await cancel(id) && complete;
        } else if (scheduled.contains(id)) {
          if (cancelled.contains(id) && !await cancel(id)) {
            complete = false;
            continue;
          }
          final saved = await schedule(current);
          complete = saved && complete;
          if (saved && current.alertSyncPending) {
            complete =
                await db.reminderDao.acknowledgeAlertSync(current) && complete;
          }
        }
        // A cancel-only receipt must not cancel an active ID restored later.
      } catch (_) {
        complete = false;
      }
    }
    for (final id
        in (result['promiseEffectIds'] as List? ?? []).cast<int>().toSet()) {
      try {
        complete =
            await (syncPromise?.call(id) ?? Future.value(false)) && complete;
      } catch (_) {
        complete = false;
      }
    }
    if (complete && result['alertEffectsPending'] == true) {
      result['alertEffectsPending'] = false;
      await (db.update(
        db.aiCommandTable,
      )..where((r) => r.requestId.equals(requestId))).write(
        AiCommandTableCompanion(resultJson: Value(jsonEncode(result))),
      );
    }
    return complete;
  }

  Future<void> syncPending() async {
    final rows = await (db.select(
      db.aiCommandTable,
    )..where((r) => r.resultJson.like('%"alertEffectsPending":true%'))).get();
    for (final row in rows) {
      await syncRequest(row.requestId);
    }
  }
}
