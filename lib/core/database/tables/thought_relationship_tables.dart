import 'package:drift/drift.dart';
import 'thought_tables.dart';
import 'reminder_table.dart';

@DataClassName('ThoughtReminderLink')
class ThoughtReminderLinkTable extends Table {
  @override
  String get tableName => 'thought_reminder_links';
  IntColumn get thoughtId =>
      integer().references(ThoughtTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get reminderId =>
      integer().references(ReminderTable, #id, onDelete: KeyAction.cascade)();
  @override
  Set<Column> get primaryKey => {thoughtId, reminderId};
}

@DataClassName('ThoughtMergeSource')
class ThoughtMergeSourceTable extends Table {
  @override
  String get tableName => 'thought_merge_sources';
  IntColumn get id => integer().autoIncrement()();
  @ReferenceName('mergedNoteSources')
  IntColumn get mergedThoughtId =>
      integer().references(ThoughtTable, #id, onDelete: KeyAction.cascade)();
  @ReferenceName('sourceNoteMerges')
  IntColumn get sourceThoughtId => integer().nullable().references(
    ThoughtTable,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get position => integer()();
  TextColumn get sourceSnapshot => text()();
  TextColumn get mergedSnapshot => text()();
  BoolColumn get archivedByMerge =>
      boolean().withDefault(const Constant(false))();
}
