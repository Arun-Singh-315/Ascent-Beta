import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_service.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import '../../features/hydration/hydration_popup_dialog.dart';

const _kLastHydrationPromptKey = 'ascent_last_hydration_prompt_time';

class HydrationReminderService {
  final Ref _ref;

  HydrationReminderService(this._ref);

  /// Checks if enough time has elapsed (e.g. > 90 minutes) during daytime (8 AM - 10 PM)
  /// without logging water, and triggers the freeze popup or notification.
  Future<void> checkAndPromptHydration(BuildContext context) async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final now = DateTime.now();

    // Only prompt between 8:00 AM and 10:00 PM
    if (now.hour < 8 || now.hour >= 22) return;

    final lastPromptMillis = prefs.getInt(_kLastHydrationPromptKey) ?? 0;
    final lastPromptTime = DateTime.fromMillisecondsSinceEpoch(lastPromptMillis);

    // Prompt at most once every 90 minutes
    if (now.difference(lastPromptTime).inMinutes < 90) return;

    // Check today's water logs
    try {
      final logs = _ref.read(todayWaterLogsStreamProvider).value;

      if (logs != null && logs.isNotEmpty) {
        final lastLog = logs.first; // newest first
        if (now.difference(lastLog.timestamp).inMinutes < 90) {
          // User already drank water recently
          return;
        }
      }

      // Record prompt time
      await prefs.setInt(_kLastHydrationPromptKey, now.millisecondsSinceEpoch);

      if (context.mounted) {
        HydrationPopupDialog.show(context);
      }
    } catch (_) {}
  }

  /// Sends an instant or scheduled reminder notification
  Future<void> sendHydrationNotification() async {
    await NotificationService.instance.showInstantNotification(
      id: 204,
      title: '💧 Drink Water Reminder',
      body: 'Hey! Didn\'t show up yet? Take a quick sip and keep your focus laser-sharp!',
    );
  }
}

final hydrationReminderServiceProvider = Provider<HydrationReminderService>((ref) {
  return HydrationReminderService(ref);
});
