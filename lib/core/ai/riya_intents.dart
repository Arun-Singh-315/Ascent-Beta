import '../database/app_database.dart';
import 'riya_capabilities.dart';
import 'riya_workspace_intents.dart';

class RiyaResolution {
  const RiyaResolution({this.command, this.message, this.options = const []});
  final RiyaCommand? command;
  final String? message;
  final List<String> options;
}

/// Conversation context comes only from user turns. Retrieved record text is
/// never interpreted as an instruction. Resolved edits are still reviewed.
class RiyaIntentResolver {
  RiyaIntentResolver(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now, _revision = db.workspaceRevision;
  final AppDatabase db;
  final DateTime Function() clock;
  String? _reminderTitle;
  DateTime? _reminderDay, _editAt;
  List<Reminder>? _editChoices;
  bool _interviewChoice = false;
  int _revision;
  late final _workspace = RiyaWorkspaceIntents(db, clock);

  void rememberResult(RiyaResult result) {
    if (result.entityType != null && result.entityId != null) {
      _workspace.remember(result.entityType!, result.entityId!);
    }
  }

  Future<RiyaResolution?> resolve(String prompt) async {
    if (_revision != db.workspaceRevision) {
      _clear();
      _workspace.cancel();
      _revision = db.workspaceRevision;
    }
    final lower = prompt.trim().toLowerCase();
    final now = clock();
    if (lower == 'cancel' || lower == 'never mind') {
      _clear();
      _workspace.cancel();
      return const RiyaResolution(message: 'Cancelled. No changes were made.');
    }
    final workspace =
        _reminderTitle == null ||
            RegExp(
              r'^(show|list|find|read|pin|unpin|archive|delete|remove|choose|edit|update|create|save|add|record|log|set|clear|correct|complete|finish|merge|convert|give|suggest|share)\b',
            ).hasMatch(lower)
        ? await _workspace.resolve(prompt)
        : null;
    if (workspace != null) {
      if (workspace.command != null ||
          RegExp(
            r'^(create|add|record|log|set|edit|change|clear|correct|delete|remove|give|suggest|share)\b',
          ).hasMatch(lower)) {
        _clear();
      }
      return workspace;
    }
    // Any new explicit command replaces an unfinished clarification.
    if (RegExp(
      r'^(add|record|log|create|find|show|start|pause|resume|open|remind|change|edit)\b',
    ).hasMatch(lower)) {
      _clear();
    }
    if (RegExp(r'^(pause|resume)\b').hasMatch(lower) &&
        (lower.contains('timer') || lower.contains('focus'))) {
      final session = await db.timeSessionDao.getActiveFocusSession();
      if (session == null) {
        return const RiyaResolution(
          message:
              'There is no active Focus session. You can start one with “Start a 25-minute timer”.',
        );
      }
      return RiyaResolution(
        command: RiyaCommand(
          lower.startsWith('pause') ? 'focus.pause' : 'focus.resume',
          {'id': session.id},
        ),
      );
    }
    if (_editChoices != null) {
      final id = int.tryParse(lower.replaceFirst('#', '').split(' ').first);
      final matches = _editChoices!
          .where((r) => r.id == id || r.title.toLowerCase() == lower)
          .toList();
      if (matches.length == 1) {
        final at = _editAt!;
        _clear();
        return RiyaResolution(
          command: RiyaCommand('reminders.edit', {
            'id': matches.single.id,
            'at': at.toIso8601String(),
          }),
        );
      }
      return RiyaResolution(
        message: 'Which reminder? Reply with its number.',
        options: _editChoices!.map((r) => '#${r.id} ${r.title}').toList(),
      );
    }
    if (_reminderTitle != null) {
      if (lower.contains('tomorrow') || lower == 'today') {
        _reminderDay = DateTime(
          now.year,
          now.month,
          now.day + (lower.contains('tomorrow') ? 1 : 0),
        );
      }
      final at = _time(prompt, _reminderDay ?? now);
      if (at == null) {
        return const RiyaResolution(
          message: 'What time? For example, 7 PM.',
          options: ['7 AM', '7 PM'],
        );
      }
      final title = _reminderTitle!;
      _clear();
      return RiyaResolution(
        command: RiyaCommand('reminders.create', {
          'title': title,
          'at': at.toIso8601String(),
        }),
      );
    }
    if (_interviewChoice) {
      _clear();
      if (lower.contains('reminder')) {
        _reminderTitle = 'Prepare for interview';
        _reminderDay = now;
        return const RiyaResolution(message: 'When should I remind you?');
      }
      if (lower.contains('timer') || lower.contains('focus')) {
        final minutes =
            int.tryParse(RegExp(r'\d+').firstMatch(lower)?.group(0) ?? '') ??
            25;
        return RiyaResolution(
          command: RiyaCommand('focus.start', {
            'minutes': minutes,
            'title': 'Interview preparation',
          }),
        );
      }
      if (lower.contains('checklist')) {
        return const RiyaResolution(
          command: RiyaCommand('tasks.checklist', {
            'title': 'Prepare for interview',
            'items': [
              'Review the role and company',
              'Practice technical questions',
              'Rehearse project and behavioral examples',
            ],
          }),
        );
      }
      if (lower.contains('task')) {
        return const RiyaResolution(
          command: RiyaCommand('tasks.create', {
            'title': 'Prepare for interview',
          }),
        );
      }
      _interviewChoice = true;
      return _interviewOptions();
    }
    if ((lower.contains('prepare for') || lower.contains('prep for')) &&
        lower.contains('interview') &&
        !RegExp(r'^(add|create|remind|schedule)\b').hasMatch(lower)) {
      _interviewChoice = true;
      return _interviewOptions();
    }
    if (lower.contains('what can riya do') ||
        lower == 'help' ||
        lower == 'what can you do') {
      return RiyaResolution(
        message:
            'I can read local records and help you make these changes. Writes are reviewed before saving.',
        options: riyaCapabilities
            .where((c) => c.example != null)
            .map((c) => c.example!)
            .toList(),
      );
    }
    if (lower.contains('thought wall') &&
        (lower.contains('use') || lower.contains('help'))) {
      return const RiyaResolution(
        command: RiyaCommand('help.feature', {'feature': 'Thought Wall'}),
      );
    }
    const routes = {
      'reminders': '/reminders',
      'focus': '/focus',
      'interview prep': '/interview-prep',
      'thought wall': '/thought-wall',
      'money': '/money',
      'tasks': '/today',
      'learning': '/learning',
      'chai': '/chai-break',
    };
    if (lower.startsWith('open ')) {
      final route = routes[lower.substring(5)];
      return route == null
          ? const RiyaResolution(
              message:
                  'I do not have a shortcut for that screen. Open More to find it.',
            )
          : RiyaResolution(
              command: RiyaCommand('navigation.open', {'route': route}),
            );
    }
    if ((lower.startsWith('find ') || lower.startsWith('search ')) &&
        (lower.contains('wrote') || lower.contains('thought'))) {
      final about = lower.indexOf('about ');
      var query = about >= 0
          ? prompt.substring(about + 6)
          : prompt.replaceFirst(
              RegExp(
                r'^(find|search)\s+(?:my\s+)?thoughts?\s*',
                caseSensitive: false,
              ),
              '',
            );
      query = query
          .trim()
          .replaceFirst(RegExp(r'^my\s+', caseSensitive: false), '')
          .replaceAll(RegExp(r'[?.]+$'), '');
      return RiyaResolution(
        command: RiyaCommand('thoughts.search', {'query': query}),
      );
    }
    if (lower.contains('spending') || lower.startsWith('spent this')) {
      final day = DateTime(now.year, now.month, now.day);
      final from = lower.contains('week')
          ? DateTime(day.year, day.month, day.day - (day.weekday - 1))
          : lower.contains('month')
          ? DateTime(day.year, day.month, 1)
          : day;
      return RiyaResolution(
        command: RiyaCommand('expenses.summary', {
          'from': from.toIso8601String(),
          'to': DateTime(day.year, day.month, day.day + 1).toIso8601String(),
        }),
      );
    }
    if (lower.contains('task') &&
        (lower.contains('today') ||
            lower.startsWith('show my') ||
            lower.startsWith('what '))) {
      if (!lower.startsWith('add ') && !lower.startsWith('create ')) {
        await _workspace.resolve('Show tasks');
        return const RiyaResolution(command: RiyaCommand('tasks.today', {}));
      }
    }
    if (lower.startsWith('start ') &&
        (lower.contains('timer') || lower.contains('focus'))) {
      final match = RegExp(
        r'(\d+)\s*(?:-\s*)?(minute|min|hour)',
      ).firstMatch(lower);
      if (match == null) {
        return const RiyaResolution(
          message:
              'How long? Please include the duration, such as “Start a 25-minute timer”.',
        );
      }
      final minutes =
          int.parse(match.group(1)!) * (match.group(2) == 'hour' ? 60 : 1);
      return RiyaResolution(
        command: RiyaCommand('focus.start', {'minutes': minutes}),
      );
    }
    if (lower.startsWith('change ') || lower.startsWith('edit ')) {
      if (!lower.contains('reminder')) return null;
      final at = _time(prompt, now);
      if (at == null) {
        return const RiyaResolution(
          message:
              'What time should the reminder move to? Include its name and the time.',
        );
      }
      final all = await db.reminderDao.watchAllReminders().first;
      final id = int.tryParse(
        RegExp(r'#(\d+)').firstMatch(lower)?.group(1) ?? '',
      );
      var matches = all
          .where((r) => r.isActive && (id == null || r.id == id))
          .toList();
      if (matches.length > 1) {
        final named = matches
            .where((r) => lower.contains(r.title.toLowerCase()))
            .toList();
        if (named.isNotEmpty) matches = named;
      }
      if (matches.isEmpty) {
        return const RiyaResolution(
          message: 'I could not find an active reminder to change.',
        );
      }
      if (matches.length == 1) {
        return RiyaResolution(
          command: RiyaCommand('reminders.edit', {
            'id': matches.single.id,
            'at': at.toIso8601String(),
          }),
        );
      }
      _editAt = at;
      _editChoices = matches;
      return RiyaResolution(
        message: 'Which reminder should I change?',
        options: matches.map((r) => '#${r.id} ${r.title}').toList(),
      );
    }
    if (lower.startsWith('remind me')) {
      final day = lower.contains('tomorrow')
          ? DateTime(now.year, now.month, now.day + 1)
          : DateTime(now.year, now.month, now.day);
      var title = prompt.replaceFirst(
        RegExp(r'^remind me\s*(?:to\s*)?', caseSensitive: false),
        '',
      );
      title = title
          .replaceAll(
            RegExp(r'\b(?:tomorrow|today)\b', caseSensitive: false),
            '',
          )
          .replaceAll(
            RegExp(
              r'\bat\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?',
              caseSensitive: false,
            ),
            '',
          )
          .replaceAll(
            RegExp(r'\bin\s+\d+\s*(?:minutes?|hours?)', caseSensitive: false),
            '',
          )
          .trim();
      final at = _time(prompt, day);
      if (title.isEmpty) {
        return const RiyaResolution(message: 'What should I remind you about?');
      }
      if (at == null) {
        _reminderTitle = title;
        _reminderDay = day;
        return const RiyaResolution(
          message: 'When should I remind you? Choose a day, then a time.',
          options: ['Today', 'Tomorrow'],
        );
      }
      return RiyaResolution(
        command: RiyaCommand('reminders.create', {
          'title': title,
          'at': at.toIso8601String(),
        }),
      );
    }
    if (lower.contains('my reminder') ||
        lower == 'show reminders' ||
        lower == 'reminders') {
      return const RiyaResolution(command: RiyaCommand('reminders.list', {}));
    }
    return null;
  }

  RiyaResolution _interviewOptions() => const RiyaResolution(
    message:
        'What would help with your interview preparation? I have not created anything.',
    options: [
      'Preparation task',
      'Preparation reminder',
      '25-minute preparation timer',
      'Preparation checklist',
    ],
  );
  void _clear() {
    _reminderTitle = null;
    _reminderDay = null;
    _editAt = null;
    _editChoices = null;
    _interviewChoice = false;
  }

  DateTime? _time(String text, DateTime day) {
    final lower = text.toLowerCase();
    final now = clock();
    final relative = RegExp(
      r'\bin\s+(\d+)\s*(minutes?|hours?)',
    ).firstMatch(lower);
    if (relative != null) {
      return now.add(
        Duration(
          minutes:
              int.parse(relative.group(1)!) *
              (relative.group(2)!.startsWith('hour') ? 60 : 1),
        ),
      );
    }
    final match =
        RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b').firstMatch(lower) ??
        RegExp(r'\bat\s+(\d{1,2}):(\d{2})\b').firstMatch(lower);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.tryParse(match.group(2) ?? '') ?? 0;
    final period = match.groupCount >= 3 ? match.group(3) : null;
    if (minute > 59 || (period != null ? hour < 1 || hour > 12 : hour > 23)) {
      return null;
    }
    if (period != null) hour = hour % 12 + (period == 'pm' ? 12 : 0);
    final base = lower.contains('tomorrow')
        ? DateTime(now.year, now.month, now.day + 1)
        : day;
    var at = DateTime(base.year, base.month, base.day, hour, minute);
    if (!at.isAfter(now) &&
        !lower.contains('today') &&
        base.day == now.day &&
        base.month == now.month &&
        base.year == now.year) {
      at = DateTime(at.year, at.month, at.day + 1, at.hour, at.minute);
    }
    return at;
  }
}
