import 'package:drift/drift.dart';
import 'application_table.dart';
import 'study_phase_table.dart';

@DataClassName('Note')
class NoteTable extends Table {
  @override
  String get tableName => 'notes';

  IntColumn get id => integer().autoIncrement()();

  /// Optional title for the note.
  TextColumn get title => text().nullable()();

  /// The main body of the note.
  TextColumn get content => text()();

  /// Company this note is about (free text).
  TextColumn get linkedCompany => text().nullable()();

  /// Topic this note is about (free text, e.g. 'System Design').
  TextColumn get linkedTopic => text().nullable()();

  /// Optional FK to [ApplicationTable].
  IntColumn get linkedApplicationId =>
      integer().nullable().references(ApplicationTable, #id)();

  /// Optional FK to [StudyPhaseTable].
  IntColumn get linkedPhaseId =>
      integer().nullable().references(StudyPhaseTable, #id)();

  /// Freshness signal used by the Insight Engine to detect stale notes.
  DateTimeColumn get lastInteractedAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------

@DataClassName('NoteTag')
class NoteTagTable extends Table {
  @override
  String get tableName => 'note_tags';

  IntColumn get id => integer().autoIncrement()();

  /// FK to [NoteTable].
  IntColumn get noteId => integer().references(NoteTable, #id)();

  /// The tag text (e.g. 'system-design', 'behavioral').
  TextColumn get tag => text().withLength(min: 1, max: 100)();
}
