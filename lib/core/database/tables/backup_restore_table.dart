import 'package:drift/drift.dart';

/// The preference snapshot commits with restored records. Startup can finish
/// synchronizing preferences after an interruption without resetting records.
class BackupRestoreTable extends Table {
  @override
  String get tableName => 'backup_restore_state';
  TextColumn get id => text()();
  TextColumn get preferencesJson => text()();
  @override
  Set<Column> get primaryKey => {id};
}
