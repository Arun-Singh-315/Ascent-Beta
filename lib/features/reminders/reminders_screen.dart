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
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_switch_row.dart';
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
  int _selectedTab = 0; // 0: Active, 1: Completed
  final Set<String> _collapsedSections = <String>{};
  bool _isCalendarView = false;
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isMonthExpanded = false;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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

  void _openAddEditReminderSheet([Reminder? existing, DateTime? initialDate]) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    DateTime scheduledDate = existing?.scheduledAt ??
        (initialDate != null
            ? DateTime(
                initialDate.year,
                initialDate.month,
                initialDate.day,
                DateTime.now().hour < 23 ? DateTime.now().hour + 1 : 9,
              )
            : DateTime.now().add(const Duration(hours: 1)));
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
                    AscentSwitchRow(
                      title: 'Ring as an alarm',
                      helper:
                          'Optional. Rings until Snooze or Done. Off uses a normal notification.',
                      value: alarmEnabled,
                      enabled: !saving,
                      onChanged: (value) =>
                          setSheetState(() => alarmEnabled = value),
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
                                setSheetState(
                                  () =>
                                      titleError = 'Title cannot be left empty',
                                );
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

  Widget _notificationPermissionNotice() {
    final g = context.glass;
    return AppCard(
      key: const ValueKey('reminder_notification_permission'),
      margin: const EdgeInsets.only(bottom: AppSpace.s16),
      padding: const EdgeInsets.all(AppSpace.s14),
      nightDecoration: BoxDecoration(
        color: g.amberSoft,
        borderRadius: AppGeometry.roundedr16,
        border: Border.all(color: g.amber.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_off_rounded, color: g.amber, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notifications disabled',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: g.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Allow notifications to receive scheduled alerts on this phone.',
                      style: TextStyle(color: g.inkMuted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () async {
                HapticFeedback.lightImpact();
                await NotificationService.instance.requestPermissions();
                await _checkNotificationPermission();
                if (_notificationsEnabled) await _syncAlerts();
              },
              child: const Text('Enable notifications'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remindersAsync = ref.watch(allRemindersProvider);
    final tasksAsync = ref.watch(allTasksStreamProvider);
    final allTasks = tasksAsync.value ?? const <Task>[];

    final g = context.glass;

    return AscentScaffold(
      title: 'Reminders & Alerts',
      subtitle: 'Scheduled notifications & deadlines',
      actions: [
        IconButton(
          key: const ValueKey('reminders_view_mode_toggle'),
          tooltip: _isCalendarView ? 'List view' : 'Calendar view',
          icon: Icon(
            _isCalendarView
                ? Icons.view_agenda_rounded
                : Icons.calendar_month_rounded,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _isCalendarView = !_isCalendarView);
          },
        ),
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
            return ListView(
              padding: const EdgeInsets.all(AppSpace.s16),
              children: [
                if (!_notificationsEnabled) _notificationPermissionNotice(),
                const SizedBox(height: 48),
                EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No Reminders Yet',
                  subtitle:
                      'Set reminders for upcoming interviews, study blocks, and application deadlines.',
                  actionLabel: 'Create Reminder',
                  onAction: () => _openAddEditReminderSheet(),
                ),
              ],
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
              if (!_notificationsEnabled) _notificationPermissionNotice(),

              // ── SEGMENTED TOP TOGGLE: UPCOMING VS COMPLETED + CALENDAR TOGGLE ─────────────
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s16),
                child: Row(
                  children: [
                    Expanded(
                      child: AscentSegmentedControl<int>(
                        segments: [
                          AscentSegment(
                            value: 0,
                            label: 'Active (${reminders.where((r) => r.isActive).length})',
                          ),
                          AscentSegment(
                            value: 1,
                            label: 'Completed (${pastReminders.length})',
                          ),
                        ],
                        selected: _selectedTab,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = val);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    IconButton.filledTonal(
                      key: const ValueKey('calendar_toggle_button'),
                      tooltip: _isCalendarView ? 'Show as List' : 'Show Calendar',
                      style: IconButton.styleFrom(
                        backgroundColor: _isCalendarView
                            ? g.clay.withValues(alpha: 0.15)
                            : g.fill,
                        foregroundColor: _isCalendarView ? g.clay : g.inkSecondary,
                        side: BorderSide(
                          color: _isCalendarView
                              ? g.clay.withValues(alpha: 0.4)
                              : g.line,
                        ),
                        padding: const EdgeInsets.all(AppSpace.s10),
                      ),
                      icon: Icon(
                        _isCalendarView
                            ? Icons.view_agenda_rounded
                            : Icons.calendar_month_rounded,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _isCalendarView = !_isCalendarView);
                      },
                    ),
                  ],
                ),
              ),

              if (_selectedTab == 0 && _isCalendarView) ...[
                _buildGoogleCalendarView(
                  context,
                  g,
                  reminders.where((r) => r.isActive).toList(),
                  allTasks,
                ),
              ] else if (_selectedTab == 0) ...[
                if (overdueReminders.isNotEmpty) ...[
                  _buildReminderGroup(
                    'Overdue',
                    overdueReminders,
                    g.coral,
                    Icons.schedule_rounded,
                    isUpcoming: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (todayReminders.isNotEmpty) ...[
                  _buildReminderGroup(
                    'Today',
                    todayReminders,
                    g.amber,
                    Icons.today_rounded,
                    isUpcoming: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (tomorrowReminders.isNotEmpty) ...[
                  _buildReminderGroup(
                    'Tomorrow',
                    tomorrowReminders,
                    g.inkSecondary,
                    Icons.event_rounded,
                    isUpcoming: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (thisWeekReminders.isNotEmpty) ...[
                  _buildReminderGroup(
                    'This Week',
                    thisWeekReminders,
                    g.inkSecondary,
                    Icons.date_range_rounded,
                    isUpcoming: true,
                  ),
                  const SizedBox(height: 12),
                ],
                if (laterReminders.isNotEmpty) ...[
                  _buildReminderGroup(
                    'Upcoming & Later',
                    laterReminders,
                    g.inkMuted,
                    Icons.calendar_month_rounded,
                    isUpcoming: true,
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
                  _buildReminderGroup(
                    'Completed & Past',
                    pastReminders,
                    g.sage,
                    Icons.history_rounded,
                    isUpcoming: false,
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
                            'Reminders you finish will appear here.',
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

  Widget _buildReminderGroup(
    String title,
    List<Reminder> reminders,
    Color color,
    IconData icon, {
    required bool isUpcoming,
  }) {
    final isCollapsed = _collapsedSections.contains(title);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                if (isCollapsed) {
                  _collapsedSections.remove(title);
                } else {
                  _collapsedSections.add(title);
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: _buildSectionHeader(
                title,
                reminders.length,
                color,
                icon,
                isCollapsed: isCollapsed,
              ),
            ),
          ),
          if (!isCollapsed)
            for (final reminder in reminders)
              _buildReminderTile(
                reminder,
                isUpcoming: isUpcoming,
                accent: color,
              ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon, {
    bool isCollapsed = false,
  }) {
    final g = context.glass;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: AscentTextStyles.headlineMedium.copyWith(
            color: g.ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        const Spacer(),
        Icon(
          isCollapsed
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_up_rounded,
          size: 18,
          color: g.inkMuted,
        ),
      ],
    );
  }

  Widget _buildReminderTile(
    Reminder reminder, {
    required bool isUpcoming,
    required Color accent,
  }) {
    final g = context.glass;
    final isOverdue =
        reminder.isActive && reminder.scheduledAt.isBefore(DateTime.now());
    final formattedTime = DateFormat(
      'EEE, MMM d • h:mm a',
    ).format(reminder.scheduledAt);
    final protection = ref.watch(reminderProtectionProvider(reminder.id)).value;

    final borderColor = isUpcoming
        ? (isOverdue
            ? g.coral.withValues(alpha: 0.45)
            : accent.withValues(alpha: 0.25))
        : g.line.withValues(alpha: 0.25);

    final groundBg = isUpcoming
        ? (isOverdue
            ? g.coral.withValues(alpha: g.isDark ? 0.08 : 0.04)
            : g.fill.withValues(alpha: g.isDark ? 0.06 : 0.03))
        : (g.isDark ? g.fill.withValues(alpha: 0.03) : Colors.transparent);

    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await _confirmDeleteReminder(reminder);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpace.s20),
        decoration: BoxDecoration(
          color: g.coralSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Delete',
              style: TextStyle(color: g.coral, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline, color: g.coral),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: groundBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isOverdue ? 1.1 : 0.9,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (protection != null) {
              showPlanDetailSheet(context, protection.planId);
            } else {
              _openAddEditReminderSheet(reminder);
            }
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Leading Circular Action Target (Apple Reminders Style)
                Semantics(
                  button: true,
                  label: reminder.isActive ? 'Mark done' : 'Completed',
                  child: InkResponse(
                    onTap: reminder.isActive
                        ? () {
                            HapticFeedback.mediumImpact();
                            _finishReminder(reminder);
                          }
                        : null,
                    radius: 20,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reminder.isActive
                            ? Colors.transparent
                            : accent.withValues(alpha: 0.15),
                        border: Border.all(
                          color: reminder.isActive
                              ? (isOverdue ? g.coral : accent)
                              : g.line,
                          width: 1.6,
                        ),
                      ),
                      child: reminder.isActive
                          ? null
                          : Icon(
                              Icons.check_rounded,
                              size: 15,
                              color: accent,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Reminder Content (Title & Metadata)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUpcoming ? g.ink : g.inkMuted,
                          fontSize: 16,
                          fontWeight:
                              isUpcoming ? FontWeight.w600 : FontWeight.w500,
                          height: 1.35,
                          decoration: isUpcoming
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (protection != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: g.claySoft,
                                borderRadius: BorderRadius.circular(6),
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
                          Icon(
                            reminder.alarmEnabled
                                ? Icons.alarm_rounded
                                : Icons.schedule_rounded,
                            size: 13,
                            color: isOverdue ? g.coral : g.inkMuted,
                          ),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: isOverdue
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isOverdue ? g.coral : g.inkMuted,
                            ),
                          ),
                          if (isOverdue)
                            Text(
                              '· Overdue',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: g.coral,
                              ),
                            ),
                          if (reminder.isActive && reminder.scheduledAt.isAfter(DateTime.now()))
                            InkWell(
                              onTap: () => _finishReminder(reminder),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: g.fill.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: g.line.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  'At ${DateFormat('h:mm a').format(reminder.scheduledAt)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: g.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Trailing Snooze button for active reminders
                if (reminder.isActive)
                  IconButton(
                    tooltip: 'Snooze 10 min',
                    icon: const Icon(Icons.snooze_rounded, size: 18),
                    color: g.inkMuted,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _snoozeReminder(reminder);
                    },
                  ),
                // Trailing 3-dots Menu for Full Options
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: g.inkMuted,
                  ),
                  tooltip: 'Reminder actions',
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
                      const PopupMenuItem(
                        value: 'done',
                        child: Text('Mark done'),
                      ),
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
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: g.coral)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleCalendarView(
    BuildContext context,
    AscentGlass g,
    List<Reminder> activeReminders,
    List<Task> allTasks,
  ) {
    final now = DateTime.now();
    final isCurrentMonth =
        _calendarMonth.year == now.year && _calendarMonth.month == now.month;

    final dayReminders =
        activeReminders
            .where((r) => _isSameDay(r.scheduledAt, _selectedCalendarDate))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final dayTasks =
        allTasks.where((t) {
          if (t.actualCompletedDate != null) return false;
          if (t.plannedDate != null) {
            return _isSameDay(t.plannedDate!, _selectedCalendarDate);
          }
          return _isSameDay(now, _selectedCalendarDate);
        }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Google Calendar Glass Card Enclosure ────────────────────────
        Container(
          key: const ValueKey('reminders_calendar_card'),
          decoration: BoxDecoration(
            color: g.fill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: g.line, width: 0.8),
          ),
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Calendar Month Navigation Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('MMMM yyyy').format(_calendarMonth),
                      style: AscentTextStyles.cardTitle.copyWith(
                        color: g.ink,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    key: const ValueKey('calendar_today_button'),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _selectedCalendarDate = DateTime.now();
                        _calendarMonth = DateTime(now.year, now.month);
                      });
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isCurrentMonth &&
                                    _isSameDay(_selectedCalendarDate, now)
                                ? g.clay.withValues(alpha: 0.18)
                                : g.fill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color:
                              isCurrentMonth &&
                                      _isSameDay(_selectedCalendarDate, now)
                                  ? g.clay.withValues(alpha: 0.4)
                                  : g.line,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Today',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.clay,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: const ValueKey('calendar_prev_month'),
                    icon: const Icon(Icons.chevron_left_rounded),
                    iconSize: 22,
                    color: g.ink,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'Previous month',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _calendarMonth = DateTime(
                          _calendarMonth.year,
                          _calendarMonth.month - 1,
                        );
                      });
                    },
                  ),
                  IconButton(
                    key: const ValueKey('calendar_next_month'),
                    icon: const Icon(Icons.chevron_right_rounded),
                    iconSize: 22,
                    color: g.ink,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: 'Next month',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _calendarMonth = DateTime(
                          _calendarMonth.year,
                          _calendarMonth.month + 1,
                        );
                      });
                    },
                  ),
                  IconButton(
                    key: const ValueKey('calendar_expand_toggle'),
                    icon: Icon(
                      _isMonthExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    iconSize: 22,
                    color: g.inkSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip:
                        _isMonthExpanded
                            ? 'Compact week view'
                            : 'Full month view',
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isMonthExpanded = !_isMonthExpanded);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weekday Names Row (Mon, Tue, Wed, Thu, Fri, Sat, Sun)
              const Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'M',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'T',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'W',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'T',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'F',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'S',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'S',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Calendar Days: either Week Strip or Full Month Grid
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child:
                    _isMonthExpanded
                        ? _buildMonthGrid(g, activeReminders, allTasks)
                        : _buildWeekStrip(g, activeReminders, allTasks),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Selected Date Agenda Section ──────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSameDay(_selectedCalendarDate, now)
                        ? 'Today, ${DateFormat('MMM d').format(_selectedCalendarDate)}'
                        : DateFormat(
                          'EEEE, MMM d',
                        ).format(_selectedCalendarDate),
                    style: AscentTextStyles.cardTitle.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${dayReminders.length} reminder${dayReminders.length == 1 ? '' : 's'} • ${dayTasks.length} task${dayTasks.length == 1 ? '' : 's'}',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AscentButton.secondary(
              label: 'Add',
              icon: Icons.add_rounded,
              compact: true,
              onPressed:
                  () => _openAddEditReminderSheet(null, _selectedCalendarDate),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Agenda Items
        if (dayReminders.isEmpty && dayTasks.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: g.fill,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: g.line, width: 0.8),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 36,
                  color: g.inkMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  'No events on this day',
                  style: AscentTextStyles.bodyMedium.copyWith(
                    color: g.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reminders and tasks scheduled for this day will appear here.',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: g.inkSecondary,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (dayReminders.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'REMINDERS',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: const Color(0xFF0284C7),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            for (final reminder in dayReminders)
              _buildCalendarReminderTile(reminder, g),
            const SizedBox(height: 12),
          ],
          if (dayTasks.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TASKS & TO-DOS',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: const Color(0xFFF59E0B),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            for (final task in dayTasks) _buildCalendarTaskTile(task, g),
          ],
        ],
      ],
    );
  }

  Widget _buildWeekStrip(
    AscentGlass g,
    List<Reminder> activeReminders,
    List<Task> allTasks,
  ) {
    final monday = _selectedCalendarDate.subtract(
      Duration(days: _selectedCalendarDate.weekday - 1),
    );
    final days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );

    return Row(
      children: [
        for (final day in days)
          Expanded(
            child: _buildCalendarDayCell(
              day,
              day.month == _calendarMonth.month,
              activeReminders,
              allTasks,
              g,
            ),
          ),
      ],
    );
  }

  Widget _buildMonthGrid(
    AscentGlass g,
    List<Reminder> activeReminders,
    List<Task> allTasks,
  ) {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final daysInMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final totalCells = (firstDay.weekday - 1 + daysInMonth <= 35) ? 35 : 42;
    final days = List.generate(
      totalCells,
      (i) => DateTime(firstMonday.year, firstMonday.month, firstMonday.day + i),
    );

    return Column(
      children: [
        for (int week = 0; week < totalCells ~/ 7; week++) ...[
          if (week > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (int dayIdx = 0; dayIdx < 7; dayIdx++)
                Expanded(
                  child: _buildCalendarDayCell(
                    days[week * 7 + dayIdx],
                    days[week * 7 + dayIdx].month == _calendarMonth.month,
                    activeReminders,
                    allTasks,
                    g,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCalendarDayCell(
    DateTime day,
    bool isCurrentMonth,
    List<Reminder> activeReminders,
    List<Task> allTasks,
    AscentGlass g,
  ) {
    final now = DateTime.now();
    final isSelected = _isSameDay(day, _selectedCalendarDate);
    final isToday = _isSameDay(day, now);

    final hasReminders = activeReminders.any(
      (r) => _isSameDay(r.scheduledAt, day),
    );
    final hasTasks = allTasks.any((t) {
      if (t.actualCompletedDate != null) return false;
      if (t.plannedDate != null) return _isSameDay(t.plannedDate!, day);
      return _isSameDay(now, day);
    });

    return InkWell(
      key: ValueKey('calendar_day_${day.year}_${day.month}_${day.day}'),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedCalendarDate = day;
          if (day.month != _calendarMonth.month) {
            _calendarMonth = DateTime(day.year, day.month);
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? g.clay.withValues(alpha: 0.22)
                  : (isToday
                      ? g.clay.withValues(alpha: 0.08)
                      : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? g.clay
                    : (isToday
                        ? g.clay.withValues(alpha: 0.4)
                        : Colors.transparent),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                  color:
                      isSelected
                          ? g.clay
                          : (isCurrentMonth
                              ? g.ink
                              : g.inkMuted.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (hasReminders)
                  Container(
                    width: 4.5,
                    height: 4.5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                if (hasTasks)
                  Container(
                    width: 4.5,
                    height: 4.5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFF59E0B),
                    ),
                  ),
                if (!hasReminders && !hasTasks) const SizedBox(height: 4.5),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarReminderTile(Reminder reminder, AscentGlass g) {
    final formatTime = DateFormat('h:mm a').format(reminder.scheduledAt);
    return Container(
      key: ValueKey('calendar_reminder_tile_${reminder.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: g.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.line, width: 0.8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openAddEditReminderSheet(reminder),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                    width: 0.7,
                  ),
                ),
                child: Text(
                  formatTime,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: g.ink,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (reminder.alarmEnabled) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.alarm_rounded, size: 12, color: g.coral),
                          const SizedBox(width: 4),
                          Text(
                            'Alarm active',
                            style: AscentTextStyles.labelSmall.copyWith(
                              color: g.coral,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: ValueKey('calendar_reminder_complete_${reminder.id}'),
                tooltip: 'Complete reminder',
                icon: Icon(Icons.circle_outlined, size: 22, color: g.clay),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _finishReminder(reminder);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarTaskTile(Task task, AscentGlass g) {
    return Container(
      key: ValueKey('calendar_task_tile_${task.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: g.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.line, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.check_box_outlined,
                size: 15,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.notes != null && task.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.notes!,
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: g.inkSecondary,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              key: ValueKey('calendar_task_complete_${task.id}'),
              tooltip: 'Complete task',
              icon: const Icon(
                Icons.circle_outlined,
                size: 22,
                color: Color(0xFFF59E0B),
              ),
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final undo = await ref
                    .read(taskDaoProvider)
                    .completeWithUndo(task.id);
                if (mounted && undo != null) {
                  AscentSnackBar.applaud(
                    context,
                    message: 'Task completed: ${task.title}',
                    onUndo: () async {
                      await ref
                          .read(taskDaoProvider)
                          .undoCompletion(undo);
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
