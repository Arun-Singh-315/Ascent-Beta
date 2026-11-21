import 'ai_service.dart';
import '../database/app_database.dart';
import 'riya_capabilities.dart';
import 'riya_intents.dart';

const riyaPromiseCapabilities = <RiyaCapability>[];

class RiyaPromiseActions {
  RiyaPromiseActions(this.db, this.clock);
  final AppDatabase db;
  final DateTime Function() clock;

  Future<RiyaResult> run(RiyaCommand command) async {
    return const RiyaResult(
      'Commitments & Promises are coming soon to Ascent!',
      '/home',
    );
  }
}

/// Small, explicit conversational state. Saved record text is never parsed as
/// an instruction; only the next user turn can fill a pending field.
class RiyaProductivityIntents {
  RiyaProductivityIntents(this.db, this.clock);
  final AppDatabase db;
  final DateTime Function() clock;
  String? _createType, _pendingVerb, _pendingType;
  int? _pendingId;
  String? _selectedType;
  int? _selectedId;
  List<Map<String, dynamic>> _records = [];
  int _offset = 0;
  String? _promiseTitle;
  String? _promiseTarget;
  int _promiseStep = 0;

  Map<String, dynamic> get snapshot => {
    'create': _createType,
    'verb': _pendingVerb,
    'type': _pendingType,
    'id': _pendingId,
    'selectedType': _selectedType,
    'selectedId': _selectedId,
    'records': _records,
    'offset': _offset,
    'promiseTitle': _promiseTitle,
    'promiseTarget': _promiseTarget,
    'promiseStep': _promiseStep,
  };
  void restore(Map<String, dynamic> s) {
    _createType = s['create'] as String?;
    _pendingVerb = s['verb'] as String?;
    _pendingType = s['type'] as String?;
    _pendingId = s['id'] as int?;
    _selectedType = s['selectedType'] as String?;
    _selectedId = s['selectedId'] as int?;
    _records = (s['records'] as List? ?? [])
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    _offset = s['offset'] as int? ?? 0;
    _promiseTitle = s['promiseTitle'] as String?;
    _promiseTarget = s['promiseTarget'] as String?;
    _promiseStep = s['promiseStep'] as int? ?? 0;
  }

  void cancel() {
    _createType = null;
    _pendingVerb = null;
    _pendingType = null;
    _pendingId = null;
    _selectedType = null;
    _selectedId = null;
    _records = [];
    _offset = 0;
    _promiseTitle = null;
    _promiseTarget = null;
    _promiseStep = 0;
  }

  void remember(RiyaResult result) {
    if (result.records.isNotEmpty) {
      _records = result.records;
      _selectedId = null;
      _selectedType = null;
    } else if (result.entityId != null &&
        ['tasks', 'promises'].contains(result.entityType)) {
      _selectedId = result.entityId;
      _selectedType = result.entityType;
    } else if (!result.route.startsWith('/today') &&
        !result.route.startsWith('/promises')) {
      _selectedId = null;
      _selectedType = null;
      _records = [];
    }
  }

