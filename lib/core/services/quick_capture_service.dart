import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'activity_entry_service.dart';
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
  CaptureKind.todo || CaptureKind.timer => 'Dayboard',
  CaptureKind.reminder => 'Reminders',
  CaptureKind.thought => 'Mind Palace',
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
  });
  final String key;
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

List<CaptureDraft> parseQuickCapture(String raw, DateTime now) {
  final lines = PlanItemDraft.parseList(raw);
  if (lines.length > 30) {
    throw ArgumentError('Capture up to 30 items at a time.');
  }
  return [
    for (var index = 0; index < lines.length; index++)
      _parse(lines[index], now, index),
  ];
}

CaptureDraft _parse(String original, DateTime now, int index) {
  var text = original;
  var kind = CaptureKind.todo;
  final prefix = RegExp(
    r'^(todo|to-do|task|reminder|remind me(?: to)?|timer|focus|thought|note|routine|expense|spent|income|earned|water)\s*(?::|\s)\s*',
    caseSensitive: false,
  ).firstMatch(text);
  if (prefix != null) {
    final label = prefix[1]!.toLowerCase();
    text = text.substring(prefix.end).trim();
    kind = switch (label) {
      'reminder' || 'remind me' || 'remind me to' => CaptureKind.reminder,
      'timer' || 'focus' => CaptureKind.timer,
      'thought' || 'note' => CaptureKind.thought,
      'routine' => CaptureKind.routine,
      'expense' || 'spent' => CaptureKind.expense,
      'income' || 'earned' => CaptureKind.income,
      'water' => CaptureKind.water,
      _ => CaptureKind.todo,
    };
  }
  if (kind == CaptureKind.thought) {
    return CaptureDraft(key: '$index', kind: kind, title: text);
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
    minutes: proposal.minutes ?? 25,
    notes: '',
    recurrence: proposal.recurrenceRule == 'weekdays' ? 'weekdays' : 'daily',
    end: parsed.endDate,
    needsClock:
        hasClock && (parsed.at == null || proposal.needsTimeClarification),
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
  ].contains(kind)) {
    final amount = RegExp(
      r'(?:₹|rs\.?\s*)?(\d[\d,]*(?:\.\d{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    if (amount != null) {
      draft.amount = double.tryParse(amount[1]!.replaceAll(',', ''));
      draft.title = text
          .replaceRange(amount.start, amount.end, '')
          .replaceAll(RegExp(r'\b(?:for|ml)\b', caseSensitive: false), '')
          .trim();
    }
    if (kind == CaptureKind.water) draft.title = 'Water';
    draft.needsClock = false;
    draft.at = null;
  }
  return draft;
}

class CaptureReceipt {
  const CaptureReceipt(this.items, this.reminderIds);
  final List<({String title, String destination, String route})> items;
  final List<int> reminderIds;
  Map<String, Object> toJson() => {
    'items': [
      for (final i in items)
        {'title': i.title, 'destination': i.destination, 'route': i.route},
    ],
    'reminderIds': reminderIds,
  };
  factory CaptureReceipt.fromJson(Map<String, dynamic> j) => CaptureReceipt([
    for (final i in j['items'] as List)
      (
        title: i['title'] as String,
        destination: i['destination'] as String,
        route: i['route'] as String,
      ),
  ], (j['reminderIds'] as List).cast<int>());
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
          route = '/thought-wall?thought=$id';
        case CaptureKind.routine:
          final before = (await db.select(db.reminderTable).get())
              .map((r) => r.id)
              .toSet();
          await PlanCollectionService(db, clock: clock).save(
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
          route = '/plans';
        case CaptureKind.expense:
        case CaptureKind.income:
          await db.financeDao.insertTransaction(
            FinanceTransactionTableCompanion.insert(
              title: d.title.trim(),
              amount: d.amount!,
              type: Value(d.kind.name),
              category: Value(d.category),
              date: d.day ?? today,
              notes: Value(d.notes.trim().isEmpty ? null : d.notes.trim()),
            ),
          );
          route = '/money';
        case CaptureKind.water:
          await db.waterDao.addWaterForDate(d.amount!.toInt(), d.day ?? today);
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
    final result = CaptureReceipt(items, alerts);
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
}
