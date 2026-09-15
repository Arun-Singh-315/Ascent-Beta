import 'package:drift/drift.dart';
import 'enums.dart';
import 'study_phase_table.dart';

// PacingRule and SeriesComputedStatus are defined in enums.dart.
// SeriesComputedStatus is computed in the Series Engine — never stored.

@DataClassName('Series')
class SeriesTable extends Table {
  @override
  String get tableName => 'series';

  IntColumn get id => integer().autoIncrement()();

  /// Display title of the series (e.g. "Blind 75 DSA").
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Total number of items in the series.  Null = open-ended series.
  IntColumn get totalItems => integer().nullable()();

  /// Stores the [PacingRule] enum name (e.g. 'fixedInterval').
  TextColumn get pacingRule =>
      text().withDefault(const Constant('fixedInterval'))();

  /// For [PacingRule.fixedInterval]: one item every N days.
  IntColumn get fixedIntervalDays => integer().nullable()();

  /// Hard deadline for completing the series.  Null = no deadline.
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Optional FK to [StudyPhaseTable].
  IntColumn get linkedPhaseId =>
      integer().nullable().references(StudyPhaseTable, #id)();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
