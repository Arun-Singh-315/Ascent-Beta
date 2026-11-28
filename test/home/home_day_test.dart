import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/features/home/model/home_day.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 28, h, m);

TodayActivityItem _item(
  String id, {
  int? hour,
  int minute = 0,
  bool done = false,
  bool overdue = false,
  String source = 'task',
  int? targetMinutes,
  bool anytime = false,
}) => TodayActivityItem(
  id: id,
  title: id,
  sourceType: source,
  status: done ? TodayActivityStatus.done : TodayActivityStatus.notStarted,
  elapsedSecondsToday: 0,
  categoryTag: 'general',
  scheduledTime: hour == null ? null : _at(hour, minute),
  isOverdue: overdue,
  linkedTaskId: anytime ? id.hashCode : null,
  plannedDate: anytime ? null : _at(0),
  targetMinutes: targetMinutes,
  kind: targetMinutes == null ? ActivityKind.todo : ActivityKind.duration,
);

Reminder _reminder(int id, DateTime at) => Reminder(
  id: id,
  title: 'R$id',
  scheduledAt: at,
  alarmEnabled: false,
  alertSyncPending: false,
  isActive: true,
  createdAt: at,
);

HomeDay _day(
  DateTime now, {
  List<TodayActivityItem> items = const [],
  List<Reminder> reminders = const [],
  bool live = false,
  List<PromiseToday> promises = const [],
  DateTime? lastBackupAt,
}) => buildHomeDay(
  now: now,
  activities: items,
  reminders: reminders,
  hasLiveSession: live,
  liveTitle: 'Pitch deck',
  promises: promises,
  lastBackupAt: lastBackupAt,
  waterMl: 1800,
  waterGoalMl: 2500,
  focusMinutes: 45,
  focusGoalMinutes: 60,
  spentToday: 350,
  dailyBudget: 500,
);

const _walk = PromiseToday(
  id: 'p1',
  title: 'Walk 20 minutes',
  day: 6,
  length: 30,
  answeredToday: false,
  yesterdayOpen: false,
  streak: 5,
);

