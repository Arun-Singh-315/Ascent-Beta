import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show DateFormat;

import 'home_day.dart';

/// What happened yesterday, for "compared with yesterday" in the summary.
@immutable
class YesterdayStats {
  const YesterdayStats({
    required this.thingsDone,
    required this.waterMl,
    required this.focusMinutes,
  });
  final int thingsDone;
  final int waterMl;
  final int focusMinutes;

  @override
  bool operator ==(Object other) =>
      other is YesterdayStats &&
      other.thingsDone == thingsDone &&
      other.waterMl == waterMl &&
      other.focusMinutes == focusMinutes;
  @override
  int get hashCode => Object.hash(thingsDone, waterMl, focusMinutes);
}

/// One line of the summary panel: label, value, unit, progress (0–1) and
/// the change against yesterday ("+1", "−0.2 L"), or null when unknown.
@immutable
class SummaryLine {
  const SummaryLine({
    required this.label,
    required this.value,
    required this.unit,
    required this.progress,
    this.delta,
    this.deltaUp = true,
  });
  final String label, value, unit;
  final double progress;
  final String? delta;
  final bool deltaUp;

  @override
  bool operator ==(Object other) =>
      other is SummaryLine &&
      other.label == label &&
      other.value == value &&
      other.unit == unit &&
      other.progress == progress &&
      other.delta == delta &&
      other.deltaUp == deltaUp;
  @override
  int get hashCode => Object.hash(label, value, unit, progress, delta, deltaUp);
}

/// A piece of the insight sentence; facts are set bold.
@immutable
class InsightPart {
  const InsightPart(this.text, {this.bold = false});
  final String text;
  final bool bold;

  @override
  bool operator ==(Object other) =>
      other is InsightPart && other.text == text && other.bold == bold;
  @override
  int get hashCode => Object.hash(text, bold);
}

/// Everything the header shows: the day's percentage, three lines (things,
/// water, focus) and one insight.
@immutable
class DaySummary {
  const DaySummary({
    required this.percent,
    required this.lines,
    required this.insight,
  });

  /// Share of today's plan that is done (0–100), or null with no plan.
  final int? percent;
  final List<SummaryLine> lines;
  final List<InsightPart> insight;

  String get insightText => insight.map((p) => p.text).join();

  @override
  bool operator ==(Object other) =>
      other is DaySummary &&
      other.percent == percent &&
      listEquals(other.lines, lines) &&
      listEquals(other.insight, insight);
  @override
  int get hashCode =>
      Object.hash(percent, Object.hashAll(lines), Object.hashAll(insight));
}

String _litres(int ml) {
  final l = ml / 1000;
  return l == l.roundToDouble() ? l.toStringAsFixed(0) : l.toStringAsFixed(1);
}

String _signed(num v, {String unit = '', int decimals = 0}) {
  final text = v.abs().toStringAsFixed(decimals);
  if (v == 0) return '±0$unit';
  return '${v > 0 ? '+' : '−'}$text$unit';
}

/// Water you'd expect by [now] if spread over 7:00–22:00.
int expectedWaterBy(DateTime now, int goalMl) {
  final start = DateTime(now.year, now.month, now.day, 7);
  final end = DateTime(now.year, now.month, now.day, 22);
  if (!now.isAfter(start)) return 0;
  if (!now.isBefore(end)) return goalMl;
  final share =
      now.difference(start).inMinutes / end.difference(start).inMinutes;
  return (goalMl * share).round();
}

/// Builds the header summary. Pure; see `day_summary_test.dart`.
DaySummary buildDaySummary(HomeDay day, YesterdayStats? y) {
  final t = day.today, v = day.vitals;
  final percent = t.total == 0 ? null : (t.done * 100 / t.total).round();
  final lines = [
    SummaryLine(
      label: 'Things done',
      value: '${t.done}',
      unit: '/${t.total}',
      progress: t.total == 0 ? 0 : t.done / t.total,
      delta: y == null ? null : _signed(t.done - y.thingsDone),
      deltaUp: y == null || t.done >= y.thingsDone,
    ),
    SummaryLine(
      label: 'Water',
      value: v.waterMl == 0 ? '–' : _litres(v.waterMl),
      unit: ' L',
      progress: v.waterProgress,
      delta: y == null
          ? null
          : _signed(
              (v.waterMl - y.waterMl) / 1000,
              decimals: 1,
            ).replaceAll('.0', ''),
      deltaUp: y == null || v.waterMl >= y.waterMl,
    ),
    SummaryLine(
      label: 'Focus',
      value: v.focusMinutes == 0 ? '–' : '${v.focusMinutes}',
      unit: ' min',
      progress: v.focusProgress,
      delta: y == null ? null : _signed(v.focusMinutes - y.focusMinutes),
      deltaUp: y == null || v.focusMinutes >= y.focusMinutes,
    ),
  ];
  return DaySummary(
    percent: percent,
    lines: lines,
    insight: buildInsight(day, y),
  );
}

/// One or two short sentences about the day, from real numbers only.
/// Facts are bold. Never says "0".
List<InsightPart> buildInsight(HomeDay day, YesterdayStats? y) {
  final t = day.today, v = day.vitals, now = day.now;
  final parts = <List<InsightPart>>[];

  if (day.mood == DayMood.live) {
    parts.add(const [
      InsightPart('A focus session is running. '),
      InsightPart('Notifications stay quiet', bold: true),
      InsightPart(' until it ends.'),
    ]);
  } else if (t.overdue > 0) {
    parts.add([
      InsightPart('${t.overdue} overdue', bold: true),
      const InsightPart(
        ' from earlier. Clearing them first frees up the rest of the day.',
      ),
    ]);
  } else if (day.mood == DayMood.allDone) {
    parts.add([
      const InsightPart('Everything planned is '),
      const InsightPart('done', bold: true),
      const InsightPart('.'),
    ]);
  } else if (y != null && t.done > 0 && t.done > y.thingsDone) {
    final ahead = t.done - y.thingsDone;
    parts.add([
      const InsightPart('You’re '),
      InsightPart('$ahead ${ahead == 1 ? 'task' : 'tasks'} ahead', bold: true),
      const InsightPart(' of yesterday.'),
    ]);
  }

  if (v.waterGoalMl > 0 && v.waterMl < v.waterGoalMl) {
    final expected = expectedWaterBy(now, v.waterGoalMl);
    final behind = expected - v.waterMl;
    if (behind >= 250) {
      parts.add([
        const InsightPart('Water is '),
        InsightPart('$behind ml behind', bold: true),
        const InsightPart('; a glass now catches you up.'),
      ]);
    } else if (now.hour >= 7 && now.hour < 22 && v.waterMl > 0) {
      parts.add([
        const InsightPart('Water is on pace for '),
        InsightPart(
          '${_litres(v.waterGoalMl)} L by ${DateFormat('H:mm').format(DateTime(now.year, now.month, now.day, 22))}',
          bold: true,
        ),
        const InsightPart('.'),
      ]);
    }
  } else if (v.waterGoalMl > 0 && v.waterMl >= v.waterGoalMl) {
    parts.add(const [
      InsightPart('Water goal '),
      InsightPart('reached', bold: true),
      InsightPart('.'),
    ]);
  }

  if (parts.isEmpty) {
    parts.add(const [
      InsightPart('A calm start. Add your first thing for today above.'),
    ]);
  }
  final out = <InsightPart>[];
  for (final (i, p) in parts.take(2).indexed) {
    if (i > 0) out.add(const InsightPart(' '));
    out.addAll(p);
  }
  return out;
}
