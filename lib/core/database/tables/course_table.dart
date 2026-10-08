import 'package:drift/drift.dart';

@DataClassName('CourseEntry')
class CourseTable extends Table {
  @override
  String get tableName => 'courses';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get author => text().withDefault(const Constant('Instructor'))();
  TextColumn get category => text().withDefault(const Constant('General'))();
  TextColumn get sourceUrl => text().nullable()();
  DateTimeColumn get targetCompletionDate => dateTime().nullable()();
  IntColumn get daysLeft => integer().withDefault(const Constant(30))();
  IntColumn get targetMinutesPerDay => integer().withDefault(const Constant(45))();
  TextColumn get modulesJson => text()(); // Serialized modules list JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
