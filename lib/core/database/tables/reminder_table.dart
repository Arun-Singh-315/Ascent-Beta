import 'package:drift/drift.dart';

/// Represents a scheduled reminder with local push notifications.
@DataClassName('Reminder')
class ReminderTable extends Table {
  @override
  String get tableName => 'reminders';

  IntColumn get id => integer().autoIncrement()();

  /// The text content/label of the reminder.
  TextColumn get title => text().withLength(min: 1, max: 300)();

  /// Scheduled date & time for the reminder notification.
  DateTimeColumn get scheduledAt => dateTime()();

  /// Whether notification is active.
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
