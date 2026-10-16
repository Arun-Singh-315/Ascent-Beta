import 'riya_capabilities.dart';
import 'riya_intents.dart';

class RiyaMoneyIntents {
  RiyaMoneyIntents(this.clock);
  final DateTime Function() clock;
  int? _selected;
  String? _day, _scope, _type;
  int _offset = 0;
  void remember(int id) => _selected = id;
  void clearSelection() => _selected = null;
  void cancel() {
    _selected = null;
    _scope = null;
    _day = null;
    _type = null;
    _offset = 0;
  }

  RiyaResolution? resolve(String prompt) {
    final text = prompt.trim();
    final lower = text.toLowerCase();
    final list = RegExp(
      r'^(?:(?:show|list|read) (?:my )?)?(income|transactions)(?: (today|tomorrow|all|\d{4}-\d{2}-\d{2}))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (list != null ||
        _scope != null && {'today', 'tomorrow', 'all'}.contains(lower)) {
      final period =
          list?.group(2)?.toLowerCase() ?? (list == null ? lower : 'today');
      if (list != null) {
        _type = list.group(1)!.toLowerCase() == 'income' ? 'income' : null;
      }
      _scope = period == 'all' ? 'all' : 'date';
      final now = clock();
      _day = period == 'all'
          ? null
          : period == 'today' || period == 'tomorrow'
          ? DateTime(
              now.year,
              now.month,
              now.day + (period == 'tomorrow' ? 1 : 0),
            ).toIso8601String()
          : period;
      _offset = 0;
      _selected = null;
      return _list();
    }
    final more = RegExp(r'^more (income|transactions)$').firstMatch(lower);
    if (more != null) {
      if (_scope == null ||
          (more.group(1) == 'income') != (_type == 'income')) {
        return const RiyaResolution(message: 'Choose that Money list first.');
      }
      _offset += 3;
      return _list();
    }
    // A fresh domain request ends date follow-ups without losing an explicitly
    // selected record used by "edit that".
    _scope = null;
    final create = RegExp(
      r'^(?:add|record|log) (income|expense) (?:₹|rs\.?\s*|inr\s*)?(\d+(?:\.\d+)?) (?:for|from) (.+?)(?: on (\d{4}-\d{2}-\d{2}))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (create != null) {
      _selected = null;
      return RiyaResolution(
        command: RiyaCommand('transactions.create', {
          'type': create.group(1)!.toLowerCase(),
          'amount': double.parse(create.group(2)!),
          'title': create.group(3)!.trim(),
          if (create.group(4) != null) 'date': create.group(4),
        }),
      );
    }
    final record = RegExp(
      r'^(read|show|delete|remove) transaction #(\d+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (record != null) {
      return RiyaResolution(
        command: RiyaCommand(
          {'delete', 'remove'}.contains(record.group(1)!.toLowerCase())
              ? 'transactions.delete'
              : 'transactions.read',
          {'id': int.parse(record.group(2)!)},
        ),
      );
    }
    final edit = RegExp(
      r'^(?:edit|update|change) (?:transaction #(\d+)|that) (title|amount|type|category|account|date|notes) (?:to|as) (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (edit != null) {
      final id = edit.group(1) == null ? _selected : int.parse(edit.group(1)!);
      if (id == null) {
        return const RiyaResolution(
          message: 'Read a transaction first, or include its record number.',
        );
      }
      final field = edit.group(2)!.toLowerCase();
      final value = field == 'amount'
          ? double.tryParse(edit.group(3)!)
          : edit.group(3)!.trim();
      if (value == null) {
        return const RiyaResolution(message: 'Use a finite positive amount.');
      }
      return RiyaResolution(
        command: RiyaCommand('transactions.edit', {'id': id, field: value}),
      );
    }
    final clear = RegExp(
      r'^clear notes (?:on|from) transaction #(\d+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (clear != null) {
      return RiyaResolution(
        command: RiyaCommand('transactions.edit', {
          'id': int.parse(clear.group(1)!),
          'clearNotes': true,
        }),
      );
    }
    final summary = RegExp(
      r'^(?:show )?(?:money|income and spending) summary(?: (today|this month|\d{4}-\d{2}-\d{2} to \d{4}-\d{2}-\d{2}))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (summary != null) {
      final now = clock(), period = summary.group(1)?.toLowerCase() ?? 'today';
      final DateTime from, to;
      if (period == 'today') {
        from = DateTime(now.year, now.month, now.day);
        to = DateTime(now.year, now.month, now.day + 1);
      } else if (period == 'this month') {
        from = DateTime(now.year, now.month, 1);
        to = DateTime(now.year, now.month + 1, 1);
      } else {
        final dates = period.split(' to ');
        // Validation is owned by the executor; don't normalize invalid dates here.
        return RiyaResolution(
          command: RiyaCommand('transactions.summary', {
            'from': dates[0],
            'to': dates[1],
          }),
        );
      }
      return RiyaResolution(
        command: RiyaCommand('transactions.summary', {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        }),
      );
    }
    return null;
  }

  RiyaResolution _list() => RiyaResolution(
    command: RiyaCommand('transactions.list', {
      'scope': _scope,
      'offset': _offset,
      if (_type != null) 'type': _type,
      if (_day != null) 'day': _day,
    }),
  );
}
