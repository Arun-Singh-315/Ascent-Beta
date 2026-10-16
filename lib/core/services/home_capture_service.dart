import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Conservative local interpretation. A proposal never writes records.
class HomeCaptureProposal {
  const HomeCaptureProposal({
    required this.title,
    this.at,
    this.minutes,
    this.followUp = false,
    this.scheduledIntent = false,
  });
  final String title;
  final DateTime? at;
  final int? minutes;
  final bool followUp, scheduledIntent;

  static HomeCaptureProposal parse(String text, DateTime now) {
    final scheduled = RegExp(
      r'\b(remind me|reminder|schedule|add (?:it |this )?to (?:my )?todo|ask (?:me )?(?:after(?:wards)?|latter|later)|check in)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final follow = RegExp(
      r'\b(ask (?:me )?(?:after(?:wards)?|latter|later)|follow.?up|check in)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final duration = RegExp(
      r'\bfor (\d{1,3}) (?:minutes?|mins?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    final minutes = duration == null ? null : int.tryParse(duration.group(1)!);
    final clock = RegExp(
      r'\b(?:at )?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(text);
    final iso = RegExp(r'\b(\d{4})-(\d{2})-(\d{2})\b').firstMatch(text);
    DateTime? day;
    if (iso != null) {
      final y = int.parse(iso.group(1)!),
          m = int.parse(iso.group(2)!),
          d = int.parse(iso.group(3)!);
      final candidate = DateTime(y, m, d);
      if (candidate.year == y && candidate.month == m && candidate.day == d) {
        day = candidate;
      }
    } else if (RegExp(r'\btomorrow\b', caseSensitive: false).hasMatch(text)) {
      day = DateTime(now.year, now.month, now.day + 1);
    } else if (RegExp(r'\btoday\b', caseSensitive: false).hasMatch(text)) {
      day = DateTime(now.year, now.month, now.day);
    }
    DateTime? at;
    if (day != null && clock != null) {
      final hour = int.parse(clock.group(1)!);
      final minute = int.parse(clock.group(2) ?? '0');
      if (hour >= 1 && hour <= 12 && minute <= 59) {
        at = DateTime(
          day.year,
          day.month,
          day.day,
          hour % 12 + (clock.group(3)!.toLowerCase() == 'pm' ? 12 : 0),
          minute,
        );
      }
    }
    // Only strip known framing from explicit planning requests.
    var title = text.trim();
    if (scheduled || (day != null && clock != null)) {
      title = title.replaceAll(
        RegExp(
          r'\b(?:tomorrow|today|\d{4}-\d{2}-\d{2})\b|\b(?:at )?\d{1,2}(?::\d{2})?\s*(?:am|pm)\b|\bfor \d{1,3} (?:minutes?|mins?)\b',
          caseSensitive: false,
        ),
        '',
      );
      title = title.replaceFirst(
        RegExp(r'^(?:please )?remind me (?:to )?', caseSensitive: false),
        '',
      );
      title = title.replaceAll(
        RegExp(
          r'(?:[.!]\s*|\s+and\s+)?(?:remind me|ask (?:me )?(?:afterwards|after|later)|check in|follow.?up).*$',
          caseSensitive: false,
        ),
        '',
      );
      title = title.replaceFirst(
        RegExp(
          r'^(?:please )?(?:schedule |remind me (?:to )?|add (?:it |this )?to (?:my )?todo[: ]*)',
          caseSensitive: false,
        ),
        '',
      );
      title = title
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll(RegExp(r'^[\s,.!]+|[\s,.!]+$'), '')
          .trim();
      if (title.isEmpty) title = text.trim();
    }
    final action = RegExp(
      r'^(?:i (?:want|need) to )?(?:practi[cs]e|study|call|buy|meet|pay|review|read|exercise|walk|attend|send|finish|submit|prepare|take|drink|work|learn|book|pick|write|clean)\b',
      caseSensitive: false,
    ).hasMatch(title);
    return HomeCaptureProposal(
      title: title,
      at: at,
      minutes: minutes != null && minutes > 0 ? minutes : null,
      followUp: follow,
      scheduledIntent: scheduled || (day != null && clock != null && action),
    );
  }
}

class HomePlan {
  const HomePlan(this.requestId, this.task, this.reminder, this.checkIn);
  final String requestId;
  final Task? task;
  final Reminder reminder;
  final Reminder? checkIn;
  bool get needsAnswer =>
      checkIn?.isActive == true &&
      !checkIn!.scheduledAt.isAfter(DateTime.now());
}

/// Native Home commands use the existing transactional receipt and backup tables.
class HomeCaptureService {
  HomeCaptureService(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;
  static const capability = 'home.schedule';

  Future<HomePlan> schedule({
    required Thought source,
    required String title,
    required DateTime at,
    DateTime? checkInAt,
    bool linkedTodo = true,
  }) => db.transaction(() async {
    final requestId = 'home.schedule:${source.id}';
    final receipt = await (db.select(
      db.aiCommandTable,
    )..where((r) => r.requestId.equals(requestId))).getSingleOrNull();
    if (receipt != null) {
      final saved = jsonDecode(receipt.argumentsJson) as Map;
      if (saved['title'] != title.trim() ||
          saved['at'] != at.toIso8601String() ||
          saved['checkAt'] != checkInAt?.toIso8601String() ||
          saved['linkedTodo'] != linkedTodo) {
        throw StateError(
          'Already scheduled. Change this plan from Up next on Home.',
        );
      }
      final plan = await _plan(receipt);
      if (plan == null ||
          plan.task?.actualCompletedDate != null ||
          (!plan.reminder.isActive && plan.checkIn?.isActive != true)) {
        throw StateError(
          'This schedule was removed or finished. Create a new capture.',
        );
      }
      return plan;
    }
    final current = await db.thoughtDao.getThoughtById(source.id);
    if (current == null ||
        current.content != source.content ||
        current.isArchived ||
        current.isCompleted) {
      throw StateError('This thought changed. Review it again.');
    }
    if (title.trim().isEmpty ||
        title.trim().length > 300 ||
        !at.isAfter(clock()) ||
        (checkInAt != null && !checkInAt.isAfter(at))) {
      throw ArgumentError(
        'Choose a short title, future time, and a later check-in.',
      );
    }
    Task? task = await db.taskDao.getTaskLinkedToThought(source.id);
    if (!linkedTodo && task != null) {
      throw StateError('This thought already has a Todo. Keep it linked.');
    }
    if (linkedTodo) {
      if (task != null) {
        throw StateError(
          'This thought already has a Todo. Use its existing planning controls.',
        );
      }
      final id = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: title.trim(),
          notes: Value(source.content),
          linkedThoughtId: Value(source.id),
          plannedDate: Value(at),
        ),
      );
      task = await db.taskDao.getTaskById(id);
    }
    Future<Reminder> add(String text, DateTime time) async {
      final id = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: text,
          scheduledAt: time,
          linkedTaskId: Value(task?.id),
          alertSyncPending: const Value(true),
        ),
      );
      await db
          .into(db.thoughtReminderLinkTable)
          .insert(
            ThoughtReminderLinkTableCompanion.insert(
              thoughtId: source.id,
              reminderId: id,
            ),
          );
      return (await db.reminderDao.getReminderById(id))!;
    }

    final reminder = await add(title.trim(), at);
    final check = checkInAt == null
        ? null
        : await add(
            'Did you do it? ${title.trim()}'.substring(
              0,
              ('Did you do it? ${title.trim()}').length.clamp(0, 300),
            ),
            checkInAt,
          );
    await db
        .into(db.aiCommandTable)
        .insert(
          AiCommandTableCompanion.insert(
            requestId: requestId,
            capability: capability,
            argumentsJson: jsonEncode({
              'thoughtId': source.id,
              'taskId': task?.id,
              'reminderId': reminder.id,
              'checkInId': check?.id,
              'title': title.trim(),
              'at': at.toIso8601String(),
              'checkAt': checkInAt?.toIso8601String(),
              'linkedTodo': linkedTodo,
            }),
            resultJson: jsonEncode({
              'reminderIds': [reminder.id, if (check != null) check.id],
              'taskIds': [if (task != null) task.id],
              'alertEffectsPending': true,
            }),
          ),
        );
    return HomePlan(requestId, task, reminder, check);
  });

  Future<HomePlan?> _plan(AiCommandReceipt receipt) async {
    final args = jsonDecode(receipt.argumentsJson) as Map;
    final reminder = await db.reminderDao.getReminderById(
      args['reminderId'] as int,
    );
    final taskId = args['taskId'] as int?;
    final task = taskId == null ? null : await db.taskDao.getTaskById(taskId);
    if (taskId != null && task == null) return null;
    final checkId = args['checkInId'] as int?;
    final check = checkId == null
        ? null
        : await db.reminderDao.getReminderById(checkId);
    // A user may remove just the initial alert in Reminders. Its surviving
    // check-in must remain answerable, without recreating a deleted alert.
    if (reminder == null && check == null) return null;
    return HomePlan(receipt.requestId, task, reminder ?? check!, check);
  }

  Future<List<HomePlan>> plans() async {
    final receipts = await (db.select(
      db.aiCommandTable,
    )..where((r) => r.capability.equals(capability))).get();
    final result = <HomePlan>[];
    for (final receipt in receipts) {
      final plan = await _plan(receipt);
      if (plan != null &&
          plan.task?.actualCompletedDate == null &&
          (plan.reminder.isActive || plan.checkIn?.isActive == true)) {
        result.add(plan);
      }
    }
    result.sort(
      (a, b) => (a.checkIn?.scheduledAt ?? a.reminder.scheduledAt).compareTo(
        b.checkIn?.scheduledAt ?? b.reminder.scheduledAt,
      ),
    );
    return result;
  }

  Stream<List<HomePlan>> watchPlans() => db
      .customSelect(
        'SELECT request_id FROM ai_command_table WHERE capability = ?',
        variables: [const Variable(capability)],
        readsFrom: {db.aiCommandTable, db.reminderTable, db.taskTable},
      )
      .watch()
      .asyncMap((_) => plans());

  Future<HomePlan?> planForReminder(int id) async {
    for (final plan in await plans()) {
      if (plan.reminder.id == id || plan.checkIn?.id == id) return plan;
    }
    return null;
  }

  Future<void> reschedule(HomePlan snapshot, DateTime at, DateTime? checkAt) =>
      db.transaction(() async {
        final current = await planForReminder(snapshot.reminder.id);
        if (current == null ||
            !current.reminder.isActive ||
            current.reminder.scheduledAt != snapshot.reminder.scheduledAt ||
            current.checkIn?.scheduledAt != snapshot.checkIn?.scheduledAt) {
          throw StateError('This plan changed. Refresh Home and try again.');
        }
        if (!at.isAfter(clock()) || (checkAt != null && !checkAt.isAfter(at))) {
          throw ArgumentError('Choose a future reminder and a later check-in.');
        }
        if (current.task != null) {
          await db.taskDao.updateTask(
            TaskTableCompanion(
              id: Value(current.task!.id),
              plannedDate: Value(at),
            ),
          );
        }
        await (db.update(
          db.reminderTable,
        )..where((r) => r.id.equals(current.reminder.id))).write(
          ReminderTableCompanion(
            scheduledAt: Value(at),
            alertSyncPending: const Value(true),
          ),
        );
        if (current.checkIn != null && checkAt != null) {
          await (db.update(
            db.reminderTable,
          )..where((r) => r.id.equals(current.checkIn!.id))).write(
            ReminderTableCompanion(
              scheduledAt: Value(checkAt),
              alertSyncPending: const Value(true),
            ),
          );
        }
      });

  Future<bool> complete(HomePlan snapshot) => db.transaction(() async {
    final current = await planForReminder(snapshot.reminder.id);
    if (current == null) return false;
    if (current.task != null) {
      if (!await db.taskDao.markComplete(current.task!.id)) {
        throw StateError(
          'Finish this activity through its Todo or Focus controls.',
        );
      }
    } else {
      for (final r in [
        current.reminder,
        if (current.checkIn != null) current.checkIn!,
      ]) {
        await (db.update(
          db.reminderTable,
        )..where((t) => t.id.equals(r.id))).write(
          const ReminderTableCompanion(
            isActive: Value(false),
            alertSyncPending: Value(true),
          ),
        );
      }
    }
    return true;
  });

  /// Occurrence comparison makes stale notification actions harmless.
  Future<bool> answer(
    int id,
    DateTime occurrence,
    String answer, {
    Duration delay = const Duration(minutes: 30),
  }) => db.transaction(() async {
    final plan = await planForReminder(id);
    final check = plan?.checkIn;
    if (plan == null ||
        check == null ||
        check.id != id ||
        !check.isActive ||
        check.scheduledAt.millisecondsSinceEpoch !=
            occurrence.millisecondsSinceEpoch) {
      return false;
    }
    if (answer == 'done') {
      if (plan.task != null && !await db.taskDao.markComplete(plan.task!.id)) {
        throw StateError(
          'Finish this activity through its Todo or Focus controls.',
        );
      }
      if (plan.task == null) {
        for (final r in [plan.reminder, check]) {
          await (db.update(
            db.reminderTable,
          )..where((t) => t.id.equals(r.id))).write(
            const ReminderTableCompanion(
              isActive: Value(false),
              alertSyncPending: Value(true),
            ),
          );
        }
      }
    } else if (answer == 'later') {
      if (delay.inMinutes <= 0) throw ArgumentError('Choose a positive delay.');
      await (db.update(db.reminderTable)..where((r) => r.id.equals(id))).write(
        ReminderTableCompanion(
          scheduledAt: Value(
            (check.scheduledAt.isAfter(clock()) ? check.scheduledAt : clock())
                .add(delay),
          ),
          alertSyncPending: const Value(true),
        ),
      );
    } else if (answer == 'skip') {
      // Skip this occurrence; leave the Todo unfinished.
      for (final r in [
        if (!plan.reminder.scheduledAt.isAfter(clock())) plan.reminder,
        check,
      ]) {
        await (db.update(
          db.reminderTable,
        )..where((t) => t.id.equals(r.id))).write(
          const ReminderTableCompanion(
            isActive: Value(false),
            alertSyncPending: Value(true),
          ),
        );
      }
    } else {
      return false;
    }
    return true;
  });
}
