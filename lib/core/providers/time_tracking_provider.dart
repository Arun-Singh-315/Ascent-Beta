import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../notifications/notification_service.dart';
import '../learning_hub/learning_hub_provider.dart';
import '../streak/study_streak_provider.dart';
import 'database_provider.dart';
import 'settings_provider.dart';

class TimeTrackingState {
  final TimeSession? activeSession;
  final SessionCategory? activeCategory;
  final int elapsedSeconds;
  final bool isRunning;
  final bool isPaused;
  final bool isFloatingDismissed;

  const TimeTrackingState({
    this.activeSession,
    this.activeCategory,
    this.elapsedSeconds = 0,
    this.isRunning = false,
    this.isPaused = false,
    this.isFloatingDismissed = false,
  });

  String get formattedTime {
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;

    final twoDigitsMinutes = minutes.toString().padLeft(2, '0');
    final twoDigitsSeconds = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final twoDigitsHours = hours.toString().padLeft(2, '0');
      return '$twoDigitsHours:$twoDigitsMinutes:$twoDigitsSeconds';
    }
    return '$twoDigitsMinutes:$twoDigitsSeconds';
  }

  TimeTrackingState copyWith({
    TimeSession? activeSession,
    SessionCategory? activeCategory,
    int? elapsedSeconds,
    bool? isRunning,
    bool? isPaused,
    bool? isFloatingDismissed,
    bool clearActive = false,
  }) {
    if (clearActive) {
      return const TimeTrackingState();
    }
    return TimeTrackingState(
      activeSession: activeSession ?? this.activeSession,
      activeCategory: activeCategory ?? this.activeCategory,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isRunning: isRunning ?? this.isRunning,
      isPaused: isPaused ?? this.isPaused,
      isFloatingDismissed: isFloatingDismissed ?? this.isFloatingDismissed,
    );
  }
}

class TimeTrackingNotifier extends Notifier<TimeTrackingState> {
  StreamSubscription<TimeSession?>? _sessionSubscription;
  Timer? _ticker;
  Timer? _heartbeatTimer;

  @override
  TimeTrackingState build() {
    final dao = ref.watch(timeSessionDaoProvider);

    _sessionSubscription?.cancel();
    _sessionSubscription = dao.watchActiveFocusSession().listen((
      session,
    ) async {
      _timedTaskDeadline?.cancel();
      _deadlineGeneration++;
      if (session == null) {
        _ticker?.cancel();
        _heartbeatTimer?.cancel();
        NotificationService.instance.cancelOngoingFocusNotification();
        if (state.activeSession != null ||
            state.isRunning ||
            state.isPaused ||
            state.elapsedSeconds != 0) {
          state = const TimeTrackingState();
        }
        return;
      }

      SessionCategory? category;
      try {
        category = await dao.getCategoryById(session.categoryId);
      } catch (_) {}

      if (!ref.mounted) return;

      final isRunning = session.status == 'running';
      final isPaused = session.status == 'paused';

      final elapsed = isPaused
          ? session.durationSeconds
          : TimeSessionDao.computeActiveDurationSeconds(
              session.startedAt,
              DateTime.now(),
              session.pausedIntervals,
            );

      state = state.copyWith(
        activeSession: session,
        activeCategory: category,
        elapsedSeconds: elapsed,
        isRunning: isRunning,
        isPaused: isPaused,
      );

      if (isRunning) {
        unawaited(_armTimedTaskDeadline(session, elapsed).catchError((_) {}));
        _startTicker();
        _startHeartbeat();
        NotificationService.instance.showOngoingSessionNotification(
          title: session.label,
          body: category?.name ?? "Study Focus",
          subText: 'Timer Active',
          elapsedSeconds: elapsed,
          payload: '/focus',
        );
      } else {
        _ticker?.cancel();
        _heartbeatTimer?.cancel();
        if (isPaused) {
          NotificationService.instance.showOngoingSessionNotification(
            title: session.label,
            body: category?.name ?? "Study Focus",
            subText: 'Focus Paused',
            elapsedSeconds: elapsed,
            isPaused: true,
            payload: '/focus',
          );
        } else {
          NotificationService.instance.cancelOngoingFocusNotification();
        }
      }
    });

    ref.onDispose(() {
      _timedTaskDeadline?.cancel();
      _deadlineGeneration++;
      _sessionSubscription?.cancel();
      _ticker?.cancel();
      _heartbeatTimer?.cancel();
      NotificationService.instance.cancelOngoingFocusNotification();
    });

    return const TimeTrackingState();
  }

