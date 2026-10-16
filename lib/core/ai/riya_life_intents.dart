import 'riya_capabilities.dart';
import 'riya_intents.dart';

class RiyaLifeIntents {
  RiyaLifeIntents(this.clock);
  final DateTime Function() clock;
  String? _list;
  int _offset = 0;
  String? _selectedType;
  int? _selectedId;
  void clearSelection() {
    _selectedType = null;
    _selectedId = null;
  }

  void remember(String type, int id) {
    _selectedType = type;
    _selectedId = id;
  }

  DateTime? _waterDay;
  void cancel() {
    _list = null;
    _selectedType = null;
    _selectedId = null;
    _offset = 0;
    _waterDay = null;
  }

  RiyaResolution? resolve(String prompt) {
    final lower = prompt.trim().toLowerCase();
    final editThat = RegExp(
      r'^(?:edit|change) that (?:to|as) (.+)$',
      caseSensitive: false,
    ).firstMatch(prompt.trim());
    if (editThat != null && _selectedId != null) {
      final text = editThat.group(1)!.trim();
      if (_selectedType == 'savings') {
        return RiyaResolution(
          command: RiyaCommand('savings.edit', {
            'id': _selectedId,
            'title': text,
          }),
        );
      }
      final number = double.tryParse(
        text
            .replaceAll('₹', '')
            .replaceAll(',', '')
            .replaceAll(RegExp(r'\s*ml$', caseSensitive: false), ''),
      );
      if (number == null) {
        return const RiyaResolution(
          message: 'Use a numeric amount for that selected record.',
        );
      }
      if (_selectedType == 'budgets') {
        return RiyaResolution(
          command: RiyaCommand('budgets.edit', {
            'id': _selectedId,
            'monthlyLimit': number,
          }),
        );
      }
      if (_selectedType == 'hydration' && number == number.toInt()) {
        return RiyaResolution(
          command: RiyaCommand('hydration.edit', {
            'id': _selectedId,
            'amountMl': number.toInt(),
          }),
        );
      }
      return const RiyaResolution(
        message:
            'Which field should I change? Include its type and record number.',
      );
    }
    final listing = RegExp(
      r'^(?:show|list|read)\s+(?:my\s+)?(budgets|savings goals|water entries)(?:\s+(today|tomorrow))?[?.!]*$',
    ).firstMatch(lower);
    if (listing != null) {
      _selectedType = null;
      _selectedId = null;
      _list = listing.group(1);
      _offset = 0;
      final now = clock();
      _waterDay = DateTime(
        now.year,
        now.month,
        now.day + (listing.group(2) == 'tomorrow' ? 1 : 0),
      );
      return _page();
    }
    final more = RegExp(
      r'^more (budgets|savings goals|water entries)$',
    ).firstMatch(lower);
    if (more != null) {
      if (_list != more.group(1)) {
        return const RiyaResolution(
          message:
              'Choose that list first so I know which results to continue.',
        );
      }
      _offset += 3;
      return _page();
    }
    final budget = RegExp(
      r'^set (?:my )?(?:monthly )?budget(?: for (.+?))? (?:to )?[₹]?([\d,]+(?:\.\d{1,2})?)(?: daily [₹]?([\d,]+(?:\.\d{1,2})?))?$',
    ).firstMatch(prompt.trim().toLowerCase());
    if (budget != null) {
      return RiyaResolution(
        command: RiyaCommand('budgets.set', {
          'monthlyLimit': _money(budget.group(2)!),
          if (budget.group(1) != null) 'category': budget.group(1)!,
          if (budget.group(3) != null) 'dailyLimit': _money(budget.group(3)!),
        }),
      );
    }
    final budgetEdit = RegExp(
      r'^(?:edit|change) budget #(\d+) (monthly|daily) (?:to )?[₹]?([\d,]+(?:\.\d{1,2})?)$',
    ).firstMatch(lower);
    if (budgetEdit != null) {
      return RiyaResolution(
        command: RiyaCommand('budgets.edit', {
          'id': int.parse(budgetEdit.group(1)!),
          budgetEdit.group(2) == 'monthly' ? 'monthlyLimit' : 'dailyLimit':
              _money(budgetEdit.group(3)!),
        }),
      );
    }
    final goal = RegExp(
      r'^(?:create|add) (?:a )?savings goal (.+?) (?:target|for) [₹]?([\d,]+(?:\.\d{1,2})?)$',
      caseSensitive: false,
    ).firstMatch(prompt.trim());
    if (goal != null) {
      return RiyaResolution(
        command: RiyaCommand('savings.create', {
          'title': goal.group(1)!.trim(),
          'targetAmount': _money(goal.group(2)!),
        }),
      );
    }
    final contribution = RegExp(
      r'^add [₹]?([\d,]+(?:\.\d{1,2})?) to (?:savings )?goal #(\d+)$',
    ).firstMatch(lower);
    if (contribution != null) {
      return RiyaResolution(
        command: RiyaCommand('savings.contribute', {
          'id': int.parse(contribution.group(2)!),
          'amount': _money(contribution.group(1)!),
        }),
      );
    }
    final edit = RegExp(
      r'^(?:edit|change) savings goal #(\d+) (title|target|saved|date) (?:to )?(.+)$',
      caseSensitive: false,
    ).firstMatch(prompt.trim());
    if (edit != null) {
      final field = edit.group(2)!.toLowerCase(), value = edit.group(3)!.trim();
      final key = {
        'title': 'title',
        'target': 'targetAmount',
        'saved': 'savedAmount',
        'date': 'targetDate',
      }[field]!;
      final amount = double.tryParse(
        value.replaceAll('₹', '').replaceAll(',', ''),
      );
      if ((field == 'target' || field == 'saved') && amount == null) {
        return const RiyaResolution(message: 'Use a numeric amount in rupees.');
      }
      return RiyaResolution(
        command: RiyaCommand('savings.edit', {
          'id': int.parse(edit.group(1)!),
          key: field == 'target' || field == 'saved' ? amount : value,
        }),
      );
    }
    final clear = RegExp(
      r'^clear date (?:on|for) savings goal #(\d+)$',
    ).firstMatch(lower);
    if (clear != null) {
      return RiyaResolution(
        command: RiyaCommand('savings.edit', {
          'id': int.parse(clear.group(1)!),
          'clearDate': true,
        }),
      );
    }
    final deletion = RegExp(
      r'^(?:delete|remove) (budget|savings goal|water entry) #(\d+)$',
    ).firstMatch(lower);
    if (deletion != null) {
      return RiyaResolution(
        command: RiyaCommand(
          switch (deletion.group(1)) {
            'budget' => 'budgets.delete',
            'savings goal' => 'savings.delete',
            _ => 'hydration.delete',
          },
          {'id': int.parse(deletion.group(2)!)},
        ),
      );
    }
    final waterEdit = RegExp(
      r'^(?:edit|correct|change) water entry #(\d+) (?:to )?(\d+)\s*ml$',
    ).firstMatch(lower);
    if (waterEdit != null) {
      return RiyaResolution(
        command: RiyaCommand('hydration.edit', {
          'id': int.parse(waterEdit.group(1)!),
          'amountMl': int.parse(waterEdit.group(2)!),
        }),
      );
    }
    final waterGoal = RegExp(
      r'^set (?:my )?(?:daily )?water goal (?:to )?(\d+)\s*ml$',
    ).firstMatch(lower);
    if (waterGoal != null) {
      return RiyaResolution(
        command: RiyaCommand('hydration.goal', {
          'amountMl': int.parse(waterGoal.group(1)!),
        }),
      );
    }
    return null;
  }

  double _money(String text) => double.parse(text.replaceAll(',', ''));
  RiyaResolution _page() => RiyaResolution(
    command: RiyaCommand(
      switch (_list) {
        'budgets' => 'budgets.list',
        'savings goals' => 'savings.list',
        _ => 'hydration.logs',
      },
      {
        'offset': _offset,
        if (_list == 'water entries' && _waterDay != null)
          'day': _waterDay!.toIso8601String(),
      },
    ),
  );
}
