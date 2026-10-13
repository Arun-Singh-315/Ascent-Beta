import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../shared/widgets/feature_guide.dart';
import 'ai_action_execution.dart';
import 'ai_service.dart';
import 'riya_workspace_actions.dart';
import 'riya_life_actions.dart';
import 'riya_learning_actions.dart';
import 'riya_session_reads.dart';
import 'riya_money_actions.dart';
import 'riya_medicine_actions.dart';

enum RiyaValue {
  text,
  longText,
  integer,
  offset,
  boolean,
  number,
  nonnegativeNumber,
  date,
  integerList,
  textList,
}

class RiyaCapability {
  const RiyaCapability(
    this.id,
    this.description,
    this.route,
    this.schema, {
    this.required = const [],
    this.write = false,
    this.example,
  });
  final String id, description, route;
  final Map<String, RiyaValue> schema;
  final List<String> required;
  final bool write;
  final String? example;
  String get permission => 'Single local profile';
  bool get requiresConfirmation => write;
  String get failureMessage =>
      'I could not verify that change. Check the relevant screen before retrying.';
}

const riyaCapabilities = <RiyaCapability>[
  ...riyaWorkspaceCapabilities,
  ...riyaLifeCapabilities,
  ...riyaMoneyCapabilities,
  ...riyaMedicineCapabilities,
  ...riyaLearningCapabilities,
  ...riyaSessionCapabilities,
  RiyaCapability(
    'tasks.today',
    'Read today’s tasks',
    '/today',
    {},
    example: 'What tasks do I have today?',
  ),
  RiyaCapability(
    'tasks.create',
    'Create a task',
    '/today',
    {
      'title': RiyaValue.text,
      'plannedDate': RiyaValue.date,
      'estimatedMinutes': RiyaValue.integer,
      'priority': RiyaValue.text,
      'reminderTime': RiyaValue.date,
    },
    required: ['title'],
    write: true,
    example: 'Add a task to prepare for an interview',
  ),
  RiyaCapability(
    'tasks.checklist',
    'Create a preparation checklist',
    '/today',
    {'title': RiyaValue.text, 'items': RiyaValue.textList},
    required: ['title', 'items'],
    write: true,
  ),
  RiyaCapability(
    'tasks.reschedule',
    'Reschedule selected tasks',
    '/today',
    {'taskIds': RiyaValue.integerList, 'newDate': RiyaValue.date},
    required: ['taskIds', 'newDate'],
    write: true,
  ),
  RiyaCapability(
    'reminders.list',
    'Read reminders for a selected day',
    '/reminders',
    {
      'scope': RiyaValue.text,
      'from': RiyaValue.date,
      'to': RiyaValue.date,
      'offset': RiyaValue.offset,
    },
    example: 'Show my reminders',
  ),
  RiyaCapability(
    'reminders.create',
    'Save a reminder',
    '/reminders',
    {'title': RiyaValue.text, 'at': RiyaValue.date},
    required: ['title', 'at'],
    write: true,
    example: 'Remind me to call tomorrow at 7 PM',
  ),
  RiyaCapability(
    'reminders.edit',
    'Change a chosen reminder time',
    '/reminders',
    {'id': RiyaValue.integer, 'at': RiyaValue.date},
    required: ['id', 'at'],
    write: true,
    example: 'Change my reminder to 7 PM',
  ),
  RiyaCapability(
    'thoughts.search',
    'Find your saved thoughts',
    '/thought-wall',
    {'query': RiyaValue.text},
    required: ['query'],
    example: 'Find what I wrote about my interview',
  ),
  RiyaCapability(
    'expenses.create',
    'Record an expense',
    '/money',
    {
      'amount': RiyaValue.number,
      'title': RiyaValue.text,
      'category': RiyaValue.text,
      'account': RiyaValue.text,
    },
    required: ['amount', 'title'],
    write: true,
    example: 'Add 200 rupees for coffee',
  ),
  RiyaCapability(
    'expenses.summary',
    'Sum expenses in a local period',
    '/money',
    {'from': RiyaValue.date, 'to': RiyaValue.date},
    required: ['from', 'to'],
    example: 'Show my spending this week',
  ),
  RiyaCapability(
    'hydration.log',
    'Record water intake',
    '/hydration',
    {'amountMl': RiyaValue.integer},
    required: ['amountMl'],
    write: true,
    example: 'Log 250ml water',
  ),
  RiyaCapability(
    'focus.start',
    'Start Focus with a duration target',
    '/focus',
    {'minutes': RiyaValue.integer, 'title': RiyaValue.text},
    required: ['minutes'],
    write: true,
    example: 'Start a 25-minute timer',
  ),
  RiyaCapability(
    'focus.pause',
    'Pause the selected Focus session',
    '/focus',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
    example: 'Pause my timer',
  ),
  RiyaCapability(
    'focus.resume',
    'Resume the selected Focus session',
    '/focus',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
    example: 'Resume my timer',
  ),
  RiyaCapability(
    'help.feature',
    'Explain a feature',
    '/more',
    {'feature': RiyaValue.text},
    required: ['feature'],
    example: 'Show me how to use Thought Wall',
  ),
  RiyaCapability(
    'navigation.open',
    'Open a supported screen',
    '/more',
    {'route': RiyaValue.text},
    required: ['route'],
  ),
];

