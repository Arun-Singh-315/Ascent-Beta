import 'package:drift/drift.dart';
import 'enums.dart';

// DsaDifficulty and DsaTopic are defined in enums.dart.

@DataClassName('DsaLog')
class DsaLogTable extends Table {
  @override
  String get tableName => 'dsa_logs';

  IntColumn get id => integer().autoIncrement()();

  /// Name of the problem (e.g. "Two Sum").
  TextColumn get problemName => text().withLength(min: 1, max: 300)();

  /// Stores the [DsaTopic] enum name (e.g. 'arrays').
  TextColumn get topic => text()();

  /// Stores the [DsaDifficulty] enum name (e.g. 'medium').
  TextColumn get difficulty => text()();

  /// The date on which the problem was solved.
  DateTimeColumn get dateSolved => dateTime()();

  /// Marks the problem for future revisit.
  BoolColumn get revisitFlag =>
      boolean().withDefault(const Constant(false))();

  /// How long the user spent on the problem, in minutes.
  IntColumn get timeTakenMinutes => integer().nullable()();

  /// Free-text notes, approach, or learnings.
  TextColumn get notes => text().nullable()();

  /// Link to the problem on LeetCode, Codeforces, etc.
  TextColumn get problemUrl => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
