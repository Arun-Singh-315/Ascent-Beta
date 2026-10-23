import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/notifications/reminder_alarm_bridge.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'medicine, reminders and plans retain individual alerts in distinct bundles',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const notifications = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      const groups = MethodChannel('ascent/notification-groups');
      final requests = <Map>[];
      final operations = <MethodCall>[];
      messenger.setMockMethodCallHandler(notifications, (call) async {
        if (call.method == 'initialize' ||
            call.method == 'areNotificationsEnabled') {
          return true;
        }
        if (call.method == 'zonedSchedule') requests.add(call.arguments as Map);
        return null;
      });
      messenger.setMockMethodCallHandler(groups, (call) async {
        operations.add(call);
        return null;
      });
      messenger.setMockMethodCallHandler(
        ReminderAlarmBridge.channel,
        (_) async => null,
      );
      try {
        final service = NotificationService.instance;
        final at = DateTime.now().add(const Duration(hours: 1));
        expect(
          await service.scheduleMedicineReminderChecked(
            id: 41,
            medicineName: 'Recorded medicine',
            dosage: 'Recorded dose',
            instructions: 'Recorded instructions',
            scheduledAt: at,
          ),
          isTrue,
        );
        expect(
          await service.scheduleMedicineReminderChecked(
            id: 42,
            medicineName: 'Second medicine',
            dosage: 'Second dose',
            instructions: '',
            scheduledAt: at,
          ),
          isTrue,
        );
        expect(
          await service.scheduleReminderNotificationChecked(
            id: 43,
            title: 'An ordinary reminder',
            scheduledAt: at,
          ),
          isTrue,
        );
        expect(
          await service.scheduleReminderNotificationChecked(
            id: 44,
            title: 'Plan check-in',
            scheduledAt: at,
            destination: '/home?checkin=44',
            checkIn: true,
          ),
          isTrue,
        );
        expect(requests, hasLength(4));
        expect(requests.map((r) => r['id']), [41, 42, 43, 44]);
        expect(
          requests.map((r) => (r['platformSpecifics'] as Map)['groupKey']),
          [
            NotificationService.groupMedicine,
            NotificationService.groupMedicine,
            NotificationService.groupReminders,
            NotificationService.groupPlans,
          ],
        );
        expect(requests.first['title'], 'Recorded medicine · Recorded dose');
        expect(requests.first['body'], contains('Recorded instructions'));
        expect(requests.first['payload'], '/medicine');
        final summarySchedules = operations
            .where((op) => op.method == 'schedule')
            .toList();
        expect(summarySchedules, hasLength(4));
        expect(
          summarySchedules.every(
            (op) =>
                (op.arguments as Map)['at'] == at.millisecondsSinceEpoch + 1500,
          ),
          isTrue,
        );
        expect(await service.cancelChecked(41), isTrue);
        expect(operations.last.method, 'cancel');
        expect((operations.last.arguments as Map)['id'], 41);
      } finally {
        messenger.setMockMethodCallHandler(notifications, null);
        messenger.setMockMethodCallHandler(groups, null);
        messenger.setMockMethodCallHandler(ReminderAlarmBridge.channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
