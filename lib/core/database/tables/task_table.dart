import 'package:drift/drift.dart';
import 'enums.dart';
import 'study_phase_table.dart';
import 'series_table.dart';
import 'application_table.dart';

// TaskPriority is defined in enums.dart.
// Task status (ahead/on-track/lagging/at-risk) is COMPUTED in
// lib/core/insight_engine/series_engine.dart — never stored here.

@DataClassName('Task')
class TaskTable extends Table {
  @override
  String get tableName => 'tasks';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get title => text().withLength(min: 1, max: 300)();

  /// Optional free-text notes about the task.
  TextColumn get notes => text().nullable()();

  /// The calendar date on which the user plans to work on this task.
  DateTimeColumn get plannedDate => dateTime().nullable()();

  /// Set when the user marks the task complete.
  DateTimeColumn get actualCompletedDate => dateTime().nullable()();

  /// Stores the [TaskPriority] enum name.  Defaults to 'medium'.
  TextColumn get priority =>
      text().withDefault(const Constant('medium'))();

  /// Optional FK to [StudyPhaseTable].
  IntColumn get linkedPhaseId =>
      integer().nullable().references(StudyPhaseTable, #id)();

  /// Optional FK to [SeriesTable].  Null = standalone to-do.
  IntColumn get seriesId =>
      integer().nullable().references(SeriesTable, #id)();

  /// 1-based position of this task within its parent series.
  IntColumn get seriesItemIndex => integer().nullable()();

  /// Optional FK to a parent [TaskTable] for sub-entries/sub-items.
  IntColumn get parentTaskId =>
      integer().nullable().references(TaskTable, #id)();

  /// Optional FK to [ApplicationTable] for tying tasks to job pipeline entries.
  IntColumn get linkedApplicationId =>
      integer().nullable().references(ApplicationTable, #id)();

  /// Estimated duration for the Focus Timer (minutes).
  IntColumn get estimatedMinutes => integer().nullable()();

  /// Actual time logged by the Focus Timer (minutes).
  IntColumn get actualMinutes => integer().nullable()();

  /// DSA-style revisit flag — marks a problem to revisit later.
  BoolColumn get revisitFlag =>
      boolean().withDefault(const Constant(false))();

  /// Last time the user opened / interacted with this task.
  /// Used as a freshness signal by the Insight Engine.
  DateTimeColumn get lastInteractedAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
