import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import 'medicine_time_dialog.dart';

Future<void> showMedicineEditor(BuildContext context, {Medicine? medicine}) =>
    showAscentCenteredForm<void>(
      context: context,
      maxWidth: 420,
      barrierDismissible: false,
      builder: (_) => MedicineEditorSheet(medicine: medicine),
    );

class MedicineEditorSheet extends ConsumerStatefulWidget {
  const MedicineEditorSheet({super.key, this.medicine, this.isDialog = true});
  final Medicine? medicine;
  final bool isDialog;
  @override
  ConsumerState<MedicineEditorSheet> createState() =>
      _MedicineEditorSheetState();
}

class _MedicineEditorSheetState extends ConsumerState<MedicineEditorSheet> {
  late final _name = TextEditingController(text: widget.medicine?.name);
  late final _dose = TextEditingController(text: widget.medicine?.dosage);
  late final _instructions = TextEditingController(
    text: widget.medicine?.instructions,
  );
  late final _type = TextEditingController(
    text: widget.medicine?.type ?? 'tablet',
  );
  late final _duration = TextEditingController(
    text: '${widget.medicine?.durationDays ?? 7}',
  );
  late List<String> _times;
  int _step = 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _times = widget.medicine == null
        ? ['09:00']
        : List<String>.from(
            jsonDecode(widget.medicine!.scheduledTimes) as List,
          );
  }

  @override
  void dispose() {
    for (final controller in [_name, _dose, _instructions, _duration, _type]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _validateDetails() {
    final valid = _name.text.trim().isNotEmpty && _dose.text.trim().isNotEmpty;
    setState(
      () => _error = valid
          ? null
          : 'Enter a medicine name and your prescribed dose.',
    );
    return valid;
  }

  Future<void> _pickTime(int index) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final parts = (index < _times.length ? _times[index] : '09:00').split(':');
    final time = await showAscentFrostedDialog<TimeOfDay>(
      context: context,
      builder: (_) => MedicineTimeDialog(
        initialTime: TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        ),
        dose: index + 1,
      ),
    );
    if (!mounted || time == null) return;
    final value =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (_times.asMap().entries.any((e) => e.key != index && e.value == value)) {
      setState(() => _error = 'That time is already on your schedule.');
      return;
    }
    setState(() {
      if (index == _times.length) {
        _times.add(value);
      } else {
        _times[index] = value;
      }
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_validateDetails()) {
      setState(() => _step = 0);
      return;
    }
    final days = int.tryParse(_duration.text);
    if (days == null || days < 1 || days > 3650 || _times.isEmpty) {
      setState(
        () => _error = 'Add a time and a duration between 1 and 3650 days.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(medicineServiceProvider);
      final times = [..._times]..sort();
      final med = widget.medicine;
      if (med == null) {
        await service.addMedicine(
          name: _name.text.trim(),
          dosage: _dose.text.trim(),
          scheduledTimes: times,
          durationDays: days,
          startDate: DateTime.now(),
          instructions: _instructions.text.trim(),
          type: _type.text.trim().isEmpty ? 'other' : _type.text.trim(),
        );
      } else {
        await service.updateMedicine(
          med.id,
          name: _name.text.trim(),
          dosage: _dose.text.trim(),
          scheduledTimes: times,
          durationDays: days,
          startDate: med.startDate,
          instructions: _instructions.text.trim(),
          type: _type.text.trim().isEmpty ? 'other' : _type.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save. Your details are still here.';
        });
      }
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType? keyboard,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: TextField(
      key: ValueKey(
        'medicine_${label == 'Medicine name'
            ? 'name'
            : label == 'Dose'
            ? 'dosage'
            : label == 'Instructions (optional)'
            ? 'instructions'
            : label == 'Form (optional)'
            ? 'type'
            : 'duration'}',
      ),
      controller: controller,
      enabled: !_saving,
      keyboardType: keyboard,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        filled: true,
        fillColor: context.glass.fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.glass.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: context.glass.line),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return PopScope(
      canPop: !_saving,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.medicine == null
                          ? 'Add medicine'
                          : 'Edit medicine',
                      style: TextStyle(
                        color: g.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              Text(
                'Your prescription, in your own words.',
                style: TextStyle(color: g.inkMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              AscentSegmentedControl<int>(
                segments: const [
                  AscentSegment(value: 0, label: 'Details'),
                  AscentSegment(value: 1, label: 'Schedule'),
                ],
                selected: _step,
                enabled: !_saving,
                accented: true,
                onChanged: (value) {
                  FocusManager.instance.primaryFocus?.unfocus();
                  setState(() {
                    _step = value;
                    _error = null;
                  });
                },
              ),
              if (_step == 0) ...[
                _field(
                  'Medicine name',
                  _name,
                  'Type any medicine or remedy',
                  maxLength: 200,
                ),
                _field(
                  'Dose',
                  _dose,
                  'As written on your prescription',
                  maxLength: 100,
                ),
                _field(
                  'Instructions (optional)',
                  _instructions,
                  'Food, water, or other notes',
                ),
              ] else ...[
                const SizedBox(height: 14),
                Text(
                  'Reminder times',
                  style: TextStyle(color: g.inkSecondary, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _times.length; i++)
                      InputChip(
                        key: ValueKey('medicine_time_$i'),
                        label: Text(_times[i]),
                        onPressed: _saving ? null : () => _pickTime(i),
                        onDeleted: _saving || _times.length == 1
                            ? null
                            : () => setState(() => _times.removeAt(i)),
                        backgroundColor: g.fill,
                        side: BorderSide(color: g.line),
                      ),
                    AscentButton.ghost(
                      label: 'Add time',
                      icon: Icons.add_rounded,
                      compact: true,
                      onPressed: _saving
                          ? null
                          : () => _pickTime(_times.length),
                    ),
                  ],
                ),
                _field(
                  'Duration (days)',
                  _duration,
                  'Number of days',
                  keyboard: TextInputType.number,
                ),
                _field(
                  'Form (optional)',
                  _type,
                  'Tablet, drops, syrup, or your own',
                ),
                const SizedBox(height: 10),
                Text(
                  '${_name.text.trim().isEmpty ? 'Medicine' : _name.text.trim()} · ${_dose.text.trim()}\n${_times.length} reminder${_times.length == 1 ? '' : 's'} each day',
                  style: TextStyle(
                    color: g.inkSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: SharedControlColors.dueRed),
                  ),
                ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                children: [
                  AscentButton.ghost(
                    label: _step == 0 ? 'Cancel' : 'Back',
                    compact: true,
                    onPressed: _saving
                        ? null
                        : () {
                            if (_step == 0) {
                              Navigator.pop(context);
                            } else {
                              setState(() => _step = 0);
                            }
                          },
                  ),
                  AscentButton.tonal(
                    label: _step == 0 ? 'Continue' : 'Save medicine',
                    compact: true,
                    loading: _saving,
                    onPressed: _saving
                        ? null
                        : () {
                            if (_step == 0) {
                              if (_validateDetails()) {
                                FocusManager.instance.primaryFocus?.unfocus();
                                setState(() => _step = 1);
                              }
                            } else {
                              _save();
                            }
                          },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
