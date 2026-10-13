import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'riya_capabilities.dart';
import 'riya_intents.dart';
import 'riya_life_intents.dart';
import 'riya_learning_intents.dart';
import 'riya_session_reads.dart';

/// Generic verbs + real entities, rather than a phrase for every test case.
class RiyaWorkspaceIntents {
  RiyaWorkspaceIntents(this.db, this.clock);
  final AppDatabase db;
  final DateTime Function() clock;
  late final _life = RiyaLifeIntents(clock);
  late final _learning = RiyaLearningIntents(db);
  late final _sessions = RiyaSessionIntents(clock);
  String? _listDomain, _listScope;
  int _offset = 0;
  String? _from, _to;
  String? _selectedType;
  int? _selectedId;
  String? _pendingIdType;
  RiyaCommand? _pendingIdCommand;
  Set<int> _choices = {};
  String? _suggestion;
  int _reflection = 0;
  bool _chooseReminderDate = false;
  Map<String, dynamic>? _pendingConversion;
  DateTime? _conversionDay;

  void remember(String type, int id) {
    if ({'savings', 'budgets', 'hydration'}.contains(type)) {
      _life.remember(type, id);
      _selectedType = null;
      _selectedId = null;
      return;
    }
    _life.clearSelection();
    _selectedType = type;
    _selectedId = id;
  }

  void cancel() {
    _life.cancel();
    _learning.cancel();
    _sessions.cancel();
    _pendingIdCommand = null;
    _pendingIdType = null;
    _choices = {};
    _listDomain = null;
    _listScope = null;
    _offset = 0;
    _chooseReminderDate = false;
    _pendingConversion = null;
    _suggestion = null;
    _selectedId = null;
    _selectedType = null;
  }

  void newCommand() {
    _pendingIdCommand = null;
    _pendingIdType = null;
    _choices = {};
    _chooseReminderDate = false;
    _pendingConversion = null;
  }

