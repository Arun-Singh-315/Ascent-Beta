import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'ai_service.dart';

/// Executes the existing SQLite actions after UI approval. Errors propagate;
/// callers must not render success for proposals or failed writes.
class AiExecutionResult {
  const AiExecutionResult(
    this.message, {
    this.reminders = const [],
    this.taskId,
  });
  final String message;
  final int? taskId;
  final List<Reminder> reminders;
}

class AiActionExecution {
  AiActionExecution(this.db);
  final AppDatabase db;

  static bool supports(AiActionType type) => const {
    AiActionType.expenseLogged,
    AiActionType.taskCreated,
    AiActionType.activityCreated,
    AiActionType.waterLogged,
    AiActionType.scheduleRearranged,
  }.contains(type);

  Future<AiExecutionResult> execute(AiProposedAction action) async {
    if (!supports(action.type)) {
      throw UnsupportedError('Action requires its feature screen');
    }
    final p = action.payload;
    if (action.type == AiActionType.expenseLogged) {
      final amount = (p['amount'] as num?)?.toDouble();
      final title = _title(p, max: 200);
      if (amount == null || !amount.isFinite || amount <= 0) {
        throw ArgumentError('Invalid amount');
      }
      return db.transaction(() async {
        final id = await db.financeDao.insertTransaction(
          FinanceTransactionTableCompanion.insert(
            title: title,
            amount: amount,
            date: DateTime.now(),
            category: Value(p['category']?.toString() ?? 'Other'),
            account: Value(p['account']?.toString() ?? 'UPI'),
          ),
        );
        final saved = await (db.select(
          db.financeTransactionTable,
        )..where((r) => r.id.equals(id))).getSingle();
        if (saved.amount != amount || saved.title != title) {
          throw StateError('Write verification failed');
        }
        return AiExecutionResult(
          'Added ₹${amount.toStringAsFixed(2)} for $title.',
        );
      });
    }
    if (action.type == AiActionType.waterLogged) {
      final ml = p['amountMl'];
      if (ml is! int || ml <= 0 || ml > 5000) {
        throw ArgumentError('Invalid water amount');
      }
      return db.transaction(() async {
        final id = await db.waterDao.addWater(ml);
        final row = await (db.select(
          db.waterLogTable,
        )..where((r) => r.id.equals(id))).getSingle();
        if (row.amountMl != ml) throw StateError('Write verification failed');
        return AiExecutionResult('Logged $ml mL of water.');
      });
    }
    if (action.type == AiActionType.scheduleRearranged) {
      final rawIds = p['taskIds'] ?? [p['taskId']];
      if (rawIds is! List || rawIds.isEmpty || rawIds.any((id) => id is! int)) {
        throw ArgumentError('Select an existing task');
      }
      final at = _date(p['newDate']);
      return db.transaction(() async {
        for (final id in rawIds.cast<int>().toSet()) {
          final before = await db.taskDao.getTaskById(id);
          if (before == null) throw StateError('Task no longer exists');
          await db.taskDao.updateTask(
            TaskTableCompanion(id: Value(id), plannedDate: Value(at)),
          );
          final saved = await db.taskDao.getTaskById(id);
          if (saved?.plannedDate != at) {
            throw StateError('Write verification failed');
          }
        }
        return AiExecutionResult(
          'Rescheduled ${rawIds.toSet().length} task(s). Reminders were not changed.',
          taskId: rawIds.toSet().length == 1 ? rawIds.first as int : null,
        );
      });
    }
    final title = _title(p);
    final planned = p['plannedDate'] == null
        ? DateTime.now()
        : _date(p['plannedDate']);
    final minutes = p['estimatedMinutes'];
    if (minutes != null &&
        (minutes is! int ||
            (minutes != -1 && minutes <= 0) ||
            minutes > 1440)) {
      throw ArgumentError('Invalid duration');
    }
    final reminderAt = p['reminderTime'] == null
        ? null
        : _date(p['reminderTime']);
    if (reminderAt != null && !reminderAt.isAfter(DateTime.now())) {
      throw ArgumentError('Reminder must be in the future');
    }
    final priority = p['priority']?.toString() ?? 'medium';
    if (!const ['low', 'medium', 'high'].contains(priority)) {
      throw ArgumentError('Invalid priority');
    }
    return db.transaction(() async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: title,
          plannedDate: Value(planned),
          priority: Value(priority),
          estimatedMinutes: Value(minutes as int?),
        ),
      );
      if ((await db.taskDao.getTaskById(taskId))?.title != title) {
        throw StateError('Write verification failed');
      }
      final savedReminders = <Reminder>[];
      if (reminderAt != null) {
        final id = await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: title,
            scheduledAt: reminderAt,
            linkedTaskId: Value(taskId),
          ),
        );
        final reminder = await db.reminderDao.getReminderById(id);
        if (reminder?.linkedTaskId != taskId) {
          throw StateError('Write verification failed');
        }
        savedReminders.add(reminder!);
      }
      return AiExecutionResult(
        reminderAt == null
            ? 'Added task: $title.'
            : 'Added task and linked reminder: $title. Open Reminders to check device alerts.',
        reminders: savedReminders,
        taskId: taskId,
      );
    });
  }

  String _title(Map<String, dynamic> payload, {int max = 300}) {
    final title = payload['title']?.toString().trim() ?? '';
    if (title.isEmpty || title.length > max) {
      throw ArgumentError('Invalid title');
    }
    return title;
  }

  DateTime _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) throw ArgumentError('Invalid date');
    return date.toLocal();
  }
}
