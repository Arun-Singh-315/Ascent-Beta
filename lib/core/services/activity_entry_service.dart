import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

class ActivityEntryResult {
  const ActivityEntryResult(this.taskId, this.reminderIds);
  final int taskId;
  final List<int> reminderIds;
}

/// Shared atomic persistence for quick capture and the detailed editor.
class ActivityEntryService {
  ActivityEntryService(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

  Future<List<ActivityEntryResult>> saveMany({
    required List<String> titles,
    required DateTime date,
    int? estimatedMinutes,
    String? notes,
    String? priority,
    int? parentTaskId,
    int? applicationId,
    DateTime? reminderAt,
  }) => db.transaction(() async {
    if (titles.isEmpty || titles.length > 200) {
      throw StateError('Add between 1 and 200 items.');
    }
    final results = <ActivityEntryResult>[];
    for (final title in titles) {
      results.add(
        await save(
          title: title,
          date: date,
          estimatedMinutes: estimatedMinutes,
          notes: notes,
          priority: priority,
          parentTaskId: parentTaskId,
          applicationId: applicationId,
          reminderAt: reminderAt,
        ),
      );
    }
    return results;
  });

  Future<ActivityEntryResult> save({
    required String title,
    required DateTime date,
    int? estimatedMinutes,
    int? taskId,
    String? notes,
    String? priority,
    int? parentTaskId,
    int? applicationId,
    DateTime? reminderAt,
    bool replaceReminders = true,
  }) => db.transaction(() async {
    final trimmed = title.trim();
    if (trimmed.isEmpty || trimmed.length > 300) {
      throw StateError('Enter an activity of 1–300 characters.');
    }
    if (estimatedMinutes != null &&
        estimatedMinutes != -1 &&
        (estimatedMinutes < 1 || estimatedMinutes > 1440)) {
      throw StateError('Choose a timer from 1 to 1440 minutes.');
    }
    if (reminderAt != null &&
        replaceReminders &&
        !reminderAt.isAfter(clock())) {
      throw StateError('Choose a reminder time in the future.');
    }
    final current = taskId == null
        ? null
        : await db.taskDao.getTaskById(taskId);
    final instant = clock();
    final today = DateTime(instant.year, instant.month, instant.day);
    final chosen = DateTime(date.year, date.month, date.day);
    if (taskId == null && chosen.isBefore(today)) {
      throw StateError('Choose today or a future date.');
    }
    if (taskId != null && current == null) {
      throw StateError('This activity no longer exists.');
    }
    if (current != null) {
      final error = await db.taskDao.activityTypeChangeError(
        current.id,
        estimatedMinutes,
      );
      if (error != null) throw StateError(error);
      final receipts = await db.select(db.aiCommandTable).get();
      final managed = receipts.any((r) {
        if (!r.requestId.startsWith('home.schedule:')) return false;
        try {
          return (jsonDecode(r.argumentsJson) as Map)['taskId'] == current.id;
        } catch (_) {
          return false;
        }
      });
      if (managed &&
          (replaceReminders ||
              date != current.plannedDate ||
              trimmed != current.title)) {
        throw StateError(
          'Use the plan controls on Home to change this scheduled plan. You can change its activity type here.',
        );
      }
    }
    final planned = replaceReminders ? (reminderAt ?? date) : date;
    final cleanNotes = notes?.trim() ?? current?.notes;
    final id =
        current?.id ??
        await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: trimmed,
            plannedDate: Value(planned),
            estimatedMinutes: Value(estimatedMinutes),
            priority: Value(priority ?? current?.priority ?? 'low'),
            notes: Value(
              cleanNotes == null || cleanNotes.isEmpty || cleanNotes == trimmed
                  ? null
                  : cleanNotes,
            ),
            parentTaskId: Value(parentTaskId),
            linkedApplicationId: Value(applicationId),
            lastInteractedAt: Value(clock()),
          ),
        );
    if (current != null) {
      final updated = await db.taskDao.updateTask(
        TaskTableCompanion(
          id: Value(id),
          title: Value(trimmed),
          plannedDate: Value(planned),
          estimatedMinutes: Value(estimatedMinutes),
          priority: Value(priority ?? current.priority),
          notes: Value(
            cleanNotes == null || cleanNotes.isEmpty || cleanNotes == trimmed
                ? null
                : cleanNotes,
          ),
          parentTaskId: Value(parentTaskId ?? current.parentTaskId),
          linkedApplicationId: Value(
            applicationId ?? current.linkedApplicationId,
          ),
          lastInteractedAt: Value(clock()),
        ),
      );
      if (!updated) {
        throw StateError(
          'The activity changed while saving. Please reopen it.',
        );
      }
    }
    final linked = await db.reminderDao.getRemindersByTaskId(id);
    final changedIds = <int>[];
    if (replaceReminders) {
      // Retain IDs, including durable cancellation records, for safe OS sync.
      for (final r in linked) {
        await (db.update(
          db.reminderTable,
        )..where((t) => t.id.equals(r.id))).write(
          const ReminderTableCompanion(
            isActive: Value(false),
            alertSyncPending: Value(true),
          ),
        );
        changedIds.add(r.id);
      }
      if (reminderAt != null) {
        final r = linked.isEmpty ? null : linked.first;
        if (r == null) {
          changedIds.add(
            await db.reminderDao.insertReminder(
              ReminderTableCompanion.insert(
                title: trimmed,
                scheduledAt: reminderAt,
                linkedTaskId: Value(id),
                alertSyncPending: const Value(true),
              ),
            ),
          );
        } else {
          await (db.update(
            db.reminderTable,
          )..where((t) => t.id.equals(r.id))).write(
            ReminderTableCompanion(
              title: Value(trimmed),
              scheduledAt: Value(reminderAt),
              isActive: const Value(true),
              alertSyncPending: const Value(true),
            ),
          );
        }
      }
    } else if (current != null && current.title != trimmed) {
      for (final r in linked.where(
        (r) => r.title == current.title && r.isActive,
      )) {
        await (db.update(
          db.reminderTable,
        )..where((t) => t.id.equals(r.id))).write(
          ReminderTableCompanion(
            title: Value(trimmed),
            alertSyncPending: const Value(true),
          ),
        );
        changedIds.add(r.id);
      }
    }
    return ActivityEntryResult(id, changedIds);
  });
}
