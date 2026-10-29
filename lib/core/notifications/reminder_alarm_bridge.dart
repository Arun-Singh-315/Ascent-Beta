import 'dart:async';
import 'package:flutter/services.dart';
import '../services/reminder_actions.dart';
import '../database/app_database.dart';

/// Android owns ringing and durable action receipts; SQLite owns reminder rows.
class ReminderAlarmBridge {
  static const channel = MethodChannel('ascent/reminder-alarms');
  static Future<bool> schedule({
    required int id,
    required String title,
    required DateTime at,
  }) async =>
      await channel.invokeMethod<bool>('schedule', {
        'id': id,
        'title': title,
        'at': at.millisecondsSinceEpoch,
      }) ??
      false;
  static bool get _hasBinding {
    try {
      ServicesBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> cancel(int id) async {
    if (!_hasBinding) return;
    try {
      await channel.invokeMethod('cancel', {'id': id});
    } on MissingPluginException {
      /* Other platforms retain ordinary reminders. */
    }
  }

  static Future<void> cancelAll() async {
    if (!_hasBinding) return;
    try {
      await channel.invokeMethod('cancelAll');
    } on MissingPluginException {
      /* No native alarms on other platforms. */
    }
  }

  static Future<Map<String, dynamic>> access() async {
    if (!_hasBinding) {
      return {'exact': true, 'fullScreen': true, 'notifications': true};
    }
    try {
      final res = await channel.invokeMethod('access');
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (_) {}
    return {'exact': true, 'fullScreen': true, 'notifications': true};
  }

  static Future<void> requestAccess() async {
    if (!_hasBinding) return;
    try {
      await channel.invokeMethod('requestAccess');
    } catch (_) {}
  }
  static Future<bool> act(int id, String action) async =>
      await channel.invokeMethod<bool>('act', {'id': id, 'action': action}) ??
      false;
  static Future<void> applyEvent(AppDatabase db, Map event) async {
    final id = event['id'];
    if (id is! int) return;
    final row = await db.reminderDao.getReminderById(id);
    if (row == null || !row.alarmEnabled) return;
    final actions = ReminderActions(db);
    if (event['action'] == 'done') {
      await actions.complete(id);
    } else if (event['action'] == 'snooze' && event['at'] is int) {
      await actions.snooze(
        id,
        DateTime.fromMillisecondsSinceEpoch(event['at']),
      );
    }
  }

  static Future<void> reconcile(AppDatabase db) async {
    List events;
    try {
      events = await channel.invokeMethod<List>('events') ?? [];
    } on MissingPluginException {
      return;
    }
    if (events.isEmpty) return;
    await db.transaction(() async {
      for (final event in events) {
        await applyEvent(db, event as Map);
      }
    });
    await channel.invokeMethod('ack', {
      'tokens': events.map((e) => e['token']).toList(),
    });
  }
}
