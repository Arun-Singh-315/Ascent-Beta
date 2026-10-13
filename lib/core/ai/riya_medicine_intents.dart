import 'riya_capabilities.dart';
import 'riya_intents.dart';

class RiyaMedicineIntents {
  RiyaMedicineIntents(this.clock);
  final DateTime Function() clock;
  int? _selected;
  String? _list, _day;
  bool _all = false;
  int _offset = 0;
  void remember(int id) => _selected = id;
  void clearSelection() => _selected = null;
  void cancel() {
    _selected = null;
    _list = null;
    _day = null;
    _offset = 0;
  }

  RiyaResolution? resolve(String prompt) {
    final text = prompt.trim(), lower = text.toLowerCase();
    final list = RegExp(
      r'^(?:(?:show|list) (?:my )?)?medicines(?: (all))?$',
    ).firstMatch(lower);
    if (list != null) {
      _list = 'medicine.list';
      _all = list.group(1) != null;
      _offset = 0;
      _selected = null;
      return _page();
    }
    final doses = RegExp(
      r'^(?:(?:show|list) )?doses(?: (today|tomorrow|\d{4}-\d{2}-\d{2}))?$',
    ).firstMatch(lower);
    if (doses != null ||
        _list == 'medicine.doses' && {'today', 'tomorrow'}.contains(lower)) {
      _list = 'medicine.doses';
      _offset = 0;
      final value = doses?.group(1) ?? (doses == null ? lower : 'today'),
          now = clock();
      _day = value == 'today' || value == 'tomorrow'
          ? DateTime(
              now.year,
              now.month,
              now.day + (value == 'tomorrow' ? 1 : 0),
            ).toIso8601String()
          : value;
      return _page();
    }
    if (lower == 'more medicines' || lower == 'more doses') {
      if (_list !=
          (lower == 'more medicines' ? 'medicine.list' : 'medicine.doses')) {
        return const RiyaResolution(message: 'Choose that list first.');
      }
      _offset += 3;
      return _page();
    }
    _list = null;
    final dose = RegExp(
      r'^(?:mark )?dose #(\d+) (?:as )?(taken|pending)$',
    ).firstMatch(lower);
    if (dose != null) {
      return RiyaResolution(
        command: RiyaCommand('medicine.taken', {
          'id': int.parse(dose.group(1)!),
          'taken': dose.group(2) == 'taken',
        }),
      );
    }
    final target = RegExp(
      r'^(read|show|delete|remove|pause|resume) medicine #(\d+)$',
    ).firstMatch(lower);
    if (target != null) {
      final verb = target.group(1)!;
      return RiyaResolution(
        command: RiyaCommand(
          {'delete', 'remove'}.contains(verb)
              ? 'medicine.delete'
              : {'pause', 'resume'}.contains(verb)
              ? 'medicine.edit'
              : 'medicine.read',
          {
            'id': int.parse(target.group(2)!),
            if ({'pause', 'resume'}.contains(verb)) 'active': verb == 'resume',
          },
        ),
      );
    }
    final edit = RegExp(
      r'^(?:edit|change|update) (?:medicine #(\d+)|that) (name|dosage|times|days|start date|instructions|form) to (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (edit != null) {
      final id = edit.group(1) == null ? _selected : int.parse(edit.group(1)!);
      if (id == null) {
        return const RiyaResolution(
          message: 'Read a medicine schedule first, or include its number.',
        );
      }
      final field = edit.group(2)!.toLowerCase(), value = edit.group(3)!.trim();
      final Object? parsed = field == 'times'
          ? value.split(',').map((t) => t.trim()).toList()
          : field == 'days'
          ? int.tryParse(value)
          : value;
      if (parsed == null) {
        return const RiyaResolution(message: 'Use a whole number of days.');
      }
      return RiyaResolution(
        command: RiyaCommand('medicine.edit', {
          'id': id,
          field == 'start date' ? 'startDate' : field: parsed,
        }),
      );
    }
    final create = RegExp(
      r'^(?:add|create|schedule) medicine (.+?) dosage (.+?) form (tablet|capsule|syrup|drops|injection) at ([\d:, ]+) for (\d+) days(?: from (\d{4}-\d{2}-\d{2}))?(?: instructions (.+))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (create != null) {
      return RiyaResolution(
        command: RiyaCommand('medicine.create', {
          'name': create.group(1)!.trim(),
          'dosage': create.group(2)!.trim(),
          'form': create.group(3)!.toLowerCase(),
          'times': create.group(4)!.split(',').map((t) => t.trim()).toList(),
          'days': int.parse(create.group(5)!),
          if (create.group(6) != null) 'startDate': create.group(6),
          if (create.group(7) != null) 'instructions': create.group(7)!.trim(),
        }),
      );
    }
    if (RegExp(r'^(?:add|create|schedule) medicine\b').hasMatch(lower)) {
      return const RiyaResolution(
        message:
            'Tell me the schedule you already use, including its name, dosage, form, times and days. For example: “Add medicine My schedule dosage My dose form tablet at 08:00 for 7 days”. I will not choose a dosage or timing for you.',
      );
    }
    return null;
  }

  RiyaResolution _page() => RiyaResolution(
    command: RiyaCommand(_list!, {
      'offset': _offset,
      if (_list == 'medicine.list') 'all': _all,
      if (_list == 'medicine.doses') 'day': _day,
    }),
  );
}
