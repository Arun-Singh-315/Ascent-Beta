import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'riya_capabilities.dart';
import 'riya_intents.dart';

const riyaSessionCapabilities = <RiyaCapability>[
  RiyaCapability('focus.history', 'Read recorded Focus history', '/focus', {
    'scope': RiyaValue.text,
    'day': RiyaValue.date,
    'offset': RiyaValue.offset,
  }),
  RiyaCapability(
    'learning.history',
    'Read recorded Learning history',
    '/learning',
    {
      'scope': RiyaValue.text,
      'day': RiyaValue.date,
      'offset': RiyaValue.offset,
    },
  ),
];

class RiyaSessionReads {
  RiyaSessionReads(this.db, this.clock);
  final AppDatabase db;
  final DateTime Function() clock;
  Future<RiyaResult> run(RiyaCommand command) async {
    final a = command.arguments;
    final scope = a['scope'] as String? ?? 'today';
    if (!{'today', 'tomorrow', 'date', 'all'}.contains(scope)) {
      throw ArgumentError('Choose a history period');
    }
    if (scope == 'all' && a.containsKey('day')) {
      throw ArgumentError('Choose All or a selected date');
    }
    if (scope == 'date' && !a.containsKey('day')) {
      throw ArgumentError('Choose a date');
    }
    final now = clock();
    final date = a['day'] == null
        ? DateTime(now.year, now.month, now.day + (scope == 'tomorrow' ? 1 : 0))
        : DateTime.parse(a['day']).toLocal();
    final from = DateTime(date.year, date.month, date.day),
        to = DateTime(date.year, date.month, date.day + 1);
    final learning = command.id == 'learning.history';
    final rows =
        await (db.select(db.timeSessionTable)
              ..where(
                (s) =>
                    (learning
                        ? s.learningCourseId.isNotNull() |
                              s.activityRefType.equals('lecture')
                        : s.learningCourseId.isNull() &
                              s.activityRefType.isNotValue('lecture')) &
                    (scope == 'all'
                        ? const Constant(true)
                        : s.startedAt.isBiggerOrEqualValue(from) &
                              s.startedAt.isSmallerThanValue(to)),
              )
              ..orderBy([
                (s) => OrderingTerm.desc(s.startedAt),
                (s) => OrderingTerm.desc(s.id),
              ])
              ..limit(4, offset: a['offset'] as int? ?? 0))
            .get();
    final domain = learning ? 'Learning' : 'Focus';
    String label(String text) =>
        text.length <= 160 ? text : '${text.substring(0, 157)}…';
    return RiyaResult(
      'Recorded $domain sessions · ${scope == 'date' ? '${from.day}/${from.month}/${from.year}' : scope}:\n${rows.isEmpty ? 'No recorded sessions in this period.' : rows.take(3).map((s) => '#${s.id} ${label(s.label)} · ${s.status} · ${s.durationSeconds ~/ 60}m ${s.durationSeconds % 60}s recorded').join('\n')}',
      command.capability.route,
      options: [
        if (rows.length > 3) 'More ${domain.toLowerCase()} history',
        '$domain history today',
        '$domain history all',
      ],
    );
  }
}

class RiyaSessionIntents {
  RiyaSessionIntents(this.clock);
  final DateTime Function() clock;
  String? _day;
  String? _domain, _scope;
  int _offset = 0;
  void cancel() {
    _domain = null;
    _scope = null;
    _offset = 0;
    _day = null;
  }

  RiyaResolution? resolve(String prompt) {
    final text = prompt.trim().toLowerCase();
    if (_domain != null && {'today', 'tomorrow', 'all'}.contains(text)) {
      _period(text);
      _offset = 0;
      return _command();
    }
    final query = RegExp(
      r'^(?:(?:show|list|read) (?:my )?)?(focus|learning) history(?: (today|tomorrow|all|\d{4}-\d{2}-\d{2}))?$',
    ).firstMatch(text);
    if (query != null) {
      _domain = query.group(1);
      _period(query.group(2) ?? 'today');
      _offset = 0;
      return _command();
    }
    final more = RegExp(r'^more (focus|learning) history$').firstMatch(text);
    if (more != null) {
      if (_domain != more.group(1)) {
        return const RiyaResolution(message: 'Choose that history list first.');
      }
      _offset += 3;
      return _command();
    }
    return null;
  }

  void _period(String value) {
    if (value == 'all') {
      _scope = 'all';
      _day = null;
      return;
    }
    _scope = 'date';
    if (value != 'today' && value != 'tomorrow') {
      _day = value;
      return;
    }
    final now = clock();
    _day = DateTime(
      now.year,
      now.month,
      now.day + (value == 'tomorrow' ? 1 : 0),
    ).toIso8601String();
  }

  RiyaResolution _command() => RiyaResolution(
    command: RiyaCommand('$_domain.history', {
      'scope': _scope ?? 'today',
      'offset': _offset,
      if (_day != null) 'day': _day,
    }),
  );
}
