import '../database/app_database.dart';
import 'boost_notification_copy.dart';

/// One bundle per slot. A short horizon prevents stale, indefinitely repeating copy.
class ThingsCheckIn {
  const ThingsCheckIn(this.at, this.message);
  final DateTime at;
  final NotificationMessage message;

  static List<ThingsCheckIn> plan({
    required DateTime now,
    required List<Task> tasks,
    required List<Reminder> reminders,
    Set<int> privateThoughtIds = const {},
    bool redact = false,
  }) {
    final result = <ThingsCheckIn>[];
    for (var day = 0; day < 2; day++) {
      for (final hour in [11, 18]) {
        final at = DateTime(now.year, now.month, now.day + day, hour, 30);
        if (!at.isAfter(now.add(const Duration(minutes: 30)))) continue;
        // A real alert already nearby takes precedence over a general check-in.
        if (reminders.any(
          (r) =>
              r.isActive &&
              r.alarmEnabled &&
              r.scheduledAt.difference(at).inMinutes.abs() <= 60,
        )) {
          continue;
        }
        final end = DateTime(at.year, at.month, at.day + 1);
        final pending = tasks
            .where(
              (t) =>
                  !t.isArchived && t.actualCompletedDate == null &&
                  t.parentTaskId == null &&
                  !privateThoughtIds.contains(t.linkedThoughtId) &&
                  (t.plannedDate == null || t.plannedDate!.isBefore(end)) &&
                  !reminders.any(
                    (r) =>
                        r.linkedTaskId == t.id &&
                        r.isActive &&
                        r.alarmEnabled &&
                        r.scheduledAt.isAfter(now) &&
                        r.scheduledAt.isBefore(end),
                  ),
            )
            .toList();
        pending.sort((a, b) {
          int rank(Task t) => t.priority == 'high'
              ? 0
              : t.priority == 'medium'
              ? 1
              : 2;
          final priority = rank(a).compareTo(rank(b));
          if (priority != 0) return priority;
          return (a.plannedDate ?? a.createdAt).compareTo(
            b.plannedDate ?? b.createdAt,
          );
        });
        if (pending.isEmpty) continue;
        final task = pending.first;
        final overdue =
            task.plannedDate != null &&
            task.plannedDate!.isBefore(DateTime(at.year, at.month, at.day));
        final title = redact
            ? 'A little room for your things?'
            : overdue
            ? 'Still on your mind?'
            : hour == 11
            ? 'One small start?'
            : 'Before you call it a day';
        final label = task.title.replaceAll(RegExp(r'\s+'), ' ').trim();
        final short = label.length > 64 ? '${label.substring(0, 61)}…' : label;
        final rest = pending.length > 1
            ? ' +${pending.length - 1} more in Things hub.'
            : '';
        final body = redact
            ? 'Your Things hub has unfinished items. Pick one small next step.'
            : '“$short”$rest ${task.estimatedMinutes != null ? 'Got 5 minutes to start?' : 'One small step is enough.'}';
        result.add(
          ThingsCheckIn(
            at,
            NotificationMessage(
              title: title,
              body: body,
              summary: 'Things hub · A gentle check-in',
            ),
          ),
        );
      }
    }
    return result;
  }
}