  Future<RiyaResolution?> resolve(String prompt) async {
    final text = prompt.trim();
    final lower = text.toLowerCase();
    final explicit = RegExp(
      r'^(show|list|open|create|add|new|delete|remove|edit|rename|change|reschedule|complete|pause|resume|mark|save)\b',
    ).hasMatch(lower);

    if (_createType != null && !explicit) {
      final type = _createType!;
      _createType = null;
      return _create(type, text);
    }
    if (_pendingVerb != null && !explicit) {
      final verb = _pendingVerb!, type = _pendingType!, id = _pendingId!;
      _pendingVerb = null;
      _pendingType = null;
      _pendingId = null;
      return _action(type, id, verb, text);
    }
    if (explicit) {
      _createType = null;
      _pendingVerb = null;
      _promiseStep = 0;
      _promiseTitle = null;
      _promiseTarget = null;
    }
    if (RegExp(
      r'^(?:(?:show|list|what are|dikhao)\s+)?(?:my\s+)?promises?[?.!]*$',
    ).hasMatch(lower)) {
      _offset = 0;
      return const RiyaResolution(command: RiyaCommand('promises.list', {}));
    }
    if (lower == 'more promises') {
      _offset += 3;
      return RiyaResolution(
        command: RiyaCommand('promises.list', {'offset': _offset}),
      );
    }
    final create = RegExp(
      r'^(?:(?:create|add|new|make|save)\s+(?:(?:a|an|new|ek)\s+)?(todo|task|promise)|(?:ek\s+)?(todo|task|promise)\s+(?:banao|banana hai|banana|create karo))(?:\s+(?:to\s+)?(.*))?$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (create != null) {
      final type = (create[1] ?? create[2])!.toLowerCase() == 'promise'
          ? 'promises'
          : 'tasks';
      final title = (create[3] ?? '').trim();
      if (title.isEmpty) {
        _createType = type;
        return RiyaResolution(
          message: type == 'promises'
              ? 'Kis cheez ka Promise? Tell me in your own words.'
              : 'What do you want to get done?',
          options: const ['Cancel'],
        );
      }
      return _create(type, title);
    }
    final direct = RegExp(
      r'^(edit|rename|delete|remove|complete|finish|check in|pause|resume|reschedule|change schedule|read)\s+(?:my\s+)?(todo|task|promise)\s*#?(\d+)(?:\s+(?:to\s+)?(.+))?$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (direct != null) {
      return _action(
        direct[2]!.toLowerCase() == 'promise' ? 'promises' : 'tasks',
        int.parse(direct[3]!),
        direct[1]!.toLowerCase(),
        direct[4],
      );
    }
    final contextual = RegExp(
      r'^(edit|rename|delete|remove|complete|finish|check in|pause|resume|reschedule)\s+(?:that|it|this)(?:\s+(?:to\s+)?(.+))?$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(text);
    if (contextual != null && _selectedId != null) {
      return _action(
        _selectedType!,
        _selectedId!,
        contextual[1]!,
        contextual[2],
      );
    }
    if (contextual != null && _selectedId == null && _records.isNotEmpty) {
      return const RiyaResolution(
        message:
            'Which item? Tap its Edit or More button on a card, or tell me its name.',
        options: ['Show todos', 'Show promises'],
      );
    }
    final ordinal = RegExp(
      r'^(?:(?:move|reschedule|edit|delete|complete)\s+)?(?:the\s+)?(first|second|third|1st|2nd|3rd|pehla|dusra|teesra)(?:\s+(?:one|wala))?(?:\s+(?:to\s+)?(.*))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (ordinal != null && _records.isNotEmpty) {
      final index = switch (ordinal[1]) {
        'first' || '1st' || 'pehla' => 0,
        'second' || '2nd' || 'dusra' => 1,
        _ => 2,
      };
      if (index >= _records.length) {
        return const RiyaResolution(
          message: 'That item is not on this page. Choose a visible card.',
        );
      }
      final r = _records[index];
      final verb = lower.startsWith('delete')
          ? 'delete'
          : lower.startsWith('complete')
          ? 'complete'
          : lower.contains('tomorrow') ||
                lower.contains('kal') ||
                lower.startsWith('move') ||
                lower.startsWith('reschedule')
          ? 'reschedule'
          : 'read';
      return _action(r['type'] as String, r['id'] as int, verb, ordinal[2]);
    }
    if (lower == 'isko kal kar do' && _selectedId != null) {
      return _action(_selectedType!, _selectedId!, 'reschedule', 'tomorrow');
    }
    return null;
  }

  RiyaResolution _create(String type, String text) {
    if (type == 'promises') {
      return const RiyaResolution(
        message: 'Commitments & Promises are coming soon to Ascent!',
        options: ['Add a task instead'],
      );
    }
    final parsed = LocalDeterministicAiEngine().tryParseActivityOrTask(
      'add a task to $text',
    );
    final title = (parsed?['title'] as String? ?? text)
        .replaceAll(RegExp(r'\s+(aaj|kal)$', caseSensitive: false), '')
        .trim();
    return RiyaResolution(
      command: RiyaCommand('tasks.create', {
        'title': title,
        'plannedDate': _day(text).toIso8601String(),
        if (parsed?['estimatedMinutes'] != null)
          'estimatedMinutes': parsed!['estimatedMinutes'],
        if (parsed?['priority'] != null) 'priority': parsed!['priority'],
        if (parsed?['reminderTime'] != null)
          'reminderTime': parsed!['reminderTime'],
      }),
    );
  }

  DateTime _day(String text) {
    final now = clock();
    final lower = text.toLowerCase();
    final iso = RegExp(r'\b20\d{2}-\d{2}-\d{2}\b').firstMatch(text);
    if (iso != null) {
      final date = DateTime.tryParse(iso[0]!);
      if (date == null || date.toIso8601String().split('T').first != iso[0]) {
        throw ArgumentError('Choose a real calendar date.');
      }
      return date;
    }
    return DateTime(
      now.year,
      now.month,
      now.day + (RegExp(r'\b(tomorrow|kal)\b').hasMatch(lower) ? 1 : 0),
    );
  }

  Future<RiyaResolution> _action(
    String type,
    int id,
    String verb,
    String? value,
  ) async {
    verb = verb.toLowerCase();
    if (type == 'promises') {
      return const RiyaResolution(
        message: 'Commitments & Promises are coming soon to Ascent!',
      );
    }
    final title = (await db.taskDao.getTaskById(id))?.title;
    if (title == null) {
      return const RiyaResolution(
        message:
            'This item is no longer available. Show the list to choose again.',
      );
    }
    _selectedType = type;
    _selectedId = id;
    final noun = type == 'promises' ? 'promise' : 'task';
    if (['edit', 'rename', 'reschedule', 'change schedule'].contains(verb) &&
        (value == null || value.trim().isEmpty)) {
      _pendingVerb = verb;
      _pendingType = type;
      _pendingId = id;
      return RiyaResolution(
        message: verb == 'reschedule' || verb == 'change schedule'
            ? 'Which day for “$title”?'
            : 'What should “$title” be called?',
        options: verb == 'reschedule' || verb == 'change schedule'
            ? ['Today', 'Tomorrow', 'Cancel']
            : ['Cancel'],
      );
    }
    final expected = {'expectedTitle': title};
    if (['edit', 'rename'].contains(verb)) {
      return RiyaResolution(
        command: RiyaCommand('$type.edit', {
          'id': id,
          'title': value!.trim(),
          ...expected,
        }),
      );
    }
    if (['reschedule', 'change schedule'].contains(verb)) {
      if (!RegExp(
        r'\b(today|tomorrow|aaj|kal|20\d{2}-\d{2}-\d{2})\b',
        caseSensitive: false,
      ).hasMatch(value!)) {
        _pendingVerb = 'reschedule';
        _pendingType = type;
        _pendingId = id;
        return const RiyaResolution(
          message: 'Choose Today, Tomorrow, or a date like 2026-11-03.',
          options: ['Today', 'Tomorrow', 'Cancel'],
        );
      }
      return RiyaResolution(
        command: type == 'promises'
            ? RiyaCommand('promises.reschedule', {
                'id': id,
                'day': _day(value).toIso8601String(),
                ...expected,
              })
            : RiyaCommand('tasks.reschedule', {
                'taskIds': [id],
                'newDate': _day(value).toIso8601String(),
                ...expected,
              }),
      );
    }
    if (verb == 'read') {
      return RiyaResolution(
        command: type == 'promises'
            ? RiyaCommand('promises.read', {'id': id})
            : null,
        message: type == 'tasks'
            ? 'Use the $noun card to edit, complete or reschedule it.'
            : null,
      );
    }
    final action = switch (verb) {
      'remove' => 'delete',
      'finish' ||
      'complete' ||
      'check in' => type == 'promises' ? 'checkin' : 'complete',
      _ => verb,
    };
    if (type == 'tasks' && !['delete', 'complete'].contains(action)) {
      return const RiyaResolution(
        message: 'Choose Done, Edit, Reschedule or Delete on this Todo.',
      );
    }
    return RiyaResolution(
      command: RiyaCommand('$type.$action', {'id': id, ...expected}),
    );
  }
}
