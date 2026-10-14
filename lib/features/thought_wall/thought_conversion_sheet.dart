import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../shared/widgets/ascent_button.dart';
import 'thought_actions.dart';

Future<bool> showThoughtConversion(
  BuildContext context,
  AppDatabase db,
  List<Thought> thoughts, {
  ThoughtConversionMode initial = ThoughtConversionMode.todo,
  bool grouped = false,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => ThoughtConversionSheet(
        db: db,
        thoughts: thoughts,
        initial: initial,
        grouped: grouped,
      ),
    ) ??
    false;

class ThoughtConversionSheet extends StatefulWidget {
  const ThoughtConversionSheet({
    super.key,
    required this.db,
    required this.thoughts,
    required this.initial,
    this.grouped = false,
  });
  final AppDatabase db;
  final List<Thought> thoughts;
  final ThoughtConversionMode initial;
  final bool grouped;
  @override
  State<ThoughtConversionSheet> createState() => _ThoughtConversionSheetState();
}

class _ThoughtConversionSheetState extends State<ThoughtConversionSheet> {
  late ThoughtConversionMode _mode = widget.initial;
  late bool _grouped = widget.grouped;
  final _title = TextEditingController(text: 'Thought checklist');
  DateTime? _day;
  TimeOfDay? _time;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    DateTime? at;
    if (_mode != ThoughtConversionMode.todo) {
      if (_day == null || _time == null) {
        setState(() => _error = 'Choose a date and time.');
        return;
      }
      at = DateTime(
        _day!.year,
        _day!.month,
        _day!.day,
        _time!.hour,
        _time!.minute,
      );
      if (!at.isAfter(DateTime.now())) {
        setState(() => _error = 'Choose a future date and time.');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ThoughtActions(widget.db).convert(
        widget.thoughts,
        mode: _mode,
        grouped: _grouped,
        at: at,
        groupTitle: _title.text,
      );
      if (result.taskIds.isEmpty && result.reminders.isEmpty) {
        throw StateError('These notes are already done. Select active notes.');
      }
      String message =
          '${result.taskIds.length} Todo${result.taskIds.length == 1 ? '' : 's'} · ${result.reminders.length} reminder${result.reminders.length == 1 ? '' : 's'} saved';
      if (result.reminders.isNotEmpty) {
        try {
          final sync = await ReminderAlertSync.device(widget.db).sync(
            onlyPending: true,
            ids: result.reminders.map((r) => r.id).toList(),
          );
          if (!sync.complete) {
            message += '. Alerts pending; retry from Reminders.';
          }
        } catch (_) {
          message += '. Alerts pending; retry from Reminders.';
        }
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      HapticFeedback.lightImpact();
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ArgumentError
              ? 'Check the title and choose a future time.'
              : error is StateError
              ? error.message.toString()
              : 'Could not save. Your notes are still here.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return PopScope(
      canPop: !_saving,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        decoration: BoxDecoration(
          color: g.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: g.edge),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: g.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Turn thoughts into action',
                style: AscentTextStyles.displaySmall.copyWith(color: g.ink),
              ),
              const SizedBox(height: 6),
              Text(
                '${widget.thoughts.length} selected · your original notes stay here',
                style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ThoughtConversionMode.values
                    .map(
                      (mode) => ChoiceChip(
                        label: Text(switch (mode) {
                          ThoughtConversionMode.todo => 'Todo',
                          ThoughtConversionMode.reminder => 'Reminder',
                          ThoughtConversionMode.both => 'Both',
                        }),
                        selected: _mode == mode,
                        onSelected: _saving
                            ? null
                            : (_) => setState(() {
                                _mode = mode;
                                _error = null;
                              }),
                      ),
                    )
                    .toList(),
              ),
              if (widget.thoughts.length > 1) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Individual items'),
                      selected: !_grouped,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _grouped = false),
                    ),
                    ChoiceChip(
                      label: const Text('One grouped item'),
                      selected: _grouped,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _grouped = true),
                    ),
                  ],
                ),
                if (_grouped && _mode != ThoughtConversionMode.reminder) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _title,
                    enabled: !_saving,
                    maxLength: 300,
                    decoration: const InputDecoration(
                      labelText: 'Checklist title',
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              for (var i = 0; i < widget.thoughts.length.clamp(0, 5); i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${i + 1}. ${widget.thoughts[i].content}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.bodyMedium.copyWith(color: g.ink),
                  ),
                ),
              if (widget.thoughts.length > 5)
                Text(
                  'And ${widget.thoughts.length - 5} more selected notes',
                  style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
                ),
              if (_mode != ThoughtConversionMode.todo) ...[
                const SizedBox(height: 14),
                Text(
                  'When should I remind you?',
                  style: AscentTextStyles.labelMedium.copyWith(color: g.ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Today'),
                      selected: _day == today,
                      onSelected: _saving
                          ? null
                          : (_) => setState(() => _day = today),
                    ),
                    ChoiceChip(
                      label: const Text('Tomorrow'),
                      selected:
                          _day == DateTime(now.year, now.month, now.day + 1),
                      onSelected: _saving
                          ? null
                          : (_) => setState(
                              () => _day = DateTime(
                                now.year,
                                now.month,
                                now.day + 1,
                              ),
                            ),
                    ),
                    ActionChip(
                      label: const Text('Pick date'),
                      onPressed: _saving
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _day ?? today,
                                firstDate: today,
                                lastDate: DateTime(now.year + 5),
                              );
                              if (mounted && date != null) {
                                setState(() => _day = date);
                              }
                            },
                    ),
                  ],
                ),
                if (_day != null)
                  Text(
                    '${_day!.day}/${_day!.month}/${_day!.year}',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: g.inkMuted,
                    ),
                  ),
                TextButton.icon(
                  onPressed: _saving
                      ? null
                      : () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _time ?? TimeOfDay.now(),
                          );
                          if (mounted && time != null) {
                            setState(() => _time = time);
                          }
                        },
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(
                    _time == null ? 'Choose time' : _time!.format(context),
                  ),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    _error!,
                    style: AscentTextStyles.bodySmall.copyWith(color: g.coral),
                    semanticsLabel: _error,
                  ),
                ),
              const SizedBox(height: 12),
              AscentButton.primary(
                label: _saving ? 'Saving…' : 'Save action',
                expanded: true,
                onPressed: _saving ? null : _save,
              ),
              TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
