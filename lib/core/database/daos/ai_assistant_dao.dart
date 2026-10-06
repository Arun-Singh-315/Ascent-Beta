part of '../app_database.dart';

@DriftAccessor(tables: [AiChatMessageTable])
class AiAssistantDao extends DatabaseAccessor<AppDatabase>
    with _$AiAssistantDaoMixin {
  AiAssistantDao(super.db);

  Stream<List<AiChatMessage>> watchRecentMessages({int limit = 60}) {
    return (select(aiChatMessageTable)
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)])
          ..limit(limit))
        .watch();
  }

  Future<int> insertMessage(AiChatMessageTableCompanion entry) {
    return into(aiChatMessageTable).insert(entry);
  }

  Future<int> clearChatHistory() {
    return delete(aiChatMessageTable).go();
  }
}
