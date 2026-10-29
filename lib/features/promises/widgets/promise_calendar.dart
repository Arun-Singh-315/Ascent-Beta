import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';

class PromiseCalendar extends ConsumerStatefulWidget {
  const PromiseCalendar({super.key, required this.promise});
  final PromiseModel promise;
  @override
  ConsumerState<PromiseCalendar> createState() => _PromiseCalendarState();
}

class _PromiseCalendarState extends ConsumerState<PromiseCalendar> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final days = ref.watch(
      promiseCalendarProvider((widget.promise.id, _month.year, _month.month)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Previous month',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month - 1),
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                MaterialLocalizations.of(context).formatMonthYear(_month),
                textAlign: TextAlign.center,
                style: TextStyle(color: g.ink, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Next month',
              onPressed: () => setState(
                () => _month = DateTime(_month.year, _month.month + 1),
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final day in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'])
              Expanded(
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: g.inkMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        days.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(
              promiseCalendarProvider((
                widget.promise.id,
                _month.year,
                _month.month,
              )),
            ),
            child: const Text('Could not load calendar. Retry'),
          ),
          data: (records) => GridView.builder(
            key: const ValueKey('promise_calendar'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: math.max(
                52,
                MediaQuery.textScalerOf(context).scale(14) + 28,
              ),
            ),
            itemCount: _month.weekday - 1 + records.length,
            itemBuilder: (context, index) {
              if (index < _month.weekday - 1) return const SizedBox.shrink();
              final day = records[index - (_month.weekday - 1)];
              final (icon, color) = switch (day.state) {
                PromiseDayState.done => (Icons.check_rounded, g.sage),
                PromiseDayState.partial => (Icons.timelapse_rounded, g.amber),
                PromiseDayState.missed => (
                  Icons.close_rounded,
                  Theme.of(context).colorScheme.error,
                ),
                PromiseDayState.paused => (Icons.pause_rounded, g.inkMuted),
                PromiseDayState.off => (Icons.remove_rounded, g.inkMuted),
                _ => (Icons.circle_outlined, g.inkMuted),
              };
              final today = promiseDay(DateTime.now()) == day.date;
              return Semantics(
                label:
                    '${MaterialLocalizations.of(context).formatFullDate(day.date)}, ${day.label}',
                button: true,
                child: InkWell(
                  key: ValueKey('promise_day_${promiseDateKey(day.date)}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: _saving ? null : () => _open(day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: today
                          ? g.claySoft
                          : day.state == PromiseDayState.done
                          ? g.sage.withValues(alpha: .10)
                          : Colors.transparent,
                      border: today ? Border.all(color: g.clay) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.date.day}',
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 14,
                            fontWeight: today
                                ? FontWeight.w700
                                : FontWeight.w400,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Icon(icon, size: 15, color: color),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            Text('✓ Done', style: TextStyle(color: g.inkMuted, fontSize: 12)),
            Text(
              '◐ Partial',
              style: TextStyle(color: g.inkMuted, fontSize: 12),
            ),
            Text('× Missed', style: TextStyle(color: g.inkMuted, fontSize: 12)),
            Text(
              '○ Pending',
              style: TextStyle(color: g.inkMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          widget.promise.schedule?.repeat == PromiseRepeat.weekly
              ? 'Flexible weekly goal — unscheduled days are not failures.'
              : 'Tap a day to view or correct an entry. Today stays pending until the day ends.',
          style: TextStyle(color: g.inkMuted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  Future<void> _open(PromiseDayRecord day) async {
    final canLog =
        (day.state == PromiseDayState.pending ||
            day.state == PromiseDayState.missed ||
            day.state == PromiseDayState.partial ||
            (day.state == PromiseDayState.off &&
                widget.promise.schedule?.repeat == PromiseRepeat.weekly &&
                widget.promise.schedule!.includes(day.date) &&
                !day.date.isBefore(promiseDay(widget.promise.createdAt)))) &&
        !day.date.isAfter(promiseDay(DateTime.now())) &&
        widget.promise.isActive;
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(MaterialLocalizations.of(context).formatFullDate(day.date)),
        content: Text(
          '${day.label}${day.amount > 0 ? ' · ${day.amount.toStringAsFixed(day.amount % 1 == 0 ? 0 : 1)} / ${day.target.toStringAsFixed(0)}' : ''}${day.note == null ? '' : '\n${day.note}'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          if (day.amount > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'undo'),
              child: const Text('Undo entry'),
            ),
          if (canLog)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, 'done'),
              child: const Text('Mark done'),
            ),
        ],
      ),
    );
    if (action == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(promiseRepositoryProvider);
      if (action == 'undo') {
        await repo.undoDay(widget.promise.id, day.date);
      } else {
        await repo.markDayDone(
          widget.promise.id,
          date: day.date,
          note: 'Manually recorded for ${promiseDateKey(day.date)}',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not update this day. Your previous entry is unchanged.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
