part of '../app_database.dart';

class _DeletedTaskTree {
  _DeletedTaskTree(this.tasks, this.reminders, this.links, this.sessions);
  final List<Task> tasks;
  final List<Reminder> reminders;
  final List<ThoughtReminderLink> links;
  final List<TimeSession> sessions;
}

@DriftAccessor(tables: [TaskTable])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);
  final _deletedTrees = <int, _DeletedTaskTree>{};
  void clearDeletionUndo() => _deletedTrees.clear();

  // ---------------------------------------------------------------------------
  // Watch helpers
  // ---------------------------------------------------------------------------

  /// Stream of all tasks ordered by plannedDate asc, then createdAt asc.
  Stream<List<Task>> watchAllTasks() =>
      (select(taskTable)..orderBy([
            (t) => OrderingTerm.asc(t.plannedDate),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
          .watch();

  /// Stream of tasks for today.
  Stream<List<Task>> watchTodayTasks() => watchTasksByDate(DateTime.now());

  /// Stream of tasks whose [plannedDate] falls on [date] (same calendar day).
  Stream<List<Task>> watchTasksByDate(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    return (select(taskTable)
          ..where(
            (t) =>
                t.plannedDate.isBiggerOrEqualValue(dayStart) &
                t.plannedDate.isSmallerThanValue(dayEnd),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Stream of tasks that are overdue:
  /// plannedDate is before today AND actualCompletedDate IS NULL.
  Stream<List<Task>> watchOverdueTasks() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return (select(taskTable)
          ..where(
            (t) =>
                t.plannedDate.isSmallerThanValue(todayStart) &
                t.actualCompletedDate.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.plannedDate)]))
        .watch();
  }

  /// Stream of incomplete tasks due within the next [days] calendar days.
  Stream<List<Task>> watchUpcomingTasks(int days) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final windowEnd = todayStart.add(Duration(days: days));
    return (select(taskTable)
          ..where(
            (t) =>
                t.plannedDate.isBiggerOrEqualValue(todayStart) &
                t.plannedDate.isSmallerThanValue(windowEnd) &
                t.actualCompletedDate.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.plannedDate)]))
        .watch();
  }

  /// Stream of tasks belonging to [seriesId], ordered by seriesItemIndex asc.
  Stream<List<Task>> watchTasksBySeries(int seriesId) =>
      (select(taskTable)
            ..where((t) => t.seriesId.equals(seriesId))
            ..orderBy([(t) => OrderingTerm.asc(t.seriesItemIndex)]))
          .watch();

  /// Stream of tasks linked to a study phase, ordered by plannedDate.
  Stream<List<Task>> watchTasksForPhase(int phaseId) =>
      (select(taskTable)
            ..where((t) => t.linkedPhaseId.equals(phaseId))
            ..orderBy([(t) => OrderingTerm.asc(t.plannedDate)]))
          .watch();

  /// Stream of tasks linked to an application, ordered by plannedDate.
  Stream<List<Task>> watchTasksForApplication(int applicationId) =>
      (select(taskTable)
            ..where((t) => t.linkedApplicationId.equals(applicationId))
            ..orderBy([
              (t) => OrderingTerm.asc(t.actualCompletedDate),
              (t) => OrderingTerm.asc(t.plannedDate),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch();

  // ---------------------------------------------------------------------------
  // Single-fetch queries
  // ---------------------------------------------------------------------------

  /// Returns the task with the given [id], or null if it doesn't exist.
  Future<Task?> getTaskById(int id) =>
      (select(taskTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Returns the Todo created for a Thought Wall Promise, if it still exists.
  Future<Task?> getTaskLinkedToThought(int thoughtId) => (select(
    taskTable,
  )..where((t) => t.linkedThoughtId.equals(thoughtId))).getSingleOrNull();

  /// Returns the task with the highest [seriesItemIndex] in [seriesId].
  /// Useful when auto-generating the next item in a series.
  Future<Task?> getLastSeriesItem(int seriesId) =>
      (select(taskTable)
            ..where((t) => t.seriesId.equals(seriesId))
            ..orderBy([(t) => OrderingTerm.desc(t.seriesItemIndex)])
            ..limit(1))
          .getSingleOrNull();

  /// Count of completed tasks (actualCompletedDate IS NOT NULL) for [phaseId].
  Future<int> getCompletedTaskCountForPhase(int phaseId) async {
    final count = taskTable.id.count();
    final query = selectOnly(taskTable)
      ..addColumns([count])
      ..where(
        taskTable.linkedPhaseId.equals(phaseId) &
            taskTable.actualCompletedDate.isNotNull(),
      );
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  /// Total task count for [phaseId] (completed + incomplete).
  Future<int> getTotalTaskCountForPhase(int phaseId) async {
    final count = taskTable.id.count();
    final query = selectOnly(taskTable)
      ..addColumns([count])
      ..where(taskTable.linkedPhaseId.equals(phaseId));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Inserts a new task and returns the generated id.
  Future<int> insertTask(TaskTableCompanion companion) async {
    if (!companion.linkedThoughtId.present) {
      final markers = RegExp(
        r'(?:^|[ •])thought_id:(\d+)(?=\s|•|$)',
      ).allMatches(companion.notes.value ?? '').toList();
      if (markers.length == 1) {
        final id = int.parse(markers.single.group(1)!);
        if (await db.thoughtDao.getThoughtById(id) != null &&
            await getTaskLinkedToThought(id) == null) {
          companion = companion.copyWith(linkedThoughtId: Value(id));
        }
      }
    }
    return into(taskTable).insert(companion);
  }

  /// Type/target edits cannot mutate live timers or rewrite completed work.
  Future<String?> activityTypeChangeError(int id, int? minutes) async {
    final task = await getTaskById(id);
    if (task == null) return 'This activity no longer exists.';
    if (task.estimatedMinutes == minutes) return null;
    if (minutes != null && minutes != -1 && (minutes < 1 || minutes > 1440)) {
      return 'Choose a timer from 1 to 1440 minutes.';
    }
    if (task.actualCompletedDate != null) {
      return 'Completed activities keep their original type.';
    }
    if (task.learningCourseId != null || task.learningLectureId != null) {
      return 'Course lectures keep their learning timer. Edit them in Learning.';
    }
    final sessions = await (select(
      db.timeSessionTable,
    )..where((s) => s.linkedTaskId.equals(id))).get();
    if (sessions.any((s) => s.status == 'running' || s.status == 'paused')) {
      return 'End the running or paused timer before changing its type or target.';
    }
    if (minutes != null && minutes > 0) {
      final logged = sessions
          .where((s) => s.status == 'completed')
          .fold<int>(0, (sum, s) => sum + s.durationSeconds);
      if (minutes * 60 <= logged || minutes <= (task.actualMinutes ?? 0)) {
        return 'Choose a timer longer than the time already logged.';
      }
    }
    return null;
  }

  /// Updates the task identified by [companion.id].
  /// Returns true if exactly one row was affected.
  Future<bool> updateTask(TaskTableCompanion companion) async {
    if (!companion.id.present) return false;
    return db.transaction(() async {
      final task = await getTaskById(companion.id.value);
      if (task == null) return false;
      if (companion.estimatedMinutes.present &&
          await activityTypeChangeError(
                task.id,
                companion.estimatedMinutes.value,
              ) !=
              null) {
        return false;
      }
      if (companion.actualCompletedDate.present) {
        if (companion.actualCompletedDate.value == null) {
          if (task.actualCompletedDate != null) return false;
        } else {
          // A field edit cannot remove the duration requirement and complete
          // the same task, or bypass an unfinished checklist.
          if (task.learningCourseId != null ||
              _isTimeBound(task) ||
              (companion.estimatedMinutes.present &&
                  (companion.estimatedMinutes.value ?? 0) > 0)) {
            return false;
          }
          final children = await (select(
            taskTable,
          )..where((t) => t.parentTaskId.equals(task.id))).get();
          if (children.any((t) => t.actualCompletedDate == null)) return false;
          if (task.actualCompletedDate == null) await _writeCompletedTask(task);
          companion = companion.copyWith(
            actualCompletedDate: const Value.absent(),
          );
        }
      }
      final rowsAffected = await (update(
        taskTable,
      )..where((t) => t.id.equals(companion.id.value))).write(companion);
      return rowsAffected == 1;
    });
  }

  bool _isTimeBound(Task task) =>
      task.estimatedMinutes != null && task.estimatedMinutes! > 0;

  /// Marks a task as complete by setting [actualCompletedDate] and
  /// [updatedAt] to the current time, and cascades completion to linked thoughts.
  Future<bool> markComplete(int id) => db.transaction(() async {
    final task = await getTaskById(id);
    if (task == null || task.learningCourseId != null || _isTimeBound(task)) {
      return false;
    }
    final children = await (select(
      taskTable,
    )..where((t) => t.parentTaskId.equals(id))).get();
    if (children.any((t) => t.actualCompletedDate == null)) return false;
    if (task.actualCompletedDate != null) return true;
    await _writeCompletedTask(task);
    return true;
  });

  /// Completes a timed task only when its required focus duration has elapsed.
  Future<bool> completeTimedTaskAfterFocus(int id) => db.transaction(() async {
    final task = await getTaskById(id);
    final targetMinutes = task?.estimatedMinutes;
    if (task == null ||
        task.learningCourseId != null ||
        targetMinutes == null ||
        targetMinutes <= 0) {
      return false;
    }
    final completedSessions =
        await (db.select(db.timeSessionTable)..where(
              (session) =>
                  session.linkedTaskId.equals(id) &
                  session.status.equals('completed'),
            ))
            .get();
    final loggedSeconds = completedSessions.fold<int>(
      0,
      (total, session) => total + session.durationSeconds,
    );
    if (loggedSeconds < targetMinutes * 60) return false;
    if (task.actualCompletedDate != null) return true;
    final children = await (select(
      taskTable,
    )..where((t) => t.parentTaskId.equals(id))).get();
    if (children.any((t) => t.actualCompletedDate == null)) return false;
    await _writeCompletedTask(task);
    return true;
  });

  /// The catalog is the only source of eligibility for a converted lecture.
  Future<bool> completeTaskForLecture(int id) => db.transaction(() async {
    final task = await getTaskById(id);
    if (task == null ||
        task.learningCourseId == null ||
        task.learningLectureId == null) {
      return false;
    }
    if (task.actualCompletedDate != null) return true;
    final course = await db.courseDao.getCourseById(task.learningCourseId!);
    if (course == null) return false;
    final modules = jsonDecode(course.modulesJson) as List;
    Map? lecture;
    for (final module in modules) {
      for (final value in (module as Map)['lectures'] as List) {
        if ((value as Map)['id'] == task.learningLectureId) lecture = value;
      }
    }
    if (lecture == null || lecture['isCompleted'] != true) return false;
    final duration = (lecture['durationSeconds'] as num?)?.toInt() ?? 0;
    final study = (lecture['studySeconds'] as num?)?.toInt() ?? 0;
    final threshold = lecture['completionThresholdPercent'] == 50 ? 50 : 100;
    if (duration <= 0 || study < (duration * threshold / 100).ceil()) {
      return false;
    }
    final children = await (select(
      taskTable,
    )..where((t) => t.parentTaskId.equals(id))).get();
    if (children.any((t) => t.actualCompletedDate == null)) return false;
    await _writeCompletedTask(task);
    return true;
  });

  Future<void> _writeCompletedTask(Task task) async {
    final id = task.id;
    final now = DateTime.now();
    await (update(taskTable)..where((t) => t.id.equals(id))).write(
      TaskTableCompanion(
        actualCompletedDate: Value(now),
        updatedAt: Value(now),
      ),
    );

    if (task.linkedThoughtId != null) {
      await db.thoughtDao.setCompleted(task.linkedThoughtId!, true);
    }
    await db.medicineDao.syncDoseFromTask(id, true);

    // Completing a task ends its linked reminder schedule, including promise
    // reminders, so a fulfilled commitment cannot keep generating alerts.
    final reminders = await db.reminderDao.getRemindersByTaskId(id);
    if (reminders.isNotEmpty) {
      await (db.update(
        db.reminderTable,
      )..where((r) => r.linkedTaskId.equals(id))).write(
        const ReminderTableCompanion(
          isActive: Value(false),
          alertSyncPending: Value(true),
        ),
      );
    }
  }

  /// Completed tasks stay sealed; use the explicit medicine-dose sync method
  /// for the linked medical task lifecycle.
  Future<bool> markIncomplete(int id) async {
    final task = await getTaskById(id);
    if (task == null || task.actualCompletedDate != null) return false;
    await _writeIncompleteTask(task);
    return true;
  }

  /// Synchronizes a task from its linked medicine dose.
  Future<bool> syncCompletionFromMedicineDose(
    int id, {
    required bool completed,
  }) async {
    final linkedDose = await (db.select(
      db.medicineLogTable,
    )..where((dose) => dose.linkedTaskId.equals(id))).getSingleOrNull();
    final task = await getTaskById(id);
    if (task?.learningCourseId != null) return false;
    if (linkedDose == null || task == null || linkedDose.isTaken != completed) {
      return false;
    }

    if (completed) {
      if (_isTimeBound(task)) return false;
      final children = await (select(
        taskTable,
      )..where((t) => t.parentTaskId.equals(id))).get();
      if (children.any((t) => t.actualCompletedDate == null)) return false;
      await _writeCompletedTask(task);
    } else {
      await _writeIncompleteTask(task);
    }
    return true;
  }

  Future<void> _writeIncompleteTask(Task task) async {
    final id = task.id;
    await (update(taskTable)..where((t) => t.id.equals(id))).write(
      TaskTableCompanion(
        actualCompletedDate: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );

    if (task.linkedThoughtId != null) {
      await db.thoughtDao.setCompleted(task.linkedThoughtId!, false);
    }
  }

  /// Toggles the [revisitFlag] on a task.
  Future<void> toggleRevisit(int id) async {
    final task = await getTaskById(id);
    if (task == null) return;
    await (update(taskTable)..where((t) => t.id.equals(id))).write(
      TaskTableCompanion(revisitFlag: Value(!task.revisitFlag)),
    );
  }

  /// Updates [lastInteractedAt] for freshness tracking by the Insight Engine.
  Future<void> touchLastInteracted(int id) async {
    await (update(taskTable)..where((t) => t.id.equals(id))).write(
      TaskTableCompanion(lastInteractedAt: Value(DateTime.now())),
    );
  }

  /// Toggles task completion.
  Future<void> toggleTaskCompletion(int id, bool completed) => db.transaction(
    () async {
      final task = await getTaskById(id);
      if (task == null) return;
      final dose = await (db.select(
        db.medicineLogTable,
      )..where((d) => d.linkedTaskId.equals(id))).getSingleOrNull();
      if (dose != null) {
        // Dose correction is the existing explicit exception to sticky generic
        // completion. A timed/lecture task never acquires that exception.
        if (_isTimeBound(task) || task.learningCourseId != null) return;
        final children = await (select(
          taskTable,
        )..where((t) => t.parentTaskId.equals(id))).get();
        if (completed && children.any((t) => t.actualCompletedDate == null)) {
          return;
        }
        await db.medicineDao.syncDoseFromTask(id, completed);
        if (!await syncCompletionFromMedicineDose(id, completed: completed)) {
          throw StateError('Dose completion could not be synchronized');
        }
      } else if (completed) {
        await markComplete(id);
      } else {
        await markIncomplete(id);
      }
    },
  );

  /// Deletes the task with [id].  Returns the number of deleted rows (0 or 1).
  Future<int> deleteTask(int id) => db.transaction(() async {
    if (await getTaskById(id) == null) return 0;
    await deleteTaskWithDependents(id);
    return 1;
  });

  /// All descendants, linked reminders and sessions are removed atomically.
  /// Reminder deletion records durable native cancellation work in this commit.
  Future<List<int>> deleteTaskWithDependents(int id) =>
      db.transaction(() async {
        final cancelled = <int>[];
        final captured = _DeletedTaskTree([], [], [], []);
        final visiting = <int>{};
        Future<void> remove(int current) async {
          if (!visiting.add(current)) {
            throw StateError(
              'A cyclic task relationship needs repair before deletion',
            );
          }
          final task = await getTaskById(current);
          if (task == null) return;
          final children = await (select(
            taskTable,
          )..where((t) => t.parentTaskId.equals(current))).get();
          for (final child in children) {
            await remove(child.id);
          }
          final reminders = await db.reminderDao.getRemindersByTaskId(current);
          captured.tasks.add(task);
          captured.reminders.addAll(reminders);
          for (final reminder in reminders) {
            captured.links.addAll(
              await (db.select(
                db.thoughtReminderLinkTable,
              )..where((l) => l.reminderId.equals(reminder.id))).get(),
            );
          }
          captured.sessions.addAll(
            await (db.select(
              db.timeSessionTable,
            )..where((s) => s.linkedTaskId.equals(current))).get(),
          );
          cancelled.addAll(reminders.map((r) => r.id));
          await db.reminderDao.deleteRemindersByTaskId(current);
          await (db.delete(
            db.timeSessionTable,
          )..where((s) => s.linkedTaskId.equals(current))).go();
          await (delete(taskTable)..where((t) => t.id.equals(current))).go();
        }

        await remove(id);
        if (captured.tasks.isNotEmpty) {
          _deletedTrees[id] = captured;
          if (_deletedTrees.length > 20) {
            _deletedTrees.remove(_deletedTrees.keys.first);
          }
        }
        return cancelled;
      });
  Future<bool> restoreDeletedTask(int id) => db.transaction(() async {
    final snapshot = _deletedTrees[id];
    if (snapshot == null) return false;
    for (final task in snapshot.tasks) {
      if (await getTaskById(task.id) != null) return false;
    }
    for (final reminder in snapshot.reminders) {
      if (await db.reminderDao.getReminderById(reminder.id) != null) {
        return false;
      }
    }
    for (final session in snapshot.sessions) {
      if (await (db.select(
            db.timeSessionTable,
          )..where((s) => s.id.equals(session.id))).getSingleOrNull() !=
          null) {
        return false;
      }
    }
    final ids = snapshot.tasks.map((t) => t.id).toSet();
    for (final task in snapshot.tasks.reversed) {
      final sourceExists =
          task.linkedThoughtId == null ||
          await db.thoughtDao.getThoughtById(task.linkedThoughtId!) != null &&
              await getTaskLinkedToThought(task.linkedThoughtId!) == null;
      final parentExists =
          task.parentTaskId == null ||
          ids.contains(task.parentTaskId) ||
          await getTaskById(task.parentTaskId!) != null;
      await into(taskTable).insert(
        task
            .toCompanion(true)
            .copyWith(
              linkedThoughtId: sourceExists
                  ? Value(task.linkedThoughtId)
                  : const Value(null),
              parentTaskId: parentExists
                  ? Value(task.parentTaskId)
                  : const Value(null),
            ),
      );
    }
    for (final reminder in snapshot.reminders) {
      final task = reminder.linkedTaskId == null
          ? null
          : await getTaskById(reminder.linkedTaskId!);
      await db
          .into(db.reminderTable)
          .insert(
            reminder
                .toCompanion(true)
                .copyWith(
                  isActive: Value(
                    reminder.isActive && task?.actualCompletedDate == null,
                  ),
                  alertSyncPending: const Value(true),
                ),
          );
    }
    for (final link in snapshot.links) {
      if (await db.thoughtDao.getThoughtById(link.thoughtId) != null) {
        await db
            .into(db.thoughtReminderLinkTable)
            .insert(link.toCompanion(true));
      }
    }
    for (final session in snapshot.sessions) {
      var restored = session.toCompanion(true);
      if (session.status == 'running') {
        final intervals = jsonDecode(session.pausedIntervals) as List;
        var pausedSeconds = 0;
        for (final interval in intervals) {
          final start = DateTime.tryParse(
            interval['pausedAt']?.toString() ?? '',
          );
          final end = DateTime.tryParse(
            interval['resumedAt']?.toString() ?? '',
          );
          if (start != null && end != null && end.isAfter(start)) {
            pausedSeconds += end.difference(start).inSeconds;
          }
        }
        final boundary = session.startedAt.add(
          Duration(seconds: session.durationSeconds + pausedSeconds),
        );
        intervals.add({
          'pausedAt': boundary.toIso8601String(),
          'resumedAt': null,
        });
        restored = restored.copyWith(
          status: const Value('paused'),
          pausedIntervals: Value(jsonEncode(intervals)),
        );
      }
      await db.into(db.timeSessionTable).insert(restored);
    }
    _deletedTrees.remove(id);
    return true;
  });
}
