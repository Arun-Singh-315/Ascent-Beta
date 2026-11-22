import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'activity_entry_service.dart';
import 'capture_router.dart';
import 'home_capture_service.dart';
import 'plan_collection_service.dart';

enum CaptureKind {
  todo,
  reminder,
  timer,
  thought,
  routine,
  expense,
  income,
  water,
}

String captureLabel(CaptureKind kind) => switch (kind) {
  CaptureKind.todo => 'To-do',
  CaptureKind.reminder => 'Reminder',
  CaptureKind.timer => 'Focus task',
  CaptureKind.thought => 'Thought',
  CaptureKind.routine => 'Routine',
  CaptureKind.expense => 'Expense',
  CaptureKind.income => 'Income',
  CaptureKind.water => 'Water',
};
String captureDestination(CaptureKind kind) => switch (kind) {
  CaptureKind.todo || CaptureKind.timer => 'Things',
  CaptureKind.reminder => 'Reminders',
  CaptureKind.thought => 'Mindspace',
  CaptureKind.routine => 'Plans',
  CaptureKind.expense || CaptureKind.income => 'Money',
  CaptureKind.water => 'Hydration',
};

/// Editable, local proposals. Text is never executed or sent to a remote model.
class CaptureDraft {
  CaptureDraft({
    required this.key,
    required this.title,
    this.kind = CaptureKind.todo,
    this.notes = '',
    this.at,
    this.day,
    this.end,
    this.minutes = 25,
    this.amount,
    this.category = 'Other',
    this.space = 'general',
    this.starred = false,
    this.recurrence = 'daily',
    this.needsClock = false,
    this.alternative,
  });
  final String key;

  /// A second likely kind when the router was unsure (not persisted).
  CaptureKind? alternative;
  String title, notes, category, space, recurrence;
  CaptureKind kind;
  DateTime? at, day, end;
  int minutes;
  double? amount;
  bool starred, needsClock;
  Map<String, Object?> toJson() => {
    'key': key,
    'title': title,
    'kind': kind.name,
    'notes': notes,
    'at': at?.toIso8601String(),
    'day': day?.toIso8601String(),
    'end': end?.toIso8601String(),
    'minutes': minutes,
    'amount': amount,
    'category': category,
    'space': space,
    'starred': starred,
    'recurrence': recurrence,
    'needsClock': needsClock,
  };
  factory CaptureDraft.fromJson(Map<String, dynamic> j) => CaptureDraft(
    key: j['key'] as String,
    title: j['title'] as String,
    kind: CaptureKind.values.byName(j['kind'] as String),
    notes: j['notes'] as String? ?? '',
    at: DateTime.tryParse(j['at'] as String? ?? ''),
    day: DateTime.tryParse(j['day'] as String? ?? ''),
    end: DateTime.tryParse(j['end'] as String? ?? ''),
    minutes: j['minutes'] as int? ?? 25,
    amount: (j['amount'] as num?)?.toDouble(),
    category: j['category'] as String? ?? 'Other',
    space: j['space'] as String? ?? 'general',
    starred: j['starred'] == true,
    recurrence: j['recurrence'] as String? ?? 'daily',
    needsClock: j['needsClock'] == true,
  );

  String? validate(DateTime now) {
    if (kind != CaptureKind.water &&
        (title.trim().isEmpty || title.trim().length > 300)) {
      return 'Give this item a title of 1–300 characters.';
    }
    if (notes.length > 20000) return 'Keep notes under 20,000 characters.';
    if (needsClock) {
      return 'Choose an exact time; the written time needs clarification.';
    }
    if ([CaptureKind.reminder, CaptureKind.routine].contains(kind) &&
        at == null) {
      return 'Choose a date and time.';
    }
    if (at != null &&
        [
          CaptureKind.todo,
          CaptureKind.timer,
          CaptureKind.reminder,
          CaptureKind.routine,
        ].contains(kind) &&
        !at!.isAfter(now)) {
      return 'That reminder time has passed. Choose a future time.';
    }
    if (kind == CaptureKind.timer && (minutes < 1 || minutes > 1440)) {
      return 'Choose a focus target between 1 and 1440 minutes.';
    }
    if ([
          CaptureKind.expense,
          CaptureKind.income,
          CaptureKind.water,
        ].contains(kind) &&
        (amount == null || !amount!.isFinite || amount! <= 0)) {
      return 'Enter a positive amount.';
    }
    if (kind == CaptureKind.water && (amount! > 5000 || amount! % 1 != 0)) {
      return 'Enter a whole amount between 1 and 5000 ml.';
    }
    if ([CaptureKind.expense, CaptureKind.income].contains(kind) &&
        title.trim().length > 200) {
      return 'Keep money entries under 200 characters.';
    }
    if (kind == CaptureKind.routine &&
        (end == null ||
            at == null ||
            end!.isBefore(DateTime(at!.year, at!.month, at!.day)) ||
            end!.difference(at!).inDays > 90)) {
      return 'Choose a routine end date within 90 days of its start.';
    }
    if (kind == CaptureKind.routine &&
        !['daily', 'weekdays'].contains(recurrence)) {
      return 'Choose Daily or Weekdays.';
    }
    if ([CaptureKind.todo, CaptureKind.timer].contains(kind) &&
        day != null &&
        DateTime(
          day!.year,
          day!.month,
          day!.day,
        ).isBefore(DateTime(now.year, now.month, now.day))) {
      return 'Choose today or a future date.';
    }
    if ([
          CaptureKind.expense,
          CaptureKind.income,
          CaptureKind.water,
        ].contains(kind) &&
        day != null &&
        day!.isAfter(now)) {
      return 'Logged activity needs today or a past date.';
    }
    return null;
  }
}

