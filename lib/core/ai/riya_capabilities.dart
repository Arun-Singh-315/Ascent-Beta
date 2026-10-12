import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../shared/widgets/feature_guide.dart';
import 'ai_action_execution.dart';
import 'ai_service.dart';

enum RiyaValue { text, integer, number, date, integerList, textList }

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
    'Read upcoming reminders',
    '/reminders',
    {},
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
  const RiyaCommand(this.id, this.arguments);
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
      'id': 'Reminder number',
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
  });
  final String message, route;
  final List<int> reminderIds;
  final bool replayed;
  Map<String, dynamic> toJson() => {
    'message': message,
    'route': route,
    'reminderIds': reminderIds,
  };
  factory RiyaResult.fromJson(
    Map<String, dynamic> json, {
    bool replayed = false,
  }) => RiyaResult(
    json['message'] as String,
    json['route'] as String,
    reminderIds: (json['reminderIds'] as List).cast<int>(),
    replayed: replayed,
  );
}

class RiyaExecutor {
  RiyaExecutor(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

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
        RiyaValue.integer =>
          v is int && (v > 0 || (entry.key == 'estimatedMinutes' && v == -1)),
        RiyaValue.number => v is num && v.isFinite && v > 0,
        RiyaValue.date => v is String && DateTime.tryParse(v) != null,
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
          v is List && v.isNotEmpty && v.every((id) => id is int && id > 0),
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
    final c = command.capability;
    if (c.write && !approved) throw StateError('Confirmation required');
    // Request IDs belong to a persisted user chat turn, not arbitrary retrieved text.
    if (requestId.isEmpty) throw ArgumentError('Request ID required');
    validate(command, checkTime: false);
    if (!c.write) {
      return _run(command);
    }
    return db.transaction(() async {
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

  Future<RiyaResult> _run(RiyaCommand cmd) async {
    final a = cmd.arguments;
    final route = cmd.capability.route;
    switch (cmd.id) {
      case 'tasks.today':
        final rows = await db.taskDao.watchTasksByDate(clock()).first;
        return RiyaResult(
          rows.isEmpty
              ? 'Nothing planned today.'
              : rows
                    .map(
                      (t) =>
                          '${t.actualCompletedDate == null ? '•' : '✓'} ${t.title}',
                    )
                    .join('\n'),
          route,
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
        final rows = await db.reminderDao.watchUpcomingReminders().first;
        return RiyaResult(
          rows.isEmpty
              ? 'No upcoming reminders.'
              : rows
                    .map((r) => '#${r.id} ${r.title} · ${r.scheduledAt}')
                    .join('\n'),
          route,
        );
      case 'thoughts.search':
        final query = (a['query'] as String).toLowerCase();
        // Bound SQLite instr avoids wildcard interpretation; retrieved content stays inert.
        final rows = await db
            .customSelect(
              'SELECT id, content, is_archived FROM thoughts WHERE instr(lower(content), ?) > 0 ORDER BY created_at DESC LIMIT 20',
              variables: [Variable(query)],
              readsFrom: {db.thoughtTable},
            )
            .get();
        return RiyaResult(
          rows.isEmpty
              ? 'No thoughts match “$query”.'
              : rows
                    .map(
                      (r) =>
                          '${r.read<int>('is_archived') == 1 ? '[Archived] ' : ''}${r.read<String>('content')}',
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
            ReminderTableCompanion.insert(title: a['title'], scheduledAt: at),
          );
        } else {
          id = a['id'];
          final old = await db.reminderDao.getReminderById(id);
          if (old == null) throw StateError('Reminder no longer exists');
          await db.reminderDao.updateReminder(
            ReminderTableCompanion(
              id: Value(id),
              title: Value(old.title),
              scheduledAt: Value(at),
              isActive: const Value(true),
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
