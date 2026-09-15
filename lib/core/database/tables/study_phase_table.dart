import 'package:drift/drift.dart';

@DataClassName('StudyPhase')
class StudyPhaseTable extends Table {
  @override
  String get tableName => 'study_phases';

  IntColumn get id => integer().autoIncrement()();

  /// Display title of the phase (e.g. "Phase 1: Fundamentals").
  TextColumn get title => text().withLength(min: 1, max: 200)();

  /// Optional description / goal for this phase.
  TextColumn get description => text().nullable()();

  /// Zero-based ordering index used to sort phases in the UI.
  IntColumn get orderIndex => integer().withDefault(const Constant(0))();

  /// When this phase is scheduled to begin.
  DateTimeColumn get startDate => dateTime().nullable()();

  /// When this phase is scheduled to end.
  DateTimeColumn get endDate => dateTime().nullable()();

  /// Hex color string used for the phase chip in the UI (e.g. '#7FA88A').
  TextColumn get colorHex =>
      text().withDefault(const Constant('#7FA88A'))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
