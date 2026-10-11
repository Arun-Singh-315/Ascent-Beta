import 'package:drift/drift.dart';

/// Lightweight v1 Challenge data, separate from the legacy fitness Momentum tables.
@DataClassName('Challenge')
class ChallengeTable extends Table {
  @override
  String get tableName => 'challenge_challenges';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()(); // activity | learning
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get unit => text().withDefault(const Constant('minutes'))();
  RealColumn get targetTotal => real()();
  RealColumn get dailyMinimum => real()();
  TextColumn get startDay =>
      text()(); // Local yyyy-MM-dd; stable across timezone changes.
  TextColumn get endDay => text()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get lockedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('ChallengeLink')
class ChallengeLinkTable extends Table {
  @override
  String get tableName => 'challenge_links';

  IntColumn get challengeId => integer().references(ChallengeTable, #id)();
  TextColumn get sourceType => text()(); // task | learning_course
  TextColumn get sourceId => text()();
  DateTimeColumn get linkedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {challengeId, sourceType, sourceId};
}

@DataClassName('ChallengeProofEvent')
class ChallengeProofEventTable extends Table {
  @override
  String get tableName => 'challenge_proof_events';

  IntColumn get challengeId => integer().references(ChallengeTable, #id)();
  TextColumn get kind => text()(); // focus_session | lecture
  TextColumn get sourceId => text()();
  TextColumn get day => text()(); // Local yyyy-MM-dd.
  RealColumn get amount => real()();
  RealColumn get trust => real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  // Upserts are idempotent: a source event contributes at most once per challenge.
  @override
  Set<Column> get primaryKey => {challengeId, kind, sourceId};
}

@DataClassName('ChallengeAmendment')
class ChallengeAmendmentTable extends Table {
  @override
  String get tableName => 'challenge_amendments';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get challengeId => integer().references(ChallengeTable, #id)();
  TextColumn get field => text()();
  TextColumn get oldValue => text()();
  TextColumn get newValue => text()();
  DateTimeColumn get changedAt => dateTime().withDefault(currentDateAndTime)();
}
