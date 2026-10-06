import 'package:drift/drift.dart';

@DataClassName('WaterLog')
class WaterLogTable extends Table {
  @override
  String get tableName => 'water_logs';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountMl => integer()();
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get date => dateTime()(); // normalized to midnight
}

@DataClassName('WaterGoal')
class WaterGoalTable extends Table {
  @override
  String get tableName => 'water_goals';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get targetMl => integer().withDefault(const Constant(2500))(); // 2500 mL default
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
