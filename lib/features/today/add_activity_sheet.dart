import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import 'add_lecture_activity_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';

class AddActivitySheet extends ConsumerStatefulWidget {
  final Task? existingTask;
  final String? initialTitle;
  final ActivityKind? initialKind;
  final int? initialDurationMinutes;
  final int? parentTaskId;
  final int? prefilledApplicationId;

  const AddActivitySheet({
    super.key,
    this.existingTask,
    this.initialTitle,
    this.initialKind,
    this.initialDurationMinutes,
    this.parentTaskId,
    this.prefilledApplicationId,
  });

  static Future<void> show(
    BuildContext context, {
    Task? existingTask,
    String? initialTitle,
    ActivityKind? initialKind,
    int? initialDurationMinutes,
    int? parentTaskId,
    int? prefilledApplicationId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppPalette.transparent,
      builder: (ctx) => AddActivitySheet(
        existingTask: existingTask,
        initialTitle: initialTitle,
        initialKind: initialKind,
        initialDurationMinutes: initialDurationMinutes,
        parentTaskId: parentTaskId,
        prefilledApplicationId: prefilledApplicationId,
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
    if (widget.initialDurationMinutes != null &&
        widget.initialDurationMinutes! > 0) {
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

      // Check if existing task has an active reminder
      Future.microtask(() async {
        try {
          final reminders = await ref
              .read(reminderDaoProvider)
              .watchAllReminders()
              .first;
          final existing = reminders
              .where((r) => r.linkedTaskId == t.id)
              .firstOrNull;
          if (existing != null && mounted) {
            setState(() {
              _hasReminder = true;
              _selectedDate = existing.scheduledAt;
              _selectedTime = TimeOfDay.fromDateTime(existing.scheduledAt);
            });
          }
        } catch (_) {}
      });
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
      final now = DateTime.now();
      if (plannedDateTime.isBefore(now)) {
        if (DateUtils.isSameDay(plannedDateTime, now)) {
          // If within the same minute (boundary condition when user takes seconds to type & save)
          if (now.difference(plannedDateTime).inMinutes <= 0) {
            plannedDateTime = now.add(const Duration(minutes: 1));
          } else {
            // Picked an earlier time today: automatically schedule for tomorrow at that time
            plannedDateTime = plannedDateTime.add(const Duration(days: 1));
          }
        } else {
          plannedDateTime = now.add(const Duration(minutes: 2));
        }
      }
    }

    int taskId;
    if (widget.existingTask != null) {
      taskId = widget.existingTask!.id;
      await taskDao.updateTask(
        TaskTableCompanion(
          id: drift.Value(taskId),
          title: drift.Value(title),
          notes: drift.Value(
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
          plannedDate: drift.Value(plannedDateTime),
          priority: drift.Value(_priority),
          estimatedMinutes: drift.Value(estMinutes),
          parentTaskId: drift.Value(
            widget.parentTaskId ?? widget.existingTask?.parentTaskId,
          ),
          linkedApplicationId: drift.Value(
            widget.prefilledApplicationId ??
                widget.existingTask?.linkedApplicationId,
          ),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
      );
    } else {
      taskId = await taskDao.insertTask(
        TaskTableCompanion.insert(
          title: title,
          notes: drift.Value(
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          ),
          plannedDate: drift.Value(plannedDateTime),
          priority: drift.Value(_priority),
          estimatedMinutes: drift.Value(estMinutes),
          parentTaskId: drift.Value(widget.parentTaskId),
          linkedApplicationId: drift.Value(widget.prefilledApplicationId),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
      );
    }

    final reminderDao = ref.read(reminderDaoProvider);

    // Clean up previous reminders for this activity to avoid duplicates
    if (widget.existingTask != null) {
      try {
        final linkedReminders = await reminderDao.getRemindersByTaskId(
          widget.existingTask!.id,
        );
        for (final r in linkedReminders) {
          await reminderDao.deleteReminder(r.id);
          await NotificationService.instance.cancel(r.id);
        }
        final allReminders = await reminderDao.watchAllReminders().first;
        for (final r in allReminders.where(
          (r) =>
              r.title.toLowerCase() ==
                  widget.existingTask!.title.toLowerCase() ||
              r.title.toLowerCase() == title.toLowerCase(),
        )) {
          await reminderDao.deleteReminder(r.id);
          await NotificationService.instance.cancel(r.id);
        }
      } catch (e) {
        debugPrint('Error cleaning up existing reminders: $e');
      }
    }

    // Schedule reminder if toggled
    if (_hasReminder) {
      try {
        final reminderId = await reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: title,
            scheduledAt: plannedDateTime,
            isActive: const drift.Value(true),
            linkedTaskId: drift.Value(taskId),
          ),
        );
        await NotificationService.instance.scheduleReminderNotification(
          id: reminderId,
          title: title,
          scheduledAt: plannedDateTime,
        );
        debugPrint(
          'Activity reminder saved: id=$reminderId title="$title" at $plannedDateTime linked to task $taskId',
        );
      } catch (e) {
        debugPrint('Error inserting reminder or scheduling notification: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AscentSnackBar.build(
          context,
          content: Text(
            widget.existingTask != null
                ? 'Activity updated'
                : 'Activity added to hub',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      nightDecoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: AppGeometry.radiusr24),
        border: Border.all(
          color: context.divider.withValues(alpha: 0.6),
          width: AppBorderScale.w1,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpace.s20,
            AppSpace.s16,
            AppSpace.s20,
            bottomInset + AppSpace.s16,
          ),
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
                      borderRadius: AppGeometry.roundedr2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.existingTask != null
                          ? 'Edit Activity'
                          : 'Add Activity',
                      style: AscentTextStyles.displaySmall
                          .copyWith(color: context.textPrimary)
                          .merge(AppTypeRoles.typeRole2),
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
                  style: AscentTextStyles.labelMedium
                      .copyWith(color: context.textPrimary)
                      .merge(AppTypeRoles.typeRole8),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleController,
                  autofocus: widget.existingTask == null,
                  textCapitalization: TextCapitalization.sentences,
                  style: AscentTextStyles.bodyMedium.copyWith(
                    color: context.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        'e.g., Buy groceries, Exercise, Study Java, Meditate',
                    hintStyle: AscentTextStyles.bodyMedium.copyWith(
                      color: context.textMuted,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppPalette.colorFF201A14
                        : AppPalette.colorFFF7F6F2,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s14,
                      vertical: AppSpace.s12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: AppGeometry.roundedr14,
                      borderSide: BorderSide(color: context.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppGeometry.roundedr14,
                      borderSide: BorderSide(
                        color: context.divider.withValues(alpha: 0.8),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppGeometry.roundedr14,
                      borderSide: BorderSide(
                        color: context.accentPrimary,
                        width: AppBorderScale.w1point5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Activity Type Selector (Progressive Disclosure)
                Text(
                  'Activity Type',
                  style: AscentTextStyles.labelMedium
                      .copyWith(color: context.textPrimary)
                      .merge(AppTypeRoles.typeRole8),
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

                if (widget.existingTask?.actualCompletedDate == null)
                  TextButton.icon(
                    icon: const Icon(Icons.school_outlined),
                    label: Text(
                      widget.existingTask == null
                          ? 'Plan a lecture instead'
                          : 'Convert to a course lecture',
                    ),
                    onPressed: () async {
                      final saved = await AddLectureActivitySheet.show(
                        context,
                        task: widget.existingTask,
                        title: _titleController.text,
                        minutes: _kind == ActivityKind.duration
                            ? _targetMinutes
                            : null,
                      );
                      if (saved && context.mounted) Navigator.pop(context);
                    },
                  ),

                // 3. Progressive Target Duration (Shown only when Timed is selected)
                if (_kind == ActivityKind.duration) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Target Duration',
                    style: AscentTextStyles.labelMedium
                        .copyWith(color: context.textPrimary)
                        .merge(AppTypeRoles.typeRole8),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final mins in [15, 30, 45, 60, 90])
                        Builder(
                          builder: (context) {
                            final isSel = !_isCustomDuration && _targetMinutes == mins;
                            return AppPill.choice(
                              label: Text('$mins min'),
                              selected: isSel,
                              selectedColor: context.accentPrimary,
                              side: BorderSide(
                                color: isSel
                                    ? context.accentPrimary
                                    : context.divider,
                              ),
                              labelStyle: AppTypeRoles.typeRole17.copyWith(
                                color: isSel
                                    ? AppPalette.white
                                    : context.textPrimary,
                                fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                              ),
                              onSelected: (_) {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _isCustomDuration = false;
                                  _targetMinutes = mins;
                                });
                              },
                            );
                          },
                        ),
                      Builder(
                        builder: (context) {
                          return AppPill.choice(
                            label: const Text('Custom'),
                            selected: _isCustomDuration,
                            selectedColor: context.accentPrimary,
                            side: BorderSide(
                              color: _isCustomDuration
                                  ? context.accentPrimary
                                  : context.divider,
                            ),
                            labelStyle: AppTypeRoles.typeRole17.copyWith(
                              color: _isCustomDuration
                                  ? AppPalette.white
                                  : context.textPrimary,
                              fontWeight: _isCustomDuration ? FontWeight.w600 : FontWeight.w400,
                            ),
                            onSelected: (_) {
                              HapticFeedback.selectionClick();
                              setState(() => _isCustomDuration = true);
                            },
                          );
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
                        hintStyle: AscentTextStyles.bodySmall.copyWith(
                          color: context.textMuted,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppPalette.colorFF201A14
                            : AppPalette.colorFFF7F6F2,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s12,
                          vertical: AppSpace.s10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: AppGeometry.roundedr12,
                        ),
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
                            style: AscentTextStyles.labelMedium
                                .copyWith(color: context.textPrimary)
                                .merge(AppTypeRoles.typeRole8),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              AppPill.choice(
                                label: const Text('Today'),
                                selected: DateUtils.isSameDay(
                                  _selectedDate,
                                  DateTime.now(),
                                ),
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => _selectedDate = DateTime.now(),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              AppPill.choice(
                                label: const Text('Tomorrow'),
                                selected: DateUtils.isSameDay(
                                  _selectedDate,
                                  DateTime.now().add(const Duration(days: 1)),
                                ),
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => _selectedDate = DateTime.now().add(
                                      const Duration(days: 1),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 20,
                                ),
                                color: context.accentPrimary,
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime.now().subtract(
                                      const Duration(days: 30),
                                    ),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
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
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s12,
                    vertical: AppSpace.s8,
                  ),
                  nightDecoration: BoxDecoration(
                    color: isDark
                        ? AppPalette.colorFF201A14
                        : AppPalette.colorFFF7F6F2,
                    borderRadius: AppGeometry.roundedr14,
                    border: Border.all(
                      color: context.divider.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        size: 20,
                        color: context.accentPrimary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppTapArea(
                          onTap: _hasReminder
                              ? () async {
                                  final pickedTime = await showTimePicker(
                                    context: context,
                                    initialTime: _selectedTime,
                                  );
                                  if (pickedTime != null) {
                                    setState(() => _selectedTime = pickedTime);
                                  }
                                }
                              : null,
                          borderRadius: AppGeometry.roundedr8,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Remind me',
                                    style: AscentTextStyles.labelMedium
                                        .copyWith(color: context.textPrimary),
                                  ),
                                  if (_hasReminder) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(Tap to edit)',
                                      style: AscentTextStyles.captionMedium
                                          .copyWith(color: context.textMuted)
                                          .merge(AppTypeRoles.typeRole18),
                                    ),
                                  ],
                                ],
                              ),
                              if (_hasReminder)
                                Text(
                                  '${DateFormat('MMM d').format(_selectedDate)} at ${_selectedTime.format(context)}',
                                  style: AscentTextStyles.captionMedium
                                      .copyWith(color: context.accentPrimary)
                                      .merge(AppTypeRoles.typeRole8),
                                ),
                            ],
                          ),
                        ),
                      ),
                      Switch(
                        value: _hasReminder,
                        onChanged: (val) async {
                          if (val) {
                            await NotificationService.instance
                                .requestPermissions();
                            if (!context.mounted) return;
                            final now = TimeOfDay.now();
                            final isPastToday =
                                DateUtils.isSameDay(
                                  _selectedDate,
                                  DateTime.now(),
                                ) &&
                                (_selectedTime.hour < now.hour ||
                                    (_selectedTime.hour == now.hour &&
                                        _selectedTime.minute <= now.minute));
                            final initial = isPastToday
                                ? TimeOfDay(
                                    hour:
                                        (now.hour +
                                            (now.minute >= 45 ? 1 : 0)) %
                                        24,
                                    minute: (now.minute + 15) % 60,
                                  )
                                : _selectedTime;

                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: initial,
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
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: AppPalette.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Priority & Notes',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: context.textMuted,
                      ),
                    ),
                    children: [
                      Row(
                        children: [
                          Text(
                            'Priority: ',
                            style: AscentTextStyles.labelSmall.copyWith(
                              color: context.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          for (final p in ['low', 'medium', 'high'])
                            Padding(
                              padding: const EdgeInsets.only(
                                right: AppSpace.s6,
                              ),
                              child: AppPill.choice(
                                label: Text(p.toUpperCase()),
                                selected: _priority == p,
                                selectedColor: p == 'high'
                                    ? context.stateDanger.withValues(
                                        alpha: 0.15,
                                      )
                                    : context.accentPrimary.withValues(
                                        alpha: 0.15,
                                      ),
                                labelStyle: AppTypeRoles.typeRole19.copyWith(
                                  color: _priority == p
                                      ? context.textPrimary
                                      : context.textMuted,
                                ),
                                onSelected: (_) =>
                                    setState(() => _priority = p),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        style: AscentTextStyles.bodyMedium.copyWith(
                          color: context.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add notes or description (optional)',
                          hintStyle: AscentTextStyles.bodySmall.copyWith(
                            color: context.textMuted,
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppPalette.colorFF201A14
                              : AppPalette.colorFFF7F6F2,
                          border: OutlineInputBorder(
                            borderRadius: AppGeometry.roundedr12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Save button
                AscentButton.primary(
                  label: widget.existingTask != null
                      ? 'Save Changes'
                      : 'Create Activity',
                  icon: widget.existingTask != null
                      ? Icons.check_rounded
                      : Icons.add_rounded,
                  onPressed: _save,
                ),

                if (widget.existingTask != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final nav = Navigator.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Activity?'),
                            content: Text(
                              'Are you sure you want to delete "${widget.existingTask!.title}"? This will also remove any linked reminders.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: context.surfaces.buttonStyle(
                                  FilledButton.styleFrom(
                                    backgroundColor: context.stateDanger,
                                  ),
                                  filled: true,
                                  icon: false,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && mounted) {
                          final taskBackup = widget.existingTask!;
                          final dummyItem = TodayActivityItem(
                            id: 'task_${taskBackup.id}',
                            title: taskBackup.title,
                            sourceType: 'task',
                            status: TodayActivityStatus.notStarted,
                            elapsedSecondsToday: 0,
                            linkedTaskId: taskBackup.id,
                            categoryTag: 'Task',
                            kind: ActivityKind.todo,
                          );
                          await deleteTodayActivity(ref, dummyItem);
                          nav.pop();
                          if (context.mounted) {
                            AscentSnackBar.undo(
                              context,
                              message: 'Activity "${taskBackup.title}" deleted',
                              onUndo: () async {
                                HapticFeedback.lightImpact();
                                await ref
                                    .read(taskDaoProvider)
                                    .insertTask(taskBackup.toCompanion(true));
                                await ref
                                    .read(
                                      dismissedTodayActivityIdsProvider
                                          .notifier,
                                    )
                                    .unDismissActivityId(dummyItem.id);
                              },
                            );
                          }
                        }
                      },
                      style: context.surfaces.buttonStyle(
                        OutlinedButton.styleFrom(
                          foregroundColor: context.stateDanger,
                          side: BorderSide(
                            color: context.stateDanger.withValues(alpha: 0.5),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.s12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppGeometry.roundedr12,
                          ),
                        ),
                        filled: false,
                        icon: false,
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        'Delete Activity',
                        style: AppTypeRoles.typeRole8,
                      ),
                    ),
                  ),
                ],
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
      child: AppTapArea(
        onTap: onTap,
        borderRadius: AppGeometry.roundedr14,
        child: AppCard(
          selected: isSelected,
          padding: const EdgeInsets.symmetric(
            vertical: AppSpace.s10,
            horizontal: AppSpace.s8,
          ),
          nightDecoration: BoxDecoration(
            color: isSelected
                ? context.accentPrimary
                : context.bgBase,
            borderRadius: AppGeometry.roundedr14,
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
                color: isSelected ? AppPalette.white : context.textMuted,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: AscentTextStyles.labelMedium
                    .copyWith(
                      color: isSelected
                          ? AppPalette.white
                          : context.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    )
                    .merge(AppTypeRoles.typeRole9),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppStateTypography.stateType4.copyWith(
                  color: isSelected
                      ? AppPalette.white.withValues(alpha: 0.85)
                      : context.textMuted,
                ),
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
