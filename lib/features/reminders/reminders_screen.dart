import 'widgets/in_app_reminder_dialog.dart';
import 'reminder_action_ui.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../core/notifications/reminder_alarm_bridge.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../core/providers/settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/frozen_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/glass_surface.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import 'package:go_router/go_router.dart';
import '../plans/widgets/plan_detail_sheet.dart';

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
  const RemindersScreen({super.key, this.initialReminderId});
  final int? initialReminderId;

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
    _scheduleTarget();
  }

  @override
  void didUpdateWidget(covariant RemindersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialReminderId != widget.initialReminderId) {
      _scheduleTarget();
    }
  }

  void _scheduleTarget() {
    final id = widget.initialReminderId;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final row = await ref.read(reminderDaoProvider).getReminderById(id);
      if (!mounted || widget.initialReminderId != id) return;
      if (row == null) {
        AscentSnackBar.error(
          context,
          message: 'This reminder is no longer available.',
        );
      } else {
        InAppReminderDialog.show(context, row, isPreview: true);
      }
    });
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
    String? titleError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.glass.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpace.s20,
                right: AppSpace.s20,
                top: AppSpace.s20,
                bottom: bottomInset + AppSpace.s24,
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
                          borderRadius: AppGeometry.roundedr2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null ? 'New Reminder' : 'Edit Reminder',
                          style: AscentTextStyles.displaySmall
                              .copyWith(color: context.textPrimary)
                              .merge(AppTypeRoles.typeRole21),
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
                      onChanged: (_) {
                        if (titleError != null) {
                          setSheetState(() => titleError = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Reminder Title *',
                        hintText: 'e.g. Solve LeetCode DP, Review notes, Walk',
                        errorText: titleError,
                        border: OutlineInputBorder(
                          borderRadius: AppGeometry.roundedr12,
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
                            style: context.surfaces.buttonStyle(
                              OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.s14,
                                ),
                                backgroundColor: context.glass.fill,
                                side: BorderSide(color: context.glass.edge),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppGeometry.roundedr12,
                                ),
                              ),
                              filled: false,
                              icon: false,
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
                            style: context.surfaces.buttonStyle(
                              OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.s14,
                                ),
                                backgroundColor: context.glass.fill,
                                side: BorderSide(color: context.glass.edge),
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppGeometry.roundedr12,
                                ),
                              ),
                              filled: false,
                              icon: false,
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
                          return AppPill.choice(
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
                            labelStyle:
                                AppStateTypography.stateType7(
                                  state0: isSelected,
                                ).copyWith(
                                  color: isSelected
                                      ? context.glass.clay
                                      : context.glass.ink,
                                ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      AppTag(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s12,
                          vertical: AppSpace.s8,
                        ),
                        nightDecoration: BoxDecoration(
                          color: context.glass.claySoft,
                          borderRadius: AppGeometry.roundedr10,
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
                                style: AscentTextStyles.bodySmall
                                    .copyWith(color: context.textPrimary)
                                    .merge(AppTypeRoles.typeRole27),
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
                        horizontal: AppSpace.s14,
                        vertical: AppSpace.s6,
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
                        padding: const EdgeInsets.only(bottom: AppSpace.s12),
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
                              if (title.isEmpty) {
                                setSheetState(() => titleError = 'Title cannot be left empty');
                                HapticFeedback.lightImpact();
                                return;
                              }

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
    await runReminderAction(context, ref, row, ReminderRowAction.done);
  }

  Future<void> _snoozeReminder(Reminder row) async {
    await runReminderAction(context, ref, row, ReminderRowAction.snooze);
  }

  Future<void> _confirmDeleteReminder(Reminder row) async {
    await runReminderAction(context, ref, row, ReminderRowAction.delete);
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(allRemindersProvider);

    final g = context.glass;

    return AscentScaffold(
      title: 'Reminders & Alerts',
      subtitle: 'Scheduled notifications & deadlines',
      actions: [
        IconButton(
          tooltip: 'Routines & Plans',
          icon: const Icon(Icons.event_repeat_rounded),
          onPressed: () => context.push('/plans'),
        ),
        IconButton(
          tooltip: 'Sync reminder alerts',
          icon: _syncingAlerts
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: g.clay,
                  ),
                )
              : const Icon(Icons.sync_rounded),
          onPressed: _syncingAlerts ? null : _syncAlerts,
        ),
      ],
      floatingActionButton: remindersAsync.value?.isNotEmpty == true
          ? AscentButton.fab(
              icon: Icons.add_rounded,
              onPressed: () => _openAddEditReminderSheet(),
            )
          : null,
      body: remindersAsync.when(
        data: (allReminders) {
          final reminders = allReminders
              .where((r) => !r.title.startsWith('Did you do it?'))
              .toList();
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
              left: AppSpace.s16,
              right: AppSpace.s16,
              top: AppSpace.s16,
              bottom: AppSpace.s80,
            ),
            children: [
              if (!_notificationsEnabled) ...[
                AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpace.s16),
                  padding: const EdgeInsets.all(AppSpace.s14),
                  nightDecoration: BoxDecoration(
                    color: g.amberSoft,
                    borderRadius: AppGeometry.roundedr16,
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
                              style: AscentTextStyles.labelMedium
                                  .copyWith(color: g.ink)
                                  .merge(AppTypeRoles.typeRole2),
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
                          style: AppTypeRoles.typeRole9.copyWith(
                            color: g.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── SEGMENTED TOP TOGGLE: UPCOMING VS COMPLETED ─────────────
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpace.s16),
                padding: const EdgeInsets.all(AppSpace.s4),
                nightDecoration: BoxDecoration(
                  color: context.isFrozen
                      ? (context.isDark
                            ? FrozenPalette.darkSurface
                            : FrozenPalette.surface)
                      : g.fill,
                  borderRadius: AppGeometry.roundedr16,
                  border: Border.all(
                    color: context.isFrozen
                        ? (context.isDark
                              ? FrozenPalette.darkLine
                              : FrozenPalette.line)
                        : g.edge,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AppTapArea(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 0);
                        },
                        borderRadius: AppGeometry.roundedr12,
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.s8,
                          ),
                          alignment: Alignment.center,
                          nightDecoration: BoxDecoration(
                            color: _selectedTab == 0
                                ? (context.isFrozen
                                      ? (context.isDark
                                            ? FrozenPalette.darkAction
                                            : FrozenPalette.action)
                                      : (context.isDark
                                            ? g.clay
                                            : context.accentPrimary))
                                : AppPalette.transparent,
                            borderRadius: AppGeometry.roundedr12,
                            border: Border.all(
                              color: _selectedTab == 0
                                  ? (context.isFrozen
                                        ? (context.isDark
                                              ? FrozenPalette.darkAction
                                              : FrozenPalette.action)
                                        : (context.isDark
                                              ? g.clay
                                              : context.accentPrimary))
                                  : AppPalette.transparent,
                              width: AppBorderScale.w1,
                            ),
                          ),
                          child: Text(
                            'Upcoming (${todayReminders.length + tomorrowReminders.length + thisWeekReminders.length + laterReminders.length})',
                            style: AppStateTypography.stateType8(
                              state0: _selectedTab == 0,
                              color: _selectedTab == 0
                                  ? AppPalette.white
                                  : (context.isFrozen
                                        ? (context.isDark
                                              ? FrozenPalette.darkMutedInk
                                              : FrozenPalette.mutedInk)
                                        : g.inkMuted),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: AppTapArea(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = 1);
                        },
                        borderRadius: AppGeometry.roundedr12,
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpace.s8,
                          ),
                          alignment: Alignment.center,
                          nightDecoration: BoxDecoration(
                            color: _selectedTab == 1
                                ? (context.isFrozen
                                      ? (context.isDark
                                            ? FrozenPalette.darkAction
                                            : FrozenPalette.action)
                                      : (context.isDark
                                            ? g.clay
                                            : context.accentPrimary))
                                : AppPalette.transparent,
                            borderRadius: AppGeometry.roundedr12,
                            border: Border.all(
                              color: _selectedTab == 1
                                  ? (context.isFrozen
                                        ? (context.isDark
                                              ? FrozenPalette.darkAction
                                              : FrozenPalette.action)
                                        : (context.isDark
                                              ? g.clay
                                              : context.accentPrimary))
                                  : AppPalette.transparent,
                              width: AppBorderScale.w1,
                            ),
                          ),
                          child: Text(
                            'Completed (${pastReminders.length})',
                            style: AppStateTypography.stateType8(
                              state0: _selectedTab == 1,
                              color: _selectedTab == 1
                                  ? AppPalette.white
                                  : (context.isFrozen
                                        ? (context.isDark
                                              ? FrozenPalette.darkMutedInk
                                              : FrozenPalette.mutedInk)
                                        : g.inkMuted),
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
                    context.isFrozen
                        ? (context.isDark
                              ? FrozenPalette.darkAction
                              : FrozenPalette.action)
                        : g.inkSecondary,
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.task_alt_rounded, size: 40, color: g.clay),
                          const SizedBox(height: 12),
                          Text(
                            'No active reminders',
                            style: AscentTextStyles.headlineMedium
                                .copyWith(color: g.ink)
                                .merge(AppTypeRoles.typeRole9),
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
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s36),
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
                            style: AscentTextStyles.headlineMedium
                                .copyWith(color: g.ink)
                                .merge(AppTypeRoles.typeRole9),
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
      padding: const EdgeInsets.only(bottom: AppSpace.s10, top: AppSpace.s12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: AscentTextStyles.labelLarge
                .copyWith(color: g.ink)
                .merge(AppTypeRoles.typeRole9),
          ),
          const SizedBox(width: 8),
          AppTag(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s7,
              vertical: AppSpace.s2,
            ),
            nightDecoration: BoxDecoration(
              color: context.isFrozen
                  ? (context.isDark
                        ? FrozenPalette.darkCanvas
                        : FrozenPalette.canvas)
                  : color.withValues(alpha: 0.12),
              borderRadius: AppGeometry.roundedr10,
              border: context.isFrozen
                  ? Border.all(
                      color: context.isDark
                          ? FrozenPalette.darkLine
                          : FrozenPalette.line,
                      width: 1.0,
                    )
                  : null,
            ),
            child: Text(
              '$count',
              style: AppTypeRoles.typeRole34.copyWith(
                color: context.isFrozen
                    ? (context.isDark
                          ? FrozenPalette.darkSecondaryInk
                          : FrozenPalette.secondaryInk)
                    : color,
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
    final protection = ref.watch(reminderProtectionProvider(reminder.id)).value;

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDeleteReminder(reminder);
        return false;
      },
      background: AppCard(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.s20),
        nightDecoration: BoxDecoration(
          color: g.coralSoft,
          borderRadius: AppGeometry.roundedr16,
        ),
        child: Icon(Icons.delete_outline, color: g.coral),
      ),
      child: AscentCard(
        margin: const EdgeInsets.only(bottom: AppSpace.s10),
        padding: const EdgeInsets.all(AppSpace.s14),
        onTap: () {
          if (protection != null) {
            showPlanDetailSheet(context, protection.planId);
          } else {
            _openAddEditReminderSheet(reminder);
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AppTag(
              padding: const EdgeInsets.all(AppSpace.s10),
              nightDecoration: BoxDecoration(
                color: isUpcoming
                    ? (context.isFrozen
                          ? (context.isDark
                                ? FrozenPalette.darkTint
                                : FrozenPalette.tint)
                          : g.claySoft)
                    : g.fill,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUpcoming
                      ? (context.isFrozen
                            ? (context.isDark
                                  ? FrozenPalette.darkLine
                                  : FrozenPalette.line)
                            : g.clay.withValues(alpha: 0.25))
                      : g.edge,
                  width: AppBorderScale.w1,
                ),
              ),
              child: Icon(
                isUpcoming
                    ? (reminder.alarmEnabled
                          ? Icons.alarm_rounded
                          : Icons.notifications_active_rounded)
                    : Icons.notifications_off_outlined,
                size: 20,
                color: isUpcoming
                    ? (context.isFrozen
                          ? (context.isDark
                                ? FrozenPalette.darkAction
                                : FrozenPalette.action)
                          : g.clay)
                    : g.inkMuted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: AscentTextStyles.bodyMedium
                        .copyWith(
                          color: isUpcoming ? g.ink : g.inkMuted,
                          decoration: isUpcoming
                              ? null
                              : TextDecoration.lineThrough,
                        )
                        .merge(AppTypeRoles.typeRole8),
                  ),
                  if (reminder.isActive)
                    Wrap(
                      children: [
                        TextButton.icon(
                          onPressed: () => _finishReminder(reminder),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Done'),
                        ),
                        TextButton.icon(
                          onPressed: () => _snoozeReminder(reminder),
                          icon: const Icon(Icons.snooze_rounded),
                          label: const Text('Snooze'),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (protection != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: g.claySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Part of ${protection.planTitle}',
                            style: TextStyle(
                              fontSize: 10,
                              color: g.clay,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      Text(
                        reminder.alarmEnabled
                            ? '$formattedTime · Alarm'
                            : formattedTime,
                        style: AscentTextStyles.bodySmall.copyWith(
                          color: isUpcoming
                              ? g.inkMuted
                              : g.inkMuted.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
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
                  if (protection != null) {
                    showPlanDetailSheet(context, protection.planId);
                  } else {
                    _openAddEditReminderSheet(reminder);
                  }
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
