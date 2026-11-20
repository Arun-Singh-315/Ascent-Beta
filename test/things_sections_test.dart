import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/today/models/things_sections.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 20, 14);

TodayActivityItem _item(
  String id, {
  TodayActivityStatus status = TodayActivityStatus.notStarted,
  DateTime? planned,
  DateTime? at,
  bool overdue = false,
  bool daily = false,
  int? taskId = 1,
  String source = 'task',
  DateTime? completedAt,
}) => TodayActivityItem(
  id: id,
  title: id,
  sourceType: source,
  status: status,
  elapsedSecondsToday: 0,
  categoryTag: 'Task',
  linkedTaskId: taskId,
  plannedDate: planned,
  scheduledTime: at,
  isOverdue: overdue,
  isDailyStanding: daily,
  completedAt: completedAt,
);

void main() {
  group('thingsSegmentForTab', () {
    test('maps current and legacy deep links', () {
      expect(thingsSegmentForTab(null), ThingsSegment.today);
      expect(thingsSegmentForTab('now'), ThingsSegment.today);
      expect(thingsSegmentForTab('done'), ThingsSegment.today);
      expect(thingsSegmentForTab('upcoming'), ThingsSegment.upcoming);
      expect(thingsSegmentForTab('anytime'), ThingsSegment.anytime);
      expect(thingsSegmentForTab('plans'), ThingsSegment.routines);
      expect(thingsSegmentForTab('routines'), ThingsSegment.routines);
    });
  });

  group('groupToday', () {
    test('handles an empty day', () {
      final view = groupToday(const []);
      expect(view.isEmpty, isTrue);
      expect(view.movableOverdueTaskIds, isEmpty);
    });

    test('splits overdue, today and completed; anytime stays out', () {
      final today = DateTime(2026, 11, 20);
      final view = groupToday([
        _item('late', planned: DateTime(2026, 11, 18), overdue: true),
        _item('untimed', planned: today),
        _item('at9', planned: today, at: DateTime(2026, 11, 20, 9)),
        _item('nodate'),
        _item(
          'done',
          planned: today,
          status: TodayActivityStatus.done,
          completedAt: DateTime(2026, 11, 20, 8),
        ),
      ]);
      expect(view.overdue.map((a) => a.id), ['late']);
      expect(view.today.map((a) => a.id), ['at9', 'untimed']);
      expect(view.completed.map((a) => a.id), ['done']);
    });

    test('completed shows the most recent first', () {
      final view = groupToday([
        _item(
          'first',
          status: TodayActivityStatus.done,
          completedAt: DateTime(2026, 11, 20, 8),
        ),
        _item(
          'second',
          status: TodayActivityStatus.done,
          completedAt: DateTime(2026, 11, 20, 12),
        ),
      ]);
      expect(view.completed.map((a) => a.id), ['second', 'first']);
    });

    test('only dated, non-routine overdue tasks can be moved', () {
      final view = groupToday([
        _item(
          'task',
          planned: DateTime(2026, 11, 18),
          overdue: true,
          taskId: 7,
        ),
        _item(
          'session',
          planned: DateTime(2026, 11, 18),
          overdue: true,
          taskId: null,
          source: 'session',
        ),
      ]);
      expect(view.movableOverdueTaskIds, [7]);
    });

    test('handles 150 items without losing any', () {
      final today = DateTime(2026, 11, 20);
      final items = [
        for (var i = 0; i < 150; i++) _item('t$i', planned: today, taskId: i),
      ];
      expect(groupToday(items).today, hasLength(150));
    });
  });

  test('anytimeThings keeps only pending, undated, non-routine to-dos', () {
    final list = anytimeThings([
      _item('nodate'),
      _item('dated', planned: DateTime(2026, 11, 20)),
      _item('routine', daily: true),
      _item('medicine', source: 'medicine'),
      _item('done', status: TodayActivityStatus.done),
    ]);
    expect(list.map((a) => a.id), ['nodate']);
  });

  test('dailyRoutines lists every daily standing item', () {
    final list = dailyRoutines([
      _item('a', daily: true),
      _item('b'),
      _item('c', daily: true, status: TodayActivityStatus.done),
    ]);
    expect(list.map((a) => a.id), ['a', 'c']);
  });

  group('upcoming', () {
    test('groups by day from tomorrow, timed items first', () {
      final days = groupUpcoming([
        _item('today', planned: DateTime(2026, 11, 20, 18)),
        _item('tue', planned: DateTime(2026, 11, 24)),
        _item('tmr', planned: DateTime(2026, 11, 21)),
        _item(
          'tmr7',
          planned: DateTime(2026, 11, 21, 7),
          at: DateTime(2026, 11, 21, 7),
        ),
      ], _now);
      expect(days.map((d) => d.day), [
        DateTime(2026, 11, 21),
        DateTime(2026, 11, 24),
      ]);
      expect(days.first.items.map((a) => a.id), ['tmr7', 'tmr']);
    });

    test('labels days in plain language', () {
      expect(upcomingDayLabel(DateTime(2026, 11, 21), _now), 'Tomorrow');
      expect(upcomingDayLabel(DateTime(2026, 11, 24), _now), 'Tuesday');
      expect(upcomingDayLabel(DateTime(2026, 11, 30), _now), 'Mon, 30 Nov');
    });
  });

  test('search matches title and notes, case-insensitively', () {
    final item = _item('Call Mom');
    expect(matchesThingsQuery(item, ''), isTrue);
    expect(matchesThingsQuery(item, 'mom'), isTrue);
    expect(matchesThingsQuery(item, 'dad'), isFalse);
  });
}
