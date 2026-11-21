import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/medicine/medicine_catalog.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/undo_snackbar.dart';
import '../../shared/widgets/ascent_dialog.dart';
import 'care_forms.dart';
import 'medicine_editor_sheet.dart';

/// Quick add: pick the kind (medicine, homeopathic, ayurvedic, supplement),
/// tap a popular one or type the whole prescription line, and the rest is
/// filled from what Ascent knows. "Save and add another" keeps the sheet
/// open so a whole shelf goes in one sitting. Returns the last new id.
Future<int?> showMedicineQuickAdd(BuildContext context) => showAscentSheet<int>(
  context: context,
  builder: (_) => const MedicineQuickAddSheet(),
);

class MedicineQuickAddSheet extends ConsumerStatefulWidget {
  const MedicineQuickAddSheet({super.key, this.clock});
  final DateTime Function()? clock;

  @override
  ConsumerState<MedicineQuickAddSheet> createState() =>
      _MedicineQuickAddSheetState();
}

class _MedicineQuickAddSheetState extends ConsumerState<MedicineQuickAddSheet> {
  final _text = TextEditingController();
  final _name = TextEditingController();
  final _strength = TextEditingController();
  final _stock = TextEditingController();
  final _amount = TextEditingController();
  MedicineSystem _system = MedicineSystem.allopathy;
  int? _lastId;
  int _addedCount = 0;

  /// Who the medicine is for. "Me" keeps it outside any care plan.
  String _person = 'Me';
  final List<String> _extraPeople = [];
  MedicineDraft? _draft;
  bool _picked = false;
  bool _saving = false;

  static const _days = [3, 5, 7, 14, 30, 90];
  static const _weeks = [28, 56, 84, 90];

  static List<int> _dayChoices(MedicineDraft d) =>
      d.frequency == DoseFrequency.weekly ? _weeks : _days;

  static String _hint(MedicineSystem s) => switch (s) {
    MedicineSystem.allopathy => 'e.g. Dolo 650 twice a day after food, 5 days',
    MedicineSystem.homeopathy => 'e.g. Arnica 30C, 4 pills thrice daily',
    MedicineSystem.ayurveda => 'e.g. Triphala churna 1 tsp at bedtime',
    MedicineSystem.supplement => 'e.g. Vitamin D3 60K once a week',
  };

  static String _cap(String f) => '${f[0].toUpperCase()}${f.substring(1)}';

  @override
  void initState() {
    super.initState();
    _text.addListener(_onType);
  }

