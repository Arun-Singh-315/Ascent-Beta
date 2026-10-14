import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../app/theme/glass_theme.dart';
import 'app_surfaces.dart';

/// A bounded month view of an inclusive date range. Crossed dates indicate
/// elapsed time only; they never imply completed work.
class DateRangeCalendar extends StatefulWidget {
  const DateRangeCalendar({
    super.key,
    required this.start,
    required this.end,
    this.today,
  });

  final DateTime start;
  final DateTime end;
  final DateTime? today;

  @override
  State<DateRangeCalendar> createState() => _DateRangeCalendarState();
}

class _DateRangeCalendarState extends State<DateRangeCalendar> {
  late DateTime _month;
  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
  DateTime get _today => _day(widget.today ?? DateTime.now());
  DateTime get _start => _day(widget.start);
  DateTime get _end => _day(widget.end);

  @override
  void initState() {
    super.initState();
    _resetMonth();
  }

  @override
  void didUpdateWidget(DateRangeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start || oldWidget.end != widget.end) {
      _resetMonth();
    }
  }

  void _resetMonth() {
    final day = _today.isBefore(_start)
        ? _start
        : (_today.isAfter(_end) ? _end : _today);
    _month = DateTime(day.year, day.month);
  }

  void _move(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final firstMonth = DateTime(_start.year, _start.month);
    final lastMonth = DateTime(_end.year, _end.month);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday - 1;
    final cells = ((offset + days + 6) ~/ 7) * 7;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'Start · ${DateFormat.yMMMd().format(_start)}',
                style: TextStyle(color: g.ink),
              ),
              Text(
                'Finish · ${DateFormat.yMMMd().format(_end)}',
                style: TextStyle(color: g.ink),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(_month),
                  style: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
                ),
              ),
              if (_month.isAfter(firstMonth))
                IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
              if (_month.isBefore(lastMonth))
                IconButton(
                  tooltip: 'Next month',
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
            ],
          ),
          Row(
            children: [
              for (final label in ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
                Expanded(
                  child: Center(
                    child: Text(label, style: TextStyle(color: g.inkMuted)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          for (var row = 0; row < cells ~/ 7; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(child: _cell(row * 7 + col - offset + 1, days)),
              ],
            ),
          const SizedBox(height: 8),
          Text(
            'Crossed dates have passed · outlined date is today',
            style: TextStyle(color: g.inkMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _cell(int number, int days) {
    if (number < 1 || number > days) return const SizedBox(height: 36);
    final g = context.glass;
    final date = DateTime(_month.year, _month.month, number);
    final inRange = !date.isBefore(_start) && !date.isAfter(_end);
    final elapsed = inRange && date.isBefore(_today);
    final today = date == _today;
    final endpoint = date == _start || date == _end;
    final key = 'calendar-day-${date.year}-${date.month}-${date.day}';
    return Semantics(
      label:
          '${DateFormat.yMMMMd().format(date)}${date == _start ? ', start' : ''}${date == _end ? ', finish' : ''}${today ? ', today' : ''}${elapsed ? ', elapsed' : ''}${inRange ? ', in range' : ', outside range'}',
      excludeSemantics: true,
      child: Container(
        height: 36,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: inRange ? g.clay.withValues(alpha: endpoint ? .2 : .08) : null,
          borderRadius: BorderRadius.circular(8),
          border: today ? Border.all(color: g.clay, width: 1.5) : null,
        ),
        child: Text(
          '$number',
          key: ValueKey(key),
          style: TextStyle(
            color: inRange ? g.ink : g.inkMuted.withValues(alpha: .5),
            fontWeight: today || endpoint ? FontWeight.w700 : FontWeight.normal,
            decoration: elapsed ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}
