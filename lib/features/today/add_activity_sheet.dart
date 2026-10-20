import '../../shared/widgets/ascent_option_tile.dart';
import '../../shared/widgets/schedule_picker.dart';
import '../../shared/widgets/note_list_button.dart';
import '../../core/services/plan_collection_service.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../core/services/activity_entry_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import 'add_lecture_activity_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../core/services/plan_child_protection.dart';
import '../plans/widgets/plan_protection_dialog.dart';
import '../plans/widgets/plan_detail_sheet.dart';
import '../home/widgets/home_schedule_sheet.dart';

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
  final _titleFocus = FocusNode();
  final _notesController = TextEditingController();
  final _notesFocus = FocusNode();
  final _customDurationController = TextEditingController();

  late ActivityKind _kind;
  int _targetMinutes = 30;
  bool _isCustomDuration = false;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _hasReminder = false;
  bool _pickingReminder = false;
  String _priority = 'medium';
  bool _saving = false;
  bool _reminderEdited = false;
  bool _loadingReminder = false;
  PlanChildRestriction? _protection;

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

      _loadingReminder = true;
      Future.microtask(() async {
        try {
          final protection = await ref
              .read(taskDaoProvider)
              .getTaskProtection(t.id);
          if (mounted) setState(() => _protection = protection);
        } catch (_) {}
      });
      // Check if existing task has an active reminder
      Future.microtask(() async {
        try {
          final reminders = await ref
              .read(reminderDaoProvider)
              .watchAllReminders()
              .first;
          final existing = reminders
              .where((r) => r.linkedTaskId == t.id && r.isActive)
              .firstOrNull;
          if (existing != null && mounted) {
            setState(() {
              _hasReminder = true;
              _selectedDate = existing.scheduledAt;
              _selectedTime = TimeOfDay.fromDateTime(existing.scheduledAt);
            });
          }
        } catch (_) {
        } finally {
          if (mounted) setState(() => _loadingReminder = false);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _titleController.dispose();
    _notesFocus.dispose();
    _notesController.dispose();
    _customDurationController.dispose();
    super.dispose();
  }

  Future<void> _chooseReminder(bool enabled) async {
    if (_pickingReminder) return;
    if (!enabled) {
      setState(() {
        _hasReminder = false;
        _reminderEdited = true;
      });
      return;
    }
    setState(() => _pickingReminder = true);
    final selected = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
    final picked = await pickFutureSchedule(
      context,
      purpose: 'Reminder',
      initial: selected.isAfter(DateTime.now()) ? selected : null,
    );
    if (!mounted) return;
    setState(() {
      _pickingReminder = false;
      if (picked != null) {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
        _selectedTime = TimeOfDay.fromDateTime(picked);
        _hasReminder = true;
        _reminderEdited = true;
      }
    });
    if (picked != null) await NotificationService.instance.requestPermissions();
  }

  Future<void> _save() async {
    if (_saving || _loadingReminder || _pickingReminder) return;
    setState(() => _saving = true);
    try {
      final minutes = _kind == ActivityKind.duration
          ? (_isCustomDuration
                ? int.tryParse(_customDurationController.text.trim())
                : _targetMinutes)
          : _kind == ActivityKind.flexible
          ? -1
          : null;
      if (_kind == ActivityKind.duration &&
          (minutes == null || minutes < 1 || minutes > 1440)) {
        throw StateError('Choose a timer from 1 to 1440 minutes.');
      }
      final reminderAt = !_hasReminder
          ? null
          : DateTime(
              _selectedDate.year,
              _selectedDate.month,
              _selectedDate.day,
              _selectedTime.hour,
              _selectedTime.minute,
            );
      final db = ref.read(databaseProvider);
      final titles = widget.existingTask == null
          ? PlanItemDraft.parseList(_titleController.text)
          : [_titleController.text];
      final results = widget.existingTask == null
          ? await ActivityEntryService(db).saveMany(
              titles: titles,
              date: _selectedDate,
              estimatedMinutes: minutes,
              notes: _notesController.text,
              priority: _priority,
              parentTaskId: widget.parentTaskId,
              applicationId: widget.prefilledApplicationId,
              reminderAt: reminderAt,
            )
          : [
              await ActivityEntryService(db).save(
                title: _titleController.text,
                date: _selectedDate,
                estimatedMinutes: minutes,
                taskId: widget.existingTask!.id,
                notes: _notesController.text,
                priority: _priority,
                parentTaskId: widget.parentTaskId,
                applicationId: widget.prefilledApplicationId,
                reminderAt: reminderAt,
                replaceReminders: _reminderEdited,
              ),
            ];
      final reminderIds = results.expand((r) => r.reminderIds).toList();
      var message = widget.existingTask == null
          ? (results.length == 1
                ? 'Activity added'
                : '${results.length} to-dos added')
          : 'Activity updated';
      if (reminderIds.isNotEmpty) {
        try {
          final sync = await ReminderAlertSync.device(
            db,
          ).sync(ids: reminderIds, onlyPending: true);
          if (!sync.complete) {
            message +=
                '. Reminder alert pending—check notification permissions.';
          }
        } catch (_) {
          message += '. Reminder alert pending.';
        }
      }
      if (mounted) {
        HapticFeedback.lightImpact();
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not save. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
      child: Material(
        color: AppPalette.transparent,
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
                  if (_protection != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        showPlanDetailSheet(context, _protection!.planId);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.glass.claySoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: context.glass.clay.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_repeat_rounded,
                              size: 14,
                              color: context.glass.clay,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Part of ${_protection!.planTitle} · Open routine',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.glass.clay,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (widget.existingTask != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(
                            Icons.event_repeat_rounded,
                            size: 16,
                          ),
                          label: const Text('Make repeating routine'),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            final db = ref.read(databaseProvider);
                            final thoughtId = await db.thoughtDao.insertThought(
                              ThoughtTableCompanion.insert(
                                content:
                                    'Routine: ${_titleController.text.trim()}',
                              ),
                            );
                            final thought = await db.thoughtDao.getThoughtById(
                              thoughtId,
                            );
                            if (context.mounted && thought != null) {
                              showHomeSchedule(
                                context,
                                thought,
                                initialText:
                                    '${_titleController.text.trim()} every day at ${_selectedTime.format(context)}',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
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
                    focusNode: _titleFocus,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: widget.existingTask == null ? 20000 : 300,
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
                      suffixIcon: widget.existingTask == null
                          ? InlineListAddButton(
                              controller: _titleController,
                              focusNode: _titleFocus,
                              enabled: !_saving,
                            )
                          : null,
                    ),
                    onTap: () {
                      try {
                        InlineListAddButton.maybeShowFirstTimeDiscovery(
                          context,
                          prefs: ref.read(sharedPreferencesProvider),
                        );
                      } catch (_) {}
                    },
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
                              final isSel =
                                  !_isCustomDuration && _targetMinutes == mins;
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
                                  fontWeight: isSel
                                      ? FontWeight.w600
                                      : FontWeight.w400,
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
                                fontWeight: _isCustomDuration
                                    ? FontWeight.w600
                                    : FontWeight.w400,
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
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                AppPill.choice(
                                  label: const Text('Today'),
                                  selected: DateUtils.isSameDay(
                                    _selectedDate,
                                    DateTime.now(),
                                  ),
                                  onSelected: (_) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _reminderEdited = true;
                                      _selectedDate = DateTime.now();
                                    });
                                  },
                                ),
                                AppPill.choice(
                                  label: const Text('Tomorrow'),
                                  selected: DateUtils.isSameDay(
                                    _selectedDate,
                                    DateTime.now().add(const Duration(days: 1)),
                                  ),
                                  onSelected: (_) {
                                    HapticFeedback.selectionClick();
                                    setState(() {
                                      _reminderEdited = true;
                                      _selectedDate = DateTime.now().add(
                                        const Duration(days: 1),
                                      );
                                    });
                                  },
                                ),
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
                                      setState(() {
                                        _reminderEdited = true;
                                        _selectedDate = picked;
                                      });
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
                                ? () => _chooseReminder(true)
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
                          onChanged: _pickingReminder ? null : _chooseReminder,
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
                          focusNode: _notesFocus,
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
                            suffixIcon: InlineListAddButton(
                              controller: _notesController,
                              focusNode: _notesFocus,
                              enabled: !_saving,
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
                    loading: _saving,
                    onPressed: _saving || _loadingReminder ? null : _save,
                  ),

                  if (widget.existingTask != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          final nav = Navigator.of(context);
                          if (_protection != null) {
                            await showPlanProtectionDialog(
                              context,
                              ref,
                              _protection!,
                            );
                            nav.pop();
                            return;
                          }
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
                                message:
                                    'Activity "${taskBackup.title}" deleted',
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
                        icon: Icon(
                          _protection != null
                              ? Icons.event_busy_rounded
                              : Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _protection != null
                              ? 'Skip session or manage routine'
                              : 'Delete Activity',
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
  Widget build(BuildContext context) => Expanded(
    child: AscentOptionTile(
      icon: icon,
      label: label,
      value: subtitle,
      selected: isSelected,
      onTap: onTap,
    ),
  );
}

