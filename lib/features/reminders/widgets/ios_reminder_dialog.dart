import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/reminder_alarm_bridge.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_sheet.dart';
import '../../../shared/widgets/ascent_switch_row.dart';

enum ReminderRepeatSchedule {
  none('Never', Icons.timer_off_outlined),
  daily7('Daily (7 days)', Icons.repeat_rounded),
  daily30('Daily (30 days)', Icons.calendar_month_rounded),
  weekdays('Weekdays (Mon-Fri)', Icons.date_range_rounded);

  const ReminderRepeatSchedule(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The reminder create/edit sheet.
///
/// A bottom sheet (not a centred dialog) so the title field always sits
/// directly above the keyboard: the sheet lifts by the keyboard inset, its
/// body scrolls, and the focused field is scrolled into view.
Future<Reminder?> showIOSReminderDialog(
  BuildContext context, {
  Reminder? existing,
  DateTime? initialDate,
}) {
  return showAscentSheet<Reminder>(
    context: context,
    builder: (ctx) => _IOSReminderDialog(
      existing: existing,
      initialDate: initialDate,
    ),
  );
}

class _IOSReminderDialog extends ConsumerStatefulWidget {
  const _IOSReminderDialog({
    this.existing,
    this.initialDate,
  });

  final Reminder? existing;
  final DateTime? initialDate;

  @override
  ConsumerState<_IOSReminderDialog> createState() => _IOSReminderDialogState();
}

class _IOSReminderDialogState extends ConsumerState<_IOSReminderDialog> {
  late final TextEditingController _titleController;
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTime;
  ReminderRepeatSchedule _repeatSchedule = ReminderRepeatSchedule.none;
  bool _alarmEnabled = false;
  bool _saving = false;
  String? _alarmInfo;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.title ?? '');
    final base = widget.existing?.scheduledAt ??
        (widget.initialDate != null
            ? DateTime(
                widget.initialDate!.year,
                widget.initialDate!.month,
                widget.initialDate!.day,
                DateTime.now().hour < 23 ? DateTime.now().hour + 1 : 9,
              )
            : DateTime.now().add(const Duration(hours: 1)));

    _scheduledDate = base;
    _scheduledTime = TimeOfDay.fromDateTime(base);
    _alarmEnabled = widget.existing?.alarmEnabled ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime get _fullScheduledDateTime => DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _scheduledTime.hour,
        _scheduledTime.minute,
      );

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _scheduledDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _scheduledTime.hour,
          _scheduledTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _scheduledTime,
    );
    if (picked != null && mounted) {
      setState(() {
        _scheduledTime = picked;
        _scheduledDate = DateTime(
          _scheduledDate.year,
          _scheduledDate.month,
          _scheduledDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _showRepeatPicker() async {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    final picked = await showAscentActionMenu<ReminderRepeatSchedule>(
      context: context,
      title: 'Repeat',
      actions: [
        for (final s in ReminderRepeatSchedule.values)
          AscentAction(s, s.label, s.icon),
      ],
    );
    if (picked != null && mounted) setState(() => _repeatSchedule = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _titleError = 'Please enter a reminder title');
      return;
    }

    setState(() {
      _saving = true;
      _titleError = null;
    });

    final db = ref.read(databaseProvider);
    final finalScheduled = _fullScheduledDateTime;
    final isNew = widget.existing == null;
    Reminder? resultReminder;

    try {
      if (isNew) {
        final dates = <DateTime>[finalScheduled];
        if (_repeatSchedule == ReminderRepeatSchedule.daily7) {
          for (int i = 1; i < 7; i++) {
            dates.add(finalScheduled.add(Duration(days: i)));
          }
        } else if (_repeatSchedule == ReminderRepeatSchedule.daily30) {
          for (int i = 1; i < 30; i++) {
            dates.add(finalScheduled.add(Duration(days: i)));
          }
        } else if (_repeatSchedule == ReminderRepeatSchedule.weekdays) {
          var cursor = finalScheduled.add(const Duration(days: 1));
          var added = 0;
          while (added < 19) {
            if (cursor.weekday >= DateTime.monday &&
                cursor.weekday <= DateTime.friday) {
              dates.add(cursor);
              added++;
            }
            cursor = cursor.add(const Duration(days: 1));
          }
        }

        final insertedIds = <int>[];
        for (final d in dates) {
          final id = await db.reminderDao.insertReminder(
            ReminderTableCompanion.insert(
              title: title,
              scheduledAt: d,
              isActive: const drift.Value(true),
              alarmEnabled: drift.Value(_alarmEnabled),
            ),
          );
          insertedIds.add(id);
        }

        await ReminderAlertSync.device(db).sync(
          ids: insertedIds,
          onlyPending: true,
        );

        if (insertedIds.isNotEmpty) {
          resultReminder =
              await db.reminderDao.getReminderById(insertedIds.first);
        }
      } else {
        final existing = widget.existing!;
        await (db.update(db.reminderTable)..where((r) => r.id.equals(existing.id)))
            .write(
          ReminderTableCompanion(
            title: drift.Value(title),
            scheduledAt: drift.Value(finalScheduled),
            alarmEnabled: drift.Value(_alarmEnabled),
          ),
        );
        await ReminderAlertSync.device(db).sync(
          ids: [existing.id],
          onlyPending: true,
        );
        resultReminder = await db.reminderDao.getReminderById(existing.id);
      }

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop(resultReminder);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _titleError = 'Could not save reminder: $e';
        });
      }
    }
  }

  Future<void> _toggleAlarm(bool val) async {
    setState(() => _alarmEnabled = val);
    if (!val) return;
    try {
      if (!await NotificationService.instance.areNotificationsEnabled()) {
        await NotificationService.instance.requestPermissions();
      }
      await ReminderAlarmBridge.requestAccess();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isNew = widget.existing == null;
    final repeatValue = _repeatSchedule == ReminderRepeatSchedule.none
        ? 'Never'
        : _repeatSchedule.label;
    return SingleChildScrollView(
      key: const ValueKey('ios_reminder_scroll'),
      primary: true,
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // iOS sheet header: Cancel · title · Add/Save.
          Row(
            children: [
              AscentButton.ghost(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  isNew ? 'New reminder' : 'Edit reminder',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.cardTitle.copyWith(color: g.ink),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _titleController,
                builder: (context, value, _) => AscentButton.ghost(
                  key: const ValueKey('ios_reminder_save_button'),
                  label: isNew ? 'Add' : 'Save',
                  loading: _saving,
                  onPressed: value.text.trim().isNotEmpty && !_saving
                      ? _save
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            key: const ValueKey('ios_reminder_title_field'),
            controller: _titleController,
            autofocus: isNew,
            hintText: 'e.g. Call mom at 6 pm',
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            onChanged: (_) {
              if (_titleError != null) setState(() => _titleError = null);
            },
          ),
          if (_titleError != null) ...[
            const SizedBox(height: AppSpace.s8),
            Padding(
              padding: const EdgeInsets.only(left: AppSpace.s4),
              child: Text(
                _titleError!,
                style: AscentTextStyles.caption.copyWith(color: g.errorInk),
              ),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          _Group(
            children: [
              _GroupRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date',
                value: DateFormat('EEE, d MMM').format(_scheduledDate),
                onTap: _pickDate,
              ),
              _GroupRow(
                icon: Icons.schedule_outlined,
                label: 'Time',
                value: _scheduledTime.format(context),
                onTap: _pickTime,
              ),
              if (isNew)
                _GroupRow(
                  icon: Icons.repeat_rounded,
                  label: 'Repeat',
                  value: repeatValue,
                  onTap: _showRepeatPicker,
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          _Group(
            children: [
              AscentSwitchRow(
                title: 'Ring as an alarm',
                helper: 'Keeps ringing until you stop it',
                value: _alarmEnabled,
                enabled: !_saving,
                onChanged: _toggleAlarm,
              ),
            ],
          ),
          if (_alarmInfo != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              _alarmInfo!,
              style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// An inset grouped list: one rounded surface, hairlines between rows.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: g.surface,
        borderRadius: AppGeometry.roundedr12,
        border: Border.all(color: g.line),
      ),
      child: ClipRRect(
        borderRadius: AppGeometry.roundedr12,
        child: Column(
          children: [
            for (final (i, c) in children.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: AppSpace.s16 + 30 + AppSpace.s12,
                  color: g.line,
                ),
              c,
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: '$label, $value',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s10,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 30,
                  height: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: g.actionInk.withValues(alpha: .12),
                      borderRadius: AppGeometry.roundedr8,
                    ),
                    child: Icon(icon, size: 17, color: g.actionInk),
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Text(
                    label,
                    style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.body.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s4),
                Icon(Icons.chevron_right_rounded, size: 20, color: g.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