class RiyaCommand {
  const RiyaCommand(this.id, this.arguments, {this.executionRequestId});
  final String? executionRequestId;
  RiyaCommand forExecution(String requestId) =>
      RiyaCommand(id, arguments, executionRequestId: requestId);
  final String id;
  final Map<String, dynamic> arguments;
  RiyaCapability get capability => riyaCapabilities.firstWhere(
    (c) => c.id == id,
    orElse: () => throw UnsupportedError('Unsupported capability'),
  );
  String get preview {
    const labels = {
      'title': 'Title',
      'at': 'When',
      'plannedDate': 'Day',
      'reminderTime': 'Reminder',
      'amount': 'Amount (₹)',
      'amountMl': 'Water (mL)',
      'minutes': 'Focus target (minutes)',
      'estimatedMinutes': 'Duration (minutes)',
      'items': 'Steps',
      'priority': 'Priority',
      'category': 'Category',
      'account': 'Account',
      'id': 'Record number',
      'noteIds': 'Selected note numbers',
      'content': 'Thought',
      'mode': 'Action',
      'grouped': 'One grouped item',
      'section': 'Home card',
      'visible': 'Show card',
      'taskIds': 'Task numbers',
      'newDate': 'Move to',
    };
    return arguments.entries
        .map(
          (e) =>
              '${labels[e.key] ?? e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}',
        )
        .join('\n');
  }
}

class RiyaResult {
  const RiyaResult(
    this.message,
    this.route, {
    this.reminderIds = const [],
    this.replayed = false,
    this.options = const [],
    this.cancelReminderIds = const [],
    this.entityType,
    this.entityId,
    this.learningCourseId,
    this.learningModuleId,
    this.learningLectureId,
  });
  final String message, route;
  final String? entityType;
  final int? entityId;
  final String? learningCourseId;
  final int? learningModuleId, learningLectureId;
  final List<int> reminderIds, cancelReminderIds;
  final List<String> options;
  final bool replayed;
  Map<String, dynamic> toJson() => {
    'message': message,
    'route': route,
    'reminderIds': reminderIds,
    'cancelReminderIds': cancelReminderIds,
    'options': options,
    'entityType': entityType,
    'entityId': entityId,
    'learningCourseId': learningCourseId,
    'learningModuleId': learningModuleId,
    'learningLectureId': learningLectureId,
    'alertEffectsPending':
        reminderIds.isNotEmpty || cancelReminderIds.isNotEmpty,
  };
  factory RiyaResult.fromJson(
    Map<String, dynamic> json, {
    bool replayed = false,
  }) => RiyaResult(
    json['message'] as String,
    json['route'] as String,
    reminderIds: (json['reminderIds'] as List? ?? []).cast<int>(),
    cancelReminderIds: (json['cancelReminderIds'] as List? ?? []).cast<int>(),
    options: (json['options'] as List? ?? []).cast<String>(),
    entityType: json['entityType'] as String?,
    entityId: json['entityId'] as int?,
    learningCourseId: json['learningCourseId'] as String?,
    learningModuleId: json['learningModuleId'] as int?,
    learningLectureId: json['learningLectureId'] as int?,
    replayed: replayed,
  );
}

