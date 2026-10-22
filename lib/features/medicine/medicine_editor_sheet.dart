import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';

Future<void> showMedicineEditor(BuildContext context, {Medicine? medicine}) =>
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (_) => MedicineEditorSheet(medicine: medicine),
    );

/// Edits a persisted medicine schedule; scheduling and dose history stay in the
/// shared MedicineService used by Today and reminders.
class MedicineEditorSheet extends ConsumerStatefulWidget {
  const MedicineEditorSheet({super.key, this.medicine});
  final Medicine? medicine;

  @override
  ConsumerState<MedicineEditorSheet> createState() =>
      _MedicineEditorSheetState();
}

class _MedicineEditorSheetState extends ConsumerState<MedicineEditorSheet> {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  final _schedule = GlobalKey();
  late final _name = TextEditingController(text: widget.medicine?.name ?? '');
  late final _dosage = TextEditingController(
    text: widget.medicine?.dosage ?? '',
  );
  late final _instructions = TextEditingController(
    text: widget.medicine?.instructions ?? '',
  );
  late final _days = TextEditingController(
    text: '${widget.medicine?.durationDays ?? 7}',
  );
  late String _type = widget.medicine?.type ?? 'tablet';
  late DateTime _start = widget.medicine?.startDate ?? DateTime.now();
  late final List<String?> _times = _initialTimes();
  bool _saving = false;
  String? _error;

  List<String?> _initialTimes() {
    if (widget.medicine == null) return [null];
    try {
      final values =
          (jsonDecode(widget.medicine!.scheduledTimes) as List).cast<String>()
            ..sort();
      if (values.isNotEmpty) return <String?>[...values];
    } catch (_) {
      /* A new or damaged schedule starts with an explicit time choice. */
    }
    return [null];
  }

  @override
  void dispose() {
    _scroll.dispose();
    _name.dispose();
    _dosage.dispose();
    _instructions.dispose();
    _days.dispose();
    super.dispose();
  }

  void _count(int count) => setState(() {
    if (_times.length > count) _times.removeRange(count, _times.length);
    while (_times.length < count) {
      _times.add(null);
    }
    _error = null;
  });