  Future<RiyaResolution?> resolve(String prompt) async {
    final lower = prompt.trim().toLowerCase();
    final session = _sessions.resolve(prompt);
    if (session != null) {
      newCommand();
      _listDomain = null;
      _listScope = null;
      _offset = 0;
      _life.clearSelection();
      _selectedType = null;
      _selectedId = null;
      return session;
    }
    // A different request ends the history follow-up context. Bare dates must
    // belong to the most recent list or pending action.
    _sessions.cancel();
    final learning = await _learning.resolve(prompt);
    if (learning != null) {
      newCommand();
      _listDomain = null;
      _listScope = null;
      _offset = 0;
      _life.clearSelection();
      _selectedType = null;
      _selectedId = null;
      return learning;
    }
    final life = _life.resolve(prompt);
    if (life != null) {
      newCommand();
      _listDomain = null;
      _listScope = null;
      _offset = 0;
      _selectedType = null;
      _selectedId = null;
      return life;
    }
    if (_pendingConversion != null) {
      if (lower == 'today' ||
          lower == 'tomorrow' ||
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(lower)) {
        final now = clock();
        final day = lower == 'today' || lower == 'tomorrow'
            ? DateTime(
                now.year,
                now.month,
                now.day + (lower == 'tomorrow' ? 1 : 0),
              )
            : DateTime.tryParse(lower);
        if (day == null ||
            (lower != 'today' &&
                lower != 'tomorrow' &&
                '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}' !=
                    lower)) {
          return const RiyaResolution(
            message: 'Choose a real date using YYYY-MM-DD.',
          );
        }
        _conversionDay = day;
        return RiyaResolution(
          message: 'What time on ${day.day}/${day.month}? For example, 7 PM.',
        );
      }
      final at =
          RegExp(r'^(?:at\s+)?\d{1,2}(?::\d{2})?\s*(?:am|pm)?$').hasMatch(lower)
          ? _conversionTime(lower)
          : null;
      if (at != null) {
        if (!at.isAfter(clock())) {
          return const RiyaResolution(
            message: 'Choose a future time, or Tomorrow.',
          );
        }
        final args = {..._pendingConversion!, 'at': at.toIso8601String()};
        _pendingConversion = null;
        return RiyaResolution(command: RiyaCommand('thoughts.convert', args));
      }
    }
    if (lower == 'save this thought' && _suggestion != null) {
      final text = _suggestion!;
      _suggestion = null;
      return RiyaResolution(
        command: RiyaCommand('thoughts.create', {'content': text}),
      );
    }
    if (RegExp(
          r'^(?:give|suggest|share|another).*\b(?:thought|reflection)\b',
        ).hasMatch(lower) ||
        lower == 'another reflection') {
      _life.clearSelection();
      _selectedType = null;
      _selectedId = null;
      const ideas = [
        'Give the next small step your attention. The whole day does not need solving at once.',
        'A pause can be part of progress. What would make your next hour kinder?',
        'Write the idea before judging it. You can decide what to do with it later.',
        'Notice one thing that worked today, even if the rest is unfinished.',
        'Choose a useful next step that fits the energy you have today.',
      ];
      _suggestion = ideas[(clock().day + _reflection++) % ideas.length];
      return RiyaResolution(
        message:
            'A reflection suggestion, separate from your saved notes:\n$_suggestion',
        options: ['Save this thought', 'Another reflection'],
      );
    }
    if (RegExp(
      r'^(add|save|create|write|edit|change|pin|unpin|archive|restore|delete|remove|merge|convert|show|read|complete|finish|snooze|stop|resume|pause)\b',
    ).hasMatch(lower)) {
      _life.clearSelection();
      newCommand();
    }
    if (_pendingIdCommand != null) {
      final id = int.tryParse(
        RegExp(r'^#?(\d+)$').firstMatch(lower)?.group(1) ?? '',
      );
      if (id == null || !_choices.contains(id)) {
        return const RiyaResolution(
          message: 'Choose one of the record numbers shown, or Cancel.',
        );
      }
      final command = _pendingIdCommand!;
      _selectedType = _pendingIdType;
      _selectedId = id;
      newCommand();
      final args = {...command.arguments};
      if (command.id.startsWith('thoughts.') &&
          {
            'thoughts.archive',
            'thoughts.delete',
            'thoughts.merge',
            'thoughts.convert',
          }.contains(command.id)) {
        args['noteIds'] = [id];
      } else {
        args['id'] = id;
      }
      return RiyaResolution(command: RiyaCommand(command.id, args));
    }
    if (lower == 'choose reminder date') {
      _chooseReminderDate = true;
      return const RiyaResolution(
        message: 'Which date? Use YYYY-MM-DD, Today or Tomorrow.',
        options: ['Today', 'Tomorrow'],
      );
    }
    if (_chooseReminderDate && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(lower)) {
      final date = DateTime.tryParse(lower);
      if (date == null ||
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}' !=
              lower) {
        return const RiyaResolution(
          message: 'Use a real calendar date, such as 2026-10-20.',
        );
      }
      _chooseReminderDate = false;
      _listDomain = 'reminders';
      _listScope = 'date';
      _from = date.toIso8601String();
      _to = DateTime(date.year, date.month, date.day + 1).toIso8601String();
      _offset = 0;
      return RiyaResolution(
        command: RiyaCommand('reminders.list', {
          'scope': 'date',
          'from': date.toIso8601String(),
          'to': DateTime(date.year, date.month, date.day + 1).toIso8601String(),
        }),
      );
    }
    if ((lower == 'today' || lower == 'tomorrow') &&
        (_listDomain != null || _chooseReminderDate)) {
      _listDomain ??= 'reminders';
      _listScope = lower;
      _offset = 0;
      _chooseReminderDate = false;
      return RiyaResolution(
        command: RiyaCommand('$_listDomain.list', {'scope': lower}),
      );
    }
    final listing = RegExp(
      r'^(?:show\s+|list\s+|what are\s+|dikhao\s+)?(?:my\s+)?(?:(recent|pinned|archived|all|overdue)\s+)?(thoughts|notes|tasks|todos|reminders|expenses)(?:\s+(today|tomorrow|all|overdue))?[?.!]*$',
    ).firstMatch(lower);
    if (listing != null) {
      final domain = switch (listing.group(2)) {
        'thoughts' || 'notes' => 'thoughts',
        'tasks' || 'todos' => 'tasks',
        'reminders' => 'reminders',
        _ => 'expenses',
      };
      final scope =
          listing.group(3) ??
          listing.group(1) ??
          (domain == 'thoughts' ? 'recent' : 'today');
      _selectedId = null;
      _selectedType = null;
      _listDomain = domain;
      _listScope = scope;
      _offset = 0;
      _chooseReminderDate = false;
      return RiyaResolution(
        command: RiyaCommand('$domain.list', {
          if (domain != 'expenses') 'scope': scope,
        }),
      );
    }
    final more = RegExp(
      r'^more\s+(thoughts|notes|tasks|reminders|expenses)$',
    ).firstMatch(lower);
    if (more != null) {
      final domain = more.group(1) == 'notes' ? 'thoughts' : more.group(1)!;
      if (_listDomain != domain) {
        return const RiyaResolution(
          message: 'Choose a list first so I know which results to continue.',
        );
      }
      _offset += 3;
      return RiyaResolution(
        command: RiyaCommand('$domain.list', {
          'offset': _offset,
          if (domain != 'expenses') 'scope': _listScope ?? 'today',
          if (domain == 'reminders' && _listScope == 'date' && _from != null)
            'from': _from,
          if (domain == 'reminders' && _listScope == 'date' && _to != null)
            'to': _to,
        }),
      );
    }
    if (RegExp(
      r'^(?:show|read|what).*\b(?:water|hydration)\b',
    ).hasMatch(lower)) {
      return const RiyaResolution(command: RiyaCommand('hydration.read', {}));
    }
    if (RegExp(
      r'^(?:show|list).*\b(?:courses|learning progress)\b',
    ).hasMatch(lower)) {
      return const RiyaResolution(command: RiyaCommand('learning.list', {}));
    }
    if (lower == 'pause learning' || lower == 'pause lecture') {
      return const RiyaResolution(command: RiyaCommand('learning.pause', {}));
    }
    if (lower == 'resume learning' || lower == 'resume lecture') {
      return const RiyaResolution(command: RiyaCommand('learning.resume', {}));
    }
    if (lower == 'show home layout') {
      return const RiyaResolution(command: RiyaCommand('home.layout', {}));
    }
    final visibility = RegExp(
      r'^(show|hide)\s+(today|learning|life|mind|money|reminders|streak|checkin)\s+(?:on|from)\s+home$',
    ).firstMatch(lower);
    if (visibility != null) {
      return RiyaResolution(
        command: RiyaCommand('home.visibility', {
          'section': visibility.group(2),
          'visible': visibility.group(1) == 'show',
        }),
      );
    }
    final create = RegExp(
      r'^(?:save|add|create|write|likho)\s+(?:(?:a|my)\s+)?(?:thought|note|idea)(?:\s*[:\-]\s*|\s+)(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(prompt.trim());
    if (create != null) {
      return RiyaResolution(
        command: RiyaCommand('thoughts.create', {
          'content': create.group(1)!.trim(),
        }),
      );
    }
    final edit = RegExp(
      r'^(?:edit|update|change|badlo)\s+(thought|note|task|todo|expense|that)\s*(.*?)\s+(?:to|as|:)\s+(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(prompt.trim());
    if (edit != null) {
      final type = edit.group(1)!.toLowerCase() == 'that'
          ? _selectedType
          : _entityType(edit.group(1)!.toLowerCase());
      if (type == null) {
        return const RiyaResolution(
          message: 'Which record should I edit? Include its type and number.',
        );
      }
      final content = edit.group(3)!.trim();
      final args = <String, dynamic>{
        type == 'thoughts'
            ? 'content'
            : type == 'expenses' && double.tryParse(content) != null
            ? 'amount'
            : 'title': type == 'expenses' && double.tryParse(content) != null
            ? double.parse(content)
            : content,
      };
      return _target(
        type,
        edit.group(1)!.toLowerCase() == 'that' && _selectedId != null
            ? '#$_selectedId'
            : edit.group(2)!,
        RiyaCommand('$type.edit', args),
      );
    }
    final reading = RegExp(
      r'^(?:read|open)\s+(?:thought|note)\s+(.+)$',
    ).firstMatch(lower);
    if (reading != null) {
      return _target(
        'thoughts',
        reading.group(1)!,
        const RiyaCommand('thoughts.read', {}),
      );
    }
    final conversion = RegExp(
      r'^(?:convert|turn)\s+(?:thoughts?|notes?)\s+(.+?)\s+(?:to|into)\s+(todo|reminder|both)(.*)$',
    ).firstMatch(lower);
    if (conversion != null) {
      final reference = conversion.group(1)!;
      final ids = RegExp(r'#(\d+)')
          .allMatches(reference)
          .map((m) => int.parse(m.group(1)!))
          .toSet()
          .toList();
      if (ids.isEmpty) {
        return const RiyaResolution(
          message:
              'Include the note numbers, such as “Convert notes #1 and #2 to Both”.',
        );
      }
      final args = <String, dynamic>{
        'noteIds': ids,
        'mode': conversion.group(2),
        'grouped': conversion.group(3)!.contains('group'),
      };
      if (conversion.group(2) == 'todo') {
        return RiyaResolution(command: RiyaCommand('thoughts.convert', args));
      }
      final now = clock();
      _conversionDay = DateTime(
        now.year,
        now.month,
        now.day + (conversion.group(3)!.contains('tomorrow') ? 1 : 0),
      );
      final at = _conversionTime(conversion.group(3)!);
      if (at != null && at.isAfter(now)) {
        return RiyaResolution(
          command: RiyaCommand('thoughts.convert', {
            ...args,
            'at': at.toIso8601String(),
          }),
        );
      }
      _pendingConversion = args;
      return RiyaResolution(
        message: 'Today by default. What time should I remind you?',
        options: ['Tomorrow', 'Today', 'Cancel'],
      );
    }
    if (lower == 'stop focus' || lower == 'finish focus session') {
      return const RiyaResolution(command: RiyaCommand('focus.stop', {}));
    }
    final lectureCompletion = RegExp(
      r'^(?:complete|finish) lecture #?(\d+) in course (.+)$',
    ).firstMatch(prompt.trim());
    if (lectureCompletion != null) {
      return RiyaResolution(
        command: RiyaCommand('learning.complete', {
          'lectureId': int.parse(lectureCompletion.group(1)!),
          'courseId': lectureCompletion.group(2)!.trim(),
        }),
      );
    }
    final merged = RegExp(
      r'^(?:merge|combine)\s+(?:thoughts|notes)\s+(.+)$',
    ).firstMatch(lower);
    if (merged != null) {
      final ids = RegExp(r'#?(\d+)')
          .allMatches(merged.group(1)!)
          .map((m) => int.parse(m.group(1)!))
          .toSet()
          .toList();
      if (ids.length < 2) {
        return const RiyaResolution(
          message:
              'Which notes? Include at least two numbers, such as “Merge notes #1 and #2”.',
        );
      }
      return RiyaResolution(
        command: RiyaCommand('thoughts.merge', {
          'noteIds': ids,
          'archiveSources': lower.contains('archive originals'),
        }),
      );
    }
    if (RegExp(
      r'^(?:delete|remove) all completed (?:thoughts|notes)$',
    ).hasMatch(lower)) {
      final rows =
          await (db.select(db.thoughtTable)
                ..where((t) => t.isCompleted.equals(true))
                ..limit(101))
              .get();
      if (rows.isEmpty) {
        return const RiyaResolution(
          message: 'There are no completed notes to delete.',
        );
      }
      if (rows.length > 100) {
        return const RiyaResolution(
          message:
              'There are more than 100 completed notes. Select a smaller batch in Mind Space.',
        );
      }
      return RiyaResolution(
        command: RiyaCommand('thoughts.delete', {
          'noteIds': rows.map((n) => n.id).toList(),
        }),
        message: 'Review deletion of ${rows.length} completed notes.',
      );
    }
    final action = RegExp(
      r'^(pin|unpin|archive|restore|delete|remove|complete|finish|snooze)\s+(?:my\s+)?(thought|note|task|todo|reminder|expense)\s*(.*)$',
    ).firstMatch(lower);
    if (action != null) {
      final type = _entityType(action.group(2)!);
      final verb = action.group(1)!;
      final suffix = action.group(3)!;
      if (type == 'thoughts') {
        if (verb == 'pin' || verb == 'unpin') {
          return _target(
            type,
            suffix,
            RiyaCommand('thoughts.pin', {'pinned': verb == 'pin'}),
          );
        }
        if (verb == 'archive' || verb == 'restore') {
          return _target(
            type,
            suffix,
            RiyaCommand('thoughts.archive', {'archived': verb == 'archive'}),
          );
        }
        if (verb == 'delete' || verb == 'remove') {
          return _target(
            type,
            suffix,
            const RiyaCommand('thoughts.delete', {}),
          );
        }
      }
      if (type == 'tasks' &&
          {'complete', 'finish', 'delete', 'remove'}.contains(verb)) {
        return _target(
          type,
          suffix,
          RiyaCommand(
            'tasks.${verb == 'complete' || verb == 'finish' ? 'complete' : 'delete'}',
            {},
          ),
        );
      }
      if (type == 'reminders' &&
          {'complete', 'finish', 'delete', 'remove', 'snooze'}.contains(verb)) {
        return _target(
          type,
          suffix,
          RiyaCommand(
            'reminders.${verb == 'complete' || verb == 'finish'
                ? 'done'
                : verb == 'snooze'
                ? 'snooze'
                : 'delete'}',
            {
              if (verb == 'snooze')
                'minutes':
                    int.tryParse(
                      RegExp(
                            r'(\d+)\s*(?:minutes|min)',
                          ).firstMatch(lower)?.group(1) ??
                          '',
                    ) ??
                    10,
            },
          ),
        );
      }
      if (type == 'expenses' && {'delete', 'remove'}.contains(verb)) {
        return _target(type, suffix, const RiyaCommand('expenses.delete', {}));
      }
    }
    return null;
  }

