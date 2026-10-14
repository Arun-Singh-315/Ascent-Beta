part of '../app_database.dart';

@DriftAccessor(
  tables: [
    TimeSessionTable,
    SessionCategoryTable,
    ConsistencyLogTable,
    TaskTable,
  ],
)
class TimeSessionDao extends DatabaseAccessor<AppDatabase>
    with _$TimeSessionDaoMixin {
  TimeSessionDao(super.db);

  // ── Categories ─────────────────────────────────────────────────────────────

  Stream<List<SessionCategory>> watchAllCategories() {
    return select(sessionCategoryTable).watch();
  }

  Future<List<SessionCategory>> getAllCategories() {
    return select(sessionCategoryTable).get();
  }

  Future<SessionCategory?> getCategoryById(int id) {
    return (select(
      sessionCategoryTable,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
  }

  Future<SessionCategory?> getCategoryByName(String name) {
    return (select(
      sessionCategoryTable,
    )..where((c) => c.name.equals(name))).getSingleOrNull();
  }

  Future<int> insertCategory(SessionCategoryTableCompanion category) {
    return into(sessionCategoryTable).insert(category);
  }

  Future<void> ensureDefaultCategories() async {
    final existing = await getAllCategories();
    if (existing.isEmpty) {
      await into(sessionCategoryTable).insert(
        SessionCategoryTableCompanion.insert(
          name: 'Study',
          colorHex: '#5FA070',
          isBuiltIn: const Value(true),
        ),
      );
      await into(sessionCategoryTable).insert(
        SessionCategoryTableCompanion.insert(
          name: 'Entertainment',
          colorHex: '#F2954F',
          isBuiltIn: const Value(true),
        ),
      );
    }
  }

  // ── Active Sessions ────────────────────────────────────────────────────────

  Stream<TimeSession?> watchActiveSession() {
    return (select(timeSessionTable)
          ..where((s) => s.status.isIn(['running', 'paused']))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Watch active focus sessions (excluding lectures to maintain strict module independence)
  Stream<TimeSession?> watchActiveFocusSession() {
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.status.isIn(['running', 'paused']) &
                s.activityRefType.isNotValue('lecture') &
                s.learningCourseId.isNull(),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<TimeSession?> getActiveSession() {
    return (select(timeSessionTable)
          ..where((s) => s.status.isIn(['running', 'paused']))
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get active focus session (excluding lectures)
  Future<TimeSession?> getActiveFocusSession() {
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.status.isIn(['running', 'paused']) &
                s.activityRefType.isNotValue('lecture') &
                s.learningCourseId.isNull(),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Get active lecture session
  Future<TimeSession?> getActiveLectureSession() {
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.status.isIn(['running', 'paused']) &
                s.activityRefType.equals('lecture'),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  // ── Date queries ───────────────────────────────────────────────────────────

  Stream<List<TimeSession>> watchSessionsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.startedAt.isBiggerOrEqualValue(start) &
                s.startedAt.isSmallerThanValue(end),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .watch();
  }

  Future<List<TimeSession>> getSessionsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.startedAt.isBiggerOrEqualValue(start) &
                s.startedAt.isSmallerThanValue(end),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)]))
        .get();
  }

  Stream<List<TimeSession>> watchSessionsBetween(DateTime start, DateTime end) {
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.startedAt.isBiggerOrEqualValue(start) &
                s.startedAt.isSmallerThanValue(end),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.startedAt)]))
        .watch();
  }

  Future<List<TimeSession>> getSessionsBetween(DateTime start, DateTime end) {
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.startedAt.isBiggerOrEqualValue(start) &
                s.startedAt.isSmallerThanValue(end),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.startedAt)]))
        .get();
  }

  /// Watches completed Focus records for the one Activity selected by a Challenge.
  Stream<List<TimeSession>> watchCompletedSessionsForTask(
    int taskId,
    DateTime start,
    DateTime end,
  ) {
    return (select(timeSessionTable)
          ..where(
            (session) =>
                session.linkedTaskId.equals(taskId) &
                session.status.equals('completed') &
                session.startedAt.isBiggerOrEqualValue(start) &
                session.startedAt.isSmallerThanValue(end),
          )
          ..orderBy([(session) => OrderingTerm.asc(session.startedAt)]))
        .watch();
  }

  // ── Mutations ──────────────────────────────────────────────────────────────

  Future<int> startSession({
    required String label,
    required int categoryId,
    String activityType = 'study',
    int? linkedTaskId,
    String activityRefType = 'task',
    String? learningCourseId,
    int? learningLectureId,
    DateTime? startedAt,
  }) {
    final now = startedAt ?? DateTime.now();
    return into(timeSessionTable).insert(
      TimeSessionTableCompanion.insert(
        label: label,
        categoryId: categoryId,
        activityType: Value(activityType),
        linkedTaskId: Value(linkedTaskId),
        activityRefType: Value(activityRefType),
        learningCourseId: Value(learningCourseId),
        learningLectureId: Value(learningLectureId),
        startedAt: now,
        status: const Value('running'),
        durationSeconds: const Value(0),
        lastHeartbeatAt: Value(now),
      ),
    );
  }

  Future<void> pauseSession(int id) async {
    final session = await (select(
      timeSessionTable,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (session == null || session.status != 'running') return;

    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    List<dynamic> intervals = [];
    try {
      intervals = jsonDecode(session.pausedIntervals) as List<dynamic>;
    } catch (_) {
      intervals = [];
    }
    intervals.add({'pausedAt': nowStr, 'resumedAt': null});

    final currentDuration = computeActiveDurationSeconds(
      session.startedAt,
      now,
      jsonEncode(intervals),
    );

    await (update(timeSessionTable)..where((s) => s.id.equals(id))).write(
      TimeSessionTableCompanion(
        status: const Value('paused'),
        pausedIntervals: Value(jsonEncode(intervals)),
        durationSeconds: Value(
          session.learningCourseId != null
              ? session.durationSeconds
              : currentDuration,
        ),
        lastHeartbeatAt: Value(now),
      ),
    );
  }

  Future<void> resumeSession(int id) async {
    final session = await (select(
      timeSessionTable,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (session == null || session.status != 'paused') return;

    final now = DateTime.now();
    final nowStr = now.toIso8601String();
    List<dynamic> intervals = [];
    try {
      intervals = jsonDecode(session.pausedIntervals) as List<dynamic>;
    } catch (_) {
      intervals = [];
    }
    if (intervals.isNotEmpty && intervals.last['resumedAt'] == null) {
      intervals.last['resumedAt'] = nowStr;
    }

    await (update(timeSessionTable)..where((s) => s.id.equals(id))).write(
      TimeSessionTableCompanion(
        status: const Value('running'),
        pausedIntervals: Value(jsonEncode(intervals)),
        lastHeartbeatAt: Value(now),
      ),
    );
  }

  /// Periodic heartbeat to flush elapsed duration to SQLite (write-ahead continuity).
  Future<void> heartbeat(int id, int activeDurationSeconds) async {
    await (update(timeSessionTable)..where((s) => s.id.equals(id))).write(
      TimeSessionTableCompanion(
        durationSeconds: Value(activeDurationSeconds),
        lastHeartbeatAt: Value(DateTime.now()),
      ),
    );
  }

  /// Finds a running or paused session from today for a given task ID.
  Future<TimeSession?> getTodayActiveOrPausedSessionForTask(int taskId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.linkedTaskId.equals(taskId) &
                s.status.isIn(['running', 'paused']) &
                s.startedAt.isBiggerOrEqualValue(startOfToday),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Finds a paused session from today for a given task ID.
  Future<TimeSession?> getTodayPausedSessionForTask(int taskId) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.linkedTaskId.equals(taskId) &
                s.status.equals('paused') &
                s.startedAt.isBiggerOrEqualValue(startOfToday),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Finds a running or paused session from today with a given label.
  Future<TimeSession?> getTodayActiveOrPausedSessionByLabel(
    String label,
  ) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.label.equals(label) &
                s.status.isIn(['running', 'paused']) &
                s.startedAt.isBiggerOrEqualValue(startOfToday),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Finds a paused session from today with a given label.
  Future<TimeSession?> getTodayPausedSessionByLabel(String label) async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return (select(timeSessionTable)
          ..where(
            (s) =>
                s.label.equals(label) &
                s.status.equals('paused') &
                s.startedAt.isBiggerOrEqualValue(startOfToday),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Ends only a running generic timed-task session whose recorded active
  /// duration, including earlier completed sessions, reaches the current target.
  Future<bool> completeTimedSessionIfTargetReached(
    int id, {
    DateTime? now,
    int? expectedWorkspaceRevision,
  }) => db.transaction(() async {
    if (expectedWorkspaceRevision != null &&
        expectedWorkspaceRevision != db.workspaceRevision) {
      return false;
    }
    final session = await (select(
      timeSessionTable,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (session == null ||
        session.status != 'running' ||
        session.linkedTaskId == null ||
        session.learningCourseId != null) {
      return false;
    }
    final task = await db.taskDao.getTaskById(session.linkedTaskId!);
    if (task == null ||
        task.learningCourseId != null ||
        (task.estimatedMinutes ?? 0) <= 0) {
      return false;
    }
    // A timer reaching its target is not evidence that a medicine was taken.
    final dose =
        await (db.select(db.medicineLogTable)
              ..where((l) => l.linkedTaskId.equals(task.id))
              ..limit(1))
            .getSingleOrNull();
    if (dose != null) return false;
    final total = timeSessionTable.durationSeconds.sum();
    final history =
        await (selectOnly(timeSessionTable)
              ..addColumns([total])
              ..where(
                timeSessionTable.linkedTaskId.equals(task.id) &
                    timeSessionTable.status.equals('completed'),
              ))
            .getSingle();
    final end = now ?? DateTime.now();
    final elapsed = computeActiveDurationSeconds(
      session.startedAt,
      end,
      session.pausedIntervals,
    );
    final recorded = history.read(total) ?? 0;
    if (recorded + elapsed < task.estimatedMinutes! * 60) return false;
    await completeSession(id, endedAt: end);
    await db.taskDao.completeTimedTaskAfterFocus(task.id);
    return true;
  });

  Future<void> completeSession(
    int id, {
    DateTime? endedAt,
  }) => db.transaction(() async {
    final session = await (select(
      timeSessionTable,
    )..where((s) => s.id.equals(id))).getSingleOrNull();
    if (session == null || session.status == 'completed') return;

    final end = endedAt ?? DateTime.now();

    // Close any open pause interval
    List<dynamic> intervals = [];
    try {
      intervals = jsonDecode(session.pausedIntervals) as List<dynamic>;
    } catch (_) {
      intervals = [];
    }
    if (intervals.isNotEmpty && intervals.last['resumedAt'] == null) {
      intervals.last['resumedAt'] = end.toIso8601String();
    }

    // Calculate active duration in minutes and hours
    final durationSeconds = session.learningCourseId != null
        ? session.durationSeconds
        : computeActiveDurationSeconds(
            session.startedAt,
            end,
            jsonEncode(intervals),
          );
    final activeMinutes = (durationSeconds / 60).round();

    await (update(timeSessionTable)..where((s) => s.id.equals(id))).write(
      TimeSessionTableCompanion(
        endedAt: Value(end),
        status: const Value('completed'),
        pausedIntervals: Value(jsonEncode(intervals)),
        durationSeconds: Value(durationSeconds),
        lastHeartbeatAt: Value(end),
      ),
    );
    final activeHours = durationSeconds / 3600.0;

    // 1. If linked to a task, update task's actualMinutes
    if (session.linkedTaskId != null) {
      final task = await (select(
        taskTable,
      )..where((t) => t.id.equals(session.linkedTaskId!))).getSingleOrNull();
      if (task != null) {
        final previous = task.actualMinutes ?? 0;
        await (update(taskTable)..where((t) => t.id.equals(task.id))).write(
          TaskTableCompanion(
            actualMinutes: Value(previous + activeMinutes),
            lastInteractedAt: Value(end),
          ),
        );
      }
    }

    // 2. If session category is Study, automatically write to consistency_logs
    final category = await getCategoryById(session.categoryId);
    final isStudy =
        category?.name.toLowerCase() == 'study' ||
        session.activityType.toLowerCase() == 'study';
    if (isStudy) {
      // Recompute total study hours for today
      final todaySessions = await getSessionsForDate(session.startedAt);
      double totalStudyHours = 0.0;
      for (final s in todaySessions) {
        final sCategory = await getCategoryById(s.categoryId);
        final sIsStudy =
            sCategory?.name.toLowerCase() == 'study' ||
            s.activityType.toLowerCase() == 'study';
        if (sIsStudy && s.status == 'completed') {
          final sDuration = s.durationSeconds;
          totalStudyHours += (sDuration / 3600.0);
        }
      }
      if (totalStudyHours == 0.0) {
        totalStudyHours = activeHours;
      }

      await db.consistencyDao.logDay(
        session.startedAt,
        true,
        hoursStudied: totalStudyHours,
      );
    }
  });

  Future<void> abandonSession(int id) async {
    await (update(timeSessionTable)..where((s) => s.id.equals(id))).write(
      TimeSessionTableCompanion(
        endedAt: Value(DateTime.now()),
        status: const Value('abandoned'),
      ),
    );
  }

  Future<void> deleteSession(int id) {
    return (delete(timeSessionTable)..where((s) => s.id.equals(id))).go();
  }

  static int computeActiveDurationSeconds(
    DateTime startedAt,
    DateTime endedAt,
    String pausedIntervalsJson,
  ) {
    int total = endedAt.difference(startedAt).inSeconds;
    try {
      final List<dynamic> intervals =
          jsonDecode(pausedIntervalsJson) as List<dynamic>;
      int pausedTotal = 0;
      for (final item in intervals) {
        if (item is Map) {
          final pAt = DateTime.tryParse(item['pausedAt']?.toString() ?? '');
          final rAt =
              DateTime.tryParse(item['resumedAt']?.toString() ?? '') ?? endedAt;
          if (pAt != null) {
            pausedTotal += rAt.difference(pAt).inSeconds;
          }
        }
      }
      total -= pausedTotal;
    } catch (_) {}
    return total < 0 ? 0 : total;
  }
}