  Timer? _timedTaskDeadline;
  int _deadlineGeneration = 0;
  Future<void> _armTimedTaskDeadline(TimeSession session, int elapsed) async {
    final generation = ++_deadlineGeneration;
    _timedTaskDeadline?.cancel();
    if (session.status != 'running' ||
        session.linkedTaskId == null ||
        session.learningCourseId != null) {
      return;
    }
    final dao = ref.read(timeSessionDaoProvider);
    final db = ref.read(databaseProvider);
    final workspaceRevision = db.workspaceRevision;
    final task = await db.taskDao.getTaskById(session.linkedTaskId!);
    if (task == null ||
        task.learningCourseId != null ||
        (task.estimatedMinutes ?? 0) <= 0) {
      return;
    }
    final dose =
        await (db.select(db.medicineLogTable)
              ..where((l) => l.linkedTaskId.equals(task.id))
              ..limit(1))
            .getSingleOrNull();
    if (dose != null) return;
    final total = db.timeSessionTable.durationSeconds.sum();
    final history =
        await (db.selectOnly(db.timeSessionTable)
              ..addColumns([total])
              ..where(
                db.timeSessionTable.linkedTaskId.equals(task.id) &
                    db.timeSessionTable.status.equals('completed'),
              ))
            .getSingle();
    if (!ref.mounted || generation != _deadlineGeneration) return;
    final remaining =
        task.estimatedMinutes! * 60 -
        elapsed -
        (history.read(total) ?? 0).toInt();
    _timedTaskDeadline = Timer(
      Duration(milliseconds: remaining > 0 ? remaining * 1000 : 1),
      () async {
        if (!ref.mounted || generation != _deadlineGeneration) return;
        if (db.workspaceRevision != workspaceRevision) return;
        try {
          if (await dao.completeTimedSessionIfTargetReached(
            session.id,
            expectedWorkspaceRevision: workspaceRevision,
          )) {
            if (ref.mounted) ref.invalidate(todayFocusTaskProvider);
          } else if (ref.mounted &&
              state.activeSession?.id == session.id &&
              state.isRunning) {
            // Re-read the target if it was edited while the timer was running.
            final current = state.activeSession!;
            await _armTimedTaskDeadline(
              current,
              TimeSessionDao.computeActiveDurationSeconds(
                current.startedAt,
                DateTime.now(),
                current.pausedIntervals,
              ),
            );
          }
        } catch (_) {
          /* The next durable heartbeat retries this deadline. */
        }
      },
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = state.activeSession;
      if (session == null || state.isPaused) return;

      final elapsed = TimeSessionDao.computeActiveDurationSeconds(
        session.startedAt,
        DateTime.now(),
        session.pausedIntervals,
      );

      // Increment active study seconds for non-lecture study sessions
      if ((session.activityType.toLowerCase() == 'study' ||
              state.activeCategory?.name.toLowerCase() == 'study') &&
          session.activityRefType != 'lecture') {
        ref
            .read(studyStreakProvider.notifier)
            .creditActiveSecond(DateTime.now());
      }

      state = state.copyWith(elapsedSeconds: elapsed);
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Flush active duration every 5 seconds to SQLite for durable write-ahead state (§3.4)
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final session = state.activeSession;
      if (session == null || state.isPaused) return;
      try {
        final dao = ref.read(timeSessionDaoProvider);
        await dao.heartbeat(session.id, state.elapsedSeconds);
      } catch (_) {}
    });
  }

  void dismissFloatingBar() {
    state = state.copyWith(isFloatingDismissed: true);
  }

  void showFloatingBar() {
    state = state.copyWith(isFloatingDismissed: false);
  }

  Future<int> startSession({
    required String label,
    required int categoryId,
    String activityType = 'study',
    int? linkedTaskId,
    String activityRefType = 'task',
  }) async {
    state = state.copyWith(isFloatingDismissed: false);
    final dao = ref.read(timeSessionDaoProvider);
    return dao.startSession(
      label: label,
      categoryId: categoryId,
      activityType: activityType,
      linkedTaskId: linkedTaskId,
      activityRefType: activityRefType,
    );
  }

  Future<void> pauseSession() async {
    final session = state.activeSession;
    if (session == null) return;
    _heartbeatTimer?.cancel();
    final dao = ref.read(timeSessionDaoProvider);
    await dao.pauseSession(session.id);
  }

  Future<void> resumeSession() async {
    final session = state.activeSession;
    if (session == null) return;
    state = state.copyWith(isFloatingDismissed: false);
    final dao = ref.read(timeSessionDaoProvider);
    await dao.resumeSession(session.id);
  }

  /// Switches to a specific task or activity without losing existing state (§3.4).
  /// Pauses current running session and either selects a previously paused/active session
  /// for the target task today or starts a new session.
  /// If [autoStart] is false, the timer remains paused with the task's existing stored time.
  Future<void> switchToTask({
    required String title,
    int? taskId,
    String sourceType = 'task',
    int? categoryId,
    bool autoStart = true,
  }) async {
    if (taskId != null) {
      final task = await ref.read(taskDaoProvider).getTaskById(taskId);
      if (task?.learningCourseId != null && task?.learningLectureId != null) {
        final learning = ref.read(learningHubProvider.notifier);
        await learning.ready;
        final state = ref.read(learningHubProvider);
        if (!state.courses.any(
          (c) =>
              c.id == task!.learningCourseId &&
              c.modules.any(
                (m) => m.lectures.any((l) => l.id == task.learningLectureId),
              ),
        )) {
          throw StateError(
            'This linked lecture no longer exists. Open Learning to review it',
          );
        }
        if (this.state.isRunning && this.state.activeSession != null) {
          await ref
              .read(timeSessionDaoProvider)
              .pauseSession(this.state.activeSession!.id);
        }
        if (state.activeCourseId != task!.learningCourseId) {
          learning.switchCourse(task.learningCourseId!);
        }
        learning.selectLecture(task.learningLectureId!, autoPlay: autoStart);
        await learning.settled;
        return;
      }
    }
    final dao = ref.read(timeSessionDaoProvider);

    // 1. If current session is running, pause it and flush elapsed duration immediately
    if (state.isRunning && state.activeSession != null) {
      await dao.pauseSession(state.activeSession!.id);
    }

    // 2. Check if target task is already the active session
    if (state.activeSession != null &&
        ((taskId != null && state.activeSession!.linkedTaskId == taskId) ||
            (taskId == null && state.activeSession!.label == title))) {
      if (autoStart && state.isPaused) {
        await dao.resumeSession(state.activeSession!.id);
      }
      return;
    }

    // 3. Check if the target task already has an existing session today
    TimeSession? existingSession;
    if (taskId != null) {
      existingSession = await dao.getTodayActiveOrPausedSessionForTask(taskId);
    } else {
      existingSession = await dao.getTodayActiveOrPausedSessionByLabel(title);
    }

    if (existingSession != null) {
      if (autoStart) {
        if (existingSession.status == 'paused') {
          await dao.resumeSession(existingSession.id);
        }
      } else {
        if (existingSession.status == 'running') {
          await dao.pauseSession(existingSession.id);
        }
      }
      return;
    }

    // 4. Resolve category ID
    int targetCatId = categoryId ?? 1;
    if (categoryId == null) {
      final categories = await dao.getAllCategories();
      if (categories.isNotEmpty) {
        if (sourceType.toLowerCase() == 'entertainment' ||
            sourceType.toLowerCase() == 'break') {
          targetCatId = categories
              .firstWhere(
                (c) => c.name.toLowerCase() == 'entertainment',
                orElse: () => categories.first,
              )
              .id;
        } else {
          targetCatId = categories
              .firstWhere(
                (c) => c.name.toLowerCase() == 'study',
                orElse: () => categories.first,
              )
              .id;
        }
      }
    }

    final activityType =
        (sourceType.toLowerCase() == 'break' ||
            sourceType.toLowerCase() == 'entertainment')
        ? 'entertainment'
        : 'study';

    // 5. Start fresh write-ahead session for the new task
    final newId = await dao.startSession(
      label: title,
      categoryId: targetCatId,
      activityType: activityType,
      linkedTaskId: taskId,
      activityRefType: sourceType,
    );

    if (!autoStart) {
      await dao.pauseSession(newId);
    }
  }

  Future<bool> completeSession() async {
    final session = state.activeSession;
    if (session == null) return false;
    final dao = ref.read(timeSessionDaoProvider);
    if (!await dao.completeFocusSession(session.id)) return false;
    _heartbeatTimer?.cancel();

    var linkedTaskCompleted = false;
    if (session.linkedTaskId != null) {
      try {
        final taskDao = ref.read(taskDaoProvider);
        final task = await taskDao.getTaskById(session.linkedTaskId!);
        if (task != null &&
            task.estimatedMinutes != null &&
            task.estimatedMinutes! > 0) {
          linkedTaskCompleted = await taskDao.completeTimedTaskAfterFocus(
            task.id,
          );
        } else {
          linkedTaskCompleted = await taskDao.markComplete(
            session.linkedTaskId!,
          );
        }
      } catch (_) {}
    }

    ref.invalidate(todayFocusTaskProvider);
    ref.invalidate(homeQuickStatsProvider);
    return linkedTaskCompleted;
  }

  Future<void> abandonSession() async {
    final session = state.activeSession;
    if (session == null) return;
    _heartbeatTimer?.cancel();
    final dao = ref.read(timeSessionDaoProvider);
    await dao.abandonSession(session.id);
  }
}

