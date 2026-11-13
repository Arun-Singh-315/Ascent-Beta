import 'package:drift/drift.dart';
import 'task_table.dart';
import 'reminder_table.dart';

/// Table representing scheduled medicines, prescriptions, and durations.
@DataClassName('Medicine')
class MedicineTable extends Table {
  @override
  String get tableName => 'medicines';

  IntColumn get id => integer().autoIncrement()();

  /// Medicine name (e.g. 'Paracetamol 500mg', 'Vitamin D3', 'Amoxicillin')
  TextColumn get name => text().withLength(min: 1, max: 200)();

  /// Optional personal treatment context; old schedules remain ungrouped.
  IntColumn get carePlanId =>
      integer().nullable().references(CarePlanTable, #id)();
  TextColumn get purpose => text().withDefault(const Constant(''))();

  /// Dosage description (e.g. '1 Tablet', '5 ml', '1 Capsule')
  TextColumn get dosage => text().withLength(min: 1, max: 100)();

  /// JSON list of time strings (e.g. '["08:00", "14:00", "20:00"]')
  TextColumn get scheduledTimes => text()();

  /// Duration of prescription in days (e.g. 3, 5, 7, 14, 30)
  IntColumn get durationDays => integer().withDefault(const Constant(7))();

  /// Date when the course begins
  DateTimeColumn get startDate => dateTime()();

  /// Instructions (e.g. 'After food', 'Before breakfast', 'With water')
  TextColumn get instructions =>
      text().withDefault(const Constant('After food'))();

  /// Formulation / Form factor (e.g. 'tablet', 'capsule', 'syrup', 'drops')
  TextColumn get type => text().withDefault(const Constant('tablet'))();

  /// Whether this medication schedule is currently active
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Table tracking daily dose compliance and completions.
@DataClassName('MedicineLog')
class MedicineLogTable extends Table {
  @override
  String get tableName => 'medicine_logs';

  IntColumn get id => integer().autoIncrement()();

  /// Foreign key to [MedicineTable]
  IntColumn get medicineId => integer().references(MedicineTable, #id)();

  /// Calendar date string 'YYYY-MM-DD'
  TextColumn get dateStr => text()();

  /// Time slot e.g. '08:00'
  TextColumn get timeSlot => text()();

  /// Linked task in [TaskTable] for bi-directional sync with Today Activities
  IntColumn get linkedTaskId =>
      integer().nullable().references(TaskTable, #id)();

  /// Linked reminder in [ReminderTable] for push notifications
  IntColumn get linkedReminderId =>
      integer().nullable().references(ReminderTable, #id)();

  /// Whether dose has been taken
  BoolColumn get isTaken => boolean().withDefault(const Constant(false))();

  /// Timestamp when dose was taken
  DateTimeColumn get takenAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// A personal folder for one health concern. Archiving never stops medicines.
@DataClassName('CarePlan')
class CarePlanTable extends Table {
  @override
  String get tableName => 'care_plans';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get person => text().withDefault(const Constant('My care'))();
  TextColumn get clinician => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get nextVisit => dateTime().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Dated, user-entered evidence; attachments are copied into app-private storage.
@DataClassName('CareRecord')
class CareRecordTable extends Table {
  @override
  String get tableName => 'care_records';
  IntColumn get id => integer().autoIncrement()();
  IntColumn get carePlanId => integer().references(CarePlanTable, #id)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().withDefault(const Constant(''))();
  DateTimeColumn get recordedAt => dateTime()();
  TextColumn get filePath => text().nullable()();
  TextColumn get fileName => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
