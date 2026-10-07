import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';

class AddActivitySheet extends ConsumerStatefulWidget {
  final Task? existingTask;
  final String? initialTitle;
  final ActivityKind? initialKind;
  final int? initialDurationMinutes;

  const AddActivitySheet({
    super.key,
    this.existingTask,
    this.initialTitle,
    this.initialKind,
    this.initialDurationMinutes,
  });

  static Future<void> show(
    BuildContext context, {
    Task? existingTask,
    String? initialTitle,
    ActivityKind? initialKind,
    int? initialDurationMinutes,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddActivitySheet(
        existingTask: existingTask,
        initialTitle: initialTitle,
        initialKind: initialKind,
        initialDurationMinutes: initialDurationMinutes,
      ),
    );
  }

  @override
  ConsumerState<AddActivitySheet> createState() => _AddActivitySheetState();
}

class _AddActivitySheetState extends ConsumerState<AddActivitySheet> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  final _customDurationController = TextEditingController();

  late ActivityKind _kind;
  int _targetMinutes = 30;
  bool _isCustomDuration = false;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _hasReminder = false;
  String _priority = 'medium';

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind ?? ActivityKind.todo;

    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialDurationMinutes != null && widget.initialDurationMinutes! > 0) {
      _kind = ActivityKind.duration;
      _targetMinutes = widget.initialDurationMinutes!;
    }

    if (widget.existingTask != null) {
      final t = widget.existingTask!;
      _titleController.text = t.title;
      _notesController.text = t.notes ?? '';
      _selectedDate = t.plannedDate ?? DateTime.now();
      _priority = t.priority;
      if (t.estimatedMinutes != null && t.estimatedMinutes! > 0) {
        _kind = ActivityKind.duration;
        _targetMinutes = t.estimatedMinutes!;
      } else if (t.estimatedMinutes == -1) {
        _kind = ActivityKind.flexible;
      } else {
        _kind = ActivityKind.todo;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    HapticFeedback.mediumImpact();
    final taskDao = ref.read(taskDaoProvider);

    int? estMinutes;
    if (_kind == ActivityKind.duration) {
      estMinutes = _isCustomDuration
          ? (int.tryParse(_customDurationController.text.trim()) ?? 30)
          : _targetMinutes;
      if (estMinutes <= 0) estMinutes = 30;
    } else if (_kind == ActivityKind.flexible) {
      estMinutes = -1;
    } else {
      estMinutes = null;
    }

    // Merge date and time if reminder is set
    DateTime plannedDateTime = _selectedDate;
    if (_hasReminder) {
      plannedDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
    }

    int taskId;
    if (widget.existingTask != null) {
      taskId = widget.existingTask!.id;
      await taskDao.updateTask(
        TaskTableCompanion(
          id: drift.Value(taskId),
          title: drift.Value(title),
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
          plannedDate: drift.Value(plannedDateTime),
          priority: drift.Value(_priority),
          estimatedMinutes: drift.Value(estMinutes),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
      );
    } else {
      taskId = await taskDao.insertTask(
        TaskTableCompanion.insert(
          title: title,
          notes: drift.Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
          plannedDate: drift.Value(plannedDateTime),
          priority: drift.Value(_priority),
          estimatedMinutes: drift.Value(estMinutes),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
      );
    }

    // Schedule reminder if toggled
    if (_hasReminder && plannedDateTime.isAfter(DateTime.now())) {
      try {
        final reminderDao = ref.read(reminderDaoProvider);
        final reminderId = await reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: title,
            scheduledAt: plannedDateTime,
            isActive: const drift.Value(true),
          ),
        );
        await NotificationService.instance.scheduleReminderNotification(
          id: reminderId,
          title: title,
          scheduledAt: plannedDateTime,
        );
      } catch (_) {}
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingTask != null ? 'Activity updated' : 'Activity added to hub'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: context.divider.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingTask != null ? 'Edit Activity' : 'Add Activity',
                      style: AscentTextStyles.displaySmall.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22),
                      color: context.textMuted,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 1. What do you want to do?
                Text(
                  'What do you want to do?',
                  style: AscentTextStyles.labelMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  autofocus: widget.existingTask == null,
                  textCapitalization: TextCapitalization.sentences,
                  style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g., Buy groceries, Exercise, Study Java, Meditate',
                    hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.divider.withValues(alpha: 0.8)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: context.accentPrimary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Activity Type Selector (Progressive Disclosure)
                Text(
                  'Activity Type',
                  style: AscentTextStyles.labelMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _TypeSelectChip(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'To-do',
                      subtitle: 'Simple task',
                      isSelected: _kind == ActivityKind.todo,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _kind = ActivityKind.todo);
                      },
                    ),
                    const SizedBox(width: 8),
                    _TypeSelectChip(
                      icon: Icons.timer_outlined,
                      label: 'Timed',
                      subtitle: 'Track duration',
                      isSelected: _kind == ActivityKind.duration,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _kind = ActivityKind.duration);
                      },
                    ),
                    const SizedBox(width: 8),
                    _TypeSelectChip(
                      icon: Icons.all_inclusive_rounded,
                      label: 'Flexible',
                      subtitle: 'Track as you go',
                      isSelected: _kind == ActivityKind.flexible,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _kind = ActivityKind.flexible);
                      },
                    ),
                  ],
                ),

                // 3. Progressive Target Duration (Shown only when Timed is selected)
                if (_kind == ActivityKind.duration) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Target Duration',
                    style: AscentTextStyles.labelMedium.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mins in [15, 30, 45, 60, 90])
                        ChoiceChip(
                          label: Text('$mins min'),
                          selected: !_isCustomDuration && _targetMinutes == mins,
                          selectedColor: context.accentPrimary.withValues(alpha: 0.15),
                          side: BorderSide(
                            color: (!_isCustomDuration && _targetMinutes == mins)
                                ? context.accentPrimary
                                : context.divider,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (!_isCustomDuration && _targetMinutes == mins)
                                ? context.accentPrimary
                                : context.textPrimary,
                          ),
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _isCustomDuration = false;
                              _targetMinutes = mins;
                            });
                          },
                        ),
                      ChoiceChip(
                        label: const Text('Custom'),
                        selected: _isCustomDuration,
                        selectedColor: context.accentPrimary.withValues(alpha: 0.15),
                        side: BorderSide(
                          color: _isCustomDuration ? context.accentPrimary : context.divider,
                        ),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _isCustomDuration ? context.accentPrimary : context.textPrimary,
                        ),
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _isCustomDuration = true);
                        },
                      ),
                    ],
                  ),
                  if (_isCustomDuration) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'Enter duration in minutes (e.g. 120)',
                        hintStyle: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 16),

                // 4. Scheduling & Date
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'When should it happen?',
                            style: AscentTextStyles.labelMedium.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              ChoiceChip(
                                label: const Text('Today'),
                                selected: DateUtils.isSameDay(_selectedDate, DateTime.now()),
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedDate = DateTime.now());
                                },
                              ),
                              const SizedBox(width: 6),
                              ChoiceChip(
                                label: const Text('Tomorrow'),
                                selected: DateUtils.isSameDay(
                                  _selectedDate,
                                  DateTime.now().add(const Duration(days: 1)),
                                ),
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedDate = DateTime.now().add(const Duration(days: 1)));
                                },
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(Icons.calendar_today_rounded, size: 20),
                                color: context.accentPrimary,
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 5. Reminder Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.divider.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 20, color: context.accentPrimary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Remind me',
                              style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
                            ),
                            if (_hasReminder)
                              Text(
                                '${DateFormat('MMM d').format(_selectedDate)} at ${_selectedTime.format(context)}',
                                style: AscentTextStyles.captionMedium.copyWith(color: context.accentPrimary),
                              ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _hasReminder,
                        activeTrackColor: context.accentPrimary,
                        onChanged: (val) async {
                          if (val) {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: _selectedTime,
                            );
                            if (pickedTime != null) {
                              setState(() {
                                _selectedTime = pickedTime;
                                _hasReminder = true;
                              });
                            }
                          } else {
                            setState(() => _hasReminder = false);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 6. Priority & Notes (Collapsible)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Priority & Notes',
                      style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                    ),
                    children: [
                      Row(
                        children: [
                          Text('Priority: ', style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted)),
                          const SizedBox(width: 8),
                          for (final p in ['low', 'medium', 'high'])
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(p.toUpperCase()),
                                selected: _priority == p,
                                selectedColor: p == 'high'
                                    ? context.stateDanger.withValues(alpha: 0.15)
                                    : context.accentPrimary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _priority == p ? context.textPrimary : context.textMuted,
                                ),
                                onSelected: (_) => setState(() => _priority = p),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Add notes or description (optional)',
                          hintStyle: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF141720) : const Color(0xFFF7F6F2),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Save button
                AscentButton.primary(
                  label: widget.existingTask != null ? 'Save Changes' : 'Create Activity',
                  icon: widget.existingTask != null ? Icons.check_rounded : Icons.add_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeSelectChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeSelectChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? context.accentPrimary.withValues(alpha: 0.12)
                : context.bgBase,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? context.accentPrimary
                  : context.divider.withValues(alpha: 0.6),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? context.accentPrimary : context.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AscentTextStyles.labelMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isSelected ? context.textPrimary : context.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
