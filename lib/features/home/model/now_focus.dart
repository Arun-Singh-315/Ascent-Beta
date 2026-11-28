import 'package:flutter/foundation.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../today/models/things_sections.dart';

/// What the Now card is showing (CLAUDE.md §5.1).
enum NowFocusKind { session, overdueReminder, activity, allDone, empty }

/// The single answer to "what should I do now?".
@immutable
class NowFocus {
  const NowFocus._(
    this.kind, {
    this.activity,
    this.reminder,
    this.next,
    this.isLater = false,
  });

  const NowFocus.session() : this._(NowFocusKind.session);
  const NowFocus.reminder(Reminder r, {TodayActivityItem? next})
    : this._(NowFocusKind.overdueReminder, reminder: r, next: next);
  const NowFocus.activity(
    TodayActivityItem a, {
    TodayActivityItem? next,
    bool isLater = false,
  }) : this._(NowFocusKind.activity, activity: a, next: next, isLater: isLater);
  const NowFocus.allDone() : this._(NowFocusKind.allDone);
  const NowFocus.empty() : this._(NowFocusKind.empty);

  final NowFocusKind kind;
  final TodayActivityItem? activity;
  final Reminder? reminder;

  /// The item after this one, shown as a quiet "Then" line.
  final TodayActivityItem? next;

  /// True when nothing is due yet and [activity] is the next scheduled item.
  final bool isLater;
}

/// Picks the Now card's focus. Pure, so it can be unit tested.
///
/// Priority: running/paused session → overdue activity → overdue reminder →
/// due medicine → due/unscheduled activity (earliest first) → next scheduled
/// activity → all done → empty.
NowFocus resolveNowFocus({
  required List<TodayActivityItem> activities,
  required List<Reminder> reminders,
  required bool hasLiveSession,
  required DateTime now,
}) {
  if (hasLiveSession) return const NowFocus.session();

  final pending = activities
      .where((a) => a.status != TodayActivityStatus.done && isOnTodayList(a))
      .toList();

  bool isFuture(TodayActivityItem a) =>
      a.scheduledTime != null && a.scheduledTime!.isAfter(now);

  int byTime(TodayActivityItem a, TodayActivityItem b) {
    final at = a.scheduledTime, bt = b.scheduledTime;
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  }

  final overdue = pending.where((a) => a.isOverdue).toList()..sort(byTime);
  final due = pending.where((a) => !a.isOverdue && !isFuture(a)).toList()
    ..sort((a, b) {
      final am = a.sourceType == 'medicine', bm = b.sourceType == 'medicine';
      if (am != bm) return am ? -1 : 1;
      return byTime(a, b);
    });
  final later = pending.where((a) => !a.isOverdue && isFuture(a)).toList()
    ..sort(byTime);
  final ordered = [...overdue, ...due, ...later];

  TodayActivityItem? after(TodayActivityItem? current) {
    for (final a in ordered) {
      if (!identical(a, current)) return a;
    }
    return null;
  }

  if (overdue.isNotEmpty) {
    return NowFocus.activity(overdue.first, next: after(overdue.first));
  }

  final linkedTaskIds = {
    for (final a in activities)
      if (a.linkedTaskId != null) a.linkedTaskId!,
  };
  final overdueReminders =
      reminders
          .where(
            (r) =>
                r.isActive &&
                r.scheduledAt.isBefore(now) &&
                (r.linkedTaskId == null ||
                    !linkedTaskIds.contains(r.linkedTaskId)),
          )
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  if (overdueReminders.isNotEmpty) {
    return NowFocus.reminder(
      overdueReminders.first,
      next: ordered.isEmpty ? null : ordered.first,
    );
  }

  if (due.isNotEmpty) {
    return NowFocus.activity(due.first, next: after(due.first));
  }
  if (later.isNotEmpty) {
    return NowFocus.activity(
      later.first,
      next: after(later.first),
      isLater: true,
    );
  }
  if (activities.any(isOnTodayList)) return const NowFocus.allDone();
  return const NowFocus.empty();
}
