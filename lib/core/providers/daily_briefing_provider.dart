import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'database_provider.dart';
import 'settings_provider.dart';
import 'local_day_provider.dart';

DateTime briefingDay(DateTime date) =>
    DateTime(date.year, date.month, date.day);

final _briefingTasksProvider = StreamProvider.autoDispose<List<Task>>(
  (ref) => ref.watch(taskDaoProvider).watchAllTasks(),
);
final _briefingSessionsProvider = StreamProvider.autoDispose
    .family<List<TimeSession>, DateTime>((ref, day) {
      final yesterday = DateTime(day.year, day.month, day.day - 1);
      return ref
          .watch(timeSessionDaoProvider)
          .watchSessionsBetween(yesterday, day);
    });

final dailyBriefingProvider = FutureProvider.autoDispose
    .family<DailyBriefing, DateTime>((ref, day) async {
      final tasks = await ref.watch(_briefingTasksProvider.future);
      final sessions = await ref.watch(_briefingSessionsProvider(day).future);
      final reminders = await ref.watch(allRemindersProvider.future);
      final now = ref.watch(localClockProvider);
      return DailyBriefing.fromRecords(
        day: day,
        tasks: tasks,
        sessions: sessions,
        reminders: reminders,
        now: now,
      );
    });

/// Describes recorded activity only; missing logs are never treated as failure.
class DailyBriefing {
  const DailyBriefing({
    required this.completedYesterday,
    required this.plannedYesterday,
    required this.finishedPlannedYesterday,
    required this.trackedMinutesYesterday,
    required this.dueToday,
    required this.overdue,
    required this.unscheduled,
    this.nextTask,
    this.nextTaskId,
    this.firstOverdueTaskId,
    this.firstUnscheduledTaskId,
    this.focusTasks = const [],
    this.remindersToday = 0,
    this.nextReminder,
  });

  final int completedYesterday;
  final int plannedYesterday;
  final int finishedPlannedYesterday;
  final int trackedMinutesYesterday;
  final int dueToday;
  final int overdue;
  final int unscheduled;
  final String? nextTask;
  final int? nextTaskId, firstOverdueTaskId, firstUnscheduledTaskId;
  final List<Task> focusTasks;
  final int remindersToday;
  final Reminder? nextReminder;

