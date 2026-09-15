import 'package:drift/drift.dart';
import 'application_table.dart';

@DataClassName('Resume')
class ResumeTable extends Table {
  @override
  String get tableName => 'resumes';

  IntColumn get id => integer().autoIncrement()();

  /// Human-readable version label (e.g. 'v2 - SDE roles', 'Backend specific').
  TextColumn get versionLabel => text().withLength(min: 1, max: 200)();

  /// Absolute path to the file in the app's documents directory.
  TextColumn get filePath => text()();

  /// File size in bytes (populated after upload).
  IntColumn get fileSize => integer().nullable()();

  /// If this resume is tailored for a specific company.
  TextColumn get tailoredForCompany => text().nullable()();

  /// Optional FK linking to an [ApplicationTable] entry.
  IntColumn get linkedApplicationId =>
      integer().nullable().references(ApplicationTable, #id)();

  DateTimeColumn get uploadedAt =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get notes => text().nullable()();
}
