import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme/home_design.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_calendar_day.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/ascent_switch_row.dart';

/// Calendar appointments use the existing reminder lifecycle and alert sync.
/// Each chosen date remains independently editable in the agenda.
Future<List<int>> saveCalendarAppointments(
  AppDatabase db, {
  required String title,
  required Iterable<DateTime> dates,
  required TimeOfDay time,
  required bool meeting,
  required bool notify,
}) async {
  final name = title.trim();
  if (name.isEmpty || name.length > 260) {
    throw ArgumentError('Enter a title up to 260 characters.');
  }
  final unique =
      dates.map((d) => DateTime(d.year, d.month, d.day)).toSet().toList()
        ..sort();
  if (unique.isEmpty) throw ArgumentError('Choose at least one date.');
  return db.transaction(() async {
    final ids = <int>[];
    for (final day in unique) {
      ids.add(
        await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: '${meeting ? 'Meeting' : 'Event'} · $name',
            scheduledAt: DateTime(
              day.year,
              day.month,
              day.day,
              time.hour,
              time.minute,
            ),
            alarmEnabled: drift.Value(notify),
            alertSyncPending: drift.Value(notify),
          ),
        ),
      );
    }
    return ids;
  });
}

Future<void> showCalendarEventSheet(BuildContext context, DateTime date) =>
    showAscentSheet<void>(
      context: context,
      builder: (_) => CalendarEventSheet(initialDate: date),
    );

class CalendarEventSheet extends ConsumerStatefulWidget {
  const CalendarEventSheet({super.key, required this.initialDate});
  final DateTime initialDate;
  @override
  ConsumerState<CalendarEventSheet> createState() => _CalendarEventSheetState();
}

class _CalendarEventSheetState extends ConsumerState<CalendarEventSheet> {
  final title = TextEditingController();
  late DateTime month;
  late Set<DateTime> dates;
  TimeOfDay time = const TimeOfDay(hour: 9, minute: 0);
  bool meeting = true, notify = false, saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final d = widget.initialDate;
    month = DateTime(d.year, d.month);
    dates = {DateTime(d.year, d.month, d.day)};
  }

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (dates.isEmpty || title.text.trim().isEmpty) {
      setState(() => error = 'Add a title and select at least one date.');
      return;
    }
    final now = DateTime.now();
    if (notify &&
        dates.any(
          (d) => DateTime(
            d.year,
            d.month,
            d.day,
            time.hour,
            time.minute,
          ).isBefore(now),
        )) {
      setState(() => error = 'Choose future times to receive notifications.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final db = ref.read(databaseProvider);
    List<int> ids;
    try {
      ids = await saveCalendarAppointments(
        db,
        title: title.text,
        dates: dates,
        time: time,
        meeting: meeting,
        notify: notify,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Could not save. Your selections are still here. Please retry.';
        });
      }
      return;
    }
    var alertsReady = true;
    if (notify) {
      try {
        final result = await ReminderAlertSync.device(
          db,
        ).sync(onlyPending: true, ids: ids);
        alertsReady = result.complete;
      } catch (_) {
        alertsReady = false;
      }
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          alertsReady
              ? 'Saved on ${ids.length} ${ids.length == 1 ? 'date' : 'dates'}.'
              : 'Saved. Alerts are pending; check notification permissions in Reminders.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = HomeDesign.of(context);
    final total = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = (month.weekday - 1) % 7;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Make time for it',
            style: HomeType.section.copyWith(color: colors.primaryText),
          ),
          const SizedBox(height: 8),
          AscentSegmentedControl<bool>(
            inline: true,
            selected: meeting,
            enabled: !saving,
            segments: const [
              AscentSegment(
                value: true,
                label: 'Meeting',
                icon: Icons.groups_outlined,
              ),
              AscentSegment(
                value: false,
                label: 'Event',
                icon: Icons.event_outlined,
              ),
            ],
            onChanged: (value) => setState(() => meeting = value),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('calendar_event_title'),
            controller: title,
            enabled: !saving,
            maxLength: 260,
            decoration: InputDecoration(
              labelText: meeting ? 'Meeting title' : 'Event title',
              hintText: 'What are you planning?',
            ),
          ),
          Text(
            'Tap multiple dates. Each date gets its own agenda entry.',
            style: HomeType.supporting.copyWith(color: colors.secondaryText),
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                onPressed: saving
                    ? null
                    : () => setState(
                        () => month = DateTime(month.year, month.month - 1),
                      ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(month),
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                onPressed: saving
                    ? null
                    : () => setState(
                        () => month = DateTime(month.year, month.month + 1),
                      ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final accessible =
                  MediaQuery.textScalerOf(context).scale(1) >= 1.45 ||
                  constraints.maxWidth < 308;
              final columns = accessible ? 4 : 7;
              final width = constraints.maxWidth / columns;
              return Wrap(
                children: [
                  if (!accessible)
                    for (final label in const [
                      'M',
                      'T',
                      'W',
                      'T',
                      'F',
                      'S',
                      'S',
                    ])
                      SizedBox(
                        width: width,
                        height: 28,
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: HomeType.supporting.copyWith(
                            color: colors.secondaryText,
                          ),
                        ),
                      ),
                  if (!accessible)
                    for (var i = 0; i < offset; i++)
                      SizedBox(width: width, height: 1),
                  for (var day = 1; day <= total; day++)
                    SizedBox(
                      width: width,
                      child: AscentCalendarDay(
                        key: ValueKey(
                          'event_date_${month.year}_${month.month}_$day',
                        ),
                        compact: true,
                        date: DateTime(month.year, month.month, day),
                        weekdayLabel: accessible
                            ? DateFormat.E().format(
                                DateTime(month.year, month.month, day),
                              )
                            : null,
                        selected: dates.contains(
                          DateTime(month.year, month.month, day),
                        ),
                        today: DateUtils.isSameDay(
                          DateTime.now(),
                          DateTime(month.year, month.month, day),
                        ),
                        onTap: () {
                          if (saving) return;
                          final date = DateTime(month.year, month.month, day);
                          setState(() {
                            if (!dates.remove(date)) dates.add(date);
                          });
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            '${dates.length} ${dates.length == 1 ? 'date' : 'dates'} selected',
            key: const ValueKey('event_date_count'),
            style: HomeType.supporting,
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final date in dates.toList()..sort())
                InputChip(
                  label: Text(DateFormat.MMMd().format(date)),
                  onDeleted: saving
                      ? null
                      : () => setState(() => dates.remove(date)),
                ),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.schedule_outlined),
            label: Text('Time · ${time.format(context)}'),
            onPressed: saving
                ? null
                : () async {
                    final result = await showTimePicker(
                      context: context,
                      initialTime: time,
                    );
                    if (result != null && mounted) {
                      setState(() => time = result);
                    }
                  },
          ),
          AscentSwitchRow(
            title: 'Notify me at this time',
            value: notify,
            onChanged: saving
                ? null
                : (value) => setState(() => notify = value),
          ),
          if (error != null)
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          AscentButton.primary(
            label: saving
                ? 'Saving…'
                : 'Schedule ${meeting ? 'meeting' : 'event'}',
            onPressed: saving ? null : save,
          ),
        ],
      ),
    );
  }
}
