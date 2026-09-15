import 'package:drift/drift.dart';

/// Represents an upcoming interview or target company deadline.
@DataClassName('UpcomingInterview')
class UpcomingInterviewTable extends Table {
  @override
  String get tableName => 'upcoming_interviews';

  IntColumn get id => integer().autoIncrement()();

  /// Target company name, e.g. "Google", "Stripe".
  TextColumn get companyName => text()();

  /// Date (and optional time) of the interview.
  DateTimeColumn get interviewDate => dateTime()();

  /// Optional free-text notes for the interview.
  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
