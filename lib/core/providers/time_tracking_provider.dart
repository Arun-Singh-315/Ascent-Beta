import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'database_provider.dart';

class TimeTrackingState {
  final TimeSession? activeSession;
  final SessionCategory? activeCategory;
  final int elapsedSeconds;
  final bool isRunning;
  final bool isPaused;

  const TimeTrackingState({
    this.activeSession,
    this.activeCategory,
    this.elapsedSeconds = 0,
    this.isRunning = false,
    this.isPaused = false,
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
    _sessionSubscription = dao.watchActiveSession().listen((session) async {
      if (session == null) {
        _ticker?.cancel();
        _heartbeatTimer?.cancel();
        state = const TimeTrackingState();
        return;
      }

      SessionCategory? category;
      try {
        category = await dao.getCategoryById(session.categoryId);
      } catch (_) {}

      final isRunning = session.status == 'running';
      final isPaused = session.status == 'paused';

      final elapsed = TimeSessionDao.computeActiveDurationSeconds(
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
        _startTicker();
        _startHeartbeat();
      } else {
        _ticker?.cancel();
        _heartbeatTimer?.cancel();
      }
    });

    ref.onDispose(() {
      _sessionSubscription?.cancel();
      _ticker?.cancel();
      _heartbeatTimer?.cancel();
    });

    return const TimeTrackingState();
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

  Future<int> startSession({
    required String label,
    required int categoryId,
    String activityType = 'study',
    int? linkedTaskId,
    String activityRefType = 'task',
  }) async {
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
    final dao = ref.read(timeSessionDaoProvider);
    await dao.resumeSession(session.id);
  }

  /// Switches to a specific task or activity without losing existing state (§3.4).
  /// Pauses current running session and either resumes a previously paused session
  /// for the target task today or starts a new session.
  Future<void> switchToTask({
    required String title,
    int? taskId,
    String sourceType = 'task',
    int? categoryId,
  }) async {
    final dao = ref.read(timeSessionDaoProvider);

    // 1. If current session is running, pause it and flush elapsed duration immediately
    if (state.isRunning && state.activeSession != null) {
      await dao.pauseSession(state.activeSession!.id);
    }

    // 2. Check if the target task already has a paused session today
    if (taskId != null) {
      final paused = await dao.getTodayPausedSessionForTask(taskId);
      if (paused != null) {
        await dao.resumeSession(paused.id);
        return;
      }
    } else {
      final paused = await dao.getTodayPausedSessionByLabel(title);
      if (paused != null) {
        await dao.resumeSession(paused.id);
        return;
      }
    }

    // 3. Resolve category ID
    int targetCatId = categoryId ?? 1;
    if (categoryId == null) {
      final categories = await dao.getAllCategories();
      if (categories.isNotEmpty) {
        if (sourceType.toLowerCase() == 'entertainment' || sourceType.toLowerCase() == 'break') {
          targetCatId = categories.firstWhere(
            (c) => c.name.toLowerCase() == 'entertainment',
            orElse: () => categories.first,
          ).id;
        } else {
          targetCatId = categories.firstWhere(
            (c) => c.name.toLowerCase() == 'study',
            orElse: () => categories.first,
          ).id;
        }
      }
    }

    final activityType = (sourceType.toLowerCase() == 'break' || sourceType.toLowerCase() == 'entertainment')
        ? 'entertainment'
        : 'study';

    // 4. Start fresh write-ahead session for the new task
    await dao.startSession(
      label: title,
      categoryId: targetCatId,
      activityType: activityType,
      linkedTaskId: taskId,
      activityRefType: sourceType,
    );
  }

  Future<void> completeSession() async {
    final session = state.activeSession;
    if (session == null) return;
    _heartbeatTimer?.cancel();
    final dao = ref.read(timeSessionDaoProvider);
    await dao.completeSession(session.id);

    // If linked to a task, mark task completed in Drift as well
    if (session.linkedTaskId != null) {
      try {
        final taskDao = ref.read(taskDaoProvider);
        await taskDao.markComplete(session.linkedTaskId!);
      } catch (_) {}
    }

    ref.invalidate(todayFocusTaskProvider);
    ref.invalidate(homeQuickStatsProvider);
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

final activeSessionCategoriesProvider =
    StreamProvider<List<SessionCategory>>((ref) {
  final dao = ref.watch(timeSessionDaoProvider);
  return dao.watchAllCategories();
});

final todayTimeSessionsProvider =
    StreamProvider.family<List<TimeSession>, DateTime>((ref, date) {
  final dao = ref.watch(timeSessionDaoProvider);
  return dao.watchSessionsForDate(date);
});

// ---------------------------------------------------------------------------
// Unified Today Activities Provider (§2.2, §5.3)
// ---------------------------------------------------------------------------

final todayActivitiesProvider = StreamProvider<List<TodayActivityItem>>((ref) async* {
  final taskDao = ref.watch(taskDaoProvider);
  final sessionDao = ref.watch(timeSessionDaoProvider);
  final timeTracking = ref.watch(timeTrackingProvider);

  final today = DateTime.now();
  final startOfToday = DateTime(today.year, today.month, today.day);

  // Watch both tasks for today and sessions for today
  final tasksStream = taskDao.watchTasksByDate(startOfToday);
  final sessionsStream = sessionDao.watchSessionsForDate(startOfToday);

  await for (final (tasks, sessions) in _combineStreams(tasksStream, sessionsStream)) {
    final List<TodayActivityItem> items = [];
    final Set<int> accountedSessionIds = {};

    // 1. Process tasks planned for today
    for (final task in tasks) {
      final taskSessions = sessions.where((s) => s.linkedTaskId == task.id).toList();
      accountedSessionIds.addAll(taskSessions.map((s) => s.id));

      int taskElapsedSeconds = 0;
      for (final s in taskSessions) {
        if (timeTracking.activeSession?.id == s.id) {
          taskElapsedSeconds += timeTracking.elapsedSeconds;
        } else {
          taskElapsedSeconds += (s.durationSeconds > 0)
              ? s.durationSeconds
              : TimeSessionDao.computeActiveDurationSeconds(
                  s.startedAt,
                  s.endedAt ?? (s.status == 'running' ? DateTime.now() : s.startedAt),
                  s.pausedIntervals,
                );
        }
      }

      TodayActivityStatus status;
      if (timeTracking.activeSession?.linkedTaskId == task.id && timeTracking.isRunning) {
        status = TodayActivityStatus.inProgress;
      } else if (taskSessions.any((s) => s.status == 'paused') ||
          (timeTracking.activeSession?.linkedTaskId == task.id && timeTracking.isPaused)) {
        status = TodayActivityStatus.paused;
      } else if (task.actualCompletedDate != null ||
          (taskSessions.isNotEmpty && taskSessions.every((s) => s.status == 'completed'))) {
        status = TodayActivityStatus.done;
      } else {
        status = TodayActivityStatus.notStarted;
      }

      String categoryTag = 'Task';
      if (task.priority == 'high') {
        categoryTag = 'High Priority';
      }

      items.add(TodayActivityItem(
        id: 'task_${task.id}',
        title: task.title,
        sourceType: 'task',
        status: status,
        elapsedSecondsToday: taskElapsedSeconds,
        linkedTaskId: task.id,
        linkedSessionId: taskSessions.isNotEmpty ? taskSessions.first.id : null,
        categoryTag: categoryTag,
        priority: task.priority,
      ));
    }

    // 2. Process standalone sessions not already accounted for by today's tasks
    for (final session in sessions) {
      if (accountedSessionIds.contains(session.id)) continue;

      int elapsed;
      if (timeTracking.activeSession?.id == session.id) {
        elapsed = timeTracking.elapsedSeconds;
      } else {
        elapsed = (session.durationSeconds > 0)
            ? session.durationSeconds
            : TimeSessionDao.computeActiveDurationSeconds(
                session.startedAt,
                session.endedAt ?? (session.status == 'running' ? DateTime.now() : session.startedAt),
                session.pausedIntervals,
              );
      }

      TodayActivityStatus status;
      if (timeTracking.activeSession?.id == session.id && timeTracking.isRunning) {
        status = TodayActivityStatus.inProgress;
      } else if (session.status == 'paused' ||
          (timeTracking.activeSession?.id == session.id && timeTracking.isPaused)) {
        status = TodayActivityStatus.paused;
      } else if (session.status == 'completed') {
        status = TodayActivityStatus.done;
      } else {
        status = TodayActivityStatus.notStarted;
      }

      String categoryTag = session.activityType == 'entertainment' ? 'Break' : 'Study';

      items.add(TodayActivityItem(
        id: 'session_${session.id}',
        title: session.label,
        sourceType: session.activityRefType,
        status: status,
        elapsedSecondsToday: elapsed,
        linkedTaskId: session.linkedTaskId,
        linkedSessionId: session.id,
        categoryTag: categoryTag,
      ));
    }

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

Stream<(T1, T2)> _combineStreams<T1, T2>(Stream<T1> s1, Stream<T2> s2) {
  late StreamController<(T1, T2)> controller;
  T1? val1;
  T2? val2;
  bool hasVal1 = false;
  bool hasVal2 = false;
  StreamSubscription<T1>? sub1;
  StreamSubscription<T2>? sub2;

  controller = StreamController<(T1, T2)>(
    onListen: () {
      sub1 = s1.listen(
        (data) {
          val1 = data;
          hasVal1 = true;
          if (hasVal2) controller.add((val1 as T1, val2 as T2));
        },
        onError: controller.addError,
      );
      sub2 = s2.listen(
        (data) {
          val2 = data;
          hasVal2 = true;
          if (hasVal1) controller.add((val1 as T1, val2 as T2));
        },
        onError: controller.addError,
      );
    },
    onCancel: () async {
      await sub1?.cancel();
      await sub2?.cancel();
    },
  );

  return controller.stream;
}
