import 'dart:convert';
import '../database/app_database.dart';

/// A persisted user-operation identity; retries never repeat a committed write.
class LocalActionReceipts {
  LocalActionReceipts(this.db);
  final AppDatabase db;
  Future<Map<String, dynamic>> run({
    required String requestId,
    required String capability,
    required Map<String, dynamic> arguments,
    required Future<Map<String, dynamic>> Function() write,
  }) => db.transaction(() async {
    if (requestId.trim().isEmpty) {
      throw ArgumentError('An operation identity is required');
    }
    final keys = arguments.keys.toList()..sort();
    final payload = jsonEncode({for (final key in keys) key: arguments[key]});
    final existing = await (db.select(
      db.aiCommandTable,
    )..where((r) => r.requestId.equals(requestId))).getSingleOrNull();
    if (existing != null) {
      if (existing.capability != capability ||
          existing.argumentsJson != payload) {
        throw StateError(
          'This operation was already used for a different change',
        );
      }
      return Map<String, dynamic>.from(jsonDecode(existing.resultJson) as Map);
    }
    final result = await write();
    await db
        .into(db.aiCommandTable)
        .insert(
          AiCommandTableCompanion.insert(
            requestId: requestId,
            capability: capability,
            argumentsJson: payload,
            resultJson: jsonEncode(result),
          ),
        );
    return result;
  });
}
