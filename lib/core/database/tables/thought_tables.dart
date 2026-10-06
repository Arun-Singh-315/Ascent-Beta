import 'package:drift/drift.dart';

@DataClassName('Thought')
class ThoughtTable extends Table {
  @override
  String get tableName => 'thoughts';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  // 'thought', 'idea', 'me_to_me', 'win', 'future'
  TextColumn get mood => text().withDefault(const Constant('thought'))();
  TextColumn get colorHex => text().withDefault(const Constant('#2D2D3A'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  TextColumn get promptQuestion => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
