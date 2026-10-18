import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/home_capture_service.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/core/notifications/reminder_alarm_bridge.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'check-in device request carries actions and its exact occurrence back to Home',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final requests = <Map>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize' ||
            call.method == 'areNotificationsEnabled') {
          return true;
        }
        if (call.method == 'zonedSchedule') requests.add(call.arguments as Map);
        return null;
      });
      messenger.setMockMethodCallHandler(
        ReminderAlarmBridge.channel,
        (_) async => null,
      );
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Call Mum'),
        );
        final source = (await db.thoughtDao.getThoughtById(id))!;
        final at = DateTime.now().add(const Duration(hours: 1));
        final plan = await HomeCaptureService(db).schedule(
          source: source,
          title: 'Call Mum',
          at: at,
          checkInAt: at.add(const Duration(minutes: 20)),
        );
        expect(await scheduleReminderOnDevice(db, plan.reminder), isTrue);
        expect(await scheduleReminderOnDevice(db, plan.checkIn!), isTrue);
        expect(requests, hasLength(2));
        expect(requests.first['payload'], '/home');
        final check = requests.last;
        expect(
          check['payload'],
          '/home?checkin=${plan.checkIn!.id}&at=${plan.checkIn!.scheduledAt.millisecondsSinceEpoch}',
        );
        final details = check['platformSpecifics'] as Map;
        final actions = details['actions'] as List;
        expect(actions.map((a) => (a as Map)['id']).toList(), [
          'home_done',
          'home_later',
          'home_skip',
        ]);
        expect(
          actions.every((a) => (a as Map)['showsUserInterface'] == true),
          isTrue,
        );
      } finally {
        messenger.setMockMethodCallHandler(channel, null);
        messenger.setMockMethodCallHandler(ReminderAlarmBridge.channel, null);
        debugDefaultTargetPlatformOverride = null;
        await db.close();
      }
    },
  );
}
