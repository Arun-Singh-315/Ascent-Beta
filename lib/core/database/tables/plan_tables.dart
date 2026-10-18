import 'package:drift/drift.dart';
import 'task_table.dart';
import 'thought_tables.dart';
import 'reminder_table.dart';

/// Managed plan and routine definition.
/// Owns the schedule rule, repetition, and future session generation.
@DataClassName('PlanDefinition')
class PlanDefinitionTable extends Table {
  @override
  String get tableName => 'plan_definitions';

  /// Stable unique identifier (e.g. 'plan_...').
  TextColumn get id => text()();

  /// Short title for the plan / routine (1 to 300 characters).
  TextColumn get title => text().withLength(min: 1, max: 300)();

  /// Optional source thought FK.
  IntColumn get sourceThoughtId => integer().nullable().references(
    ThoughtTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Optional source task FK if promoted from an existing standalone activity.
  IntColumn get sourceTaskId => integer().nullable().references(
    TaskTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Activity classification: 'todo', 'timer', 'flexible'.
  TextColumn get activityType => text().withDefault(const Constant('todo'))();

  /// Target timer duration in minutes if [activityType] == 'timer'.
  IntColumn get targetMinutes => integer().nullable()();

  /// Expected duration in minutes (used for calculating check-in window without forcing a timer).
  IntColumn get expectedDurationMinutes => integer().nullable()();

  /// Start date in 'YYYY-MM-DD'.
  TextColumn get startDate => text()();

  /// Inclusive end date in 'YYYY-MM-DD'.
  TextColumn get endDate => text()();

  /// Recurrence rule: 'once', 'daily', 'weekdays', 'custom_days'.
  TextColumn get recurrenceRule => text().withDefault(const Constant('once'))();

  /// JSON array of integer weekdays (1=Mon..7=Sun) for 'custom_days'.
  TextColumn get customDaysJson => text().nullable()();

  /// Local time of day in 'HH:mm' format (e.g. '07:00').
  TextColumn get localTime => text()();

  /// Timezone policy: 'device_local' (recommended) or specific IANA timezone identifier.
  TextColumn get timezonePolicy =>
      text().withDefault(const Constant('device_local'))();

  /// Reminder policy: 'at_start', 'none'.
  TextColumn get reminderPolicy =>
      text().withDefault(const Constant('at_start'))();

  /// Check-in follow-up policy: 'off', 'once', 'gentle'.
  TextColumn get checkInPolicy => text().withDefault(const Constant('off'))();

  /// Lifecycle status: 'active', 'paused', 'ended'.
  TextColumn get status => text().withDefault(const Constant('active'))();

  /// Revision counter for optimistic concurrency and cache invalidation.
  IntColumn get revision => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Dated session occurrence of a plan or routine.
/// Owns at most one linked task, its start reminder, and check-in attempts for that specific date.
@DataClassName('PlanOccurrence')
class PlanOccurrenceTable extends Table {
  @override
  String get tableName => 'plan_occurrences';

  /// Stable unique occurrence ID (e.g. `occ_<planId>_<date>_<slotIndex>`).
  TextColumn get id => text()();

  /// Parent plan reference.
  TextColumn get planId => text().references(
    PlanDefinitionTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Eligible calendar date string 'YYYY-MM-DD'.
  TextColumn get eligibleLocalDate => text()();

  /// Slot index for daily multi-slot routines (default 0).
  IntColumn get slotIndex => integer().withDefault(const Constant(0))();

  /// Definition revision snapshot under which this occurrence was generated.
  IntColumn get definitionRevision =>
      integer().withDefault(const Constant(1))();

  /// Exact scheduled start timestamp.
  DateTimeColumn get scheduledStartTime => dateTime()();

  /// Optional scheduled end timestamp.
  DateTimeColumn get scheduledEndTime => dateTime().nullable()();

  /// Cutoff timestamp after which the session is marked 'not_confirmed'.
  DateTimeColumn get closeTime => dateTime()();

  /// Optional linked Todo task for this occurrence.
  IntColumn get linkedTaskId => integer().nullable().references(
    TaskTable,
    #id,
    onDelete: KeyAction.setNull,
  )();

  /// Outcome: 'scheduled', 'done', 'skipped', 'not_confirmed'.
  TextColumn get outcome => text().withDefault(const Constant('scheduled'))();

  /// Timestamp when check-in or user action answered this occurrence.
  DateTimeColumn get answeredAt => dateTime().nullable()();

  /// Timestamp when the task or occurrence was completed.
  DateTimeColumn get completedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {planId, eligibleLocalDate, slotIndex},
  ];
}

/// Explicit link between a device reminder and a plan occurrence.
@DataClassName('OccurrenceAlertLink')
class OccurrenceAlertLinkTable extends Table {
  @override
  String get tableName => 'occurrence_alert_links';

  IntColumn get id => integer().autoIncrement()();

  /// Linked occurrence ID.
  TextColumn get occurrenceId => text().references(
    PlanOccurrenceTable,
    #id,
    onDelete: KeyAction.cascade,
  )();

  /// Linked reminder ID in ReminderTable.
  IntColumn get reminderId =>
      integer().references(ReminderTable, #id, onDelete: KeyAction.cascade)();

  /// Alert role: 'start', 'check_in'.
  TextColumn get role => text()();

  /// Attempt index for gentle retries (0 = initial, 1 = +30m, 2 = +90m).
  IntColumn get attemptIndex => integer().withDefault(const Constant(0))();

  /// Revision version expected at scheduling time.
  IntColumn get expectedVersion => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A named collection of independently actionable items.
@DataClassName('PlanCollection')
class PlanCollectionTable extends Table {
  @override
  String get tableName => 'plan_collections';
  TextColumn get id => text()();
  TextColumn get requestId => text().unique()();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get sourceThoughtId => integer().nullable().references(
    ThoughtTable,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PlanCollectionItem')
class PlanCollectionItemTable extends Table {
  @override
  String get tableName => 'plan_collection_items';
  TextColumn get id => text()();
  TextColumn get collectionId => text().references(
    PlanCollectionTable,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  TextColumn get title => text().withLength(min: 1, max: 300)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  BoolColumn get dateOnly => boolean().withDefault(const Constant(false))();
  IntColumn get taskId => integer().nullable().unique().references(
    TaskTable,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get definitionId => text().nullable().unique().references(
    PlanDefinitionTable,
    #id,
    onDelete: KeyAction.setNull,
  )();
  @override
  Set<Column> get primaryKey => {id};
}
