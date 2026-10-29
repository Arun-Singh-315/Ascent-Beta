import 'riya_alert_effects.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import 'riya_intents.dart';

const riyaConversationKey = 'riya_productivity_conversation_v1';

/// Both Home sheet and full chat use one resolver in the current workspace.
final riyaConversationProvider = Provider<RiyaIntentResolver>((ref) {
  final resolver = RiyaIntentResolver(ref.watch(databaseProvider));
  try {
    final raw = ref
        .read(sharedPreferencesProvider)
        .getString(riyaConversationKey);
    if (raw != null) {
      resolver.restoreConversation(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    }
  } catch (_) {
    /* A corrupt draft must never block chatting. */
  }
  return resolver;
});

final riyaAlertEffectsProvider = Provider<RiyaAlertEffects>(
  (ref) => RiyaAlertEffects.device(ref.watch(databaseProvider)),
);
