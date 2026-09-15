import 'package:drift/drift.dart';

@DataClassName('ConsistencyLog')
class ConsistencyLogTable extends Table {
  @override
  String get tableName => 'consistency_logs';

  IntColumn get id => integer().autoIncrement()();

  /// Store as midnight UTC to represent a calendar date (e.g. 2024-01-15 00:00:00Z).
  DateTimeColumn get date => dateTime()();

  /// true = user showed up and studied; false = absent day.
  BoolColumn get present => boolean()();

  /// Optional note about the day.
  TextColumn get note => text().nullable()();

  /// Actual hours studied that day (logged manually or from focus timer).
  RealColumn get hoursStudied => real().nullable()();

  /// Enforce one log entry per calendar date.
  @override
  List<Set<Column>> get uniqueKeys => [
        {date},
      ];
}