  Future<void> _pickTime(int index) async {
    FocusScope.of(context).unfocus();
    final parts = _times[index]?.split(':');
    final value = await showTimePicker(
      context: context,
      initialTime: parts == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      helpText: 'Time for dose ${index + 1}',
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (value == null || !mounted) return;
    final time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    if (_times.asMap().entries.any(
      (entry) => entry.key != index && entry.value == time,
    )) {
      setState(
        () => _error =
            'That time is already added. Choose a different time for this dose.',
      );
      return;
    }
    setState(() {
      _times[index] = time;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _form.currentState!.validate();
    if (!valid) {
      FocusScope.of(context).unfocus();
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    if (_times.any((time) => time == null)) {
      setState(() => _error = 'Choose an exact time for every dose.');
      FocusScope.of(context).unfocus();
      Scrollable.ensureVisible(
        _schedule.currentContext!,
        duration: const Duration(milliseconds: 250),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service = ref.read(medicineServiceProvider);
      final times = _times.cast<String>();
      final days = int.parse(_days.text.trim());
      if (widget.medicine == null) {
        await service.addMedicine(
          name: _name.text,
          dosage: _dosage.text,
          scheduledTimes: times,
          durationDays: days,
          startDate: _start,
          instructions: _instructions.text.trim(),
          type: _type,
        );
      } else {
        await service.updateMedicine(
          widget.medicine!.id,
          name: _name.text,
          dosage: _dosage.text,
          scheduledTimes: times,
          durationDays: days,
          startDate: _start,
          instructions: _instructions.text.trim(),
          type: _type,
        );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _saving = false);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${_name.text.trim()} · ${times.length} daily dose${times.length == 1 ? '' : 's'}.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save your medicine. Your changes are still here; try again.';
        });
      }
    }
  }

  Widget _section(String number, String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$number  $title',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(color: context.glass.inkMuted, height: 1.4),
            ),
          ),
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    required String fieldKey,
    String? hint,
    int? maxLength,
    int lines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.glass.inkSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey(fieldKey),
            controller: controller,
            enabled: !_saving,
            minLines: 1,
            maxLines: lines,
            maxLength: maxLength,
            textCapitalization: keyboard == null
                ? TextCapitalization.sentences
                : TextCapitalization.none,
            keyboardType: keyboard,
            inputFormatters: formatters,
            validator: validator,
            onChanged: controller == _days ? (_) => setState(() {}) : null,
            style: TextStyle(color: context.glass.ink, height: 1.5),
            cursorColor: context.glass.inkSecondary,
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              filled: true,
              fillColor: context.bgSurfaceElevated,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: context.glass.inkMuted.withValues(alpha: .4),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: context.glass.inkSecondary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final days = int.tryParse(_days.text.trim());
    final end = days == null || days < 1
        ? null
        : DateTime(_start.year, _start.month, _start.day + days - 1);
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.medicine == null
                                  ? 'Add medicine'
                                  : 'Edit medicine',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your medicine, your schedule',
                              style: TextStyle(color: g.inkMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close medicine form',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _section('01', 'Medicine details'),
                          _field(
                            'Medicine name',
                            _name,
                            fieldKey: 'medicine_name',
                            hint: 'Name on your prescription',
                            lines: 3,
                            maxLength: 200,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the medicine name.'
                                : null,
                          ),
                          _field(
                            'Dose',
                            _dosage,
                            fieldKey: 'medicine_dosage',
                            hint: 'e.g. 1 tablet or 5 ml',
                            lines: 2,
                            maxLength: 100,
                            validator: (value) =>
                                value == null || value.trim().isEmpty
                                ? 'Enter the dose from your prescription.'
                                : null,
                          ),
                          const Text(
                            'Form',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: _type,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(16),
                            ),
                            items: [
                              for (final type in [
                                'tablet',
                                'capsule',
                                'syrup',
                                'drops',
                                'injection',
                              ])
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    '${type[0].toUpperCase()}${type.substring(1)}',
                                  ),
                                ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => setState(() => _type = value!),
                          ),
                          KeyedSubtree(
                            key: _schedule,
                            child: _section(
                              '02',
                              'Daily dose times',
                              subtitle:
                                  'Set each time exactly as you need it. These times repeat every day of the course.',
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final count in [1, 2, 3, 4])
                                ChoiceChip(
                                  label: Text(
                                    '$count dose${count == 1 ? '' : 's'}',
                                  ),
                                  selected: _times.length == count,
                                  onSelected: _saving
                                      ? null
                                      : (_) => _count(count),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          for (var i = 0; i < _times.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      key: ValueKey('medicine_time_$i'),
                                      onPressed: _saving
                                          ? null
                                          : () => _pickTime(i),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.all(14),
                                        alignment: Alignment.centerLeft,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Dose ${i + 1}',
                                            style: TextStyle(color: g.inkMuted),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _times[i] == null
                                                      ? 'Choose time'
                                                      : TimeOfDay(
                                                          hour: int.parse(
                                                            _times[i]!.split(
                                                              ':',
                                                            )[0],
                                                          ),
                                                          minute: int.parse(
                                                            _times[i]!.split(
                                                              ':',
                                                            )[1],
                                                          ),
                                                        ).format(context),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: g.ink,
                                                  ),
                                                ),
                                              ),
                                              const Icon(
                                                Icons.schedule_rounded,
                                                size: 20,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (_times.length > 1)
                                    IconButton(
                                      tooltip: 'Remove dose ${i + 1}',
                                      onPressed: _saving
                                          ? null
                                          : () => setState(() {
                                              _times.removeAt(i);
                                              _error = null;
                                            }),
                                      icon: const Icon(
                                        Icons.remove_circle_outline_rounded,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          if (_times.length < 10)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _saving
                                    ? null
                                    : () => _count(_times.length + 1),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add another time'),
                              ),
                            ),
                          _section('03', 'Course & instructions'),
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    FocusScope.of(context).unfocus();
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _start,
                                      firstDate: DateTime(2000),
                                      lastDate: DateTime(
                                        DateTime.now().year + 5,
                                      ),
                                    );
                                    if (date != null && mounted) {
                                      setState(() => _start = date);
                                    }
                                  },
                            icon: const Icon(Icons.calendar_today_outlined),
                            label: Text(
                              'Starts ${DateFormat.yMMMd().format(_start)}',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _field(
                            'Course length (days)',
                            _days,
                            fieldKey: 'medicine_days',
                            maxLength: 3,
                            keyboard: TextInputType.number,
                            formatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (value) {
                              final count = int.tryParse(value ?? '');
                              return count == null || count < 1 || count > 366
                                  ? 'Enter 1 to 366 days.'
                                  : null;
                            },
                          ),
                          if (end != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Last day · ${DateFormat.yMMMd().format(end)}',
                                style: TextStyle(color: g.inkMuted),
                              ),
                            ),
                          _field(
                            'Instructions (optional)',
                            _instructions,
                            fieldKey: 'medicine_instructions',
                            hint: 'Meal timing or notes from your prescription',
                            lines: 4,
                            maxLength: 2000,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  decoration: BoxDecoration(
                    color: context.bgSurface,
                    border: Border(top: BorderSide(color: g.line)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                        child: Text(
                          _saving
                              ? 'Saving…'
                              : widget.medicine == null
                              ? 'Save medicine'
                              : 'Update Prescription',
                          textAlign: TextAlign.center,
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
    );
  }
}
