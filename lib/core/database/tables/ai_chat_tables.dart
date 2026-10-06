import 'package:drift/drift.dart';

@DataClassName('AiChatMessage')
class AiChatMessageTable extends Table {
  @override
  String get tableName => 'ai_chat_messages';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get sender => text()(); // 'user' or 'assistant'
  TextColumn get message => text()();
  TextColumn get actionType => text().nullable()(); // 'task_created', 'plan_generated', 'expense_logged', 'insight', 'study_explained'
  TextColumn get actionPayloadJson => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