/// Splits [raw] into up to 30 lines and proposes one editable draft per line.
///
/// Lines with a prefix ("todo:", "spent", "water", …) keep that kind. Other
/// lines are routed by [guessCaptureKind]; when the guessed kind is not in
/// [allowed] (its feature is switched off), the line falls back to a to-do.
List<CaptureDraft> parseQuickCapture(
  String raw,
  DateTime now, {
  Set<CaptureKind>? allowed,
}) {
  final lines = PlanItemDraft.parseList(raw);
  if (lines.length > 30) {
    throw ArgumentError('Capture up to 30 items at a time.');
  }
  return [
    for (var index = 0; index < lines.length; index++)
      _parse(lines[index], now, index, allowed),
  ];
}

/// One line as a draft with key [index] (the sheet re-parses lines one by
/// one so a change to one line never moves another).
CaptureDraft parseCaptureLine(
  String line,
  DateTime now,
  int index, {
  Set<CaptureKind>? allowed,
}) => _parse(line, now, index, allowed);

final _bareClock = RegExp(
  r'\bat\s+(\d{1,2})(?::(\d{2}))?\b(?!\s*(?:am|pm|a\.m|p\.m))',
  caseSensitive: false,
);

/// "at 6" with no am/pm means the next 6 o'clock still ahead on that day.
DateTime? _resolveBareClock(String text, DateTime now, DateTime? day) {
  final match = _bareClock.firstMatch(text);
  if (match == null) return null;
  final hour = int.parse(match[1]!);
  final minute = int.tryParse(match[2] ?? '0') ?? 0;
  if (minute > 59) return null;
  final base = day ?? DateTime(now.year, now.month, now.day);
  if (hour > 23) return null;
  if (hour > 12 || hour == 0) {
    final at = DateTime(base.year, base.month, base.day, hour, minute);
    return at.isAfter(now)
        ? at
        : DateTime(base.year, base.month, base.day + 1, hour, minute);
  }
  final morning = hour % 12;
  for (final h in [morning, morning + 12]) {
    final at = DateTime(base.year, base.month, base.day, h, minute);
    if (at.isAfter(now)) return at;
  }
  return DateTime(base.year, base.month, base.day + 1, morning, minute);
}

/// The next half-hour boundary at least 15 minutes from [now].
DateTime nextFreeSlot(DateTime now) {
  final soon = now.add(const Duration(minutes: 15));
  final extra = soon.minute % 30 == 0 && soon.second == 0
      ? 0
      : 30 - soon.minute % 30;
  final slot = DateTime(
    soon.year,
    soon.month,
    soon.day,
    soon.hour,
    soon.minute,
  ).add(Duration(minutes: extra));
  return slot;
}

