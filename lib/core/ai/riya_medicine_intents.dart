import '../database/app_database.dart';
import 'riya_capabilities.dart';
import 'riya_intents.dart';

class RiyaMedicineIntents {
  RiyaMedicineIntents(this.db, this.clock);
  final AppDatabase db;
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

  Future<RiyaResolution?> resolve(String prompt) async {
    var text = prompt.trim();
    final lower = text.toLowerCase();
    final renameSelected = RegExp(
      r'^rename that to (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (renameSelected != null && _selected != null) {
      text = 'edit that name to ${renameSelected.group(1)}';
    }
    final list = RegExp(
      r'^(?:(?:show|list) (?:my )?)?(?:medicine|medicines|medications|medicine schedules)(?: (all))?$',
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
    if (lower == 'read selected medicine' && _selected != null) {
      return RiyaResolution(
        command: RiyaCommand('medicine.read', {'id': _selected}),
      );
    }
    if (lower == 'edit that' && _selected != null) return _editHelp();
    final choose = RegExp(
      r'^edit medicine (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (choose != null &&
        !RegExp(
          r' (?:name|dosage|times|days|start date|instructions|form) to ',
          caseSensitive: false,
        ).hasMatch(text)) {
      final target = await _target(choose.group(1)!);
      if (target.command == null) return target;
      _selected = target.command!.arguments['id'];
      return _editHelp();
    }
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
      r'^(read|show|delete|remove|pause|resume) medicine (.+)$',
    ).firstMatch(lower);
    if (target != null) {
      final verb = target.group(1)!;
      final found = await _target(target.group(2)!);
      if (found.command == null) return found;
      return RiyaResolution(
        command: RiyaCommand(
          {'delete', 'remove'}.contains(verb)
              ? 'medicine.delete'
              : {'pause', 'resume'}.contains(verb)
              ? 'medicine.edit'
              : 'medicine.read',
          {
            'id': found.command!.arguments['id'],
            if ({'pause', 'resume'}.contains(verb)) 'active': verb == 'resume',
          },
        ),
      );
    }
    final rename = RegExp(
      r'^rename medicine (.+?) to (.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    final editText = rename == null
        ? text
        : 'edit medicine ${rename.group(1)} name to ${rename.group(2)}';
    final edit = RegExp(
      r'^(?:(?:edit|change|update) (medicine .+?|that) )?(name|dosage|times|days|start date|instructions|form) to (.+)$',
      caseSensitive: false,
    ).firstMatch(editText);
    if (edit != null) {
      var id = _selected;
      if (edit.group(1)?.toLowerCase().startsWith('medicine ') == true) {
        final target = await _target(edit.group(1)!.substring(9));
        if (target.command == null) return target;
        id = target.command!.arguments['id'];
      } else if (id == null &&
          (edit.group(1) == null || edit.group(1)!.toLowerCase() == 'that')) {
        return null; // A field-only follow-up may belong to Learning.
      }
      if (id == null) {
        return const RiyaResolution(
          message: 'Read a medicine schedule first, or include its number.',
        );
      }
      final field = edit.group(2)!.toLowerCase(), value = edit.group(3)!.trim();
      final Object? parsed = field == 'times'
          ? _times(value)
          : field == 'days'
          ? int.tryParse(value)
          : value;
      if (parsed == null) {
        return RiyaResolution(
          message: field == 'times'
              ? 'Use explicit times such as 08:00 or 8 AM, separated by commas.'
              : 'Use a whole number of days.',
        );
      }
      return RiyaResolution(
        command: RiyaCommand('medicine.edit', {
          'id': id,
          field == 'start date' ? 'startDate' : field: parsed,
        }),
      );
    }
    final create = RegExp(
      r'^(?:add|create|schedule) medicine (.+?) dosage (.+?) form (tablet|capsule|syrup|drops|injection) at (.+?) for (\d+) days(?: from (\d{4}-\d{2}-\d{2}))?(?: instructions (.+))?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (create != null) {
      final times = _times(create.group(4)!);
      if (times == null) {
        return const RiyaResolution(
          message:
              'Use explicit times such as 08:00 or 8 AM, separated by commas.',
        );
      }
      return RiyaResolution(
        command: RiyaCommand('medicine.create', {
          'name': create.group(1)!.trim(),
          'dosage': create.group(2)!.trim(),
          'form': create.group(3)!.toLowerCase(),
          'times': times,
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

  RiyaResolution _editHelp() => const RiyaResolution(
    message:
        'Which schedule field should change? For example, “name to New name” or “times to 8 AM, 8 PM”.',
    options: ['Read selected medicine', 'Cancel'],
  );

  Future<RiyaResolution> _target(String reference) async {
    final query = reference.trim();
    final number = RegExp(r'^#?(\d+)$').firstMatch(query);
    final medicine = number == null
        ? null
        : await db.medicineDao.getMedicineById(int.parse(number.group(1)!));
    final rows = number == null
        ? (await db.medicineDao.watchAllMedicines().first)
              .where((m) => m.name.toLowerCase() == query.toLowerCase())
              .toList()
        : [?medicine];
    if (rows.length != 1) {
      _selected = null;
      return RiyaResolution(
        message: rows.isEmpty
            ? 'That medicine schedule was not found. Show medicines to choose its name or number.'
            : 'Several schedules have that name. Include a number:\n${rows.take(3).map((m) => '#${m.id} ${m.name} · ${m.dosage}').join('\n')}',
      );
    }
    return RiyaResolution(
      command: RiyaCommand('medicine.read', {'id': rows.single.id}),
    );
  }

  List<String>? _times(String value) {
    final result = <String>[];
    for (final part in value.split(
      RegExp(r',|\s+and\s+', caseSensitive: false),
    )) {
      final text = part.trim();
      if (RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(text)) {
        result.add(text);
        continue;
      }
      final match = RegExp(
        r'^(\d{1,2})(?::([0-5]\d))?\s*(am|pm)$',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) return null;
      final hour = int.parse(match.group(1)!);
      if (hour < 1 || hour > 12) return null;
      final converted =
          hour % 12 + (match.group(3)!.toLowerCase() == 'pm' ? 12 : 0);
      result.add(
        '${converted.toString().padLeft(2, '0')}:${match.group(2) ?? '00'}',
      );
    }
    return result;
  }

  RiyaResolution _page() => RiyaResolution(
    command: RiyaCommand(_list!, {
      'offset': _offset,
      if (_list == 'medicine.list') 'all': _all,
      if (_list == 'medicine.doses') 'day': _day,
    }),
  );
}
