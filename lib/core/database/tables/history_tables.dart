import 'package:drift/drift.dart';

/// Durable snapshots without foreign keys: removing a source cannot erase its past.
@DataClassName('HistoryEvent')
class HistoryEventTable extends Table {
  @override
  String get tableName => 'history_events';
  TextColumn get id => text()();
  TextColumn get module => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get title => text()();
  TextColumn get detail => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredAt => dateTime()();
  IntColumn get privacyThoughtId => integer().nullable()();
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();
  TextColumn get parentEntityId => text().nullable()();
  BoolColumn get imported => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('WaterGoalVersion')
class WaterGoalVersionTable extends Table {
  @override
  String get tableName => 'water_goal_versions';
  TextColumn get day => text()();
  IntColumn get targetMl => integer()();
  @override
  Set<Column> get primaryKey => {day};
}
