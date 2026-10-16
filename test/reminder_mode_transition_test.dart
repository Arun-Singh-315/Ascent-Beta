import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/notifications/reminder_alarm_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'switching to Alarm cancels ordinary alert and legacy follow-up before scheduling',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final operations = <String>[];
      const notificationChannel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationChannel, (call) async {
            if (call.method == 'initialize') return true;
            if (call.method == 'areNotificationsEnabled') return true;
            if (call.method == 'getNotificationAppLaunchDetails') return null;
            if (call.method == 'cancel') {
              operations.add('cancel:${(call.arguments as Map)['id']}');
            }
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ReminderAlarmBridge.channel, (call) async {
            if (call.method == 'schedule') {
              operations.add('alarm');
              return true;
            }
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(notificationChannel, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ReminderAlarmBridge.channel, null);
      });
      final ok = await NotificationService.instance
          .scheduleReminderNotificationChecked(
            id: 12,
            title: 'Call',
            scheduledAt: DateTime.now().add(const Duration(hours: 1)),
            alarmEnabled: true,
          );
      expect(ok, true);
      expect(operations, [
        'cancel:12',
        'cancel:${12 + NotificationService.followUpIdOffset}',
        'alarm',
      ]);
    },
  );
}