  DateTime? _conversionTime(String text) {
    final match = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\b',
    ).firstMatch(text.trim());
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final meridiem = match.group(3);
    if (minute > 59 || (meridiem == null ? hour > 23 : hour < 1 || hour > 12)) {
      return null;
    }
    if (meridiem != null) hour = hour % 12 + (meridiem == 'pm' ? 12 : 0);
    final day = _conversionDay ?? clock();
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  String _entityType(String type) => switch (type) {
    'thought' || 'note' => 'thoughts',
    'task' || 'todo' => 'tasks',
    'reminder' => 'reminders',
    _ => 'expenses',
  };
  Future<RiyaResolution> _target(
    String type,
    String reference,
    RiyaCommand command,
  ) async {
    final trimmed = reference.trim();
    final explicit = int.tryParse(
      (RegExp(
                    r'^#(\d+)(?:\s+for\s+\d+\s*(?:minutes|min))?$',
                  ).firstMatch(trimmed) ??
                  RegExp(r'^(\d+)$').firstMatch(trimmed))
              ?.group(1) ??
          '',
    );
    final query = explicit == null
        ? trimmed.replaceAll(RegExp(r'\b(?:my|please)\b'), '').trim()
        : '';
    Expression<bool> containsLiteral(Expression<String> text) =>
        FunctionCallExpression<int>('instr', [
          text,
          Variable<String>(query),
        ]).isBiggerThanValue(0);
    List<({int id, String title})> rows;
    switch (type) {
      case 'thoughts':
        rows =
            (await (db.select(db.thoughtTable)
                      ..where(
                        (n) => explicit != null
                            ? n.id.equals(explicit)
                            : containsLiteral(n.content.lower()),
                      )
                      ..limit(4))
                    .get())
                .map((n) => (id: n.id, title: n.content))
                .toList();
      case 'tasks':
        rows =
            (await (db.select(db.taskTable)
                      ..where(
                        (n) => explicit != null
                            ? n.id.equals(explicit)
                            : containsLiteral(n.title.lower()),
                      )
                      ..limit(4))
                    .get())
                .map((n) => (id: n.id, title: n.title))
                .toList();
      case 'reminders':
        rows =
            (await (db.select(db.reminderTable)
                      ..where(
                        (n) => explicit != null
                            ? n.id.equals(explicit)
                            : containsLiteral(n.title.lower()),
                      )
                      ..limit(4))
                    .get())
                .map((n) => (id: n.id, title: n.title))
                .toList();
      default:
        rows =
            (await (db.select(db.financeTransactionTable)
                      ..where(
                        (n) =>
                            n.type.equals('expense') &
                            (explicit != null
                                ? n.id.equals(explicit)
                                : containsLiteral(n.title.lower())),
                      )
                      ..limit(4))
                    .get())
                .map((n) => (id: n.id, title: n.title))
                .toList();
    }
    if (rows.isEmpty) {
      return RiyaResolution(
        message:
            'I could not find that ${type == 'thoughts' ? 'note' : type.substring(0, type.length - 1)}.',
      );
    }
    if (rows.length != 1 || (explicit == null && query.isEmpty)) {
      _pendingIdCommand = command;
      _pendingIdType = type;
      _choices = rows.map((r) => r.id).toSet();
      return RiyaResolution(
        message: 'Which record? Choose its number.',
        options: rows
            .map(
              (r) =>
                  '#${r.id} ${r.title.length > 70 ? '${r.title.substring(0, 67)}…' : r.title}',
            )
            .toList(),
      );
    }
    _selectedType = type;
    _selectedId = rows.single.id;
    final args = {...command.arguments};
    if (type == 'thoughts' &&
        {'thoughts.archive', 'thoughts.delete'}.contains(command.id)) {
      args['noteIds'] = [rows.single.id];
    } else {
      args['id'] = rows.single.id;
    }
    return RiyaResolution(command: RiyaCommand(command.id, args));
  }
}
