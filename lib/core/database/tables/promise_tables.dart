import 'package:drift/drift.dart';

/// A promise to yourself: "I promise to ___ for N days" (CLAUDE.md §7:
/// uuid key, timestamps and a soft-delete column so sync can follow).
@DataClassName('PromiseRow')
class PromiseTable extends Table {
  @override
  String get tableName => 'promises';
  TextColumn get id => text()();
  TextColumn get title => text()();

  /// Optional "because …" the person can add later.
  TextColumn get why => text().nullable()();

  /// Local midnight of day 1.
  DateTimeColumn get startDay => dateTime()();

  /// 7, 21, 30, 66 … or null for an ongoing promise.
  IntColumn get lengthDays => integer().nullable()();

  /// Daily nudge, minutes after midnight (e.g. 1260 = 9 pm), or null.
  IntColumn get nudgeMinute => integer().nullable()();

  /// 'active', 'done' (ran its full length) or 'released' (ended early).
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get endedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One answer for one day: kept or missed.
@DataClassName('PromiseCheckInRow')
class PromiseCheckInTable extends Table {
  @override
  String get tableName => 'promise_check_ins';
  TextColumn get id => text()();
  TextColumn get promiseId => text()();

  /// Local midnight of the day answered.
  DateTimeColumn get day => dateTime()();

  /// 'kept' or 'missed'.
  TextColumn get result => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {promiseId, day},
  ];
}
