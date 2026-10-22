import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// The database transition used by Home, reminder dialogs and alarm receipts.
/// Device effects are retriable and never roll back a saved user action.
class ReminderActions {
  ReminderActions(this.db, {this.sync});
  final AppDatabase db;
  final Future<void> Function(int id)? sync;

  Future<Reminder?> complete(int id) => _change(id, active: false);
  Future<Reminder?> snooze(int id, DateTime at) =>
      _change(id, active: true, at: at);

  Future<Reminder?> _change(
    int id, {
    required bool active,
    DateTime? at,
  }) async {
    final before = await db.transaction(() async {
      final row = await db.reminderDao.getReminderById(id);
      if (row == null || (!active && !row.isActive)) return null;
      await (db.update(db.reminderTable)..where((r) => r.id.equals(id))).write(
        ReminderTableCompanion(
          isActive: Value(active),
          scheduledAt: at == null ? const Value.absent() : Value(at),
          alertSyncPending: const Value(true),
        ),
      );
      return row;
    });
    if (before != null) await _sync(id);
    return before;
  }

  Future<void> delete(int id) async {
    await db.reminderDao.deleteReminder(id);
    await _sync(id);
  }

  Future<bool> restoreDeleted(Reminder row) async {
    final restored = await db.reminderDao.restoreDeletedReminder(row, const []);
    if (restored) await _sync(row.id);
    return restored;
  }

  /// Undo only our completion. A subsequent edit or snooze takes precedence.
  Future<bool> undoCompletion(Reminder before) async {
    final count = await db.transaction(() async {
      if (before.linkedTaskId != null) {
        final task = await db.taskDao.getTaskById(before.linkedTaskId!);
        if (task == null || task.actualCompletedDate != null) return 0;
      }
      return (db.update(db.reminderTable)..where(
            (r) =>
                r.id.equals(before.id) &
                r.createdAt.equals(before.createdAt) &
                r.isActive.equals(false) &
                r.scheduledAt.equals(before.scheduledAt) &
                r.title.equals(before.title) &
                r.alarmEnabled.equals(before.alarmEnabled) &
                (before.linkedTaskId == null
                    ? r.linkedTaskId.isNull()
                    : r.linkedTaskId.equals(before.linkedTaskId!)),
          ))
          .write(
            ReminderTableCompanion(
              isActive: Value(before.isActive),
              alertSyncPending: const Value(true),
            ),
          );
    });
    if (count == 1) await _sync(before.id);
    return count == 1;
  }

  Future<void> _sync(int id) async {
    try {
      await sync?.call(id);
    } catch (_) {
      // alertSyncPending (or the deletion receipt) retains the retry intent.
    }
  }
}