  @override
  void dispose() {
    _text.dispose();
    _name.dispose();
    _strength.dispose();
    _stock.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _onType() {
    if (_picked) return;
    final t = _text.text.trim();
    setState(() {
      if (t.isEmpty) {
        _draft = null;
        return;
      }
      _draft = parseMedicineText(t, hint: _system);
      _fillFields(_draft!);
    });
  }

  void _fillFields(MedicineDraft d) {
    _name.text = d.name;
    _strength.text = d.strength;
    _amount.text = d.amount;
    _system = d.system;
  }

  void _chooseSystem(MedicineSystem s) {
    HapticFeedback.selectionClick();
    setState(() {
      _system = s;
      if (_draft != null) {
        _draft = _draft!.withSystem(s);
        _amount.text = _draft!.amount;
      }
    });
  }

  void _pick(KnownMedicine m) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _picked = true;
      // Keep anything else the user already typed (timing, days).
      final typed = parseMedicineText('${m.name} ${_text.text}');
      _draft = typed;
      _fillFields(typed);
    });
  }

  /// Back to an empty sheet for the next one; keeps kind and person.
  void _reset() {
    _text.clear();
    _name.clear();
    _strength.clear();
    _amount.clear();
    _stock.clear();
    setState(() {
      _draft = null;
      _picked = false;
      _saving = false;
    });
  }

  void _set(MedicineDraft Function(MedicineDraft d) change) {
    HapticFeedback.selectionClick();
    setState(() => _draft = change(_draft!));
  }

  Future<void> _save({bool another = false}) async {
    final d = _draft!.copyWith(
      name: _name.text.trim(),
      strength: _strength.text.trim(),
      amount: _amount.text.trim(),
    );
    if (d.name.isEmpty) {
      AscentSnackBar.error(context, message: 'Add the medicine’s name.');
      return;
    }
    final stock = _stock.text.trim().isEmpty
        ? null
        : int.tryParse(_stock.text.trim());
    if (_stock.text.trim().isNotEmpty && stock == null) {
      AscentSnackBar.error(context, message: 'Stock must be a whole number.');
      return;
    }
    setState(() => _saving = true);
    final service = ref.read(medicineServiceProvider);
    int? carePlanId;
    try {
      carePlanId = await _planFor(_person);
    } catch (_) {
      carePlanId = null;
    }
    final now = (widget.clock ?? DateTime.now)();
    try {
      final id = await service.addMedicine(
        name: d.name,
        dosage: d.dosage,
        scheduledTimes: d.frequency.times,
        durationDays: d.days,
        startDate: now,
        instructions: d.food == FoodTiming.any ? '' : d.food.label,
        type: d.form,
        purpose: d.purpose,
        carePlanId: carePlanId,
        stockCount: stock,
        system: d.system.name,
        everyDays: d.everyDays,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _lastId = id;
      _addedCount++;
      showUndoSnackbar(
        context,
        message: '${d.name} added · ${d.frequency.label.toLowerCase()}',
        onUndo: () => service.deleteMedicine(id),
      );
      if (another) {
        _reset();
      } else {
        Navigator.of(context).pop(id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AscentSnackBar.error(
        context,
        message: e is ArgumentError
            ? '${e.message}'
            : 'Could not add the medicine. Try again.',
      );
    }
  }

  /// The care plan that holds [person]'s medicines, created when needed.
  Future<int?> _planFor(String person) async {
    if (person == 'Me') return null;
    final plans = await ref.read(careRepositoryProvider).watchPlans().first;
    final existing = plans
        .where((p) => !p.isArchived && p.person == person)
        .firstOrNull;
    if (existing != null) return existing.id;
    return ref
        .read(careRepositoryProvider)
        .savePlan(
          title: 'Medicines for $person',
          person: person,
          clinician: '',
          notes: '',
        );
  }

  Future<void> _addPerson() async {
    final name = await showAscentFrostedDialog<String>(
      context: context,
      builder: (_) => const _PersonDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    setState(() {
      if (!_extraPeople.contains(name.trim())) _extraPeople.add(name.trim());
      _person = name.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final d = _draft;
    final people = <String>{
      'Me',
      ...?ref
          .watch(carePlansProvider)
          .value
          ?.where((p) => !p.isArchived && p.person != 'My care')
          .map((p) => p.person),
      ..._extraPeople,
    }.toList();
    final suggestions = _picked
        ? const <KnownMedicine>[]
        : searchKnownMedicines(_text.text);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
      child: Text(
        text,
        style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
      ),
    );
    Widget chips<T>(
      List<T> values,
      T selected,
      String Function(T) name,
      void Function(T) onTap,
      String keyPrefix,
    ) => Wrap(
      spacing: AppSpace.s8,
      runSpacing: AppSpace.s8,
      children: [
        for (final v in values)
          AppChip(
            key: ValueKey('${keyPrefix}_$v'),
            label: name(v),
            isSelected: v == selected,
            onTap: () => onTap(v),
          ),
      ],
    );

    return SingleChildScrollView(
      key: const ValueKey('medicine_quick_add'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AscentButton.ghost(
                key: const ValueKey('medicine_quick_close'),
                label: _addedCount == 0 ? 'Cancel' : 'Done',
                compact: true,
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).pop(_lastId),
              ),
              Expanded(
                child: Text(
                  _addedCount == 0 ? 'Add medicine' : '$_addedCount added',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.dialogTitle.copyWith(color: g.ink),
                ),
              ),
              const SizedBox(width: 72),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final s in MedicineSystem.values)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpace.s8),
                    child: AppChip(
                      key: ValueKey('medicine_system_${s.name}'),
                      label: s.label,
                      icon: s.icon,
                      isSelected: _system == s,
                      onTap: () => _chooseSystem(s),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          if (_draft == null)
            Align(
              alignment: Alignment.centerLeft,
              child: AscentButton.ghost(
                key: const ValueKey('medicine_full_editor'),
                label: 'Custom times and care plan',
                compact: true,
                onPressed: () {
                  final nav = Navigator.of(context);
                  final parent = nav.context;
                  nav.pop();
                  showMedicineEditor(parent);
                },
              ),
            ),
          if (!_picked)
            AppTextField(
              key: const ValueKey('medicine_quick_text'),
              controller: _text,
              autofocus: true,
              hintText: _hint(_system),
              textCapitalization: TextCapitalization.sentences,
            ),
          if (_draft == null) ...[
            label(
              'Popular ${_system == MedicineSystem.allopathy ? 'medicines' : _system.label.toLowerCase()}',
            ),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final m in popularFor(_system))
                  AppChip(
                    key: ValueKey('medicine_popular_${m.name}'),
                    label: m.name,
                    onTap: () => _pick(m),
                  ),
              ],
            ),
          ],
          for (final m in suggestions)
            InkWell(
              key: ValueKey('medicine_suggestion_${m.name}'),
              onTap: () => _pick(m),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s8,
                  ),
                  child: Row(
                    children: [
                      Icon(m.system.icon, color: g.actionInk),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.strength.isEmpty
                                  ? m.name
                                  : '${m.name} · ${m.strength}',
                              style: AscentTextStyles.body.copyWith(
                                color: g.ink,
                              ),
                            ),
                            Text(
                              '${m.purpose} · ${m.frequency.label.toLowerCase()}',
                              style: AscentTextStyles.caption.copyWith(
                                color: g.inkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (d != null) ...[
            label('Medicine'),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: AppTextField(
                    key: const ValueKey('medicine_quick_name'),
                    controller: _name,
                    hintText: 'Name',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  flex: 2,
                  child: AppTextField(
                    key: const ValueKey('medicine_quick_strength'),
                    controller: _strength,
                    hintText: d.system == MedicineSystem.homeopathy
                        ? 'Potency, e.g. 30C'
                        : 'e.g. 500 mg',
                  ),
                ),
              ],
            ),
            label('Form'),
            chips<String>(
              d.system.forms,
              d.form,
              _cap,
              (f) => _set((x) {
                // A new form brings its usual amount unless one was typed.
                final typed = _amount.text.trim();
                final usual = defaultAmountFor(f);
                if (typed.isEmpty || typed == defaultAmountFor(x.form)) {
                  _amount.text = usual;
                }
                return x.copyWith(form: f, amount: _amount.text);
              }),
              'medicine_form',
            ),
            label('How much each time'),
            AppTextField(
              key: const ValueKey('medicine_quick_amount'),
              controller: _amount,
              hintText: d.system == MedicineSystem.homeopathy
                  ? 'e.g. 4 pills'
                  : d.form == 'syrup'
                  ? 'e.g. 10 ml'
                  : 'e.g. 1 tablet',
            ),
            label('When'),
            chips<DoseFrequency>(
              DoseFrequency.values,
              d.frequency,
              (f) => f.label,
              (f) => _set(
                (x) => x.copyWith(
                  frequency: f,
                  // Weekly over a few days would be a single dose.
                  days: f == DoseFrequency.weekly && x.days < 28 ? 56 : null,
                ),
              ),
              'medicine_freq',
            ),
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s8),
              child: Text(
                'Reminders at ${d.frequency.times.map((t) => TimeOfDay(hour: int.parse(t.substring(0, 2)), minute: int.parse(t.substring(3))).format(context)).join(', ')}',
                key: const ValueKey('medicine_quick_times'),
                style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
              ),
            ),
            label('Food'),
            chips<FoodTiming>(
              FoodTiming.values,
              d.food,
              (f) => f.label,
              (f) => _set((x) => x.copyWith(food: f)),
              'medicine_food',
            ),
            label('How long'),
            chips<int>(
              _dayChoices(d),
              _dayChoices(d).contains(d.days) ? d.days : -1,
              (n) => n == 90
                  ? 'Ongoing'
                  : d.frequency == DoseFrequency.weekly
                  ? '${n ~/ 7} weeks'
                  : '$n days',
              (n) => _set((x) => x.copyWith(days: n)),
              'medicine_days',
            ),
            if (!_dayChoices(d).contains(d.days))
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s8),
                child: Text(
                  '${d.days} days, as you typed',
                  style: AscentTextStyles.caption.copyWith(
                    color: g.inkSecondary,
                  ),
                ),
              ),
            label('Who it’s for'),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final p in people)
                  AppChip(
                    key: ValueKey('medicine_person_$p'),
                    label: p,
                    isSelected: _person == p,
                    onTap: () => setState(() => _person = p),
                  ),
                AppChip(
                  key: const ValueKey('medicine_person_add'),
                  label: 'Someone else',
                  icon: Icons.add_rounded,
                  onTap: _addPerson,
                ),
              ],
            ),
            label('How many do you have? (optional)'),
            AppTextField(
              key: const ValueKey('medicine_quick_stock'),
              controller: _stock,
              keyboardType: TextInputType.number,
              hintText: d.form == 'syrup' ? 'e.g. 100 (ml)' : 'e.g. 15',
            ),
            const SizedBox(height: AppSpace.s16),
            Text(
              d.known != null
                  ? 'Usual timing for ${d.known!.name} filled in. ${d.system.tip} Change anything here.'
                  : '${d.system.tip} Change anything here.',
              style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
            ),
            const SizedBox(height: AppSpace.s12),
            AscentButton.primary(
              key: const ValueKey('medicine_quick_save'),
              label:
                  'Add ${d.system == MedicineSystem.supplement ? 'supplement' : 'medicine'}',
              expanded: true,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: AppSpace.s8),
            AscentButton.ghost(
              key: const ValueKey('medicine_quick_save_another'),
              label: 'Save and add another',
              expanded: true,
              onPressed: _saving ? null : () => _save(another: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog();
  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AscentDialog(
    title: 'Who is it for?',
    contentWidget: AppTextField(
      key: const ValueKey('medicine_person_name'),
      controller: _c,
      autofocus: true,
      hintText: 'e.g. Mum',
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => setState(() {}),
      onSubmitted: (v) {
        if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
      },
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpace.s8,
        children: [
          AscentButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AscentButton.tonal(
            key: const ValueKey('medicine_person_save'),
            label: 'Add',
            compact: true,
            onPressed: _c.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, _c.text.trim()),
          ),
        ],
      ),
    ],
  );
}
