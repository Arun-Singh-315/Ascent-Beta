import 'package:drift/drift.dart';
import 'enums.dart';

// ApplicationStage is defined in enums.dart.

@DataClassName('ApplicationRow')
class ApplicationTable extends Table {
  @override
  String get tableName => 'applications';

  IntColumn get id => integer().autoIncrement()();

  TextColumn get company => text().withLength(min: 1, max: 200)();

  TextColumn get role => text().withLength(min: 1, max: 200)();

  /// Stores the [ApplicationStage] enum name.  Defaults to 'wishlist'.
  TextColumn get currentStage =>
      text().withDefault(const Constant('wishlist'))();

  TextColumn get notes => text().nullable()();

  /// Date by which the user wants to take the next action.
  DateTimeColumn get nextActionDate => dateTime().nullable()();

  /// Link to the job posting.
  TextColumn get jobUrl => text().nullable()();

  /// Free-text salary range / CTC (e.g. '18–22 LPA').
  TextColumn get salary => text().nullable()();

  /// Last time the user opened or edited this application.
  DateTimeColumn get lastInteractedAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ---------------------------------------------------------------------------

@DataClassName('ApplicationStatusHistory')
class ApplicationStatusHistoryTable extends Table {
  @override
  String get tableName => 'application_status_history';

  IntColumn get id => integer().autoIncrement()();

  /// FK to [ApplicationTable].
  IntColumn get applicationId =>
      integer().references(ApplicationTable, #id)();

  /// Stores the [ApplicationStage] enum name.
  TextColumn get stage => text()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get occurredAt =>
      dateTime().withDefault(currentDateAndTime)();
}
