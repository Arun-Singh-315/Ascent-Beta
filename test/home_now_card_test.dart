import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/home_now_card.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime(2026, 11, 20, 14, 0);

TodayActivityItem _item(
  String id, {
  TodayActivityStatus status = TodayActivityStatus.notStarted,
  DateTime? at,
  bool overdue = false,
  String source = 'task',
  int? taskId,
  bool anytime = false,
}) => TodayActivityItem(
  id: id,
  title: id,
  sourceType: source,
  status: status,
  elapsedSecondsToday: 0,
  categoryTag: 'general',
  scheduledTime: at,
  isOverdue: overdue,
  linkedTaskId: taskId,
  // Items on today's list carry today's date; anytime to-dos have none.
  plannedDate: anytime ? null : _now,
);

Reminder _reminder(int id, DateTime at, {int? taskId, bool active = true}) =>
    Reminder(
      id: id,
      title: 'R$id',
      scheduledAt: at,
      alarmEnabled: false,
      alertSyncPending: false,
      isActive: active,
      createdAt: at,
      linkedTaskId: taskId,
    );

NowFocus _resolve({
  List<TodayActivityItem> activities = const [],
  List<Reminder> reminders = const [],
  bool session = false,
}) => resolveNowFocus(
  activities: activities,
  reminders: reminders,
  hasLiveSession: session,
  now: _now,
);

void main() {
  test('empty day asks the user to plan', () {
    expect(_resolve().kind, NowFocusKind.empty);
  });

  test('all activities done shows the all-done state', () {
    final f = _resolve(
      activities: [_item('a', status: TodayActivityStatus.done)],
    );
    expect(f.kind, NowFocusKind.allDone);
  });

  test('a live session always wins', () {
    final f = _resolve(
      session: true,
      activities: [_item('late', overdue: true)],
    );
    expect(f.kind, NowFocusKind.session);
  });

  test('overdue activity beats overdue reminder and due items', () {
    final f = _resolve(
      activities: [_item('due'), _item('late', overdue: true)],
      reminders: [_reminder(1, _now.subtract(const Duration(hours: 1)))],
    );
    expect(f.activity?.id, 'late');
    expect(f.next?.id, 'due');
  });

  test('overdue reminder beats due activities, unless linked to one', () {
    final past = _now.subtract(const Duration(minutes: 30));
    expect(
      _resolve(
        activities: [_item('due')],
        reminders: [_reminder(1, past)],
      ).kind,
      NowFocusKind.overdueReminder,
    );
    expect(
      _resolve(
        activities: [_item('due', taskId: 7)],
        reminders: [_reminder(1, past, taskId: 7)],
      ).activity?.id,
      'due',
      reason: 'a reminder for a visible activity is not shown twice',
    );
  });

  test('anytime to-dos stay out of Now, like the Things Today list', () {
    final f = _resolve(
      activities: [_item('someday', taskId: 3, anytime: true)],
    );
    expect(f.kind, NowFocusKind.empty);
    final g = _resolve(
      activities: [
        _item('someday', taskId: 3, anytime: true),
        _item('today', taskId: 4),
      ],
    );
    expect(g.activity?.id, 'today');
  });

  test('inactive or future reminders are ignored', () {
    final f = _resolve(
      reminders: [
        _reminder(1, _now.add(const Duration(hours: 1))),
        _reminder(2, _now.subtract(const Duration(hours: 1)), active: false),
      ],
    );
    expect(f.kind, NowFocusKind.empty);
  });

  test('due medicine comes before other due activities', () {
    final f = _resolve(
      activities: [
        _item('read', at: _now.subtract(const Duration(hours: 2))),
        _item('pill', source: 'medicine', at: _now),
      ],
    );
    expect(f.activity?.id, 'pill');
  });

  test('scheduled due items come before unscheduled ones, earliest first', () {
    final f = _resolve(
      activities: [
        _item('anytime'),
        _item('b', at: _now.subtract(const Duration(minutes: 10))),
        _item('a', at: _now.subtract(const Duration(hours: 1))),
      ],
    );
    expect(f.activity?.id, 'a');
    expect(f.next?.id, 'b');
    expect(f.isLater, isFalse);
  });

  test('when nothing is due, the next scheduled item is shown as later', () {
    final f = _resolve(
      activities: [
        _item('gym', at: _now.add(const Duration(hours: 3))),
        _item('call', at: _now.add(const Duration(hours: 1))),
      ],
    );
    expect(f.activity?.id, 'call');
    expect(f.isLater, isTrue);
    expect(f.next?.id, 'gym');
  });
}
