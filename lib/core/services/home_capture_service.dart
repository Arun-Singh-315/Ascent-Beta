import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../shared/utils/action_text.dart';

/// Conservative local interpretation. A proposal never writes records.
class HomeCaptureProposal {
  const HomeCaptureProposal({
    required this.title,
    this.at,
    this.minutes,
    this.followUp = false,
    this.scheduledIntent = false,
    this.isRecurring = false,
    this.recurrenceRule = 'once',
    this.localTime,
    this.startDate,
    this.endDate,
    this.checkInPolicy = 'off',
    this.needsEndClarification = false,
    this.needsTimeClarification = false,
  });
  final String title;
  final DateTime? at;
  final int? minutes;
  final bool followUp, scheduledIntent;
  final bool isRecurring;
  final String recurrenceRule;
  final String? localTime;
  final String? startDate;
  final String? endDate;
  final String checkInPolicy;
  final bool needsEndClarification;
  final bool needsTimeClarification;

  static HomeCaptureProposal parse(String text, DateTime now) {
    final lower = text.toLowerCase();
    final recurringMatch = RegExp(
      r'\b(every\s+(?:day|morning|evening|night|afternoon|weekday|mon|tue|wed|thu|fri|sat|sun)|daily|weekdays)\b',
      caseSensitive: false,
    ).firstMatch(text);
    final isRecurring = recurringMatch != null;

    var recurrenceRule = 'once';
    if (isRecurring) {
      final recWord = recurringMatch.group(1)!.toLowerCase();
      if (recWord.contains('weekday')) {
        recurrenceRule = 'weekdays';
      } else {
        recurrenceRule = 'daily';
      }
    }

    final scheduled = isRecurring || RegExp(
      r'\b(remind me|reminder|schedule|add (?:it |this )?to (?:my )?todo|ask (?:me )?(?:after(?:wards)?|latter|later)|check in)\b',
      caseSensitive: false,
    ).hasMatch(text);

    final keepAsking = RegExp(
      r'\b(keep asking|ask repeatedly|nudge me|keep reminding)\b',
      caseSensitive: false,
    ).hasMatch(text);
    final followMatch = RegExp(
      r'\b(ask (?:me )?(?:after(?:wards)?|latter|later)|follow.?up|check in)\b',
      caseSensitive: false,
    ).hasMatch(text);

    final follow = keepAsking || followMatch;
    final checkInPolicy = keepAsking ? 'gentle' : (follow ? 'once' : 'off');

    final duration = RegExp(
      r'\bfor (\d{1,3}) (?:minutes?|mins?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    final minutes = duration == null ? null : int.tryParse(duration.group(1)!);

    // Clock extraction: explicit am/pm
    final clockWithMeridiem = RegExp(
      r'\b(?:at )?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
      caseSensitive: false,
    ).firstMatch(text);

    // Ambiguous clock: e.g. "at 7" without am/pm
    final bareClock = RegExp(
      r'\b(?:at )?(\d{1,2})(?::(\d{2}))?\b',
      caseSensitive: false,
    ).firstMatch(text);

    int? resolvedHour;
    int? resolvedMinute;
    bool needsTimeClarification = false;

    if (clockWithMeridiem != null) {
      final h = int.parse(clockWithMeridiem.group(1)!);
      final m = int.parse(clockWithMeridiem.group(2) ?? '0');
      final isPm = clockWithMeridiem.group(3)!.toLowerCase() == 'pm';
      if (h >= 1 && h <= 12 && m <= 59) {
        resolvedHour = (h % 12) + (isPm ? 12 : 0);
        resolvedMinute = m;
      }
    } else if (bareClock != null && scheduled) {
      final h = int.parse(bareClock.group(1)!);
      final m = int.parse(bareClock.group(2) ?? '0');
      if (h >= 1 && h <= 24 && m <= 59) {
        if (lower.contains('morning')) {
          resolvedHour = h % 12;
          resolvedMinute = m;
        } else if (lower.contains('evening') || lower.contains('night')) {
          resolvedHour = (h % 12) + 12;
          resolvedMinute = m;
        } else if (h > 12) {
          resolvedHour = h;
          resolvedMinute = m;
        } else {
          needsTimeClarification = true;
          resolvedHour = h;
          resolvedMinute = m;
        }
      }
    }

    String? localTime;
    if (resolvedHour != null && resolvedMinute != null) {
      localTime =
          '${resolvedHour.toString().padLeft(2, '0')}:${resolvedMinute.toString().padLeft(2, '0')}';
    }

    // End date extraction: "until YYYY-MM-DD" or "until 31 October" or "until Nov 15"
    String? resolvedEndDate;
    bool needsEndClarification = false;
    final isoEnd = RegExp(r'\buntil\s+(\d{4})-(\d{2})-(\d{2})\b', caseSensitive: false)
        .firstMatch(text);
    final monthNames = {
      'jan': 1, 'january': 1,
      'feb': 2, 'february': 2,
      'mar': 3, 'march': 3,
      'apr': 4, 'april': 4,
      'may': 5,
      'jun': 6, 'june': 6,
      'jul': 7, 'july': 7,
      'aug': 8, 'august': 8,
      'sep': 9, 'september': 9,
      'oct': 10, 'october': 10,
      'nov': 11, 'november': 11,
      'dec': 12, 'december': 12,
    };
    final namedEndDayFirst = RegExp(
      r'\buntil\s+(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]+)\b',
      caseSensitive: false,
    ).firstMatch(text);
    final namedEndMonthFirst = RegExp(
      r'\buntil\s+([a-z]+)\s+(\d{1,2})(?:st|nd|rd|th)?\b',
      caseSensitive: false,
    ).firstMatch(text);

    if (isoEnd != null) {
      resolvedEndDate =
          '${isoEnd.group(1)}-${isoEnd.group(2)}-${isoEnd.group(3)}';
    } else if (namedEndDayFirst != null &&
        monthNames.containsKey(namedEndDayFirst.group(2)!.toLowerCase())) {
      final day = int.parse(namedEndDayFirst.group(1)!);
      final month = monthNames[namedEndDayFirst.group(2)!.toLowerCase()]!;
      final year = now.year;
      resolvedEndDate =
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    } else if (namedEndMonthFirst != null &&
        monthNames.containsKey(namedEndMonthFirst.group(1)!.toLowerCase())) {
      final month = monthNames[namedEndMonthFirst.group(1)!.toLowerCase()]!;
      final day = int.parse(namedEndMonthFirst.group(2)!);
      final year = now.year;
      resolvedEndDate =
          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    } else if (isRecurring) {
      needsEndClarification = true;
    }

    // Start date / single day resolution
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
    } else if (isRecurring) {
      // Routines default start date to today or tomorrow depending on current time
      day = DateTime(now.year, now.month, now.day);
    }

    DateTime? at;
    if (day != null && resolvedHour != null && resolvedMinute != null) {
      at = DateTime(
        day.year,
        day.month,
        day.day,
        resolvedHour,
        resolvedMinute,
      );
    }

    // Only strip known framing from explicit planning requests.
    var title = text.trim();
    if (scheduled || (day != null && resolvedHour != null)) {
      title = title.replaceAll(
        RegExp(
          r'\buntil\s+(?:\d{4}-\d{2}-\d{2}|\d{1,2}(?:st|nd|rd|th)?\s+[a-z]+|[a-z]+\s+\d{1,2}(?:st|nd|rd|th)?)\b',
          caseSensitive: false,
        ),
        '',
      );
      title = title.replaceAll(
        RegExp(
          r'\b(?:every\s+(?:day|morning|evening|night|afternoon|weekday)|daily|weekdays)\b',
          caseSensitive: false,
        ),
        '',
      );
      title = title.replaceAll(
        RegExp(
          r'\b(?:tomorrow|today|\d{4}-\d{2}-\d{2})\b|\b(?:at )?\d{1,2}(?::\d{2})?\s*(?:am|pm)?\b|\bfor \d{1,3} (?:minutes?|mins?)\b',
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
          r'(?:[.!]\s*|\s+and\s+)?(?:remind me|keep asking|ask (?:me )?(?:afterwards|after|later|repeatedly)|nudge me|check in|follow.?up).*$',
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

    final String? startDateStr = day != null
        ? '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}'
        : null;

    return HomeCaptureProposal(
      title: title,
      at: at,
      minutes: minutes != null && minutes > 0 ? minutes : null,
      followUp: follow,
      scheduledIntent: scheduled || (day != null && resolvedHour != null && action),
      isRecurring: isRecurring,
      recurrenceRule: recurrenceRule,
      localTime: localTime,
      startDate: startDateStr,
      endDate: resolvedEndDate,
      checkInPolicy: checkInPolicy,
      needsEndClarification: needsEndClarification,
      needsTimeClarification: needsTimeClarification,
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
      if (saved['title'] == title.trim() &&
          saved['at'] == at.toIso8601String() &&
          saved['checkAt'] == checkInAt?.toIso8601String() &&
          saved['linkedTodo'] == linkedTodo) {
        final plan = await _plan(receipt);
        if (plan != null &&
            plan.task?.actualCompletedDate == null &&
            (plan.reminder.isActive || plan.checkIn?.isActive == true)) {
          return plan;
        }
      }
      // Re-scheduling or updating: clean up the prior alerts and command receipt
      final oldRemId = saved['reminderId'] as int?;
      final oldCheckId = saved['checkInId'] as int?;
      if (oldRemId != null) {
        await (db.delete(db.reminderTable)..where((r) => r.id.equals(oldRemId))).go();
      }
      if (oldCheckId != null) {
        await (db.delete(db.reminderTable)..where((r) => r.id.equals(oldCheckId))).go();
      }
      await (db.delete(db.aiCommandTable)..where((r) => r.requestId.equals(requestId))).go();
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
        await (db.update(db.taskTable)..where((t) => t.id.equals(task!.id))).write(
          TaskTableCompanion(
            title: Value(title.trim()),
            plannedDate: Value(at),
          ),
        );
        task = await db.taskDao.getTaskById(task.id);
      } else {
        final cleanTitle = title.trim();
        final taskNotes = actionSupportingText(cleanTitle, source.content);
        final id = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: cleanTitle,
            notes: Value(taskNotes),
            linkedThoughtId: Value(source.id),
            plannedDate: Value(at),
          ),
        );
        task = await db.taskDao.getTaskById(id);
      }
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
          mode: InsertMode.insertOrReplace,
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
