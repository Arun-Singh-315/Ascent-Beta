import 'package:drift/drift.dart';

// Travel (CLAUDE.md §7): every table has a uuid key, timestamps and a
// soft-delete column so sync can follow.

/// A trip: a name, optional dates, and the people sharing it.
@DataClassName('TripRow')
class TripTable extends Table {
  @override
  String get tableName => 'trips';
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get startDay => dateTime().nullable()();
  DateTimeColumn get endDay => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// Someone on a trip. Exactly one person per trip is "you".
@DataClassName('TripPersonRow')
class TripPersonTable extends Table {
  @override
  String get tableName => 'trip_people';
  TextColumn get id => text()();
  TextColumn get tripId => text()();
  TextColumn get name => text()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// A place you were: from one tap of "I'm here" (GPS) or typed in.
@DataClassName('VisitRow')
class VisitTable extends Table {
  @override
  String get tableName => 'visits';
  TextColumn get id => text()();

  /// The trip it belongs to, or null for an everyday visit.
  TextColumn get tripId => text().nullable()();
  TextColumn get name => text()();

  /// Area or address line, e.g. "Small Vagator, Goa".
  TextColumn get area => text().nullable()();
  RealColumn get lat => real().nullable()();
  RealColumn get lon => real().nullable()();

  /// When you were there.
  DateTimeColumn get at => dateTime()();

  /// A guess like 'food', 'beach', 'stay', 'sight', 'shop' (or null).
  TextColumn get kind => text().nullable()();

  /// "27°, clear" when it was fetched online.
  TextColumn get weather => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get rating => integer().nullable()();

  /// False while the place still needs a name (captured offline).
  BoolColumn get named => boolean().withDefault(const Constant(true))();

  /// The Home "recent visits" question was answered or skipped.
  BoolColumn get settled => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// A bill: who paid, how much, and (in [TripShareTable]) who shares it.
/// [kind] 'settlement' records a pay-back between two people.
@DataClassName('TripExpenseRow')
class TripExpenseTable extends Table {
  @override
  String get tableName => 'trip_expenses';
  TextColumn get id => text()();
  TextColumn get tripId => text().nullable()();
  TextColumn get visitId => text().nullable()();
  TextColumn get title => text()();
  RealColumn get amount => real()();
  TextColumn get paidBy => text().nullable()();
  TextColumn get kind => text().withDefault(const Constant('expense'))();
  DateTimeColumn get at => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// One person's part of a bill.
@DataClassName('TripShareRow')
class TripShareTable extends Table {
  @override
  String get tableName => 'trip_expense_shares';
  TextColumn get id => text()();
  TextColumn get expenseId => text()();
  TextColumn get personId => text()();
  RealColumn get amount => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

/// A photo attached to a visit, copied into the app's private folder.
@DataClassName('VisitPhotoRow')
class VisitPhotoTable extends Table {
  @override
  String get tableName => 'visit_photos';
  TextColumn get id => text()();
  TextColumn get visitId => text()();
  TextColumn get path => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}
