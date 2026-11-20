import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/database_provider.dart';

/// One dated session of a plan, as the progress view needs it.
class PlanSession {
  const PlanSession({
    required this.at,
    required this.done,
    required this.skipped,
    this.taskId,
    this.occurrenceId,
    this.title = '',
    this.minutes,
  });
  final DateTime at;
  final bool done;
  final bool skipped;
  final int? taskId;
  final String? occurrenceId;
  final String title;
  final int? minutes;
}

enum PlanDayState { none, done, partial, missed, upcoming }

/// Everything the plan page shows about progress. Pure, so it is easy to test.
class PlanProgress {
  const PlanProgress({
    required this.week,
    required this.streak,
    required this.behind,
    required this.missedTaskIds,
    required this.missed,
    required this.dayNumber,
    required this.totalDays,
    required this.first,
    required this.last,
  });

  /// The last 7 days, oldest first; the last entry is today.
  final List<(DateTime, PlanDayState)> week;

  /// Days in a row with every session done (one missed day per week is
  /// forgiven, CLAUDE.md §1.8).
  final int streak;

  /// Past sessions not done or skipped.
  final int behind;

  /// To-dos of missed sessions.
  final List<int> missedTaskIds;

  /// Missed sessions, for "Catch up".
  final List<PlanSession> missed;
  final int dayNumber;
  final int totalDays;
  final DateTime? first;
  final DateTime? last;

  bool get onTrack => behind == 0;

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  factory PlanProgress.from(List<PlanSession> sessions, DateTime now) {
    final today = _day(now);
    final byDay = <DateTime, List<PlanSession>>{};
    for (final s in sessions) {
      byDay.putIfAbsent(_day(s.at), () => []).add(s);
    }
    PlanDayState stateOf(DateTime day) {
      final list = byDay[day];
      if (list == null || list.isEmpty) return PlanDayState.none;
      final done = list.where((s) => s.done).length;
      final settled = list.where((s) => s.done || s.skipped).length;
      if (done == list.length) return PlanDayState.done;
      if (settled == list.length) return PlanDayState.partial;
      if (day.isBefore(today)) {
        return settled == 0 ? PlanDayState.missed : PlanDayState.partial;
      }
      return settled == 0 ? PlanDayState.upcoming : PlanDayState.partial;
    }

    final week = [
      for (var i = 6; i >= 0; i--)
        (
          today.subtract(Duration(days: i)),
          stateOf(today.subtract(Duration(days: i))),
        ),
    ];

    // Streak: walk back from today (today counts only when finished).
    var streak = 0;
    var graceLeft = 1;
    var day = stateOf(today) == PlanDayState.done
        ? today
        : today.subtract(const Duration(days: 1));
    for (var i = 0; i < 120; i++) {
      final st = stateOf(day);
      if (st == PlanDayState.done) {
        streak++;
      } else if (st == PlanDayState.none) {
        // Rest days (e.g. weekends for weekday steps) don't break a streak.
      } else if (graceLeft > 0 && streak > 0) {
        graceLeft--;
      } else {
        break;
      }
      if (i % 7 == 6) graceLeft = 1;
      day = day.subtract(const Duration(days: 1));
      if (sessions.isNotEmpty &&
          day.isBefore(
            _day(
              sessions.map((s) => s.at).reduce((a, b) => a.isBefore(b) ? a : b),
            ),
          )) {
        break;
      }
    }

    final missed = sessions
        .where((s) => !s.done && !s.skipped && s.at.isBefore(now))
        .toList();
    final days = byDay.keys.toList()..sort();
    final first = days.isEmpty ? null : days.first;
    final last = days.isEmpty ? null : days.last;
    final total = first == null ? 0 : last!.difference(first).inDays + 1;
    final dayNumber = first == null
        ? 0
        : (today.difference(first).inDays + 1).clamp(0, total);
    return PlanProgress(
      week: week,
      streak: streak,
      behind: missed.length,
      missed: missed,
      missedTaskIds: [
        for (final s in missed)
          if (s.taskId != null) s.taskId!,
      ],
      dayNumber: dayNumber,
      totalDays: total,
      first: first,
      last: last,
    );
  }
}

/// Live sessions of every step in a plan, with their to-do completion.
final planSessionsProvider = StreamProvider.autoDispose
    .family<List<PlanSession>, String>((ref, collectionId) {
      final db = ref.watch(databaseProvider);
      return db
          .customSelect(
            '''
        SELECT o.id AS occ_id, o.scheduled_start_time AS at,
               o.outcome AS outcome, o.completed_at AS occ_done,
               o.linked_task_id AS task_id, d.title AS title,
               d.target_minutes AS minutes,
               t.actual_completed_date AS task_done
        FROM plan_collection_items i
        JOIN plan_definitions d ON d.id = i.definition_id
        JOIN plan_occurrences o ON o.plan_id = i.definition_id
        LEFT JOIN tasks t ON t.id = o.linked_task_id
        WHERE i.collection_id = ?
        ORDER BY o.scheduled_start_time
        ''',
            variables: [Variable(collectionId)],
            readsFrom: {
              db.planCollectionItemTable,
              db.planDefinitionTable,
              db.planOccurrenceTable,
              db.taskTable,
            },
          )
          .watch()
          .map(
            (rows) => [
              for (final r in rows)
                PlanSession(
                  at: DateTime.fromMillisecondsSinceEpoch(
                    (r.data['at'] as int) * 1000,
                  ),
                  done:
                      r.data['outcome'] == 'done' ||
                      r.data['occ_done'] != null ||
                      r.data['task_done'] != null,
                  skipped: r.data['outcome'] == 'skipped',
                  taskId: r.data['task_id'] as int?,
                  occurrenceId: r.data['occ_id'] as String?,
                  title: r.data['title'] as String? ?? '',
                  minutes: r.data['minutes'] as int?,
                ),
            ],
          );
    });