void main() {
  group('time of day', () {
    test('periods follow the copy rules', () {
      expect(dayPeriodAt(_at(4, 59)), DayPeriod.night);
      expect(dayPeriodAt(_at(5)), DayPeriod.morning);
      expect(dayPeriodAt(_at(12)), DayPeriod.afternoon);
      expect(dayPeriodAt(_at(17)), DayPeriod.evening);
      expect(dayPeriodAt(_at(21)), DayPeriod.night);
      expect(greetingFor(DayPeriod.evening), 'Good evening');
    });
  });

  group('every moment of the day', () {
    test('morning, plans ahead', () {
      final d = _day(
        _at(8, 10),
        items: [
          _item('Review PRs', hour: 9, targetMinutes: 45),
          _item('Call mom', hour: 18),
          _item('Buy oats'),
        ],
        promises: [_walk],
      );
      expect(d.mood, DayMood.ahead);
      expect(d.greeting, 'Good morning');
      expect(
        d.dayLine.text,
        '3 things today, first at 9:00. 1 promise to keep.',
      );
      expect(d.dayLine.parts.where((p) => p.fact).length, 2);
      expect(d.focus.activity?.id, 'Buy oats'); // untimed and due now
    });

    test('midday, some done', () {
      final d = _day(
        _at(14, 20),
        items: [
          _item('a', hour: 9, done: true),
          _item('b', hour: 10, done: true),
          _item('c', hour: 15),
        ],
      );
      expect(d.mood, DayMood.underway);
      expect(d.dayLine.text, '2 of 3 done. Next at 15:00.');
      expect(d.today.done, 2);
      expect(d.today.pending.map((a) => a.id), ['c']);
    });

    test('a session is running', () {
      final d = _day(_at(14, 20), items: [_item('a', hour: 15)], live: true);
      expect(d.mood, DayMood.live);
      expect(d.dayLine.text, 'You’re focusing on Pitch deck.');
      expect(d.focus.kind, NowFocusKind.session);
    });

    test('behind: overdue comes first everywhere', () {
      final d = _day(
        _at(10),
        items: [
          _item('later', hour: 18),
          _item('late', hour: 8, overdue: true),
        ],
      );
      expect(d.mood, DayMood.behind);
      expect(d.dayLine.text, '1 overdue to catch up, then 1 thing for today.');
      expect(d.today.pending.first.id, 'late');
      expect(d.needsYou.first.kind, NeedsYouKind.overdue);
      expect(d.needsYou.first.action, 'Move to today');
    });

    test('evening, all done with a promise still to keep', () {
      final d = _day(
        _at(19, 40),
        items: [_item('a', hour: 9, done: true), _item('b', done: true)],
        promises: [_walk],
      );
      expect(d.mood, DayMood.allDone);
      expect(d.dayLine.text, 'All 2 done. 1 promise to keep.');
    });

    test('an open day mentions anytime to-dos, never "0"', () {
      final empty = _day(_at(9));
      expect(empty.mood, DayMood.open);
      expect(empty.dayLine.text, 'Your day is open.');
      final anytime = _day(_at(9), items: [_item('someday', anytime: true)]);
      expect(anytime.mood, DayMood.open);
      expect(
        anytime.dayLine.text,
        'Your day is open. 1 anytime to-do waiting.',
      );
      for (final d in [empty, anytime]) {
        expect(d.dayLine.text, isNot(contains(' 0 ')));
      }
    });

    test('a quiet night', () {
      final d = _day(_at(22, 30));
      expect(d.mood, DayMood.quiet);
      expect(d.greeting, 'Good night');
    });

    test('plurals are right', () {
      expect(
        _day(_at(8), items: [_item('a', hour: 9)]).dayLine.text,
        '1 thing today, first at 9:00.',
      );
    });
  });

  group('day rail', () {
    test('marks sit between 6:00 and midnight, sorted', () {
      expect(railPosition(_at(6)), 0);
      expect(railPosition(_at(15)), 0.5);
      expect(railPosition(_at(3)), 0);
      final d = _day(
        _at(12),
        items: [
          _item('b', hour: 18),
          _item('a', hour: 9, done: true),
          _item('pill', hour: 20, source: 'medicine'),
          _item('x'),
        ],
        reminders: [_reminder(1, _at(19))],
      );
      expect(d.rail.now, closeTo(1 / 3, 1e-9));
      expect(d.rail.marks.map((m) => m.kind), [
        RailKind.task,
        RailKind.task,
        RailKind.reminder,
        RailKind.dose,
      ]);
      expect(d.rail.marks.first.done, isTrue);
    });
  });

  group('needs you', () {
    test('missed doses only after 30 minutes', () {
      final d = _day(
        _at(9, 20),
        items: [_item('Vitamin D3', hour: 9, source: 'medicine')],
      );
      expect(d.needsYou, isEmpty);
      final later = _day(
        _at(9, 45),
        items: [_item('Vitamin D3', hour: 9, source: 'medicine')],
      );
      expect(later.needsYou.single.kind, NeedsYouKind.missedDose);
      expect(later.needsYou.single.detail, 'Due 9:00, not taken');
    });

    test('overdue reminders, yesterday’s promise and an old backup', () {
      final d = _day(
        _at(12),
        reminders: [_reminder(7, _at(10, 30))],
        promises: [
          const PromiseToday(
            id: 'p2',
            title: 'No phone after 10',
            day: 3,
            length: null,
            answeredToday: false,
            yesterdayOpen: true,
            streak: 2,
          ),
        ],
        lastBackupAt: _at(12).subtract(const Duration(days: 9)),
      );
      expect(d.needsYou.map((n) => n.kind), [
        NeedsYouKind.overdueReminder,
        NeedsYouKind.promiseWaiting,
        NeedsYouKind.backup,
      ]);
      expect(d.needsYou.last.detail, 'Last one 9 days ago');
    });

    test('a recent backup or none at all does not nag', () {
      expect(
        _day(
          _at(12),
          lastBackupAt: _at(12).subtract(const Duration(days: 2)),
        ).needsYou,
        isEmpty,
      );
      expect(_day(_at(12)).needsYou, isEmpty);
    });

    test('shows at most 4', () {
      final d = _day(
        _at(23),
        items: [
          for (var i = 0; i < 6; i++)
            _item('dose $i', hour: 8 + i, source: 'medicine'),
        ],
      );
      expect(d.needsYou.length, needsYouCap);
    });
  });

  group('vitals and slices', () {
    test('vitals measure against goals', () {
      final d = _day(
        _at(12),
        items: [
          _item('d1', hour: 9, source: 'medicine', done: true),
          _item('d2', hour: 20, source: 'medicine'),
        ],
      );
      expect(d.vitals.dosesTaken, 1);
      expect(d.vitals.dosesTotal, 2);
      expect(d.vitals.waterProgress, closeTo(0.72, 1e-9));
      expect(d.vitals.focusProgress, closeTo(0.75, 1e-9));
    });

    test('identical inputs give equal slices (no needless rebuilds)', () {
      HomeDay make() => _day(
        _at(12),
        items: [_item('a', hour: 9), _item('b', hour: 15)],
        reminders: [_reminder(1, _at(19))],
      );
      final a = make(), b = make();
      expect(a.dayLine, b.dayLine);
      expect(a.rail, b.rail);
      expect(a.today, b.today);
      expect(a.vitals, b.vitals);
      expect(a.needsYou, b.needsYou);
    });

    test('100+ items stay fast and capped', () {
      final items = [
        for (var i = 0; i < 150; i++) _item('t$i', hour: 6 + i % 17),
      ];
      final sw = Stopwatch()..start();
      final d = _day(_at(5), items: items);
      sw.stop();
      expect(d.today.total, 150);
      expect(d.rail.marks.length, 150);
      expect(sw.elapsedMilliseconds, lessThan(50));
    });
  });

  group('Home layout v2', () {
    test('round-trips every setting', () {
      final layout = HomeLayout.defaults().copyWith(
        zones: [HomeZone.mind, HomeZone.plan, HomeZone.money],
        hiddenZones: {HomeZone.money},
        background: HomeBackground.doodle,
        zoneStrength: 0.5,
        density: HomeDensity.compact,
        changeThroughDay: false,
      );
      final back = HomeLayout.fromJson(layout.toJson());
      expect(back.zones.first, HomeZone.now);
      expect(back.zones.sublist(1, 4), [
        HomeZone.mind,
        HomeZone.plan,
        HomeZone.money,
      ]);
      expect(back.zones.toSet(), HomeZone.values.toSet());
      expect(back.hiddenZones, {HomeZone.money});
      expect(back.background, HomeBackground.doodle);
      expect(back.zoneStrength, 0.5);
      expect(back.density, HomeDensity.compact);
      expect(back.changeThroughDay, isFalse);
      expect(back.visibleZones, isNot(contains(HomeZone.money)));
    });

    test('Now can never be hidden; strength stays in range', () {
      final layout = HomeLayout.defaults().copyWith(
        hiddenZones: {HomeZone.now, HomeZone.mind},
        zoneStrength: 3,
      );
      expect(layout.hiddenZones, {HomeZone.mind});
      expect(layout.zoneStrength, 1);
    });

    test('a saved v1 layout keeps what the person hid', () {
      final v1 = HomeLayout.fromJson({
        'version': 1,
        'order': ['today', 'mind', 'life'],
        'visible': ['today', 'promises'],
        'tools': ['hydration'],
      });
      expect(v1.hiddenZones, {HomeZone.mind, HomeZone.care});
      expect(v1.background, HomeBackground.zones);
      expect(v1.zoneStrength, defaultZoneStrength);
      expect(HomeLayout.fromJson(v1.toJson()).hiddenZones, v1.hiddenZones);
    });

    test('a bare v1 Home stays bare; defaults show every zone', () {
      final bare = HomeLayout.fromJson({
        'version': 1,
        'order': <String>[],
        'visible': <String>[],
        'tools': <String>[],
      });
      expect(bare.visibleZones, [HomeZone.now]);
      expect(HomeLayout.defaults().visibleZones, HomeZone.values);
    });

    test('unknown values fall back to defaults', () {
      final json = HomeLayout.defaults().toJson()
        ..['background'] = 'sparkles'
        ..['density'] = 42
        ..['zones'] = ['nope', 'mind']
        ..['hiddenZones'] = ['nope'];
      final layout = HomeLayout.fromJson(json);
      expect(layout.background, HomeBackground.zones);
      expect(layout.density, HomeDensity.comfortable);
      expect(layout.zones[1], HomeZone.mind);
      expect(layout.hiddenZones, isEmpty);
    });
  });
}
