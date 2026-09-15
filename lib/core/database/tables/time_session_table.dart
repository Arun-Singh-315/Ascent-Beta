import 'package:drift/drift.dart';
import 'session_category_table.dart';
import 'task_table.dart';

/// Represents a live or logged time tracking session.
@DataClassName('TimeSession')
class TimeSessionTable extends Table {
  @override
  String get tableName => 'time_sessions';

  IntColumn get id => integer().autoIncrement()();

  /// User-entered label, e.g. "DSA Module 1", "Watched a movie".
  TextColumn get label => text()();

  /// Activity label convenience (study | entertainment | custom).
  TextColumn get activityType =>
      text().withDefault(const Constant('study'))();

  /// Authoritative FK to [SessionCategoryTable].
  IntColumn get categoryId =>
      integer().references(SessionCategoryTable, #id)();

  /// Optional FK to [TaskTable].
  IntColumn get linkedTaskId =>
      integer().nullable().references(TaskTable, #id)();

  /// Start timestamp of the session.
  DateTimeColumn get startedAt => dateTime()();

  /// End timestamp (null while running or paused).
  DateTimeColumn get endedAt => dateTime().nullable()();

  /// JSON array of paused intervals: `[{"pausedAt":"...","resumedAt":"..."}]`.
  TextColumn get pausedIntervals =>
      text().withDefault(const Constant('[]'))();

  /// Session status: 'running' | 'paused' | 'completed' | 'discarded'.
  TextColumn get status =>
      text().withDefault(const Constant('running'))();

  /// Accumulated active duration in seconds.
  IntColumn get durationSeconds =>
      integer().withDefault(const Constant(0))();

  /// Reference type: 'task' | 'dsa_log' | 'interview_prep' | 'custom'.
  TextColumn get activityRefType =>
      text().withDefault(const Constant('task'))();

  /// Heartbeat timestamp flushed periodically while running.
  DateTimeColumn get lastHeartbeatAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