final timeTrackingProvider =
    NotifierProvider<TimeTrackingNotifier, TimeTrackingState>(
      TimeTrackingNotifier.new,
    );

final activeSessionCategoriesProvider = StreamProvider<List<SessionCategory>>((
  ref,
) {
  final dao = ref.watch(timeSessionDaoProvider);
  return dao.watchAllCategories();
});

final todayTimeSessionsProvider =
    StreamProvider.family<List<TimeSession>, DateTime>((ref, date) {
      final dao = ref.watch(timeSessionDaoProvider);
      return dao.watchSessionsForDate(date);
    });

// ---------------------------------------------------------------------------
// Dismissed Today Activities Provider (prevents swiped items from resurrecting)
// ---------------------------------------------------------------------------

final dismissedTodayActivityIdsProvider =
    NotifierProvider<DismissedTodayActivityIdsNotifier, Set<String>>(
      DismissedTodayActivityIdsNotifier.new,
    );

class DismissedTodayActivityIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return _loadFromPrefs();
  }

  String _todayKey() {
    final now = DateTime.now();
    return 'ascent_dismissed_today_activities_${now.year}_${now.month}_${now.day}';
  }

  Set<String> _loadFromPrefs() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final list = prefs.getStringList(_todayKey()) ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> dismissActivityId(String id) async {
    final next = {...state, id};
    state = next;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setStringList(_todayKey(), next.toList());
    } catch (_) {}
  }

  Future<void> unDismissActivityId(String id) async {
    if (!state.contains(id)) return;
    final next = Set<String>.from(state)..remove(id);
    state = next;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setStringList(_todayKey(), next.toList());
    } catch (_) {}
  }

  Future<void> clearDismissedForToday() async {
    state = {};
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.remove(_todayKey());
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Dismissed Reminders for Home View
// ---------------------------------------------------------------------------

final dismissedTodayReminderIdsProvider =
    NotifierProvider<DismissedTodayReminderIdsNotifier, Set<int>>(
      DismissedTodayReminderIdsNotifier.new,
    );

class DismissedTodayReminderIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    return _loadFromPrefs();
  }

  String _todayKey() {
    final now = DateTime.now();
    return 'ascent_dismissed_today_reminders_${now.year}_${now.month}_${now.day}';
  }

  Set<int> _loadFromPrefs() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final list = prefs.getStringList(_todayKey()) ?? [];
      return list.map((e) => int.tryParse(e)).whereType<int>().toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> dismissReminderId(int id) async {
    final next = {...state, id};
    state = next;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setStringList(
        _todayKey(),
        next.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  Future<void> unDismissReminderId(int id) async {
    if (!state.contains(id)) return;
    final next = Set<int>.from(state)..remove(id);
    state = next;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setStringList(
        _todayKey(),
        next.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }
}

final homeVisibleRemindersProvider = Provider<List<Reminder>>((ref) {
  final remindersAsync = ref.watch(allRemindersProvider);
  final dismissedIds = ref.watch(dismissedTodayReminderIdsProvider);
  final reminders = remindersAsync.value ?? [];

  final now = DateTime.now();
  final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

  final visible = reminders.where((r) {
    if (!r.isActive) return false;
    if (dismissedIds.contains(r.id)) return false;
    // Reminders of that particular day only (including overdue today)
    if (r.scheduledAt.isAfter(endOfToday)) return false;
    return true;
  }).toList();

  // Order soonest first
  visible.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return visible;
});

// ---------------------------------------------------------------------------
// Unified Today Activities Provider (§2.2, §5.3)
// ---------------------------------------------------------------------------

final todayActivitiesProvider = StreamProvider<List<TodayActivityItem>>((
  ref,
) async* {
  final taskDao = ref.watch(taskDaoProvider);
  final sessionDao = ref.watch(timeSessionDaoProvider);
  final reminderDao = ref.watch(reminderDaoProvider);
  final planDao = ref.watch(planDaoProvider);
  final activeSessionState = ref.watch(
    timeTrackingProvider.select(
      (s) => (
        activeSessionId: s.activeSession?.id,
        linkedTaskId: s.activeSession?.linkedTaskId,
        isRunning: s.isRunning,
        isPaused: s.isPaused,
      ),
    ),
  );
  final dismissedIds = ref.watch(dismissedTodayActivityIdsProvider);
  final activeCourseId = ref.watch(
    learningHubProvider.select((s) => s.activeCourseId),
  );
  final activeLectureId = ref.watch(
    learningHubProvider.select((s) => s.activeLectureId),
  );
  final isLecturePlaying = ref.watch(
    learningHubProvider.select((s) => s.isPlaying),
  );
  final courses = ref.watch(learningHubProvider.select((s) => s.courses));

  final medicineLogs =
      ref.watch(todayMedicineLogsStreamProvider).value ?? <MedicineLog>[];
  final medicineById = {
    for (final medicine
        in ref.watch(allMedicinesStreamProvider).value ?? <Medicine>[])
      medicine.id: medicine,
  };
  final doseByTask = {
    for (final dose in medicineLogs)
      if (dose.linkedTaskId != null) dose.linkedTaskId!: dose,
  };

  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);

  // Watch both tasks for today (including uncompleted overdue tasks) and sessions for today
  final tasksStream = taskDao.watchTodayAndOverdueTasks(startOfToday);
  final sessionsStream = sessionDao.watchSessionsForDate(startOfToday);
  final remindersStream = reminderDao.watchAllReminders();

  await for (final (tasks, sessions, reminders) in combineStreams3(
    tasksStream,
    sessionsStream,
    remindersStream,
  )) {
    final List<TodayActivityItem> items = [];
    final Set<int> accountedSessionIds = {};

    // 1. Process tasks planned for today
    for (final task in tasks) {
      final medicineDose = doseByTask[task.id];
      if (medicineDose != null &&
          medicineById[medicineDose.medicineId]?.isActive == false &&
          task.actualCompletedDate == null) {
        continue;
      }

      if (task.learningCourseId != null) continue;
      final occ = await planDao.getOccurrenceByTaskId(task.id);
      if (occ != null) {
        if (occ.outcome == 'skipped') continue;
        final plan = await planDao.getPlanById(occ.planId);
        if (plan != null &&
            (plan.status == 'paused' || plan.status == 'ended') &&
            task.actualCompletedDate == null) {
          continue;
        }
      }
      final taskSessions = sessions
          .where((s) => s.linkedTaskId == task.id)
          .toList();
      accountedSessionIds.addAll(taskSessions.map((s) => s.id));

      int taskElapsedSeconds = 0;
      for (final s in taskSessions) {
        if (activeSessionState.activeSessionId == s.id) {
          taskElapsedSeconds += ref.read(timeTrackingProvider).elapsedSeconds;
        } else {
          taskElapsedSeconds += (s.durationSeconds > 0)
              ? s.durationSeconds
              : TimeSessionDao.computeActiveDurationSeconds(
                  s.startedAt,
                  s.endedAt ??
                      (s.status == 'running' ? DateTime.now() : s.startedAt),
                  s.pausedIntervals,
                );
        }
      }

      TodayActivityStatus status;
      if (activeSessionState.linkedTaskId == task.id &&
          activeSessionState.isRunning) {
        status = TodayActivityStatus.inProgress;
      } else if (taskSessions.any((s) => s.status == 'paused') ||
          (activeSessionState.linkedTaskId == task.id &&
              activeSessionState.isPaused)) {
        status = TodayActivityStatus.paused;
      } else if (task.actualCompletedDate != null) {
        status = TodayActivityStatus.done;
      } else {
        status = TodayActivityStatus.notStarted;
      }

      String categoryTag = 'Task';
      if (task.priority == 'high') {
        categoryTag = 'High Priority';
      }

      ActivityKind kind = ActivityKind.todo;
      int? targetMinutes;
      if (task.estimatedMinutes != null && task.estimatedMinutes! > 0) {
        kind = ActivityKind.duration;
        targetMinutes = task.estimatedMinutes;
      } else if (task.estimatedMinutes == -1) {
        kind = ActivityKind.flexible;
      }

      final isOverdue =
          status != TodayActivityStatus.done &&
          task.plannedDate != null &&
          DateTime(
            task.plannedDate!.year,
            task.plannedDate!.month,
            task.plannedDate!.day,
          ).isBefore(startOfToday);

      final matchingReminder = reminders.where(
        (r) =>
            r.isActive &&
            (r.linkedTaskId == task.id ||
                (r.linkedTaskId == null &&
                    r.title.trim().toLowerCase() ==
                        task.title.trim().toLowerCase())),
      ).firstOrNull;
      final hasReminder = matchingReminder != null;

      DateTime? scheduledTime;
      if (medicineDose != null) {
        final parts = medicineDose.timeSlot.split(':');
        scheduledTime = DateTime(
          today.year,
          today.month,
          today.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      } else if (matchingReminder != null) {
        scheduledTime = matchingReminder.scheduledAt;
      } else if (task.plannedDate != null &&
          (task.plannedDate!.hour != 0 || task.plannedDate!.minute != 0)) {
        scheduledTime = task.plannedDate;
      }

      items.add(
        TodayActivityItem(
          id: 'task_${task.id}',
          title: task.title,
          sourceType: medicineDose != null ? 'medicine' : 'task',
          status: status,
          elapsedSecondsToday: taskElapsedSeconds,
          linkedTaskId: task.id,
          linkedSessionId: taskSessions.isNotEmpty
              ? taskSessions.first.id
              : null,
          categoryTag: medicineDose != null ? 'Medicine' : categoryTag,
          priority: task.priority,
          kind: kind,
          targetMinutes: targetMinutes,
          plannedDate: medicineDose == null
              ? task.plannedDate
              : scheduledTime,
          isOverdue: isOverdue,
          hasReminder: hasReminder,
          notes: task.notes,
          completedAt: task.actualCompletedDate,
          medicineId: medicineDose?.medicineId,
          timeSlot: medicineDose?.timeSlot,
          scheduledTime: scheduledTime,
        ),
      );
    }

    // 2. Process standalone sessions (excluding lectures which are kept in Learning Hub)
    for (final session in sessions) {
      if (accountedSessionIds.contains(session.id) ||
          (session.activityRefType == 'lecture' ||
              session.learningCourseId != null)) {
        continue;
      }

      int elapsed;
      if (activeSessionState.activeSessionId == session.id) {
        elapsed = ref.read(timeTrackingProvider).elapsedSeconds;
      } else {
        elapsed = (session.durationSeconds > 0)
            ? session.durationSeconds
            : TimeSessionDao.computeActiveDurationSeconds(
                session.startedAt,
                session.endedAt ??
                    (session.status == 'running'
                        ? DateTime.now()
                        : session.startedAt),
                session.pausedIntervals,
              );
      }

      TodayActivityStatus status;
      if (activeSessionState.activeSessionId == session.id &&
          activeSessionState.isRunning) {
        status = TodayActivityStatus.inProgress;
      } else if (session.status == 'paused' ||
          (activeSessionState.activeSessionId == session.id &&
              activeSessionState.isPaused)) {
        status = TodayActivityStatus.paused;
      } else if (session.status == 'completed') {
        status = TodayActivityStatus.done;
      } else {
        status = TodayActivityStatus.notStarted;
      }
      final targetMinutes = (session.durationSeconds > 0)
          ? (session.durationSeconds / 60).round()
          : null;

      String categoryTag = session.activityType == 'entertainment'
          ? 'Break'
          : 'Study';

      items.add(
        TodayActivityItem(
          id: 'session_${session.id}',
          title: session.label,
          sourceType: session.activityRefType,
          status: status,
          elapsedSecondsToday: elapsed,
          linkedTaskId: session.linkedTaskId,
          linkedSessionId: session.id,
          categoryTag: categoryTag,
          kind: ActivityKind.duration,
          targetMinutes: targetMinutes,
          plannedDate: session.startedAt,
          isOverdue: false,
          completedAt: session.status == 'completed' ? session.endedAt : null,
        ),
      );
    }

    // A lecture is projected once, with a course-scoped identity and genuine
    // engagement. It remains in the catalog when dismissed from Today.
    for (final course in courses) {
      for (final lec in course.modules.expand((m) => m.lectures)) {
        final related = sessions
            .where(
              (s) =>
                  s.learningCourseId == course.id &&
                  s.learningLectureId == lec.id &&
                  s.activityRefType == 'lecture',
            )
            .toList();
        final planned = lec.plannedDate;
        final plannedToday =
            planned != null &&
            planned.year == today.year &&
            planned.month == today.month &&
            planned.day == today.day;
        if (!lec.isCompleted && !plannedToday && related.isEmpty) continue;
        final active = activeCourseId == course.id && activeLectureId == lec.id;
        final linkedTask = tasks
            .where(
              (t) =>
                  t.learningCourseId == course.id &&
                  t.learningLectureId == lec.id,
            )
            .firstOrNull;
        items.add(
          TodayActivityItem(
            id: 'lecture_${Uri.encodeComponent(course.id)}_${lec.id}',
            title: '${course.title}: ${lec.title}',
            sourceType: 'lecture',
            learningCourseId: course.id,
            learningLectureId: lec.id,
            status: lec.isCompleted
                ? TodayActivityStatus.done
                : active && isLecturePlaying
                ? TodayActivityStatus.inProgress
                : related.isNotEmpty
                ? TodayActivityStatus.paused
                : TodayActivityStatus.notStarted,
            elapsedSecondsToday: 0,
            linkedTaskId: linkedTask?.id,
            categoryTag: 'Study',
            kind: ActivityKind.duration,
            targetMinutes: null,
            plannedDate: planned ?? lec.lastPlayedAt,
            completedAt: lec.isCompleted ? lec.lastPlayedAt : null,
          ),
        );
      }
    }

    // 2.7 Filter out any activities that the user explicitly removed/dismissed for today
    items.removeWhere((item) => dismissedIds.contains(item.id));

    // 3. Sort items: inProgress first (0), paused second (1), notStarted third (2), done last (3)
    items.sort((a, b) {
      int score(TodayActivityStatus s) => switch (s) {
        TodayActivityStatus.inProgress => 0,
        TodayActivityStatus.paused => 1,
        TodayActivityStatus.notStarted => 2,
        TodayActivityStatus.done => 3,
      };
      final diff = score(a.status).compareTo(score(b.status));
      if (diff != 0) return diff;
      return b.elapsedSecondsToday.compareTo(a.elapsedSecondsToday);
    });

    yield items;
  }
});

Stream<(T1, T2)> combineStreams<T1, T2>(Stream<T1> s1, Stream<T2> s2) {
  late StreamController<(T1, T2)> controller;
  T1? val1;
  T2? val2;
  bool hasVal1 = false;
  bool hasVal2 = false;
  StreamSubscription<T1>? sub1;
  StreamSubscription<T2>? sub2;

  controller = StreamController<(T1, T2)>(
    onListen: () {
      sub1 = s1.listen((data) {
        val1 = data;
        hasVal1 = true;
        if (hasVal2) controller.add((val1 as T1, val2 as T2));
      }, onError: controller.addError);
      sub2 = s2.listen((data) {
        val2 = data;
        hasVal2 = true;
        if (hasVal1) controller.add((val1 as T1, val2 as T2));
      }, onError: controller.addError);
    },
    onCancel: () async {
      await sub1?.cancel();
      await sub2?.cancel();
    },
  );

  return controller.stream;
}

Stream<(T1, T2, T3)> combineStreams3<T1, T2, T3>(
  Stream<T1> s1,
  Stream<T2> s2,
  Stream<T3> s3,
) {
  late StreamController<(T1, T2, T3)> controller;
  T1? val1;
  T2? val2;
  T3? val3;
  bool hasVal1 = false;
  bool hasVal2 = false;
  bool hasVal3 = false;
  StreamSubscription<T1>? sub1;
  StreamSubscription<T2>? sub2;
  StreamSubscription<T3>? sub3;

  controller = StreamController<(T1, T2, T3)>(
    onListen: () {
      sub1 = s1.listen((data) {
        val1 = data;
        hasVal1 = true;
        if (hasVal2 && hasVal3) {
          controller.add((val1 as T1, val2 as T2, val3 as T3));
        }
      }, onError: controller.addError);
      sub2 = s2.listen((data) {
        val2 = data;
        hasVal2 = true;
        if (hasVal1 && hasVal3) {
          controller.add((val1 as T1, val2 as T2, val3 as T3));
        }
      }, onError: controller.addError);
      sub3 = s3.listen((data) {
        val3 = data;
        hasVal3 = true;
        if (hasVal1 && hasVal2) {
          controller.add((val1 as T1, val2 as T2, val3 as T3));
        }
      }, onError: controller.addError);
    },
    onCancel: () async {
      await sub1?.cancel();
      await sub2?.cancel();
      await sub3?.cancel();
    },
  );

  return controller.stream;
}

/// Cleanly and completely deletes a task and cascades across all reminders,
/// local notification alarms, running timers, and child subtasks with zero orphaned state (Rule 8).
Future<void> deleteTaskAndCleanCascade(
  dynamic ref,
  int taskId, {
  String? taskTitle,
}) async {
  // Shared deletion uses explicit IDs across the entire history and commits
  // durable native alert cancellation; matching titles never select records.
  await ref.read(taskDaoProvider).deleteTask(taskId);
}

Future<void> deleteTodayActivity(
  dynamic ref,
  TodayActivityItem activity,
) async {
  // 1. Mark as dismissed for today so it will never resurrect in today's activities
  await ref
      .read(dismissedTodayActivityIdsProvider.notifier)
      .dismissActivityId(activity.id);

  // Dismissing a lecture never deletes its task, catalog, or timer history.
  if (activity.sourceType == 'lecture' || activity.id.startsWith('lecture_')) {
    final learning = ref.read(learningHubProvider);
    final matches = activity.learningCourseId == null
        ? activity.id == 'lecture_${learning.activeLectureId}'
        : activity.learningCourseId == learning.activeCourseId &&
              activity.learningLectureId == learning.activeLectureId;
    if (matches && learning.isPlaying) {
      ref.read(learningHubProvider.notifier).pause();
    }
    return;
  }

  // 3. If linked to a task, cascade delete
  if (activity.linkedTaskId != null) {
    await deleteTaskAndCleanCascade(
      ref,
      activity.linkedTaskId!,
      taskTitle: activity.title,
    );
  }

  // 4. If linked to a session, delete session from database
  if (activity.linkedSessionId != null) {
    try {
      await ref
          .read(timeSessionDaoProvider)
          .deleteSession(activity.linkedSessionId!);
    } catch (_) {}
  }

  // 5. If it's a standalone session
  if (activity.id.startsWith('session_')) {
    final sId = int.tryParse(activity.id.replaceFirst('session_', ''));
    if (sId != null) {
      try {
        await ref.read(timeSessionDaoProvider).deleteSession(sId);
      } catch (_) {}
    }
  }
}
