import 'package:drift/drift.dart';
import 'application_table.dart';

@DataClassName('InterviewPrep')
class InterviewPrepTable extends Table {
  @override
  String get tableName => 'interview_prep';

  IntColumn get id => integer().autoIncrement()();

  /// Company the interview is / was with.
  TextColumn get company => text().nullable()();

  /// Role being interviewed for.
  TextColumn get role => text().nullable()();

  /// Optional FK to [ApplicationTable].
  IntColumn get linkedApplicationId =>
      integer().nullable().references(ApplicationTable, #id)();

  /// The actual interview question.
  TextColumn get questionAsked => text()();

  /// User's answer notes / approach.
  TextColumn get answerNotes => text().nullable()();

  /// Self-assessment of the answer (e.g. 'Good', 'Needs work', 'Stumped').
  TextColumn get outcome => text().nullable()();

  /// Question category (e.g. 'Behavioral', 'DSA', 'System Design').
  TextColumn get category => text().nullable()();

  DateTimeColumn get preparedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Last time the user opened or reviewed this prep entry.
  DateTimeColumn get lastInteractedAt => dateTime().nullable()();
}
