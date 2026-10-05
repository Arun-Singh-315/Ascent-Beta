part of '../app_database.dart';

@DriftAccessor(tables: [TaskTable])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  // ---------------------------------------------------------------------------
  // Watch helpers
  // ---------------------------------------------------------------------------

  /// Stream of all tasks ordered by plannedDate asc, then createdAt asc.
  Stream<List<Task>> watchAllTasks() =>
      (select(taskTable)
            ..orderBy([
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
  Future<int> insertTask(TaskTableCompanion companion) =>
      into(taskTable).insert(companion);

  /// Updates the task identified by [companion.id].
  /// Returns true if exactly one row was affected.
  Future<bool> updateTask(TaskTableCompanion companion) async {
    final rowsAffected = await (update(taskTable)
          ..where((t) => t.id.equals(companion.id.value)))
        .write(companion);
    return rowsAffected == 1;
  }

  /// Marks a task as complete by setting [actualCompletedDate] and
  /// [updatedAt] to the current time.
  Future<void> markComplete(int id) async {
    final now = DateTime.now();
    await (update(taskTable)..where((t) => t.id.equals(id))).write(
      TaskTableCompanion(
        actualCompletedDate: Value(now),
        updatedAt: Value(now),
      ),
    );
  }

  /// Marks a task as incomplete (clears [actualCompletedDate]).
  Future<void> markIncomplete(int id) async {
    await (update(taskTable)..where((t) => t.id.equals(id))).write(
      TaskTableCompanion(
        actualCompletedDate: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
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
  Future<void> toggleTaskCompletion(int id, bool completed) async {
    if (completed) {
      await markComplete(id);
    } else {
      await markIncomplete(id);
    }
  }

  /// Deletes the task with [id].  Returns the number of deleted rows (0 or 1).
  Future<int> deleteTask(int id) =>
      (delete(taskTable)..where((t) => t.id.equals(id))).go();
}
