import '../../shared/widgets/ascent_snack_bar.dart';
import '../../core/notifications/reminder_alarm_bridge.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../core/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/glass_surface.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';

enum _ReminderRepeatMode {
  none('One-time', 'Specific date only', Icons.event_rounded),
  monthly(
    'Monthly (SIP/Bills)',
    'Same date every month for 12 months',
    Icons.event_repeat_rounded,
  ),
  daily7('7 Days', 'Every day for next week', Icons.date_range_rounded),
  daily30(
    'Whole Month',
    'Every day for next 30 days',
    Icons.calendar_month_rounded,
  ),
  weekdays(
    'Weekdays',
    'Mon to Fri for next 4 weeks',
    Icons.work_history_outlined,
  );

  final String label;
  final String subtitle;
  final IconData icon;
  const _ReminderRepeatMode(this.label, this.subtitle, this.icon);
}

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  bool _notificationsEnabled = true;
  int _selectedTab = 0; // 0: Upcoming, 1: Completed

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final enabled = await NotificationService.instance
        .areNotificationsEnabled();
    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }
  }

  bool _syncingAlerts = false;
  Future<void> _syncAlerts() async {
    if (_syncingAlerts) return;
    setState(() => _syncingAlerts = true);
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final result = await ReminderAlertSync.device(ref.read(databaseProvider))
          .sync(
            replaceAll: prefs.getBool('ascent_restore_alert_sync_v1') ?? false,
          );
      if (result.complete) await prefs.remove('ascent_restore_alert_sync_v1');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AscentSnackBar.build(context, content: Text(result.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AscentSnackBar.build(
            context,
            content: Text('Could not verify reminder alerts. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncingAlerts = false);
    }
  }

  void _openAddEditReminderSheet([Reminder? existing]) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    DateTime scheduledDate =
        existing?.scheduledAt ?? DateTime.now().add(const Duration(hours: 1));
    TimeOfDay scheduledTime = TimeOfDay.fromDateTime(scheduledDate);
    _ReminderRepeatMode repeatMode = _ReminderRepeatMode.none;
    bool alarmEnabled = existing?.alarmEnabled ?? false;
    bool saving = false;
    String? alarmInfo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.glass.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: context.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null ? 'New Reminder' : 'Edit Reminder',
                          style: AscentTextStyles.displaySmall.copyWith(
                            color: context.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      autofocus: existing == null,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Reminder Title *',
                        hintText: 'e.g. Solve LeetCode DP, Review notes, Walk',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Starting Date & Time',
                      style: AscentTextStyles.labelMedium.copyWith(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              DateFormat('EEE, MMM d').format(scheduledDate),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: context.glass.fill,
                              side: BorderSide(color: context.glass.edge),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: scheduledDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 1),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  scheduledDate = DateTime(
                                    picked.year,
                                    picked.month,
                                    picked.day,
                                    scheduledTime.hour,
                                    scheduledTime.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(scheduledTime.format(context)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: context.glass.fill,
                              side: BorderSide(color: context.glass.edge),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: scheduledTime,
                              );
                              if (picked != null) {
                                setSheetState(() {
                                  scheduledTime = picked;
                                  scheduledDate = DateTime(
                                    scheduledDate.year,
                                    scheduledDate.month,
                                    scheduledDate.day,
                                    picked.hour,
                                    picked.minute,
                                  );
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (existing == null) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Repeat Schedule',
                        style: AscentTextStyles.labelMedium.copyWith(
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Schedule daily focus nudges across multiple days or the whole month',
                        style: AscentTextStyles.bodySmall.copyWith(
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _ReminderRepeatMode.values.map((mode) {
                          final isSelected = repeatMode == mode;
                          return ChoiceChip(
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  mode.icon,
                                  size: 14,
                                  color: isSelected
                                      ? context.glass.clay
                                      : context.textPrimary,
                                ),
                                const SizedBox(width: 6),
                                Text(mode.label),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setSheetState(() => repeatMode = mode);
                              }
                            },
                            selectedColor: context.glass.claySoft,
                            backgroundColor: context.glass.fill,
                            side: BorderSide(
                              color: isSelected
                                  ? context.glass.clay
                                  : context.glass.edge,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? context.glass.clay
                                  : context.glass.ink,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.glass.claySoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: context.glass.clay.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: context.glass.clay,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                repeatMode == _ReminderRepeatMode.none
                                    ? 'Fires once on the selected date.'
                                    : repeatMode == _ReminderRepeatMode.daily7
                                    ? 'Fires every day for the next 7 days at ${scheduledTime.format(context)}.'
                                    : repeatMode == _ReminderRepeatMode.daily30
                                    ? 'Fires every day for the next 30 days (whole month) at ${scheduledTime.format(context)}.'
                                    : 'Fires every weekday (Mon-Fri) for the next 4 weeks at ${scheduledTime.format(context)}.',
                                style: AscentTextStyles.bodySmall.copyWith(
                                  color: context.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    GlassSurface(
                      radius: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ring as an alarm'),
                        secondary: Icon(
                          alarmEnabled
                              ? Icons.alarm_rounded
                              : Icons.notifications_none_rounded,
                          color: context.glass.clay,
                        ),
                        subtitle: const Text(
                          'Optional. Rings until Snooze or Done. Off uses a normal notification.',
                        ),
                        value: alarmEnabled,
                        onChanged: saving
                            ? null
                            : (value) =>
                                  setSheetState(() => alarmEnabled = value),
                      ),
                    ),
                    if (alarmEnabled) ...[
                      const Text(
                        'Lock-screen popups require Android alarm access. Without popup access, use the alarm notification to open Snooze and Done.',
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.alarm_on_outlined),
                        label: const Text('Enable alarm access'),
                        onPressed: () async {
                          try {
                            if (!await NotificationService.instance
                                .areNotificationsEnabled()) {
                              await NotificationService.instance
                                  .requestPermissions();
                            }
                            await ReminderAlarmBridge.requestAccess();
                            final access = await ReminderAlarmBridge.access();
                            if (context.mounted) {
                              setSheetState(
                                () => alarmInfo =
                                    access['exact'] == true &&
                                        access['fullScreen'] == true &&
                                        access['notifications'] == true
                                    ? 'Alarm access is ready.'
                                    : 'Enable notification, exact alarm and popup access in Android settings, then return here.',
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              setSheetState(
                                () => alarmInfo =
                                    'Alarm mode needs Android alarm access.',
                              );
                            }
                          }
                        },
                      ),
                    ],
                    if (alarmInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(alarmInfo!),
                      ),
                    AscentButton.primary(
                      label: existing == null
                          ? 'Set Reminder'
                          : 'Update Reminder',
                      expanded: true,
                      onPressed: saving
                          ? null
                          : () async {
                              if (saving) return;
                              final title = titleController.text.trim();
                              if (title.isEmpty) return;

                              final dao = ref.read(reminderDaoProvider);
                              final baseScheduled = DateTime(
                                scheduledDate.year,
                                scheduledDate.month,
                                scheduledDate.day,
                                scheduledTime.hour,
                                scheduledTime.minute,
                              );

                              if (!baseScheduled.isAfter(DateTime.now())) {
                                setSheetState(
                                  () => alarmInfo =
                                      'Choose a future date and time.',
                                );
                                return;
                              }
                              setSheetState(() => saving = true);
                              var failedAlerts = 0;
                              try {
                                if (!await NotificationService.instance
                                    .areNotificationsEnabled()) {
                                  await NotificationService.instance
                                      .requestPermissions();
                                }
                                if (existing == null) {
                                  // Handle multi-day / recurring reminder insertion
                                  List<DateTime> datesToSchedule = [];
                                  if (repeatMode == _ReminderRepeatMode.none) {
                                    datesToSchedule.add(baseScheduled);
                                  } else if (repeatMode ==
                                      _ReminderRepeatMode.monthly) {
                                    // Schedule on specific day of month across next 12 months for SIP, bills, rent
                                    for (int m = 0; m < 12; m++) {
                                      final year =
                                          baseScheduled.year +
                                          ((baseScheduled.month - 1 + m) ~/ 12);
                                      final month =
                                          ((baseScheduled.month - 1 + m) % 12) +
                                          1;
                                      final maxDaysInMonth = DateTime(
                                        year,
                                        month + 1,
                                        0,
                                      ).day;
                                      final day =
                                          baseScheduled.day <= maxDaysInMonth
                                          ? baseScheduled.day
                                          : maxDaysInMonth;
                                      datesToSchedule.add(
                                        DateTime(
                                          year,
                                          month,
                                          day,
                                          baseScheduled.hour,
                                          baseScheduled.minute,
                                        ),
                                      );
                                    }
                                  } else if (repeatMode ==
                                      _ReminderRepeatMode.daily7) {
                                    for (int i = 0; i < 7; i++) {
                                      datesToSchedule.add(
                                        baseScheduled.add(Duration(days: i)),
                                      );
                                    }
                                  } else if (repeatMode ==
                                      _ReminderRepeatMode.daily30) {
                                    for (int i = 0; i < 30; i++) {
                                      datesToSchedule.add(
                                        baseScheduled.add(Duration(days: i)),
                                      );
                                    }
                                  } else if (repeatMode ==
                                      _ReminderRepeatMode.weekdays) {
                                    int added = 0;
                                    DateTime current = baseScheduled;
                                    while (added < 20) {
                                      if (current.weekday >= DateTime.monday &&
                                          current.weekday <= DateTime.friday) {
                                        datesToSchedule.add(current);
                                        added++;
                                      }
                                      current = current.add(
                                        const Duration(days: 1),
                                      );
                                    }
                                  }

                                  for (final d in datesToSchedule) {
                                    final id = await dao.insertReminder(
                                      ReminderTableCompanion(
                                        title: drift.Value(title),
                                        scheduledAt: drift.Value(d),
                                        isActive: const drift.Value(true),
                                        alarmEnabled: drift.Value(alarmEnabled),
                                        createdAt: drift.Value(DateTime.now()),
                                      ),
                                    );

                                    final scheduled = await NotificationService
                                        .instance
                                        .scheduleReminderNotificationChecked(
                                          id: id,
                                          title: title,
                                          scheduledAt: d,
                                          alarmEnabled: alarmEnabled,
                                        );
                                    if (!scheduled) failedAlerts++;
                                  }
                                } else {
                                  await dao.updateReminder(
                                    ReminderTableCompanion(
                                      id: drift.Value(existing.id),
                                      title: drift.Value(title),
                                      scheduledAt: drift.Value(baseScheduled),
                                      isActive: const drift.Value(true),
                                      alarmEnabled: drift.Value(alarmEnabled),
                                      createdAt: drift.Value(
                                        existing.createdAt,
                                      ),
                                    ),
                                  );

                                  final scheduled = await NotificationService
                                      .instance
                                      .scheduleReminderNotificationChecked(
                                        id: existing.id,
                                        title: title,
                                        scheduledAt: baseScheduled,
                                        alarmEnabled: alarmEnabled,
                                      );
                                  if (!scheduled) failedAlerts++;
                                }

                                ref.invalidate(allRemindersProvider);
                                ref.invalidate(nextUpcomingReminderProvider);

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    AscentSnackBar.build(
                                      context,
                                      content: Text(
                                        failedAlerts > 0
                                            ? 'Saved. $failedAlerts alerts need notification or alarm access. Enable access and tap Sync reminder alerts.'
                                            : existing == null
                                            ? (repeatMode ==
                                                      _ReminderRepeatMode.none
                                                  ? 'Reminder scheduled'
                                                  : 'Recurring reminders scheduled (${repeatMode.label})')
                                            : 'Reminder updated',
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  setSheetState(
                                    () => alarmInfo =
                                        'Could not finish saving. Check the saved reminders before retrying.',
                                  );
                                }
                              } finally {
                                if (context.mounted) {
                                  setSheetState(() => saving = false);
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _finishReminder(Reminder row) async {
    try {
      await ref
          .read(reminderDaoProvider)
          .updateReminder(
            row.toCompanion(true).copyWith(isActive: const drift.Value(false)),
          );
      await NotificationService.instance.cancel(row.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AscentSnackBar.build(
            context,
            content: Text('Reminder completed'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AscentSnackBar.build(
            context,
            content: Text('Could not finish the reminder. Please retry.'),
          ),
        );
      }
    }
  }

  Future<void> _snoozeReminder(Reminder row) async {
    try {
      final at = DateTime.now().add(const Duration(minutes: 10));
      await ref
          .read(reminderDaoProvider)
          .updateReminder(
            row
                .toCompanion(true)
                .copyWith(
                  scheduledAt: drift.Value(at),
                  isActive: const drift.Value(true),
                ),
          );
      await NotificationService.instance.cancel(row.id);
      final scheduled = await NotificationService.instance
          .scheduleReminderNotificationChecked(
            id: row.id,
            title: row.title,
            scheduledAt: at,
            alarmEnabled: row.alarmEnabled,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AscentSnackBar.build(
            context,
            content: Text(
              scheduled
                  ? 'Snoozed for 10 minutes'
                  : 'Saved for 10 minutes from now. Enable notification or alarm access and retry alert sync.',
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AscentSnackBar.build(
            context,
            content: Text(
              'Could not snooze. Check saved reminder time and retry.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteReminder(Reminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to delete "${reminder.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.glass.coral),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dao = ref.read(reminderDaoProvider);
      final deletedReminder = reminder;
      final thoughtIds = await dao.getLinkedThoughtIds(deletedReminder.id);
      await dao.deleteReminder(deletedReminder.id);
      await NotificationService.instance.cancel(deletedReminder.id);
      ref.invalidate(allRemindersProvider);
      ref.invalidate(nextUpcomingReminderProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          AscentSnackBar.build(
            context,
            content: Text('Reminder "${deletedReminder.title}" deleted'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: const Color(0xFFF9AB67),
              onPressed: () async {
                try {
                  final restored = await dao.restoreDeletedReminder(
                    deletedReminder,
                    thoughtIds,
                  );
                  if (!restored && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A newer reminder already uses this record. It was kept.',
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not restore the reminder. Try again.',
                        ),
                      ),
                    );
                  }
                }
                ref.invalidate(allRemindersProvider);
                ref.invalidate(nextUpcomingReminderProvider);
              },
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(allRemindersProvider);

    final g = context.glass;

    return AscentScaffold(
      title: 'Reminders & Alerts',
      subtitle: 'Scheduled notifications & deadlines',
      floatingActionButton: remindersAsync.value?.isNotEmpty == true
          ? AscentButton.fab(
              icon: Icons.add_rounded,
              onPressed: () => _openAddEditReminderSheet(),
            )
          : null,
      body: remindersAsync.when(
        data: (reminders) {
          if (reminders.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No Reminders Yet',
              subtitle:
                  'Set reminders for upcoming interviews, study blocks, and application deadlines.',
              actionLabel: 'Create Reminder',
              onAction: () => _openAddEditReminderSheet(),
            );
          }

          final now = DateTime.now();
          final startOfToday = DateTime(now.year, now.month, now.day);
          final endOfToday = DateTime(
            now.year,
            now.month,
            now.day,
            23,
            59,
            59,
            999,
          );
          final startOfTomorrow = startOfToday.add(const Duration(days: 1));
          final endOfTomorrow = endOfToday.add(const Duration(days: 1));
          final endOfWeek = startOfToday.add(const Duration(days: 7));

          final overdueReminders =
              reminders
                  .where((r) => r.isActive && r.scheduledAt.isBefore(now))
                  .toList()
                ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
          final todayReminders =
              reminders
                  .where(
                    (r) =>
                        r.isActive &&
                        !r.scheduledAt.isBefore(now) &&
                        r.scheduledAt.isAfter(
                          startOfToday.subtract(const Duration(seconds: 1)),
                        ) &&
                        r.scheduledAt.isBefore(startOfTomorrow),
                  )
                  .toList()
                ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          final tomorrowReminders =
              reminders
                  .where(
                    (r) =>
                        r.isActive &&
                        r.scheduledAt.isAfter(endOfToday) &&
                        r.scheduledAt.isBefore(
                          endOfTomorrow.add(const Duration(milliseconds: 1)),
                        ),
                  )
                  .toList()
                ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          final thisWeekReminders =
              reminders
                  .where(
                    (r) =>
                        r.isActive &&
                        r.scheduledAt.isAfter(endOfTomorrow) &&
                        r.scheduledAt.isBefore(endOfWeek),
                  )
                  .toList()
                ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          final laterReminders =
              reminders
                  .where(
                    (r) =>
                        r.isActive &&
                        r.scheduledAt.isAfter(
                          endOfWeek.subtract(const Duration(milliseconds: 1)),
                        ),
                  )
                  .toList()
                ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

          final pastReminders = reminders.where((r) => !r.isActive).toList()
            ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

          return ListView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80,
            ),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _syncingAlerts ? null : _syncAlerts,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(
                    _syncingAlerts ? 'Scheduling…' : 'Sync reminder alerts',
                  ),
                ),
              ),
              if (!_notificationsEnabled) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: g.amberSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: g.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_off_rounded,
                        color: g.amber,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications Disabled',
                              style: AscentTextStyles.labelMedium.copyWith(
                                color: g.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Enable notifications to receive your scheduled alerts and streak reminders.',
                              style: AscentTextStyles.bodySmall.copyWith(
                                color: g.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await NotificationService.instance
                              .requestPermissions();
                          await _checkNotificationPermission();
                          if (_notificationsEnabled) await _syncAlerts();
                        },
                        child: Text(
                          'Enable',
                          style: TextStyle(
                            color: g.amber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── SEGMENTED TOP TOGGLE: UPCOMING VS COMPLETED ─────────────
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: g.fill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: g.edge),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 0);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? g.claySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedTab == 0
                                  ? g.clay
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Upcoming (${todayReminders.length + tomorrowReminders.length + thisWeekReminders.length + laterReminders.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: _selectedTab == 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _selectedTab == 0 ? g.ink : g.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 1);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? g.claySoft
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _selectedTab == 1
                                  ? g.clay
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Completed (${pastReminders.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: _selectedTab == 1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _selectedTab == 1 ? g.ink : g.inkMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_selectedTab == 0) ...[
                if (overdueReminders.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Overdue',
                    overdueReminders.length,
                    g.coral,
                    Icons.schedule_rounded,
                  ),
                  ...overdueReminders.map(
                    (rem) => _buildReminderTile(rem, isUpcoming: true),
                  ),
                  const SizedBox(height: 12),
                ],
                if (todayReminders.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Today',
                    todayReminders.length,
                    g.clay,
                    Icons.today_rounded,
                  ),
                  ...todayReminders.map(
                    (rem) => _buildReminderTile(rem, isUpcoming: true),
                  ),
                  const SizedBox(height: 12),
                ],
                if (tomorrowReminders.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Tomorrow',
                    tomorrowReminders.length,
                    g.inkSecondary,
                    Icons.event_rounded,
                  ),
                  ...tomorrowReminders.map(
                    (rem) => _buildReminderTile(rem, isUpcoming: true),
                  ),
                  const SizedBox(height: 12),
                ],
                if (thisWeekReminders.isNotEmpty) ...[
                  _buildSectionHeader(
                    'This Week',
                    thisWeekReminders.length,
                    g.inkSecondary,
                    Icons.date_range_rounded,
                  ),
                  ...thisWeekReminders.map(
                    (rem) => _buildReminderTile(rem, isUpcoming: true),
                  ),
                  const SizedBox(height: 12),
                ],
                if (laterReminders.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Upcoming & Later',
                    laterReminders.length,
                    g.inkMuted,
                    Icons.calendar_month_rounded,
                  ),
                  ...laterReminders.map(
                    (rem) => _buildReminderTile(rem, isUpcoming: true),
                  ),
                  const SizedBox(height: 12),
                ],
                if (overdueReminders.isEmpty &&
                    todayReminders.isEmpty &&
                    tomorrowReminders.isEmpty &&
                    thisWeekReminders.isEmpty &&
                    laterReminders.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.task_alt_rounded, size: 40, color: g.clay),
                          const SizedBox(height: 12),
                          Text(
                            'No active reminders',
                            style: AscentTextStyles.headlineMedium.copyWith(
                              color: g.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed reminders stay in the Completed tab. Tasks have their own completion status.',
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: g.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ] else ...[
                // Tab 1: Completed Reminders displayed immediately at the top without scrolling
                if (pastReminders.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Completed & Past',
                    pastReminders.length,
                    g.inkMuted,
                    Icons.history_rounded,
                  ),
                  ...pastReminders.map(
                    (rem) => _buildReminderTile(rem, isUpcoming: false),
                  ),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_toggle_off_rounded,
                            size: 40,
                            color: g.inkMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No completed reminders yet',
                            style: AscentTextStyles.headlineMedium.copyWith(
                              color: g.ink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Completed reminders and passed deadlines will appear right here.',
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: g.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: g.clay)),
        error: (err, stack) => Center(
          child: Text('Error: $err', style: TextStyle(color: g.inkMuted)),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: AscentTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: g.ink,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTile(Reminder reminder, {required bool isUpcoming}) {
    final g = context.glass;
    final formattedTime = DateFormat(
      'EEE, MMM d • h:mm a',
    ).format(reminder.scheduledAt);

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDeleteReminder(reminder);
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: g.coralSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: g.coral),
      ),
      child: AscentCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        onTap: () => _openAddEditReminderSheet(reminder),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isUpcoming ? g.claySoft : g.fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUpcoming ? g.clay.withValues(alpha: 0.25) : g.edge,
                  width: 0.8,
                ),
              ),
              child: Icon(
                isUpcoming
                    ? (reminder.alarmEnabled
                          ? Icons.alarm_rounded
                          : Icons.notifications_active_rounded)
                    : Icons.notifications_off_outlined,
                size: 20,
                color: isUpcoming ? g.clay : g.inkMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: AscentTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isUpcoming ? g.ink : g.inkMuted,
                      decoration: isUpcoming
                          ? null
                          : TextDecoration.lineThrough,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$formattedTime · ${reminder.alarmEnabled ? "Alarm" : "Notification"}',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: isUpcoming
                          ? g.inkMuted
                          : g.inkMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, size: 20, color: g.inkMuted),
              padding: EdgeInsets.zero,
              onSelected: (val) {
                if (val == 'done') {
                  _finishReminder(reminder);
                  return;
                }
                if (val == 'snooze') {
                  _snoozeReminder(reminder);
                  return;
                }
                if (val == 'edit') {
                  _openAddEditReminderSheet(reminder);
                } else if (val == 'delete') {
                  _confirmDeleteReminder(reminder);
                }
              },
              itemBuilder: (context) => [
                if (reminder.isActive)
                  const PopupMenuItem(value: 'done', child: Text('Mark done')),
                if (reminder.isActive)
                  const PopupMenuItem(
                    value: 'snooze',
                    child: Text('Snooze 10 min'),
                  ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 16),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 16, color: g.coral),
                      const SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: g.coral)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
