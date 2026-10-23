import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/reminder_actions.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../plans/widgets/plan_protection_dialog.dart';

enum ReminderRowAction { done, snooze, delete }

ReminderActions deviceReminderActions(AppDatabase db) => ReminderActions(
  db,
  sync: (id) async {
    if (await db.reminderDao.getReminderById(id) == null) {
      await NotificationService.instance.cancel(id);
    } else {
      await ReminderAlertSync.device(db).sync(ids: [id], onlyPending: true);
    }
  },
);

/// Returns whether the row changed; cancelled plan guardrails leave it visible.
Future<bool> runReminderAction(
  BuildContext context,
  WidgetRef ref,
  Reminder row,
  ReminderRowAction action, {
  DateTime? snoozeUntil,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final undoError = AscentSnackBar.build(
    context,
    content: const Text(
      'Could not undo this action. A newer change may have been kept.',
    ),
  );
  Future<void> undo(Future<bool> Function() restore) async {
    var restored = false;
    try {
      restored = await restore();
    } catch (_) {
      /* Keep the saved action. */
    }
    if (!restored && messenger.mounted) messenger.showSnackBar(undoError);
  }

  final db = ref.read(databaseProvider);
  final actions = deviceReminderActions(db);
  try {
    if (action == ReminderRowAction.delete) {
      final protection = await db.reminderDao.getReminderProtection(row.id);
      if (!context.mounted) return false;
      if (protection != null) {
        await showPlanProtectionDialog(context, ref, protection);
        return false;
      }
      await actions.delete(row.id);
      if (context.mounted) {
        AscentSnackBar.undo(
          context,
          message: 'Reminder deleted',
          onUndo: () => undo(() => actions.restoreDeleted(row)),
        );
      }
    } else if (action == ReminderRowAction.done) {
      final before = await actions.complete(row.id);
      if (before == null) return false;
      if (context.mounted) {
        AscentSnackBar.undo(
          context,
          message: 'Reminder completed',
          onUndo: () => undo(() => actions.undoCompletion(before)),
        );
      }
    } else {
      final before = await actions.snooze(
        row.id,
        snoozeUntil ?? DateTime.now().add(const Duration(minutes: 10)),
      );
      if (before == null) return false;
      if (context.mounted) {
        final current = await db.reminderDao.getReminderById(row.id);
        if (context.mounted) {
          AscentSnackBar.show(
            context,
            message: current?.alertSyncPending == true
                ? 'Snooze saved. Alert access needs verification; retry Sync reminder alerts.'
                : 'Reminder snoozed',
          );
        }
      }
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(
        context,
        message: 'Could not update the reminder. Please retry.',
      );
    }
    return false;
  }
}
