import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_navigation.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/local_day_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_calendar_day.dart';
import '../../calendar/multi_day_todo_sheet.dart';

/// One agenda line on Home's week card.
class HomeAgendaEntry {
  const HomeAgendaEntry(this.icon, this.title, this.at, this.route);
  final IconData icon;
  final String title;
  final DateTime? at;
  final String route;
}

/// Everything on [day]: reminders, to-dos and thoughts, timed items first.
List<HomeAgendaEntry> homeAgendaFor(
  DateTime day, {
  required List<Reminder> reminders,
  required List<Task> tasks,
  required List<Thought> thoughts,
}) {
  bool same(DateTime a) =>
      a.year == day.year && a.month == day.month && a.day == day.day;
  final out = <HomeAgendaEntry>[
    for (final r in reminders)
      if (r.isActive && same(r.scheduledAt))
        HomeAgendaEntry(
          Icons.notifications_none_rounded,
          r.title,
          r.scheduledAt,
          '/reminders?reminder=${r.id}',
        ),
    for (final t in tasks)
      if (t.actualCompletedDate == null &&
          t.plannedDate != null &&
          same(t.plannedDate!))
        HomeAgendaEntry(
          Icons.check_circle_outline_rounded,
          t.title,
          null,
          '/today?task=${t.id}',
        ),
    for (final t in thoughts)
      if (same(calendarDayOf(t)))
        HomeAgendaEntry(
          Icons.lightbulb_outline_rounded,
          t.content.trim().split('\n').first,
          null,
          '/thought-wall?thought=${t.id}',
        ),
  ];
  out.sort((a, b) {
    if (a.at == null && b.at == null) return 0;
    if (a.at == null) return 1;
    if (b.at == null) return -1;
    return a.at!.compareTo(b.at!);
  });
  return out;
}

/// Home's structured week: a seven-day strip with dots for busy days and
/// the chosen day's agenda (reminders, to-dos, thoughts) below it.
class HomeCalendar extends ConsumerStatefulWidget {
  const HomeCalendar({super.key});

  @override
  ConsumerState<HomeCalendar> createState() => _HomeCalendarState();
}

class _HomeCalendarState extends ConsumerState<HomeCalendar> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final today = ref.watch(localDayProvider);
    final selected = _selected ?? today;
    final monday = DateTime(
      today.year,
      today.month,
      today.day - today.weekday + 1,
    );
    final days = List.generate(
      7,
      (i) => DateTime(monday.year, monday.month, monday.day + i),
    );
    final reminders = ref.watch(allRemindersProvider).value ?? const [];
    final tasks = ref.watch(allTasksStreamProvider).value ?? const [];
    final thoughts = ref.watch(calendarThoughtsProvider).value ?? const [];
    List<HomeAgendaEntry> on(DateTime d) => homeAgendaFor(
      d,
      reminders: reminders,
      tasks: tasks,
      thoughts: thoughts,
    );
    final agenda = on(selected);
    final dateKey = DateFormat('yyyy-MM-dd').format(selected);
    return Padding(
      key: const ValueKey('home_calendar'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s20,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius: AppGeometry.roundedr20,
          border: Border.all(color: g.line),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'This week',
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: g.ink,
                        ),
                      ),
                    ),
                  ),
                  AscentButton.ghost(
                    key: const ValueKey('home_calendar_open'),
                    label: 'Calendar',
                    compact: true,
                    onPressed: () => context.open('/calendar?date=$dateKey'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              LayoutBuilder(
                builder: (context, box) {
                  Widget cell(DateTime d) => AscentCalendarDay(
                    key: ValueKey(
                      'home_calendar_day_${DateFormat('yyyy-MM-dd').format(d)}',
                    ),
                    date: d,
                    weekdayLabel: DateFormat('E').format(d).substring(0, 1),
                    today: d == today,
                    selected: d == selected,
                    hasScheduledItems: on(d).isNotEmpty,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selected = d);
                    },
                  );
                  // Large text or a narrow screen: scroll the week instead
                  // of squeezing seven days into the width.
                  final roomy =
                      box.maxWidth / 7 >= 44 &&
                      MediaQuery.textScalerOf(context).scale(1) < 1.45;
                  if (roomy) {
                    return Row(
                      children: [
                        for (final d in days) Expanded(child: cell(d)),
                      ],
                    );
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        for (final d in days)
                          SizedBox(width: 64, child: cell(d)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpace.s12),
              Divider(height: 1, thickness: 1, color: g.line),
              if (agenda.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_available_outlined,
                        size: 18,
                        color: g.inkSecondary,
                      ),
                      const SizedBox(width: AppSpace.s12),
                      Expanded(
                        child: Text(
                          selected == today
                              ? 'Nothing scheduled today'
                              : 'Nothing on ${DateFormat('EEEE').format(selected)}',
                          style: AscentTextStyles.body.copyWith(
                            color: g.inkSecondary,
                          ),
                        ),
                      ),
                      AscentButton.ghost(
                        key: const ValueKey('home_calendar_add'),
                        label: 'Add',
                        compact: true,
                        onPressed: () =>
                            showMultiDayTodoSheet(context, [selected]),
                      ),
                    ],
                  ),
                )
              else ...[
                for (final (i, e) in agenda.take(4).indexed) ...[
                  if (i > 0)
                    Divider(height: 1, thickness: 1, indent: 30, color: g.line),
                  _AgendaRow(entry: e),
                ],
                if (agenda.length > 4)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AscentButton.ghost(
                      label: 'Show all ${agenda.length}',
                      compact: true,
                      onPressed: () => context.open('/calendar?date=$dateKey'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaRow extends StatelessWidget {
  const _AgendaRow({required this.entry});
  final HomeAgendaEntry entry;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return InkWell(
      onTap: () => context.open(entry.route),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Icon(entry.icon, size: 18, color: g.inkSecondary),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.body.copyWith(color: g.ink),
              ),
            ),
            if (entry.at != null)
              Text(
                DateFormat('h:mm a').format(entry.at!).toLowerCase(),
                style: AscentTextStyles.tabular(
                  AscentTextStyles.caption,
                ).copyWith(color: g.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}
