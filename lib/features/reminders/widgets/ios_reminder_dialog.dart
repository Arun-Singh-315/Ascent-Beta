import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/reminder_alarm_bridge.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_switch.dart';

enum ReminderRepeatSchedule {
  none('Never', Icons.timer_off_outlined),
  daily7('Daily (7 days)', Icons.repeat_rounded),
  daily30('Daily (30 days)', Icons.calendar_month_rounded),
  weekdays('Weekdays (Mon-Fri)', Icons.date_range_rounded);

  const ReminderRepeatSchedule(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// iOS-style centered modal dialog for creating and editing reminders.
///
/// Features:
/// - Centered layout with smooth backdrop blur.
/// - Top navigation header with Cancel (left), Title (center), and Add/Save (top-right).
/// - Top-right action button is never hidden behind the keyboard.
/// - Inset grouped glass sections for Title, Date/Time/Repeat, and Alarm notifications.
/// - Defensive keyboard avoidance and tactile haptic feedback.
Future<Reminder?> showIOSReminderDialog(
  BuildContext context, {
  Reminder? existing,
  DateTime? initialDate,
}) {
  return showDialog<Reminder>(
    context: context,
    barrierDismissible: true,
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

  void _showRepeatPicker() {
    HapticFeedback.selectionClick();
    final g = context.glass;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: g.isDark ? const Color(0xFF1C1E22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: g.ink.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Repeat Schedule',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              for (final schedule in ReminderRepeatSchedule.values)
                ListTile(
                  leading: Icon(
                    schedule.icon,
                    color: _repeatSchedule == schedule
                        ? SharedControlColors.actionBlue
                        : g.inkMuted,
                  ),
                  title: Text(
                    schedule.label,
                    style: TextStyle(
                      color: _repeatSchedule == schedule
                          ? SharedControlColors.actionBlue
                          : g.ink,
                      fontWeight: _repeatSchedule == schedule
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  trailing: _repeatSchedule == schedule
                      ? const Icon(
                          Icons.check_rounded,
                          color: SharedControlColors.actionBlue,
                        )
                      : null,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _repeatSchedule = schedule);
                    Navigator.pop(sheetCtx);
                  },
                ),
            ],
          ),
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = g.isDark;
    final groupFill = isDark
        ? const Color(0xFF1B1E22)
        : const Color(0xFFF3F4F6);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121417) : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.10),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── iOS Navigation Bar Header ───────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(48, 36),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: g.inkMuted,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          widget.existing == null ? 'New Reminder' : 'Edit Reminder',
                          style: AscentTextStyles.homeTitle.copyWith(
                            color: g.ink,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _titleController,
                                builder: (context, value, _) {
                                  final hasText = value.text.trim().isNotEmpty;
                                  return TextButton(
                                    key: const ValueKey('ios_reminder_save_button'),
                                    onPressed: hasText ? _save : null,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      minimumSize: const Size(48, 36),
                                    ),
                                    child: Text(
                                      widget.existing == null ? 'Add' : 'Save',
                                      style: TextStyle(
                                        color: hasText
                                            ? SharedControlColors.actionBlue
                                            : g.inkMuted.withValues(alpha: 0.5),
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 0.75),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Group 1: Title Input ───────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: groupFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor, width: 0.8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          child: TextField(
                            key: const ValueKey('ios_reminder_title_field'),
                            controller: _titleController,
                            autofocus: widget.existing == null,
                            style: TextStyle(
                              color: g.ink,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Title',
                              hintStyle: TextStyle(
                                color: g.inkMuted.withValues(alpha: 0.7),
                                fontSize: 15.5,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onChanged: (_) {
                              if (_titleError != null) {
                                setState(() => _titleError = null);
                              }
                            },
                          ),
                        ),

                        if (_titleError != null) ...[
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              _titleError!,
                              style: TextStyle(
                                color: SharedControlColors.dueRed,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // ── Group 2: Date, Time & Repeat ───────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: groupFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor, width: 0.8),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              // Date Row
                              InkWell(
                                onTap: _pickDate,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: SharedControlColors.dueRed
                                              .withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.calendar_today_rounded,
                                          size: 16,
                                          color: SharedControlColors.dueRed,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Date',
                                        style: TextStyle(
                                          color: g.ink,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        DateFormat('EEE, d MMM').format(_scheduledDate),
                                        style: TextStyle(
                                          color: SharedControlColors.actionBlue,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: g.inkMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              Divider(
                                height: 1,
                                thickness: 0.75,
                                color: borderColor,
                                indent: 14,
                              ),

                              // Time Row
                              InkWell(
                                onTap: _pickTime,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: SharedControlColors.actionBlue
                                              .withValues(alpha: 0.14),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.access_time_filled_rounded,
                                          size: 16,
                                          color: SharedControlColors.actionBlue,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Time',
                                        style: TextStyle(
                                          color: g.ink,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _scheduledTime.format(context),
                                        style: TextStyle(
                                          color: SharedControlColors.actionBlue,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: g.inkMuted,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              if (widget.existing == null) ...[
                                Divider(
                                  height: 1,
                                  thickness: 0.75,
                                  color: borderColor,
                                  indent: 14,
                                ),

                                // Repeat Row
                                InkWell(
                                  onTap: _showRepeatPicker,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8E44AD)
                                                .withValues(alpha: 0.14),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.repeat_rounded,
                                            size: 16,
                                            color: Color(0xFF8E44AD),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Repeat',
                                          style: TextStyle(
                                            color: g.ink,
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          _repeatSchedule.label,
                                          style: TextStyle(
                                            color: g.inkMuted,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          size: 18,
                                          color: g.inkMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Group 3: Alarm Switch ──────────────────────────
                        Container(
                          decoration: BoxDecoration(
                            color: groupFill,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor, width: 0.8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF39C12)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.alarm_rounded,
                                  size: 16,
                                  color: Color(0xFFF39C12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ring as an alarm',
                                      style: TextStyle(
                                        color: g.ink,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      'Persistent ring until acknowledged',
                                      style: TextStyle(
                                        color: g.inkMuted,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AscentSwitch(
                                value: _alarmEnabled,
                                onChanged: _saving
                                    ? null
                                    : (val) async {
                                        HapticFeedback.selectionClick();
                                        setState(() => _alarmEnabled = val);
                                        if (val) {
                                          try {
                                            if (!await NotificationService
                                                .instance
                                                .areNotificationsEnabled()) {
                                              await NotificationService
                                                  .instance
                                                  .requestPermissions();
                                            }
                                            await ReminderAlarmBridge
                                                .requestAccess();
                                          } catch (_) {}
                                        }
                                      },
                              ),
                            ],
                          ),
                        ),

                        if (_alarmInfo != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _alarmInfo!,
                            style: TextStyle(
                              color: g.inkMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