CaptureDraft _parse(
  String original,
  DateTime now,
  int index,
  Set<CaptureKind>? allowed,
) {
  var text = original;
  var kind = CaptureKind.todo;
  CaptureGuess? guess;
  final prefix = RegExp(
    r'^(todo|to-do|task|reminder|remind me(?: to)?|timer|focus|thought|idea|note|routine|expense|spent|income|earned|water)\s*(?::|\s)\s*',
    caseSensitive: false,
  ).firstMatch(text);
  final label = prefix?[1]!.toLowerCase();
  // "water the plants" and "spent time with Sam" are not logs: amount
  // prefixes only count when a number follows.
  final amountPrefix = const {'water', 'spent', 'earned', 'expense', 'income'};
  final ignorePrefix =
      label != null &&
      amountPrefix.contains(label) &&
      !RegExp(r'\d').hasMatch(text.substring(prefix!.end));
  if (prefix != null && !ignorePrefix) {
    text = text.substring(prefix.end).trim();
    kind = switch (label!) {
      'reminder' || 'remind me' || 'remind me to' => CaptureKind.reminder,
      'timer' || 'focus' => CaptureKind.timer,
      'thought' || 'idea' || 'note' => CaptureKind.thought,
      'routine' => CaptureKind.routine,
      'expense' || 'spent' => CaptureKind.expense,
      'income' || 'earned' => CaptureKind.income,
      'water' => CaptureKind.water,
      _ => CaptureKind.todo,
    };
    if (allowed != null && !allowed.contains(kind)) {
      kind = CaptureKind.todo;
      text = original.trim();
    }
  } else {
    guess = guessCaptureKind(text);
    if (allowed == null || allowed.contains(guess.kind)) {
      kind = guess.kind;
      text = guess.text;
    } else {
      guess = null;
    }
  }
  if (kind == CaptureKind.thought) {
    final t = text.trim();
    return CaptureDraft(
      key: '$index',
      kind: kind,
      title: t.isEmpty ? t : t[0].toUpperCase() + t.substring(1),
      alternative: guess?.alternative,
    );
  }
  final proposal = HomeCaptureProposal.parse(text, now);
  final hasClock = RegExp(
    r'\bat\s+\d|\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b',
    caseSensitive: false,
  ).hasMatch(text);
  final hasDay = RegExp(
    r'\btoday\b|\btomorrow\b|\b\d{4}-\d{2}-\d{2}\b',
    caseSensitive: false,
  ).hasMatch(text);
  final parsed = PlanItemDraft.fromText(
    '${kind == CaptureKind.reminder ? 'remind me to ' : ''}$text',
    now,
  );
  final draft = CaptureDraft(
    key: '$index',
    kind: kind,
    title: parsed.title,
    at: hasClock ? parsed.at : null,
    minutes: guess?.minutes ?? proposal.minutes ?? 25,
    notes: '',
    recurrence: proposal.recurrenceRule == 'weekdays' ? 'weekdays' : 'daily',
    end: parsed.endDate,
    needsClock:
        hasClock && (parsed.at == null || proposal.needsTimeClarification),
    alternative: guess?.alternative,
  );
  if (proposal.isRecurring) draft.kind = CaptureKind.routine;
  if (RegExp(
        r'\bevery\s+(?:mon|tue|wed|thu|fri|sat|sun)',
        caseSensitive: false,
      ).hasMatch(text) &&
      !text.toLowerCase().contains('weekday')) {
    draft.recurrence = '';
  }
  if (hasDay) {
    if (RegExp(r'\btomorrow\b', caseSensitive: false).hasMatch(text)) {
      draft.day = DateTime(now.year, now.month, now.day + 1);
    } else if (RegExp(r'\btoday\b', caseSensitive: false).hasMatch(text)) {
      draft.day = DateTime(now.year, now.month, now.day);
    } else {
      final match = RegExp(r'\b\d{4}-\d{2}-\d{2}\b').firstMatch(text);
      draft.day = DateTime.tryParse(match?.group(0) ?? '');
    }
  }
  if ([
    CaptureKind.expense,
    CaptureKind.income,
    CaptureKind.water,
  ].contains(draft.kind)) {
    final amount = RegExp(
      r'(?:₹|rs\.?\s*)?(\d[\d,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (amount != null) {
      draft.amount = double.tryParse(amount[1]!.replaceAll(',', ''));
      draft.title = text
          .replaceRange(amount.start, amount.end, '')
          .replaceAll(RegExp(r'\b(?:for|ml)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'^\s*(?:on|at|in)\b', caseSensitive: false), '')
          .replaceAll(RegExp(r'\s{2,}'), ' ')
          .trim();
      if (draft.title.isNotEmpty) {
        draft.title = draft.title[0].toUpperCase() + draft.title.substring(1);
      } else {
        draft.title = draft.kind == CaptureKind.income ? 'Income' : 'Expense';
      }
    }
    if (guess?.amount != null) draft.amount = guess!.amount;
    if (draft.kind == CaptureKind.water) draft.title = 'Water';
    draft.needsClock = false;
    draft.at = null;
    return draft;
  }
  // Smart defaults (CLAUDE.md §1.4): never leave a line blocked on a time.
  if (draft.needsClock || (draft.at == null && _bareClock.hasMatch(text))) {
    final resolved = _resolveBareClock(text, now, draft.day);
    if (resolved != null) {
      draft
        ..at = resolved
        ..needsClock = false
        ..title = draft.title
            .replaceAll(
              RegExp(r'\s*\bat\s+\d{1,2}(?::\d{2})?\b', caseSensitive: false),
              '',
            )
            .trim();
    }
  }
  if (draft.kind == CaptureKind.routine &&
      draft.at == null &&
      !draft.needsClock) {
    final lower = text.toLowerCase();
    final hour = lower.contains('morning')
        ? 8
        : lower.contains('evening')
        ? 19
        : lower.contains('night')
        ? 21
        : 9;
    final todayAt = DateTime(now.year, now.month, now.day, hour);
    draft.at = todayAt.isAfter(now)
        ? todayAt
        : todayAt.add(const Duration(days: 1));
  }
  if (draft.kind == CaptureKind.routine) {
    final cleaned = draft.title
        .replaceAll(
          RegExp(
            r'\b(?:every\s+(?:day|morning|evening|night|weekday)s?|daily|on weekdays|weekdays)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    if (cleaned.isNotEmpty) draft.title = cleaned;
  }
  final t = draft.title.trimLeft();
  if (t.isNotEmpty) draft.title = t[0].toUpperCase() + t.substring(1);
  if (draft.kind == CaptureKind.routine && draft.at != null) {
    draft.end ??= DateTime(draft.at!.year, draft.at!.month, draft.at!.day + 30);
  }
  if (draft.kind == CaptureKind.reminder &&
      draft.at == null &&
      !draft.needsClock) {
    draft.at = draft.day == null
        ? nextFreeSlot(now)
        : DateTime(draft.day!.year, draft.day!.month, draft.day!.day, 9);
    if (!draft.at!.isAfter(now)) draft.at = nextFreeSlot(now);
  }
  return draft;
}

/// One saved record, so Undo can remove exactly what a capture created.
typedef CaptureRecord = ({String type, String id});

class CaptureReceipt {
  const CaptureReceipt(this.items, this.reminderIds, [this.records = const []]);
  final List<({String title, String destination, String route})> items;
  final List<int> reminderIds;

  /// Created rows by table ('task', 'reminder', 'thought', 'plan',
  /// 'money', 'water'), in save order.
  final List<CaptureRecord> records;
  Map<String, Object> toJson() => {
    'items': [
      for (final i in items)
        {'title': i.title, 'destination': i.destination, 'route': i.route},
    ],
    'reminderIds': reminderIds,
    'records': [
      for (final r in records) {'type': r.type, 'id': r.id},
    ],
  };
  factory CaptureReceipt.fromJson(Map<String, dynamic> j) => CaptureReceipt(
    [
      for (final i in j['items'] as List)
        (
          title: i['title'] as String,
          destination: i['destination'] as String,
          route: i['route'] as String,
        ),
    ],
    (j['reminderIds'] as List).cast<int>(),
    [
      for (final r in (j['records'] as List?) ?? const [])
        (type: r['type'] as String, id: r['id'] as String),
    ],
  );
}

/// One reviewed batch, one transaction, one retry-safe receipt. Device alert
/// delivery runs after commit and cannot duplicate or roll back saved records.
class QuickCaptureService {
  QuickCaptureService(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;
  Future<CaptureReceipt> save(
    List<CaptureDraft> drafts, {
    required String requestId,
  }) => db.transaction(() async {
    final key = 'quick.capture:$requestId';
    final previous = await (db.select(
      db.aiCommandTable,
    )..where((r) => r.requestId.equals(key))).getSingleOrNull();
    if (previous != null) {
      return CaptureReceipt.fromJson(
        jsonDecode(previous.resultJson) as Map<String, dynamic>,
      );
    }
    if (drafts.isEmpty || drafts.length > 30) {
      throw ArgumentError('Add between 1 and 30 items.');
    }
    for (final draft in drafts) {
      final error = draft.validate(clock());
      if (error != null) throw ArgumentError(error);
    }
    final items = <({String title, String destination, String route})>[];
    final alerts = <int>[];
    final records = <CaptureRecord>[];
    final today = clock();
    for (final d in drafts) {
      var route = '';
      switch (d.kind) {
        case CaptureKind.todo:
        case CaptureKind.timer:
          final saved = await ActivityEntryService(db, clock: clock).save(
            title: d.title,
            date: d.at ?? d.day ?? DateTime(today.year, today.month, today.day),
            estimatedMinutes: d.kind == CaptureKind.timer ? d.minutes : null,
            notes: d.notes,
            priority: d.starred ? 'high' : 'low',
            reminderAt: d.at,
          );
          alerts.addAll(saved.reminderIds);
          records.add((type: 'task', id: '${saved.taskId}'));
          route = '/today?task=${saved.taskId}';
        case CaptureKind.reminder:
          final id = await db.reminderDao.insertReminder(
            ReminderTableCompanion.insert(
              title: d.title.trim(),
              scheduledAt: d.at!,
              alertSyncPending: const Value(true),
            ),
          );
          alerts.add(id);
          records.add((type: 'reminder', id: '$id'));
          route = '/reminders?reminder=$id';
        case CaptureKind.thought:
          final categories = await db.thoughtDao.watchCategories().first;
          if (!categories.containsKey(d.space)) {
            throw ArgumentError(
              'This space no longer exists. Choose another space.',
            );
          }
          final content = d.notes.trim().isEmpty
              ? d.title.trim()
              : '${d.title.trim()}\n\n${d.notes.trim()}';
          final id = await db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(
              content: content,
              category: Value(d.space),
            ),
          );
          records.add((type: 'thought', id: '$id'));
          route = '/thought-wall?thought=$id';
        case CaptureKind.routine:
          final before = (await db.select(db.reminderTable).get())
              .map((r) => r.id)
              .toSet();
          final planId = await PlanCollectionService(db, clock: clock).save(
            title: d.title.trim(),
            items: [
              PlanItemDraft(
                title: d.title.trim(),
                notes: d.notes,
                at: d.at,
                recurrence: d.recurrence,
                endDate: d.end,
              ),
            ],
            requestId: 'quick:$requestId:${d.key}',
          );
          alerts.addAll(
            (await db.select(db.reminderTable).get())
                .where((r) => !before.contains(r.id))
                .map((r) => r.id),
          );
          records.add((type: 'plan', id: planId));
          route = '/plans';
        case CaptureKind.expense:
        case CaptureKind.income:
          final moneyId = await db.financeDao.insertTransaction(
            FinanceTransactionTableCompanion.insert(
              title: d.title.trim(),
              amount: d.amount!,
              type: Value(d.kind.name),
              category: Value(d.category),
              date: d.day ?? today,
              notes: Value(d.notes.trim().isEmpty ? null : d.notes.trim()),
            ),
          );
          records.add((type: 'money', id: '$moneyId'));
          route = '/money';
        case CaptureKind.water:
          final waterId = await db.waterDao.addWaterForDate(
            d.amount!.toInt(),
            d.day ?? today,
          );
          records.add((type: 'water', id: '$waterId'));
          route = '/hydration';
      }
      items.add((
        title: d.kind == CaptureKind.water
            ? '${d.amount!.toInt()} ml water'
            : d.title.trim(),
        destination: captureDestination(d.kind),
        route: route,
      ));
    }
    final result = CaptureReceipt(items, alerts, records);
    await db
        .into(db.aiCommandTable)
        .insert(
          AiCommandTableCompanion.insert(
            requestId: key,
            capability: 'quick.capture',
            argumentsJson: jsonEncode([for (final d in drafts) d.toJson()]),
            resultJson: jsonEncode(result.toJson()),
          ),
        );
    return result;
  });

  /// Removes exactly the records [receipt] created, in one transaction.
  /// Tasks take their reminders and sessions with them; already-deleted rows
  /// are skipped. Returns how many records were removed.
  Future<int> undo(CaptureReceipt receipt) => db.transaction(() async {
    var removed = 0;
    for (final r in receipt.records.reversed) {
      switch (r.type) {
        case 'task':
          removed += await db.taskDao.deleteTask(
            int.parse(r.id),
            bypassProtection: true,
          );
        case 'reminder':
          removed += await db.reminderDao.deleteReminder(
            int.parse(r.id),
            bypassProtection: true,
          );
        case 'thought':
          removed += await db.thoughtDao.deleteThought(int.parse(r.id));
        case 'plan':
          await PlanCollectionService(db, clock: clock).deleteCollection(r.id);
          removed++;
        case 'money':
          removed += await db.financeDao.deleteTransaction(int.parse(r.id));
        case 'water':
          removed += await db.waterDao.deleteWater(int.parse(r.id));
      }
    }
    return removed;
  });
}