bool _validCalendarDate(String value) {
  if (DateTime.tryParse(value) == null) return false;
  final parts = RegExp(
    r'^([+-]?\d{4,6})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(?:[zZ]|[+-](\d{2}):?(\d{2}))?)?$',
  ).firstMatch(value);
  if (parts == null) return false;
  try {
    final year = int.parse(parts.group(1)!);
    final month = int.parse(parts.group(2)!);
    final day = int.parse(parts.group(3)!);
    final calendar = DateTime(year, month, day);
    if (calendar.year != year ||
        calendar.month != month ||
        calendar.day != day) {
      return false;
    }
    int number(int group) => int.tryParse(parts.group(group) ?? '0') ?? 0;
    return number(4) <= 23 &&
        number(5) <= 59 &&
        number(6) <= 59 &&
        number(7) <= 23 &&
        number(8) <= 59;
  } catch (_) {
    return false;
  }
}

class RiyaCommittedActionError implements Exception {
  const RiyaCommittedActionError(this.result);
  final RiyaResult result;
}

class RiyaExecutor {
  RiyaExecutor(
    this.db, {
    DateTime Function()? clock,
    this.external,
    this.verifyExternal,
    this.expectedWorkspaceRevision,
  }) : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final int? expectedWorkspaceRevision;
  void _checkWorkspace(int revision) {
    if (db.workspaceRevision != revision) {
      throw StateError(
        'The workspace changed. Choose the record again and confirm a fresh request',
      );
    }
  }

  Future<void> _checkWritableWorkspace(int revision) async {
    _checkWorkspace(revision);
    if ((await db.select(db.backupRestoreTable).get()).isNotEmpty) {
      throw StateError(
        'Finish workspace recovery before making another change',
      );
    }
  }

  final DateTime Function() clock;
  final Future<RiyaResult> Function(RiyaCommand)? external;
  final Future<RiyaResult?> Function(RiyaCommand)? verifyExternal;
  static final _externalWrites =
      Expando<Map<String, (String, Future<RiyaResult>)>>();
  static const _recoverableExternal = {
    'home.visibility',
    'learning.complete',
    'learning.pause',
    'learning.resume',
    ...riyaLearningWriteIds,
  };

  void validate(RiyaCommand command, {bool checkTime = true}) {
    final c = command.capability;
    final a = command.arguments;
    if (a.keys.any((k) => !c.schema.containsKey(k))) {
      throw ArgumentError('Unknown field');
    }
    for (final key in c.required) {
      if (!a.containsKey(key)) throw ArgumentError('Missing $key');
    }
    for (final entry in a.entries) {
      final v = entry.value;
      final valid = switch (c.schema[entry.key]!) {
        RiyaValue.text => v is String && v.trim().isNotEmpty && v.length <= 300,
        RiyaValue.longText =>
          v is String && v.trim().isNotEmpty && v.length <= 20000,
        RiyaValue.offset => v is int && v >= 0 && v <= 100000,
        RiyaValue.boolean => v is bool,
        RiyaValue.integer =>
          v is int && (v > 0 || (entry.key == 'estimatedMinutes' && v == -1)),
        RiyaValue.number => v is num && v.isFinite && v > 0,
        RiyaValue.nonnegativeNumber => v is num && v.isFinite && v >= 0,
        RiyaValue.date => v is String && _validCalendarDate(v),
        RiyaValue.textList =>
          v is List &&
              v.isNotEmpty &&
              v.length <= 10 &&
              v.every(
                (item) =>
                    item is String &&
                    item.trim().isNotEmpty &&
                    item.length <= 300,
              ),
        RiyaValue.integerList =>
          v is List &&
              v.isNotEmpty &&
              v.length <= 100 &&
              v.every((id) => id is int && id > 0),
      };
      if (!valid) throw ArgumentError('Invalid ${entry.key}');
    }
    if (checkTime &&
        (command.id == 'reminders.create' || command.id == 'reminders.edit')) {
      if (!DateTime.parse(a['at'] as String).isAfter(clock())) {
        throw ArgumentError('Choose a future time');
      }
    }
    if (command.id == 'focus.start' && (a['minutes'] as int) > 1440) {
      throw ArgumentError('Duration too long');
    }
    if (command.id == 'expenses.summary') {
      final from = DateTime.parse(a['from']);
      final to = DateTime.parse(a['to']);
      if (!to.isAfter(from) || to.difference(from).inDays > 366) {
        throw ArgumentError('Invalid period');
      }
    }
    if (command.id == 'navigation.open' &&
        !const [
          '/today',
          '/reminders',
          '/thought-wall',
          '/money',
          '/focus',
          '/learning',
          '/interview-prep',
          '/more',
          '/chai-break',
        ].contains(a['route'])) {
      throw ArgumentError('Unsupported destination');
    }
    if (command.id == 'help.feature' &&
        !featureGuides.containsKey(a['feature'])) {
      throw ArgumentError('Unknown feature');
    }
  }

