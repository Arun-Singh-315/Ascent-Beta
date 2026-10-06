import 'package:drift/drift.dart';

@DataClassName('WalkSession')
class WalkSessionTable extends Table {
  @override
  String get tableName => 'walk_sessions';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  RealColumn get distanceMeters => real().withDefault(const Constant(0.0))();
  IntColumn get calories => integer().withDefault(const Constant(0))();
  RealColumn get avgPaceSecondsPerKm => real().withDefault(const Constant(0.0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  // JSON array string: [{"lat": 12.97, "lng": 77.59, "t": 1700000000, "acc": 5.2}, ...]
  TextColumn get routeCoordinatesJson => text().withDefault(const Constant('[]'))();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('DailyActivityGoal')
class DailyActivityGoalTable extends Table {
  @override
  String get tableName => 'daily_activity_goals';

  IntColumn get id => integer().autoIncrement()();
  RealColumn get targetDistanceMeters => real().withDefault(const Constant(5000.0))(); // 5km default
  IntColumn get targetWalkMinutes => integer().withDefault(const Constant(45))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
