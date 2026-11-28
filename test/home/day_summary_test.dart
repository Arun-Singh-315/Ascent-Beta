import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/model/day_summary.dart';
import 'package:ascent/features/home/model/home_day.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 28, h, m);

TodayActivityItem _item(String id, {bool done = false, bool overdue = false}) =>
    TodayActivityItem(
      id: id,
      title: id,
      sourceType: 'task',
      status: done ? TodayActivityStatus.done : TodayActivityStatus.notStarted,
      elapsedSecondsToday: 0,
      categoryTag: 'general',
      isOverdue: overdue,
      plannedDate: _at(0),
    );

HomeDay _day(
  DateTime now, {
  int done = 0,
  int open = 0,
  int overdue = 0,
  int water = 0,
  int focus = 0,
  bool live = false,
}) => buildHomeDay(
  now: now,
  activities: [
    for (var i = 0; i < done; i++) _item('d$i', done: true),
    for (var i = 0; i < open; i++) _item('o$i'),
    for (var i = 0; i < overdue; i++) _item('x$i', overdue: true),
  ],
  reminders: const [],
  hasLiveSession: live,
  waterMl: water,
  waterGoalMl: 2500,
  focusMinutes: focus,
  focusGoalMinutes: 60,
);

const _yesterday = YesterdayStats(
  thingsDone: 4,
  waterMl: 1500,
  focusMinutes: 30,
);

void main() {
  test('percent, values and deltas against yesterday', () {
    final s = buildDaySummary(
      _day(_at(10), done: 5, open: 3, water: 1800, focus: 45),
      _yesterday,
    );
    expect(s.percent, 63);
    expect(s.lines[0].value, '5');
    expect(s.lines[0].unit, '/8');
    expect(s.lines[0].delta, '+1');
    expect(s.lines[1].value, '1.8');
    expect(s.lines[1].delta, '+0.3');
    expect(s.lines[2].delta, '+15');
    expect(s.lines.every((l) => l.deltaUp), isTrue);
  });

  test('no plan means no percent; empty values show a dash, never 0', () {
    final s = buildDaySummary(_day(_at(9)), null);
    expect(s.percent, isNull);
    expect(s.lines[1].value, '–');
    expect(s.lines[2].value, '–');
    expect(s.lines.every((l) => l.delta == null), isTrue);
  });

  test('falling behind yesterday is marked as down', () {
    final s = buildDaySummary(
      _day(_at(20), done: 1, open: 1, water: 1000, focus: 10),
      _yesterday,
    );
    expect(s.lines[0].delta, '−3');
    expect(s.lines[0].deltaUp, isFalse);
    expect(s.lines[1].delta, '−0.5');
  });

  group('insight', () {
    test('ahead of yesterday and water on pace', () {
      final s = buildDaySummary(
        _day(_at(10), done: 5, open: 3, water: 900),
        _yesterday,
      );
      expect(
        s.insightText,
        'You’re 1 task ahead of yesterday. Water is on pace for 2.5 L by 22:00.',
      );
      expect(s.insight.where((p) => p.bold).length, 2);
    });

    test('overdue comes first', () {
      final s = buildDaySummary(_day(_at(10), overdue: 2, water: 900), null);
      expect(s.insightText, startsWith('2 overdue from earlier.'));
    });

    test('behind on water says how much', () {
      final s = buildDaySummary(_day(_at(16), open: 1, water: 300), null);
      expect(s.insightText, contains('ml behind'));
    });

    test('a running session leads', () {
      final s = buildDaySummary(_day(_at(14), open: 1, live: true), null);
      expect(s.insightText, startsWith('A focus session is running.'));
    });

    test('all done and goal reached', () {
      final s = buildDaySummary(
        _day(_at(21), done: 3, water: 2600),
        _yesterday,
      );
      expect(s.insightText, 'Everything planned is done. Water goal reached.');
    });

    test('a quiet start still says something useful', () {
      final s = buildDaySummary(_day(_at(6, 30)), null);
      expect(s.insightText, isNotEmpty);
      expect(s.insightText, isNot(contains(' 0 ')));
    });
  });

  test('expected water follows the waking day', () {
    expect(expectedWaterBy(_at(6), 2500), 0);
    expect(expectedWaterBy(_at(14, 30), 2500), 1250);
    expect(expectedWaterBy(_at(23), 2500), 2500);
  });
}
