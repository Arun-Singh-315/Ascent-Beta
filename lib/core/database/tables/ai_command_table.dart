import 'package:drift/drift.dart';

/// Local command receipts. The write and receipt commit in one transaction.
/// Not an account boundary; this app has one local profile/database.
@DataClassName('AiCommandReceipt')
class AiCommandTable extends Table {
  TextColumn get requestId => text()();
  TextColumn get capability => text()();
  TextColumn get argumentsJson => text()();
  TextColumn get resultJson => text()();
  DateTimeColumn get completedAt =>
      dateTime().withDefault(currentDateAndTime)();
  @override
  Set<Column> get primaryKey => {requestId};
}
