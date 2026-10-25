import 'package:flutter/material.dart';
import '../../../app/theme/glass_theme.dart';
import '../models/promise_model.dart';

/// Small, direct controls. Nothing here depends on a chat interpretation.
class PromiseScheduleEditor extends StatelessWidget {
  const PromiseScheduleEditor({
    super.key,
    required this.proposal,
    required this.onChanged,
    this.allowTrackingType = true,
  });
  final PromiseProposal proposal;
  final bool allowTrackingType;
  final ValueChanged<PromiseProposal> onChanged;
  PromiseSchedule get schedule =>
      proposal.schedule ??
      PromiseSchedule(startDate: promiseDay(DateTime.now()));

  Future<void> _date(BuildContext context, {bool end = false}) async {
    final first = end ? promiseDay(schedule.startDate) : DateTime(2020);
    var initial = end
        ? schedule.endDate ?? schedule.startDate
        : schedule.startDate;
    if (initial.isBefore(first)) initial = first;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) return;
    final next = end
        ? schedule.copyWith(endDate: date)
        : schedule.copyWith(
            startDate: date,
            endDate:
                schedule.endDate != null && schedule.endDate!.isBefore(date)
                ? date
                : schedule.endDate,
          );
    onChanged(proposal.copyWith(schedule: next, targetDate: next.endDate));
  }

  Future<void> _time(BuildContext context, {bool reminder = false}) async {
    final value = reminder ? proposal.reminderTime : schedule.plannedTime;
    final parts = (value ?? '09:00').split(':');
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
    if (selected == null || !context.mounted) return;
    final time =
        '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
    onChanged(
      reminder
          ? proposal.copyWith(reminderTime: time)
          : proposal.copyWith(schedule: schedule.copyWith(plannedTime: time)),
    );
  }

  String _dateLabel(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatShortDate(date);
  String _timeLabel(BuildContext context, String time) {
    final p = time.split(':');
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final s = schedule;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'When?',
          style: TextStyle(
            color: g.ink,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              key: const ValueKey('promise_start_date'),
              avatar: const Icon(Icons.calendar_today_outlined, size: 17),
              label: Text(
                '${s.repeat == PromiseRepeat.once ? 'Date' : 'Start'}: ${_dateLabel(context, s.startDate)}',
              ),
              onPressed: () => _date(context),
            ),
            PopupMenuButton<PromiseRepeat>(
              key: const ValueKey('promise_repeat'),
              tooltip: 'Repeat',
              initialValue: s.repeat,
              onSelected: (repeat) {
                var next = proposal.copyWith(
                  schedule: s.copyWith(repeat: repeat),
                );
                if (repeat == PromiseRepeat.weekly &&
                    proposal.trackingType != PromiseTrackingType.duration) {
                  next = next.copyWith(
                    trackingType: PromiseTrackingType.frequency,
                    frequencyPerWeek: proposal.frequencyPerWeek > 0
                        ? proposal.frequencyPerWeek
                        : 3,
                    targetValue: proposal.frequencyPerWeek > 0
                        ? proposal.frequencyPerWeek.toDouble()
                        : 3,
                  );
                }
                if (repeat != PromiseRepeat.weekly &&
                    proposal.trackingType == PromiseTrackingType.frequency) {
                  next = next.copyWith(
                    trackingType: PromiseTrackingType.completion,
                    targetValue: 1,
                    frequencyPerWeek: 0,
                  );
                }
                onChanged(next);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: PromiseRepeat.once,
                  child: Text('Just once'),
                ),
                PopupMenuItem(
                  value: PromiseRepeat.daily,
                  child: Text('Every day'),
                ),
                PopupMenuItem(
                  value: PromiseRepeat.selectedDays,
                  child: Text('Choose days'),
                ),
                PopupMenuItem(
                  value: PromiseRepeat.weekly,
                  child: Text('A few times a week'),
                ),
              ],
              child: Chip(
                avatar: const Icon(Icons.repeat_rounded, size: 17),
                label: Text(s.summary),
              ),
            ),
            InputChip(
              key: const ValueKey('promise_planned_time'),
              avatar: const Icon(Icons.schedule_rounded, size: 17),
              label: Text(
                s.plannedTime == null
                    ? 'Add a time'
                    : _timeLabel(context, s.plannedTime!),
              ),
              onPressed: () => _time(context),
              onDeleted: s.plannedTime == null
                  ? null
                  : () => onChanged(
                      proposal.copyWith(
                        schedule: s.copyWith(plannedTime: null),
                      ),
                    ),
            ),
            InputChip(
              key: const ValueKey('promise_end_date'),
              avatar: const Icon(Icons.event_available_outlined, size: 17),
              label: Text(
                s.endDate == null
                    ? (s.repeats ? 'Until… (optional)' : 'Due by… (optional)')
                    : 'Until ${_dateLabel(context, s.endDate!)}',
              ),
              onPressed: () => _date(context, end: true),
              onDeleted: s.endDate == null
                  ? null
                  : () => onChanged(
                      proposal.copyWith(
                        schedule: s.copyWith(endDate: null),
                        targetDate: null,
                      ),
                    ),
            ),
          ],
        ),
        if (s.repeat == PromiseRepeat.selectedDays)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(
                      const [
                        'Mon',
                        'Tue',
                        'Wed',
                        'Thu',
                        'Fri',
                        'Sat',
                        'Sun',
                      ][day - 1],
                    ),
                    selected: s.days.contains(day),
                    onSelected: (selected) {
                      final days = {...s.days};
                      selected ? days.add(day) : days.remove(day);
                      onChanged(
                        proposal.copyWith(
                          schedule: s.copyWith(days: days.toList()..sort()),
                          reminderDays: days.toList()..sort(),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        if (s.repeat == PromiseRepeat.weekly)
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Weekly target'),
              DropdownButton<int>(
                value: proposal.frequencyPerWeek.clamp(1, 7),
                items: [
                  for (var n = 1; n <= 7; n++)
                    DropdownMenuItem(
                      value: n,
                      child: Text('$n ${n == 1 ? 'time' : 'times'}'),
                    ),
                ],
                onChanged: (n) {
                  if (n != null) {
                    onChanged(
                      proposal.copyWith(
                        frequencyPerWeek: n,
                        targetValue:
                            proposal.trackingType ==
                                PromiseTrackingType.frequency
                            ? n.toDouble()
                            : proposal.targetValue,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          key: const ValueKey('promise_reminder_toggle'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Remind me'),
          subtitle: const Text('Optional — your planned time is separate'),
          value: proposal.reminderTime != null,
          onChanged: (on) => onChanged(
            proposal.copyWith(
              reminderTime: on ? s.plannedTime ?? '09:00' : null,
            ),
          ),
        ),
        if (proposal.reminderTime != null)
          TextButton.icon(
            key: const ValueKey('promise_reminder_time'),
            onPressed: () => _time(context, reminder: true),
            icon: const Icon(Icons.notifications_none_rounded, size: 18),
            label: Text(
              'Reminder at ${_timeLabel(context, proposal.reminderTime!)}',
            ),
          ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Keep this private'),
          subtitle: const Text('Discreet reminder text'),
          value: proposal.isPrivate,
          onChanged: (value) => onChanged(proposal.copyWith(isPrivate: value)),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Tracking options'),
          children: [
            if (allowTrackingType)
              DropdownButtonFormField<PromiseTrackingType>(
                key: ValueKey(proposal.trackingType),
                initialValue: proposal.trackingType,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: PromiseTrackingType.completion,
                    child: Text('Check it off'),
                  ),
                  DropdownMenuItem(
                    value: PromiseTrackingType.duration,
                    child: Text('Time a session'),
                  ),
                  DropdownMenuItem(
                    value: PromiseTrackingType.frequency,
                    child: Text('Count sessions each week'),
                  ),
                  DropdownMenuItem(
                    value: PromiseTrackingType.milestone,
                    child: Text('Track progress toward a goal'),
                  ),
                  DropdownMenuItem(
                    value: PromiseTrackingType.reflection,
                    child: Text('Write a reflection'),
                  ),
                ],
                onChanged: (type) {
                  if (type != null) {
                    onChanged(
                      proposal.copyWith(
                        trackingType: type,
                        targetValue: type == PromiseTrackingType.duration
                            ? 20
                            : type == PromiseTrackingType.milestone
                            ? 100
                            : type == PromiseTrackingType.frequency
                            ? 3
                            : 1,
                        unit: type == PromiseTrackingType.duration
                            ? 'minutes'
                            : type == PromiseTrackingType.milestone
                            ? 'percent'
                            : '',
                        frequencyPerWeek: type == PromiseTrackingType.frequency
                            ? 3
                            : proposal.frequencyPerWeek,
                        schedule: type == PromiseTrackingType.frequency
                            ? s.copyWith(repeat: PromiseRepeat.weekly)
                            : s,
                      ),
                    );
                  }
                },
              ),
            if (proposal.trackingType == PromiseTrackingType.duration ||
                proposal.trackingType == PromiseTrackingType.milestone)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: TextFormField(
                  key: ValueKey('promise_target_${proposal.trackingType.name}'),
                  initialValue: proposal.targetValue.toStringAsFixed(0),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) => (double.tryParse(value ?? '') ?? 0) > 0
                      ? null
                      : 'Enter a number greater than zero',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText:
                        'Target (${proposal.unit.isEmpty ? 'units' : proposal.unit})',
                  ),
                  onChanged: (value) {
                    final n = double.tryParse(value);
                    onChanged(proposal.copyWith(targetValue: n ?? 0));
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}