  Future<RiyaResult> execute(
    RiyaCommand command, {
    required String requestId,
    bool approved = false,
  }) async {
    final revision = expectedWorkspaceRevision ?? db.workspaceRevision;
    _checkWorkspace(revision);
    final c = command.capability;
    if (c.write && !approved) throw StateError('Confirmation required');
    // Request IDs belong to a persisted user chat turn, not arbitrary retrieved text.
    if (requestId.isEmpty) throw ArgumentError('Request ID required');
    validate(command, checkTime: false);
    if (!c.write) {
      return _run(command);
    }
    if (c.id.startsWith('home.') || c.id.startsWith('learning.')) {
      if (!_recoverableExternal.contains(c.id)) {
        throw UnsupportedError(
          'This workspace action needs a recoverable domain executor',
        );
      }
      final sorted = Map<String, dynamic>.fromEntries(
        command.arguments.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      final payload = jsonEncode(sorted);
      final identity = '${c.id}:$payload';
      final running = _externalWrites[db] ??= {};
      final old = running[requestId];
      if (old != null) {
        if (old.$1 != identity) throw StateError('Request ID already used');
        return RiyaResult.fromJson((await old.$2).toJson(), replayed: true);
      }
      final work = _executeExternal(command, requestId, payload, revision);
      running[requestId] = (identity, work);
      try {
        return await work;
      } finally {
        running.remove(requestId);
      }
    }
    return db.transaction(() async {
      await _checkWritableWorkspace(revision);
      final old = await (db.select(
        db.aiCommandTable,
      )..where((r) => r.requestId.equals(requestId))).getSingleOrNull();
      final sorted = Map<String, dynamic>.fromEntries(
        command.arguments.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)),
      );
      final json = jsonEncode(sorted);
      if (old != null) {
        if (old.capability != c.id || old.argumentsJson != json) {
          throw StateError('Request ID already used');
        }
        return RiyaResult.fromJson(
          jsonDecode(old.resultJson) as Map<String, dynamic>,
          replayed: true,
        );
      }
      validate(command);
      final result = await _run(command);
      await db
          .into(db.aiCommandTable)
          .insert(
            AiCommandTableCompanion.insert(
              requestId: requestId,
              capability: c.id,
              argumentsJson: json,
              resultJson: jsonEncode(result.toJson()),
            ),
          );
      return result;
    });
  }

  /// Prepare a durable identity before stateful/prefs work. These domain
  /// adapters commit independently; they never publish inside a receipt TX.
  Future<RiyaResult> _executeExternal(
    RiyaCommand command,
    String requestId,
    String arguments,
    int revision,
  ) async {
    final old = await db.transaction(() async {
      await _checkWritableWorkspace(revision);
      final row = await (db.select(
        db.aiCommandTable,
      )..where((r) => r.requestId.equals(requestId))).getSingleOrNull();
      if (row != null) {
        if (row.capability != command.id || row.argumentsJson != arguments) {
          throw StateError('Request ID already used');
        }
        return row;
      }
      validate(command);
      await db
          .into(db.aiCommandTable)
          .insert(
            AiCommandTableCompanion.insert(
              requestId: requestId,
              capability: command.id,
              argumentsJson: arguments,
              resultJson: jsonEncode({'executionStatus': 'prepared'}),
            ),
          );
      return null;
    });
    _checkWorkspace(revision);
    RiyaResult result;
    if (old != null) {
      final saved = jsonDecode(old.resultJson) as Map<String, dynamic>;
      if (saved['executionStatus'] != 'prepared') {
        return RiyaResult.fromJson(saved, replayed: true);
      }
      // An interrupted action may already have happened. Verify current state;
      // never reapply an old request over a newer user change.
      final verified = await verifyExternal?.call(
        command.forExecution(requestId),
      );
      if (verified == null) {
        throw StateError(
          'This interrupted request needs a fresh confirmation; newer work was kept',
        );
      }
      result = verified;
    } else {
      result = await _run(command.forExecution(requestId));
    }
    try {
      final updated =
          await (db.update(
            db.aiCommandTable,
          )..where((r) => r.requestId.equals(requestId))).write(
            AiCommandTableCompanion(
              resultJson: Value(jsonEncode(result.toJson())),
            ),
          );
      if (updated != 1) throw StateError('Confirmation record missing');
    } catch (_) {
      throw RiyaCommittedActionError(result);
    }
    return result;
  }

  Future<RiyaResult> _run(RiyaCommand cmd) async {
    final a = cmd.arguments;
    final route = cmd.capability.route;
    if (riyaSessionCapabilities.any((c) => c.id == cmd.id)) {
      return RiyaSessionReads(db, clock).run(cmd);
    }
    final medicine = RiyaMedicineActions(db, clock);
    if (medicine.handles(cmd.id)) return medicine.run(cmd);
    final money = RiyaMoneyActions(db, clock);
    if (money.handles(cmd.id)) return money.run(cmd);
    final workspace = RiyaWorkspaceActions(db, clock, external: external);
    if (workspace.handles(cmd.id) ||
        riyaLearningCapabilities.any((c) => c.id == cmd.id)) {
      if (cmd.id.startsWith('learning.') && !workspace.handles(cmd.id)) {
        if (external == null) {
          throw StateError('This action needs the active workspace');
        }
        return external!(cmd);
      }
      return workspace.run(cmd);
    }
    final life = RiyaLifeActions(db, clock);
    if (life.handles(cmd.id)) return life.run(cmd);
    switch (cmd.id) {
      case 'tasks.today':
        return workspace.run(
          const RiyaCommand('tasks.list', {'scope': 'today'}),
        );
      case 'tasks.checklist':
        final parent = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: a['title'],
            plannedDate: Value(clock()),
          ),
        );
        final ids = <int>[];
        for (final item in (a['items'] as List).cast<String>()) {
          ids.add(
            await db.taskDao.insertTask(
              TaskTableCompanion.insert(
                title: item,
                plannedDate: Value(clock()),
                parentTaskId: Value(parent),
              ),
            ),
          );
        }
        for (final id in ids) {
          if ((await db.taskDao.getTaskById(id))?.parentTaskId != parent) {
            throw StateError('Checklist verification failed');
          }
        }
        return RiyaResult(
          'Created “${a['title']}” with ${ids.length} checklist steps in Today.',
          route,
        );
      case 'reminders.list':
        final now = clock();
        final scope = a['scope'] as String? ?? 'today';
        if (!{'today', 'tomorrow', 'date', 'all', 'overdue'}.contains(scope)) {
          throw ArgumentError('Choose a reminder period');
        }
        final from = a['from'] == null
            ? DateTime(
                now.year,
                now.month,
                now.day + (scope == 'tomorrow' ? 1 : 0),
              )
            : DateTime.parse(a['from']).toLocal();
        final to = a['to'] == null
            ? DateTime(from.year, from.month, from.day + 1)
            : DateTime.parse(a['to']).toLocal();
        if (!to.isAfter(from)) throw ArgumentError('Choose a valid period');
        Expression<bool> filter = db.reminderTable.isActive.equals(true);
        if (scope == 'overdue') {
          filter &= db.reminderTable.scheduledAt.isSmallerThanValue(now);
        } else if (scope != 'all') {
          filter &=
              db.reminderTable.scheduledAt.isBiggerOrEqualValue(from) &
              db.reminderTable.scheduledAt.isSmallerThanValue(to) &
              db.reminderTable.scheduledAt.isBiggerOrEqualValue(now);
        }
        final count = db.reminderTable.id.count();
        final countQuery = db.selectOnly(db.reminderTable)
          ..addColumns([count])
          ..where(filter);
        final total = (await countQuery.getSingle()).read(count) ?? 0;
        final rows =
            await (db.select(db.reminderTable)
                  ..where((_) => filter)
                  ..orderBy([
                    (r) => OrderingTerm.asc(r.scheduledAt),
                    (r) => OrderingTerm.asc(r.id),
                  ])
                  ..limit(3, offset: a['offset'] as int? ?? 0))
                .get();
        final overdueCount = db.reminderTable.id.count();
        final overdueQuery = db.selectOnly(db.reminderTable)
          ..addColumns([overdueCount])
          ..where(
            db.reminderTable.isActive.equals(true) &
                db.reminderTable.scheduledAt.isSmallerThanValue(now),
          );
        final overdue =
            (await overdueQuery.getSingle()).read(overdueCount) ?? 0;
        final label = scope == 'date'
            ? '${from.day}/${from.month}/${from.year}'
            : '${scope[0].toUpperCase()}${scope.substring(1)}';
        final message = rows.isEmpty
            ? 'No reminders for $label.'
            : '$label: $total reminder${total == 1 ? '' : 's'}.\n${rows.map((r) => '#${r.id} ${r.title.length > 140 ? '${r.title.substring(0, 137)}…' : r.title} · ${r.scheduledAt.hour.toString().padLeft(2, '0')}:${r.scheduledAt.minute.toString().padLeft(2, '0')}').join('\n')}';
        return RiyaResult(
          '$message${overdue > 0 && scope != 'overdue' ? '\n$overdue overdue reminder${overdue == 1 ? '' : 's'} available separately.' : ''}',
          route,
          options: [
            'Reminders tomorrow',
            'Choose reminder date',
            'All reminders',
            if (overdue > 0) 'Overdue reminders',
            if ((a['offset'] as int? ?? 0) + rows.length < total)
              'More reminders',
          ],
        );
      case 'thoughts.search':
        final query = (a['query'] as String).toLowerCase();
        // Bound SQLite instr avoids wildcard interpretation; retrieved content stays inert.
        final rows = await db
            .customSelect(
              'SELECT id, content, is_archived FROM thoughts WHERE instr(lower(content), ?) > 0 ORDER BY created_at DESC, id DESC LIMIT 4',
              variables: [Variable(query)],
              readsFrom: {db.thoughtTable},
            )
            .get();
        return RiyaResult(
          rows.isEmpty
              ? 'No thoughts match “$query”.'
              : rows
                    .take(3)
                    .map(
                      (r) =>
                          '#${r.read<int>('id')} ${r.read<int>('is_archived') == 1 ? '[Archived] ' : ''}${r.read<String>('content').length > 180 ? '${r.read<String>('content').substring(0, 177)}…' : r.read<String>('content')}',
                    )
                    .join('\n\n'),
          route,
        );
      case 'expenses.summary':
        final from = DateTime.parse(a['from']).toLocal();
        final to = DateTime.parse(a['to']).toLocal();
        final rows =
            await (db.select(db.financeTransactionTable)..where(
                  (r) =>
                      r.type.equals('expense') &
                      r.date.isBiggerOrEqualValue(from) &
                      r.date.isSmallerThanValue(to),
                ))
                .get();
        final total = rows.fold<double>(0, (sum, r) => sum + r.amount);
        return RiyaResult(
          'Spent ₹${total.toStringAsFixed(2)} across ${rows.length} expenses, ${from.month}/${from.day}–${to.month}/${to.day} (end exclusive).',
          route,
        );
      case 'reminders.create':
      case 'reminders.edit':
        final at = DateTime.parse(a['at']).toLocal();
        int id;
        if (cmd.id == 'reminders.create') {
          id = await db.reminderDao.insertReminder(
            ReminderTableCompanion.insert(
              title: a['title'],
              scheduledAt: at,
              alertSyncPending: const Value(true),
            ),
          );
        } else {
          id = a['id'];
          final old = await db.reminderDao.getReminderById(id);
          if (old == null) throw StateError('Reminder no longer exists');
          await db.reminderDao.updateReminder(
            old
                .toCompanion(true)
                .copyWith(
                  scheduledAt: Value(at),
                  isActive: const Value(true),
                  alertSyncPending: const Value(true),
                ),
          );
        }
        final saved = await db.reminderDao.getReminderById(id);
        if (saved == null || saved.scheduledAt != at) {
          throw StateError('Reminder verification failed');
        }
        return RiyaResult(
          'Saved reminder “${saved.title}” for $at. Device alert scheduling has not been verified.',
          route,
          reminderIds: [id],
        );
      case 'focus.start':
        if (await db.timeSessionDao.getActiveFocusSession() != null) {
          throw StateError('A Focus session is already active');
        }
        final minutes = a['minutes'] as int;
        final title = a['title'] as String? ?? '$minutes-minute Focus';
        await db.timeSessionDao.ensureDefaultCategories();
        final category = await db.timeSessionDao.getCategoryByName('Study');
        if (category == null) throw StateError('Study category unavailable');
        final taskId = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: title,
            plannedDate: Value(clock()),
            estimatedMinutes: Value(minutes),
          ),
        );
        final sessionId = await db.timeSessionDao.startSession(
          label: title,
          categoryId: category.id,
          linkedTaskId: taskId,
        );
        final saved = await db.timeSessionDao.getActiveFocusSession();
        if (saved?.id != sessionId || saved?.status != 'running') {
          throw StateError('Timer verification failed');
        }
        return RiyaResult(
          'Started a $minutes-minute Focus target. Pause or finish in Focus; it uses the existing stopwatch and does not stop automatically.',
          route,
        );
      case 'focus.pause':
      case 'focus.resume':
        final session = await db.timeSessionDao.getActiveFocusSession();
        if (session == null || session.id != a['id']) {
          throw StateError('The selected Focus session is no longer active');
        }
        final pausing = cmd.id == 'focus.pause';
        if (pausing) {
          await db.timeSessionDao.pauseSession(session.id);
        } else {
          await db.timeSessionDao.resumeSession(session.id);
        }
        final saved = await db.timeSessionDao.getActiveFocusSession();
        if (saved?.id != session.id ||
            saved?.status != (pausing ? 'paused' : 'running')) {
          throw StateError('Focus state could not be verified');
        }
        return RiyaResult(
          '${pausing ? 'Paused' : 'Resumed'} Focus “${session.label}”.',
          route,
        );
      case 'help.feature':
        return RiyaResult(
          featureGuides[a['feature']]!,
          _featureRoute(a['feature']),
        );
      case 'navigation.open':
        return RiyaResult('Opening the requested screen.', a['route']);
      default:
        final type = switch (cmd.id) {
          'tasks.create' => AiActionType.taskCreated,
          'tasks.reschedule' => AiActionType.scheduleRearranged,
          'expenses.create' => AiActionType.expenseLogged,
          'hydration.log' => AiActionType.waterLogged,
          _ => throw UnsupportedError('Unsupported action'),
        };
        final result = await AiActionExecution(db).execute(
          AiProposedAction(
            type: type,
            title: cmd.capability.description,
            summary: cmd.preview,
            payload: a,
          ),
        );
        return RiyaResult(
          result.message,
          route,
          reminderIds: result.reminders.map((r) => r.id).toList(),
        );
    }
  }

  String _featureRoute(String feature) => switch (feature) {
    'Thought Wall' => '/thought-wall',
    'Focus Timer' => '/focus',
    'Money' => '/money',
    'Reminders & Alerts' => '/reminders',
    'Interview Prep' => '/interview-prep',
    _ => '/more',
  };
}
