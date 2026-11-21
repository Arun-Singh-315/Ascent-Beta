import 'package:ascent/app/app_navigation.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../calendar/calendar_event_sheet.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../today/add_activity_sheet.dart';
import 'widgets/in_app_reminder_dialog.dart';
import 'widgets/ios_reminder_dialog.dart';
import 'reminder_action_ui.dart';
import 'package:drift/drift.dart' as drift;
import '../../core/services/quick_add_parser.dart';
import '../../shared/widgets/app_input_bar.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../shared/widgets/undo_snackbar.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/calendar_view_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../app/theme/glass_theme.dart';
import '../../app/theme/monochrome_surfaces.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../shared/widgets/ascent_calendar_day.dart';
import '../../shared/widgets/feature_guide.dart';
import '../home/widgets/home_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/services/festival_service.dart';
import '../../shared/widgets/festive_sparkle_badge.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import 'package:go_router/go_router.dart';
import '../plans/widgets/plan_detail_sheet.dart';

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({
    super.key,
    this.initialReminderId,
    this.initialCalendarDate,
    this.openCalendar = false,
    this.calendarOnly = false,
    this.thingsOnly = false,
  });
  final DateTime? initialCalendarDate;
  final bool openCalendar;
  final bool calendarOnly;
  final bool thingsOnly;
  final int? initialReminderId;

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> {
  int _calendarScope = 0;
  bool _notificationsEnabled = true;
  int _selectedTab = 0; // 0: Active, 1: Completed
  final Set<String> _collapsedSections = <String>{};
  bool _isCalendarView = false;
  DateTime _selectedCalendarDate = DateTime.now();
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isMonthExpanded = false;

  void _publishCalendarView() {
    if (widget.calendarOnly) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref
            .read(calendarViewModeProvider.notifier)
            .showCalendar(_isCalendarView);
      }
    });
  }

  void _toggleCalendarView() {
    setState(() => _isCalendarView = !_isCalendarView);
    ref.read(calendarViewModeProvider.notifier).showCalendar(_isCalendarView);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  void initState() {
    super.initState();
    _calendarScope = widget.thingsOnly ? 1 : 0;
    _applyCalendarTarget();
    _publishCalendarView();
    if (!widget.calendarOnly) _checkNotificationPermission();
    _scheduleTarget();
  }

  @override
  void didUpdateWidget(covariant RemindersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCalendarDate != widget.initialCalendarDate ||
        oldWidget.openCalendar != widget.openCalendar) {
      _applyCalendarTarget();
      _publishCalendarView();
    }
    if (oldWidget.initialReminderId != widget.initialReminderId) {
      _scheduleTarget();
    }
  }

  void _applyCalendarTarget() {
    if (!widget.openCalendar) return;
    final day = widget.initialCalendarDate ?? DateTime.now();
    _isCalendarView = true;
    _selectedTab = 0;
    _selectedCalendarDate = DateTime(day.year, day.month, day.day);
    _calendarMonth = DateTime(day.year, day.month);
    _isMonthExpanded = true;
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

  Future<void> _openAddEditReminderSheet([Reminder? existing, DateTime? initialDate]) async {
    final result = await showIOSReminderDialog(
      context,
      existing: existing,
      initialDate: initialDate,
    );
    if (result != null && mounted) {
      ref.invalidate(allRemindersProvider);
      ref.invalidate(nextUpcomingReminderProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        AscentSnackBar.build(
          context,
          content: Text(
            existing == null ? 'Reminder scheduled' : 'Reminder updated',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _more() async {
    final action = await showAscentActionMenu<String>(
      context: context,
      title: 'Reminders',
      actions: [
        const AscentAction(
          'things',
          'Open Things',
          Icons.dashboard_customize_outlined,
        ),
        const AscentAction('plans', 'Routines and plans', Icons.event_repeat_rounded),
        AscentAction(
          'sync',
          _syncingAlerts ? 'Syncing alerts…' : 'Sync reminder alerts',
          Icons.sync_rounded,
        ),
        const AscentAction('help', 'How this works', Icons.help_outline_rounded),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'things':
        context.open('/things');
      case 'plans':
        context.push('/plans');
      case 'sync':
        if (!_syncingAlerts) await _syncAlerts();
      case 'help':
        showFeatureGuide(context, 'Reminders & Alerts');
    }
  }

  // Quick add ---------------------------------------------------------------

  final _quick = TextEditingController();

  @override
  void dispose() {
    _quick.dispose();
    super.dispose();
  }

  /// "Pay rent tomorrow 9am" → a reminder at that time; with no time, the
  /// next half hour today (9:00 on other days). Undo removes it.
  Future<void> _quickAdd() async {
    final text = _quick.text.trim();
    if (text.isEmpty) return;
    final now = DateTime.now();
    final parsed = parseQuickAdd(text, now);
    final title = parsed.title.trim().isEmpty ? text : parsed.title.trim();
    final day = parsed.day ?? DateTime(now.year, now.month, now.day);
    DateTime at;
    if (parsed.hour != null) {
      at = DateTime(day.year, day.month, day.day, parsed.hour!, parsed.minute ?? 0);
    } else if (DateTime(day.year, day.month, day.day)
        .isAfter(DateTime(now.year, now.month, now.day))) {
      at = DateTime(day.year, day.month, day.day, 9);
    } else {
      final next = now.add(Duration(minutes: 30 - now.minute % 30));
      at = DateTime(next.year, next.month, next.day, next.hour, next.minute);
    }
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    final db = ref.read(databaseProvider);
    try {
      final id = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: title,
          scheduledAt: at,
          alertSyncPending: const drift.Value(true),
        ),
      );
      _quick.clear();
      HapticFeedback.lightImpact();
      try {
        await ReminderAlertSync.device(db).sync(ids: [id], onlyPending: true);
      } catch (_) {}
      if (!mounted) return;
      showUndoSnackbar(
        context,
        message:
            'Reminder set for ${DateFormat('EEE h:mm a').format(at)}',
        onUndo: () async {
          await (db.update(db.reminderTable)..where((r) => r.id.equals(id)))
              .write(
                const ReminderTableCompanion(
                  isActive: drift.Value(false),
                  alertSyncPending: drift.Value(true),
                ),
              );
          await db.reminderDao.deleteReminder(id);
        },
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not set the reminder.');
      }
    }
  }

  Future<void> _finishReminder(Reminder row) async {
    await runReminderAction(context, ref, row, ReminderRowAction.done);
  }

  Future<void> _snoozeReminder(Reminder row) async {
    await runReminderAction(context, ref, row, ReminderRowAction.snooze);
  }

  Future<void> _confirmDeleteReminder(Reminder row) async {
    final confirmed = await AscentDialog.confirm(
      context: context,
      title: 'Delete this reminder?',
      content:
          'Are you sure you want to delete "${row.title}"? You can undo this immediately afterwards.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep reminder',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true && mounted) {
      await runReminderAction(context, ref, row, ReminderRowAction.delete);
    }
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
    final activitiesAsync = ref.watch(todayActivitiesProvider);
    final allActivities = activitiesAsync.value ?? const <TodayActivityItem>[];

    return Theme(
      data: _isCalendarView
          ? HomeTheme.from(Theme.of(context))
          : Theme.of(context),
      child: Builder(
        builder: (context) =>
            _buildScreen(context, remindersAsync, allTasks, allActivities),
      ),
    );
  }

  Widget _buildScreen(
    BuildContext context,
    AsyncValue<List<Reminder>> remindersAsync,
    List<Task> allTasks,
    List<TodayActivityItem> allActivities,
  ) {
    final g = context.glass;
    if (widget.calendarOnly) {
      final reminders = remindersAsync.value ?? const <Reminder>[];
      final tasksState = ref.watch(allTasksStreamProvider);
      final activitiesState = ref.watch(todayActivitiesProvider);
      final sources = [remindersAsync, tasksState, activitiesState];
      return AscentScaffold(
        title: 'Calendar',
        subtitle: _calendarScope == 1
            ? 'Tasks, to-dos & activities'
            : _calendarScope == 2
            ? 'Reminders & alerts'
            : 'Tasks, activities & reminders',
        showFeatureHelp: false,
        glow1: Colors.transparent,
        glow2: Colors.transparent,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            AscentSegmentedControl<int>(
              inline: true,
              segments: const [
                AscentSegment(value: 0, label: 'Everything'),
                AscentSegment(value: 1, label: 'Things'),
                AscentSegment(value: 2, label: 'Reminders'),
              ],
              selected: _calendarScope,
              onChanged: (value) => setState(() => _calendarScope = value),
            ),
            const SizedBox(height: 12),
            if (sources.any((source) => source.isLoading))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LinearProgressIndicator(),
              ),
            if (sources.any((source) => source.hasError))
              TextButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Some items could not load. Retry'),
                onPressed: () {
                  ref.invalidate(allRemindersProvider);
                  ref.invalidate(allTasksStreamProvider);
                  ref.invalidate(todayActivitiesProvider);
                },
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('calendar_schedule_event'),
                icon: const Icon(Icons.event_available_outlined),
                label: const Text('Schedule meeting or event'),
                onPressed: () =>
                    showCalendarEventSheet(context, _selectedCalendarDate),
              ),
            ),
            const SizedBox(height: 16),
            _buildGoogleCalendarView(
              context,
              g,
              _calendarScope == 1
                  ? []
                  : reminders
                        .where(
                          (r) =>
                              r.isActive &&
                              !r.title.startsWith('Did you do it?'),
                        )
                        .toList(),
              _calendarScope == 2 ? [] : allTasks,
              _calendarScope == 2 ? [] : allActivities,
            ),
          ],
        ),
      );
    }
    return AscentScaffold(
      title: 'Reminders',
      titleWidget: _isCalendarView
          ? Text(
              'Calendar',
              style: AscentTextStyles.interfaceTitle.copyWith(color: g.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      showFeatureHelp: !_isCalendarView,
      glow1: _isCalendarView ? Colors.transparent : null,
      glow2: _isCalendarView ? Colors.transparent : null,
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
            _toggleCalendarView();
          },
        ),
        if (_isCalendarView)
          PopupMenuButton<String>(
            key: const ValueKey('calendar_more_actions'),
            tooltip: 'More calendar actions',
            icon: const Icon(Icons.more_horiz_rounded),
            onSelected: (action) {
              switch (action) {
                case 'activities':
                  context.go('/things');
                case 'plans':
                  context.go('/plans');
                case 'sync':
                  _syncAlerts();
                case 'help':
                  showFeatureGuide(context, 'Reminders & Alerts');
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'activities',
                key: ValueKey('calendar_dayboard_button'),
                child: Text('Dayboard & activities'),
              ),
              const PopupMenuItem(
                value: 'plans',
                child: Text('Routines & plans'),
              ),
              PopupMenuItem(
                value: 'sync',
                enabled: !_syncingAlerts,
                child: Text(
                  _syncingAlerts ? 'Syncing alerts…' : 'Sync reminder alerts',
                ),
              ),
              const PopupMenuItem(value: 'help', child: Text('How this works')),
            ],
          )
        else
          IconButton(
            key: const ValueKey('reminders_more'),
            tooltip: 'More',
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: _more,
          ),
      ],
      // Quick add at the thumb: type it, send it. "+" opens the full form.
      bottomNavigationBar: _isCalendarView
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s16,
                  AppSpace.s8,
                  AppSpace.s16,
                  AppSpace.s12,
                ),
                child: AppInputBar(
                  key: const ValueKey('reminders_quick_add'),
                  controller: _quick,
                  hint: 'e.g. Pay rent tomorrow 9am',
                  singleLine: true,
                  submitTooltip: 'Set reminder',
                  leadingIcon: Icons.add_rounded,
                  leadingTooltip: 'More options',
                  onLeadingTap: () => _openAddEditReminderSheet(),
                  onSubmit: _quickAdd,
                  glass: true,
                ),
              ),
            ),
      body: remindersAsync.when(
        data: (allReminders) {
          final reminders = allReminders
              .where((r) => !r.title.startsWith('Did you do it?'))
              .toList();
          if (reminders.isEmpty && !_isCalendarView) {
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s16,
                AppSpace.s16,
                100 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (!_notificationsEnabled) _notificationPermissionNotice(),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s16),
                  child: Row(
                    children: [
                      Expanded(
                        child: AscentSegmentedControl<int>(
                          segments: const [
                            AscentSegment(value: 0, label: 'Active'),
                            AscentSegment(value: 1, label: 'Completed'),
                          ],
                          selected: _selectedTab,
                          onChanged: (val) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedTab = val);
                          },
                        ),
                      ),

                    ],
                  ),
                ),
                const SizedBox(height: 32),
                EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No Reminders Yet',
                  subtitle:
                      'Set reminders for upcoming interviews, study blocks, and application deadlines.',
                  actionLabel: 'Create Reminder',
                  onAction: () => _openAddEditReminderSheet(),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: const Text('Open Calendar & Schedule View'),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isCalendarView = true);
                    },
                  ),
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
            padding: EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s16,
              AppSpace.s16,
              100 + MediaQuery.paddingOf(context).bottom,
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
                            label: _count(
                              'Active',
                              reminders.where((r) => r.isActive).length,
                            ),
                          ),
                          AscentSegment(
                            value: 1,
                            label: _count('Completed', pastReminders.length),
                          ),
                        ],
                        selected: _selectedTab,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTab = val);
                        },
                      ),
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
                  allActivities,
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
          border: Border.all(color: borderColor, width: isOverdue ? 1.1 : 0.9),
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
                          : Icon(Icons.check_rounded, size: 15, color: accent),
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
                          fontWeight: isUpcoming
                              ? FontWeight.w600
                              : FontWeight.w500,
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
    List<Task> allTasks, [
    List<TodayActivityItem> allActivities = const [],
  ]) {
    final now = DateTime.now();

    final dayReminders =
        activeReminders
            .where((r) => _isSameDay(r.scheduledAt, _selectedCalendarDate))
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final dayTasks = allTasks.where((t) {
      if (t.actualCompletedDate != null) return false;
      if (t.plannedDate != null) {
        return _isSameDay(t.plannedDate!, _selectedCalendarDate);
      }
      return _isSameDay(now, _selectedCalendarDate);
    }).toList();

    final dayTaskIds = dayTasks.map((t) => t.id).toSet();
    final dayActivities = allActivities.where((a) {
      if (a.status == TodayActivityStatus.done) return false;
      if (a.linkedTaskId != null && dayTaskIds.contains(a.linkedTaskId)) {
        return false;
      }
      if (a.plannedDate != null) {
        return _isSameDay(a.plannedDate!, _selectedCalendarDate);
      }
      return _isSameDay(now, _selectedCalendarDate);
    }).toList();

    bool inMonth(DateTime date) =>
        date.year == _calendarMonth.year && date.month == _calendarMonth.month;
    final monthTasks = allTasks
        .where(
          (task) =>
              task.actualCompletedDate == null &&
              inMonth(task.plannedDate ?? now),
        )
        .length;
    final taskIds = allTasks.map((task) => task.id).toSet();
    final monthActivities = allActivities
        .where(
          (activity) =>
              activity.status != TodayActivityStatus.done &&
              !taskIds.contains(activity.linkedTaskId) &&
              inMonth(activity.plannedDate ?? now),
        )
        .length;
    final monthReminders = activeReminders
        .where((reminder) => inMonth(reminder.scheduledAt))
        .length;

    final selectedFestival = FestivalService.getFestivalForDate(
      _selectedCalendarDate,
    );

    final neutral = MonochromeSurfaces.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('reminders_calendar_card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: neutral.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: MediaQuery.highContrastOf(context)
                  ? neutral.controlOutline
                  : neutral.separator,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _calendarNavigation(context, g),
              if (widget.calendarOnly) ...[
                const SizedBox(height: 8),
                Text(
                  '$monthTasks ${monthTasks == 1 ? 'task' : 'tasks'} · $monthActivities ${monthActivities == 1 ? 'activity' : 'activities'} · $monthReminders ${monthReminders == 1 ? 'reminder' : 'reminders'}',
                  key: const ValueKey('calendar_month_summary'),
                  style: AscentTextStyles.interfaceSupporting.copyWith(
                    color: g.inkSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final accessible =
                      constraints.maxWidth < 7 * 44 ||
                      MediaQuery.textScalerOf(context).scale(1) >= 1.45;
                  if (accessible) {
                    return _accessibleCalendarWeek(
                      g,
                      activeReminders,
                      allTasks,
                      allActivities,
                    );
                  }
                  return Column(
                    children: [
                      Row(
                        children: [
                          for (final day in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                            Expanded(
                              child: Center(
                                child: Text(
                                  day,
                                  style: AscentTextStyles.interfaceLabel
                                      .copyWith(color: g.inkSecondary),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AnimatedSize(
                        duration: Duration(
                          milliseconds: MediaQuery.disableAnimationsOf(context)
                              ? 0
                              : 220,
                        ),
                        curve: Curves.easeOutCubic,
                        child: _isMonthExpanded
                            ? _buildMonthGrid(
                                g,
                                activeReminders,
                                allTasks,
                                allActivities,
                              )
                            : _buildWeekStrip(
                                g,
                                activeReminders,
                                allTasks,
                                allActivities,
                              ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final heading = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSameDay(_selectedCalendarDate, now)
                      ? 'Today, ${DateFormat('MMM d').format(_selectedCalendarDate)}'
                      : DateFormat('EEEE, MMM d').format(_selectedCalendarDate),
                  style: AscentTextStyles.interfaceTitle.copyWith(color: g.ink),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    for (final count in [
                      '${dayReminders.length} reminder${dayReminders.length == 1 ? '' : 's'}',
                      '${dayTasks.length} task${dayTasks.length == 1 ? '' : 's'}',
                      if (dayActivities.isNotEmpty)
                        '${dayActivities.length} activit${dayActivities.length == 1 ? 'y' : 'ies'}',
                    ])
                      Text(
                        count,
                        style: AscentTextStyles.interfaceSupporting.copyWith(
                          color: g.inkSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            );
            final add = AscentButton.primary(
              label: 'Add',
              icon: Icons.add_rounded,
              compact: true,
              onPressed: () => widget.calendarOnly
                  ? _addCalendarItem()
                  : _openAddEditReminderSheet(null, _selectedCalendarDate),
            );
            if (MediaQuery.textScalerOf(context).scale(1) >= 1.45) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading, const SizedBox(height: 12), add],
              );
            }
            return Row(
              children: [
                Expanded(child: heading),
                const SizedBox(width: 12),
                add,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (selectedFestival != null)
          FestiveBannerCard(
            festival: selectedFestival,
            restrained: true,
            onTap: () => HapticFeedback.lightImpact(),
          ),
        if (dayReminders.isEmpty &&
            dayTasks.isEmpty &&
            dayActivities.isEmpty &&
            selectedFestival == null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: neutral.surface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 32,
                  color: g.inkSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'No events on this day',
                  style: AscentTextStyles.interfaceBody.copyWith(color: g.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reminders, tasks, and activities scheduled for this day will appear here.',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.interfaceSupporting.copyWith(
                    color: g.inkSecondary,
                  ),
                ),
              ],
            ),
          )
        else ...[
          if (dayReminders.isNotEmpty) ...[
            _calendarSectionLabel('Reminders', g),
            for (final reminder in dayReminders)
              _buildCalendarReminderTile(reminder, g),
            const SizedBox(height: 12),
          ],
          if (dayTasks.isNotEmpty) ...[
            _calendarSectionLabel('Tasks & to-dos', g),
            for (final task in dayTasks) _buildCalendarTaskTile(task, g),
            const SizedBox(height: 12),
          ],
          if (dayActivities.isNotEmpty) ...[
            _calendarSectionLabel('Things & activities', g),
            for (final activity in dayActivities)
              _buildCalendarActivityTile(activity, g),
          ],
        ],
      ],
    );
  }

  Future<void> _addCalendarItem() async {
    if (_calendarScope == 1) {
      await AddActivitySheet.show(context, initialDate: _selectedCalendarDate);
      return;
    }
    if (_calendarScope == 2) {
      _openAddEditReminderSheet(null, _selectedCalendarDate);
      return;
    }
    final choice = await showAscentSheet<String>(
      context: context,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.check_circle_outline_rounded),
            title: const Text('Task or activity'),
            subtitle: Text(DateFormat.yMMMd().format(_selectedCalendarDate)),
            onTap: () => Navigator.pop(sheetContext, 'thing'),
          ),
          ListTile(
            leading: const Icon(Icons.event_available_outlined),
            title: const Text('Meeting or event'),
            subtitle: const Text('Pick one or multiple dates'),
            onTap: () => Navigator.pop(sheetContext, 'event'),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: const Text('Reminder'),
            subtitle: const Text('Schedule a notification or alarm'),
            onTap: () => Navigator.pop(sheetContext, 'reminder'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'event') {
      await showCalendarEventSheet(context, _selectedCalendarDate);
    } else if (choice == 'thing') {
      await AddActivitySheet.show(context, initialDate: _selectedCalendarDate);
    } else if (choice == 'reminder') {
      _openAddEditReminderSheet(null, _selectedCalendarDate);
    }
  }

  Widget _calendarSectionLabel(String label, AscentGlass g) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: AscentTextStyles.interfaceSupporting.copyWith(
        color: g.inkSecondary,
      ),
    ),
  );

  void _selectCalendarDay(DateTime day) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCalendarDate = DateTime(day.year, day.month, day.day);
      _calendarMonth = DateTime(day.year, day.month);
    });
  }

  Widget _calendarNavigation(BuildContext context, AscentGlass g) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final title = Text(
      DateFormat('MMMM yyyy').format(_calendarMonth),
      style: AscentTextStyles.interfaceTitle.copyWith(color: g.ink),
    );
    final controls = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          key: const ValueKey('calendar_today_button'),
          style: TextButton.styleFrom(
            foregroundColor: g.ink,
            minimumSize: const Size(48, 48),
            textStyle: AscentTextStyles.interfaceNavigation,
          ),
          onPressed: () => _selectCalendarDay(DateTime.now()),
          child: const Text('Today'),
        ),
        IconButton(
          key: const ValueKey('calendar_prev_month'),
          tooltip: 'Previous month',
          icon: Icon(
            rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            size: 18,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(
              () => _calendarMonth = DateTime(
                _calendarMonth.year,
                _calendarMonth.month - 1,
              ),
            );
          },
        ),
        IconButton(
          key: const ValueKey('calendar_next_month'),
          tooltip: 'Next month',
          icon: Icon(
            rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 18,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(
              () => _calendarMonth = DateTime(
                _calendarMonth.year,
                _calendarMonth.month + 1,
              ),
            );
          },
        ),
        IconButton(
          key: const ValueKey('calendar_expand_toggle'),
          tooltip: _isMonthExpanded ? 'Compact week view' : 'Full month view',
          icon: Icon(
            _isMonthExpanded
                ? Icons.expand_less_rounded
                : Icons.expand_more_rounded,
            size: 20,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() => _isMonthExpanded = !_isMonthExpanded);
          },
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 430 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.45) {
          return Row(
            children: [
              Expanded(child: title),
              controls,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            title,
            const SizedBox(height: 4),
            Align(alignment: AlignmentDirectional.centerEnd, child: controls),
          ],
        );
      },
    );
  }

  DateTime get _calendarAnchor =>
      _selectedCalendarDate.year == _calendarMonth.year &&
          _selectedCalendarDate.month == _calendarMonth.month
      ? _selectedCalendarDate
      : _calendarMonth;

  Widget _accessibleCalendarWeek(
    AscentGlass g,
    List<Reminder> reminders,
    List<Task> tasks,
    List<TodayActivityItem> activities,
  ) {
    // Month navigation must also move this fallback when selection is in another month.
    final anchor = _calendarAnchor;
    final monday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - anchor.weekday + 1,
    );
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Column(
      key: const ValueKey('calendar_accessible_week'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Week of ${DateFormat.MMMd().format(monday)}',
              style: AscentTextStyles.interfaceSupporting.copyWith(
                color: g.inkSecondary,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('calendar_prev_week'),
                  tooltip: 'Previous week',
                  icon: Icon(
                    rtl
                        ? Icons.chevron_right_rounded
                        : Icons.chevron_left_rounded,
                    size: 18,
                  ),
                  onPressed: () => _selectCalendarDay(
                    DateTime(anchor.year, anchor.month, anchor.day - 7),
                  ),
                ),
                IconButton(
                  key: const ValueKey('calendar_next_week'),
                  tooltip: 'Next week',
                  icon: Icon(
                    rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 18,
                  ),
                  onPressed: () => _selectCalendarDay(
                    DateTime(anchor.year, anchor.month, anchor.day + 7),
                  ),
                ),
              ],
            ),
          ],
        ),
        for (var i = 0; i < 7; i++)
          _buildCalendarDayCell(
            DateTime(monday.year, monday.month, monday.day + i),
            DateTime(monday.year, monday.month, monday.day + i).month ==
                _calendarMonth.month,
            reminders,
            tasks,
            g,
            allActivities: activities,
            agendaRow: true,
          ),
      ],
    );
  }

  Widget _buildWeekStrip(
    AscentGlass g,
    List<Reminder> activeReminders,
    List<Task> allTasks, [
    List<TodayActivityItem> allActivities = const [],
  ]) {
    final anchor = _calendarAnchor;
    final monday = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - anchor.weekday + 1,
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
              allActivities: allActivities,
            ),
          ),
      ],
    );
  }

  Widget _buildMonthGrid(
    AscentGlass g,
    List<Reminder> activeReminders,
    List<Task> allTasks, [
    List<TodayActivityItem> allActivities = const [],
  ]) {
    final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
    final firstMonday = firstDay.subtract(Duration(days: firstDay.weekday - 1));
    final daysInMonth = DateTime(
      _calendarMonth.year,
      _calendarMonth.month + 1,
      0,
    ).day;
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
                    allActivities: allActivities,
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
    AscentGlass g, {
    List<TodayActivityItem> allActivities = const [],
    bool agendaRow = false,
  }) {
    final now = DateTime.now();
    final isSelected = _isSameDay(day, _selectedCalendarDate);
    final isToday = _isSameDay(day, now);
    final festival = FestivalService.getFestivalForDate(day);

    final hasReminders = activeReminders.any(
      (r) => _isSameDay(r.scheduledAt, day),
    );
    final hasTasks = allTasks.any((t) {
      if (t.actualCompletedDate != null) return false;
      if (t.plannedDate != null) return _isSameDay(t.plannedDate!, day);
      return _isSameDay(now, day);
    });
    final taskIds = allTasks.map((t) => t.id).toSet();
    final hasActivities = allActivities.any((a) {
      if (a.status == TodayActivityStatus.done) return false;
      if (a.linkedTaskId != null && taskIds.contains(a.linkedTaskId)) {
        return false;
      }
      if (a.plannedDate != null) return _isSameDay(a.plannedDate!, day);
      return _isSameDay(now, day);
    });

    return AscentCalendarDay(
      key: ValueKey('calendar_day_${day.year}_${day.month}_${day.day}'),
      date: day,
      today: isToday,
      selected: isSelected,
      outsideMonth: !isCurrentMonth,
      hasScheduledItems: hasReminders || hasTasks || hasActivities,
      semanticLabel:
          '${DateFormat.yMMMMEEEEd().format(day)}${festival == null ? '' : ', ${festival.name}'}',
      agendaRow: agendaRow,
      compact: widget.calendarOnly && !agendaRow,
      onTap: () => _selectCalendarDay(day),
    );
  }

  Widget _buildCalendarReminderTile(Reminder reminder, AscentGlass g) {
    final overdue =
        reminder.isActive && reminder.scheduledAt.isBefore(DateTime.now());
    final red = g.isDark
        ? SharedControlColors.dueRedDark
        : SharedControlColors.dueRed;
    final time = Text(
      '${overdue ? 'Overdue · ' : ''}${DateFormat('h:mm a').format(reminder.scheduledAt)}',
      style: AscentTextStyles.interfaceSupporting.copyWith(
        color: overdue ? red : g.inkSecondary,
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          reminder.title,
          style: AscentTextStyles.interfaceBody.copyWith(color: g.ink),
        ),
        if (reminder.alarmEnabled) ...[
          const SizedBox(height: 4),
          Text(
            'Alarm active',
            style: AscentTextStyles.interfaceSupporting.copyWith(
              color: g.inkSecondary,
            ),
          ),
        ],
      ],
    );
    final complete = IconButton(
      key: ValueKey('calendar_reminder_complete_${reminder.id}'),
      tooltip: 'Complete reminder',
      icon: Icon(Icons.circle_outlined, size: 22, color: g.clay),
      onPressed: () {
        HapticFeedback.mediumImpact();
        _finishReminder(reminder);
      },
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: ValueKey('calendar_reminder_tile_${reminder.id}'),
        color: g.fill,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _openAddEditReminderSheet(reminder),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                time,
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    complete,
                  ],
                ),
              ],
            ),
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
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: MonochromeSurfaces.of(context).groupedFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_box_outlined,
                size: 15,
                color: g.inkSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AscentTextStyles.interfaceBody.copyWith(
                      color: g.ink,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.notes != null && task.notes!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.notes!,
                      style: AscentTextStyles.interfaceSupporting.copyWith(
                        color: g.inkSecondary,
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
              icon: Icon(Icons.circle_outlined, size: 22, color: g.clay),
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
                      await ref.read(taskDaoProvider).undoCompletion(undo);
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

  Widget _buildCalendarActivityTile(TodayActivityItem activity, AscentGlass g) {
    final isTimer = activity.kind != ActivityKind.todo;
    final isMedicine = activity.sourceType == 'medicine';

    return Container(
      key: ValueKey('calendar_activity_tile_${activity.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: g.fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          context.open('/things');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: MonochromeSurfaces.of(context).groupedFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isMedicine
                      ? Icons.medication_rounded
                      : (isTimer
                            ? Icons.timer_outlined
                            : Icons.check_circle_outline_rounded),
                  size: 15,
                  color: g.inkSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: AscentTextStyles.interfaceBody.copyWith(
                        color: g.ink,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.categoryTag.isNotEmpty
                          ? '${activity.categoryTag} · Dayboard'
                          : 'Dayboard Activity',
                      style: AscentTextStyles.interfaceSupporting.copyWith(
                        color: g.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: g.inkMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _count(String label, int n) => n > 0 ? '$label $n' : label;
