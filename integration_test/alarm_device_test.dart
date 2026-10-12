import 'package:ascent/main.dart' as app;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/notifications/reminder_alarm_bridge.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('background ringing, native Snooze, in-app Done and recovery', (
    tester,
  ) async {
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'com.arun.ascent.debug',
    );
    await (await SharedPreferences.getInstance()).clear();
    await app.main();
    for (var i = 0; i < 40 && find.text('Start now').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(find.text('Start now'));
    for (var i = 0; i < 40 && find.text('Your space').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    final container = ProviderScope.containerOf(
      tester.element(find.text('Your space')),
    );
    final db = container.read(databaseProvider);
    debugPrint('QA: ready for alarm permissions');
    for (var i = 0; i < 30; i++) {
      final access = await ReminderAlarmBridge.access();
      if (access['notifications'] == true &&
          access['exact'] == true &&
          access['fullScreen'] == true) {
        break;
      }
      await tester.pump(const Duration(seconds: 1));
    }
    final at = DateTime.now().add(const Duration(seconds: 10));
    final id = await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'QA alarm: call the accountant',
        scheduledAt: at,
        alarmEnabled: const Value(true),
      ),
    );
    expect(
      await NotificationService.instance.scheduleReminderNotificationChecked(
        id: id,
        title: 'QA alarm: call the accountant',
        scheduledAt: at,
        alarmEnabled: true,
      ),
      true,
    );
    debugPrint('QA: alarm scheduled; background app');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 15)),
    );
    expect(
      (await ReminderAlarmBridge.channel.invokeMethod<List>(
        'ringing',
      ))!.any((a) => a['id'] == id),
      true,
    );
    final sound = await ReminderAlarmBridge.channel
        .invokeMapMethod<String, dynamic>('status');
    expect(sound!['soundPlaying'], true);
    debugPrint('QA: alarm ringing; Snooze from native screen');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 14)),
    );
    await ReminderAlarmBridge.reconcile(db);
    final snoozed = (await db.reminderDao.getReminderById(id))!;
    expect(snoozed.isActive, true);
    expect(
      snoozed.scheduledAt.isAfter(
        DateTime.now().add(const Duration(minutes: 8)),
      ),
      true,
    );
    expect(
      await ReminderAlarmBridge.channel.invokeMethod<List>('ringing'),
      isEmpty,
    );
    expect(
      (await ReminderAlarmBridge.channel.invokeMapMethod<String, dynamic>(
        'status',
      ))!['soundPlaying'],
      false,
    );
    final again = DateTime.now().add(const Duration(seconds: 8));
    await db.reminderDao.updateReminder(
      snoozed.toCompanion(true).copyWith(scheduledAt: Value(again)),
    );
    expect(
      await ReminderAlarmBridge.schedule(
        id: id,
        title: 'QA alarm: Done stops ringing',
        at: again,
      ),
      true,
    );
    debugPrint('QA: second alarm scheduled');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 12)),
    );
    debugPrint('QA: second alarm ringing; Done from native screen');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 14)),
    );
    await ReminderAlarmBridge.reconcile(db);
    expect((await db.reminderDao.getReminderById(id))!.isActive, false);
    expect(
      await ReminderAlarmBridge.channel.invokeMethod<List>('ringing'),
      isEmpty,
    );
    expect(
      await ReminderAlarmBridge.channel.invokeMethod<List>('events'),
      isEmpty,
    );
    expect(
      (await ReminderAlarmBridge.channel.invokeMapMethod<String, dynamic>(
        'status',
      ))!['soundPlaying'],
      false,
    );
    debugPrint('QA: native Snooze/Done and database recovery verified');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
