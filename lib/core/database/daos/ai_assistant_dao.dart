part of '../app_database.dart';

@DriftAccessor(tables: [AiChatMessageTable])
class AiAssistantDao extends DatabaseAccessor<AppDatabase>
    with _$AiAssistantDaoMixin {
  AiAssistantDao(super.db);

  Stream<List<AiChatMessage>> watchRecentMessages({int limit = 60}) {
    return (select(aiChatMessageTable)
          ..orderBy([(m) => OrderingTerm.desc(m.id)])
          ..limit(limit))
        .watch()
        .map((rows) => rows.reversed.toList());
  }

  Future<int> insertMessage(AiChatMessageTableCompanion entry) {
    return into(aiChatMessageTable).insert(entry);
  }

  Future<int> clearChatHistory() => db.transaction(() async {
    await db.delete(db.aiCommandTable).go();
    return delete(aiChatMessageTable).go();
  });

  /// Recover committed local commands if the app stopped before their chat
  /// response was saved. Never resurrect cleared conversations.
  Future<void> recoverCommandResponses() => db.transaction(() async {
    final receipts =
        await (db.select(db.aiCommandTable)
              ..orderBy([(r) => OrderingTerm.desc(r.completedAt)])
              ..limit(60))
            .get();
    final messages = await select(aiChatMessageTable).get();
    final userIds = messages
        .where((m) => m.sender == 'user')
        .map((m) => 'chat:${m.id}')
        .toSet();
    final reported = <String>{};
    for (final message in messages) {
      try {
        final data =
            jsonDecode(message.actionPayloadJson ?? '{}')
                as Map<String, dynamic>;
        if (data['requestId'] is String) {
          reported.add(data['requestId'] as String);
        }
      } catch (_) {
        /* Legacy chat payloads may not contain receipts. */
      }
    }
    for (final receipt in receipts.reversed) {
      if (!userIds.contains(receipt.requestId) ||
          reported.contains(receipt.requestId)) {
        continue;
      }
      final result = jsonDecode(receipt.resultJson) as Map<String, dynamic>;
      await insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'assistant',
          message: 'Recovered saved result: ${result['message']}',
          actionType: Value(receipt.capability),
          actionPayloadJson: Value(
            jsonEncode({
              'requestId': receipt.requestId,
              'executionStatus': 'verified',
              'write': true,
              'title': 'Saved result',
              'summary': result['message'],
              'route': result['route'],
            }),
          ),
        ),
      );
    }
  });
}
