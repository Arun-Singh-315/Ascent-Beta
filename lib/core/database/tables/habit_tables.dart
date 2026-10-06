import 'package:drift/drift.dart';

@DataClassName('Habit')
class HabitTable extends Table {
  @override
  String get tableName => 'habits';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 150)();
  TextColumn get frequency => text().withDefault(const Constant('daily'))(); // 'daily', 'weekdays', 'weekly'
  TextColumn get category => text().withDefault(const Constant('Health'))(); // 'Health', 'Study', 'Fitness', 'Productivity'
  TextColumn get colorHex => text().withDefault(const Constant('#38664D'))();
  IntColumn get targetStreak => integer().withDefault(const Constant(30))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('HabitCompletion')
class HabitCompletionTable extends Table {
  @override
  String get tableName => 'habit_completions';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId => integer().references(HabitTable, #id)();
  DateTimeColumn get date => dateTime()(); // normalized to midnight
  TextColumn get notes => text().nullable()();
}