  factory DailyBriefing.fromRecords({
    required DateTime day,
    required List<Task> tasks,
    required List<TimeSession> sessions,
    List<Reminder> reminders = const [],
    DateTime? now,
  }) {
    final today = briefingDay(day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    bool yesterdayDate(DateTime? date) =>
        date != null && !date.isBefore(yesterday) && date.isBefore(today);
    final visibleTasks = tasks.where((t) => !t.isArchived).toList();
    final planned = visibleTasks.where((t) => yesterdayDate(t.plannedDate));
    final pending = visibleTasks.where((t) => t.actualCompletedDate == null);
    final due = pending
        .where(
          (t) =>
              t.isDailyStanding ||
              (t.plannedDate != null && briefingDay(t.plannedDate!) == today),
        )
        .toList();
    final overdue = pending
        .where(
          (t) =>
              !t.isDailyStanding &&
              t.plannedDate != null &&
              t.plannedDate!.isBefore(today),
        )
        .toList();
    final unscheduled = pending
        .where((t) => !t.isDailyStanding && t.plannedDate == null)
        .toList();
    int order(Task a, Task b) {
      final dateOrder = (a.plannedDate ?? a.createdAt).compareTo(
        b.plannedDate ?? b.createdAt,
      );
      if (dateOrder != 0) return dateOrder;
      final createdOrder = a.createdAt.compareTo(b.createdAt);
      return createdOrder != 0 ? createdOrder : a.id.compareTo(b.id);
    }

    due.sort(order);
    overdue.sort(order);
    unscheduled.sort(order);
    final candidates = [...due, ...overdue, ...unscheduled];
    final todayReminders =
        reminders
            .where((r) => r.isActive && briefingDay(r.scheduledAt) == today)
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final clock = now ?? DateTime.now();
    final upcoming = todayReminders
        .where((r) => !r.scheduledAt.isBefore(clock))
        .toList();
    return DailyBriefing(
      completedYesterday: visibleTasks
          .where((t) => yesterdayDate(t.actualCompletedDate))
          .length,
      plannedYesterday: planned.length,
      finishedPlannedYesterday: planned
          .where(
            (t) =>
                t.actualCompletedDate != null &&
                t.actualCompletedDate!.isBefore(today),
          )
          .length,
      trackedMinutesYesterday:
          sessions
              .where(
                (s) => s.status != 'discarded' && yesterdayDate(s.startedAt),
              )
              .fold<int>(0, (total, s) => total + s.durationSeconds) ~/
          60,
      dueToday: due.length,
      overdue: overdue.length,
      unscheduled: unscheduled.length,
      nextTask: candidates.isEmpty ? null : candidates.first.title,
      nextTaskId: candidates.isEmpty ? null : candidates.first.id,
      firstOverdueTaskId: overdue.isEmpty ? null : overdue.first.id,
      firstUnscheduledTaskId: unscheduled.isEmpty ? null : unscheduled.first.id,
      focusTasks: List.unmodifiable(candidates.take(3)),
      remindersToday: todayReminders.length,
      nextReminder: upcoming.isEmpty ? null : upcoming.first,
    );
  }

  String get yesterdaySummary {
    if (completedYesterday == 0 &&
        trackedMinutesYesterday == 0 &&
        plannedYesterday == 0) {
      return 'No completed tasks or tracked time recorded yesterday. That is all I can see — how was your day?';
    }
    return 'Yesterday: $completedYesterday tasks completed · $trackedMinutesYesterday min tracked.'
        '${plannedYesterday > 0 ? ' $finishedPlannedYesterday of $plannedYesterday tasks planned for yesterday were complete by the end of the day.' : ''}';
  }

  static String _plural(int n, String one, [String? many]) =>
      '$n ${n == 1 ? one : (many ?? '${one}s')}';

  static String _duration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  /// Yesterday as one calm sentence. Missing logs are never framed as failure.
  String get yesterdayStory {
    if (completedYesterday > 0 && trackedMinutesYesterday > 0) {
      return 'Yesterday you finished ${_plural(completedYesterday, 'task')} '
          'and spent ${_duration(trackedMinutesYesterday)} in focus.';
    }
    if (completedYesterday > 0) {
      return 'Yesterday you finished ${_plural(completedYesterday, 'task')}.';
    }
    if (trackedMinutesYesterday > 0) {
      return 'Yesterday you put ${_duration(trackedMinutesYesterday)} into focused work.';
    }
    return 'Today is a clean page. Start small and let the day build itself.';
  }

  /// Today in words: what is waiting and where to begin.
  String get todayStory {
    final parts = <String>[
      if (dueToday > 0) '${_plural(dueToday, 'thing')} due today',
      if (overdue > 0) '${_plural(overdue, 'task')} carried over',
    ];
    final start = nextTask == null
        ? ''
        : ' A good place to begin: “$nextTask”.';
    if (parts.isEmpty && nextTask == null) {
      return 'Your day is wide open. Capture what is on your mind, or pick one small thing to begin.';
    }
    if (parts.isEmpty) return 'Nothing is pressing.$start';
    return 'You have ${parts.join(' and ')}.$start';
  }

  String get encouragement {
    if (overdue > 0) {
      return '$overdue overdue ${overdue == 1 ? 'task needs' : 'tasks need'} a decision. Pick one to do, reschedule, or let go. A smaller, honest plan helps.';
    }
    if (plannedYesterday > finishedPlannedYesterday) {
      return 'Yesterday’s plan was not fully finished. Let’s make today manageable: choose one small thing first.';
    }
    if (completedYesterday > 0 || trackedMinutesYesterday > 0) {
      return 'You have recorded progress to build on. Give today one clear next step.';
    }
    return 'Bro, you don’t need a perfect plan. Start with one task or tell me what’s on your mind.';
  }
}

const dailyBriefingAutoOpenKey = 'ascent_daily_briefing_auto_open_v1';

class DailyBriefingAutoOpenNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(dailyBriefingAutoOpenKey) ??
      true;

  Future<void> setEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (!await prefs.setBool(dailyBriefingAutoOpenKey, enabled)) {
      throw StateError('Could not save daily welcome preference');
    }
    state = enabled;
  }
}

final dailyBriefingAutoOpenProvider =
    NotifierProvider<DailyBriefingAutoOpenNotifier, bool>(
      DailyBriefingAutoOpenNotifier.new,
    );
