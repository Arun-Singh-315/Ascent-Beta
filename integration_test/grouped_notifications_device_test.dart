import 'package:ascent/core/notifications/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native medicine bundles preserve children and cancellation', (
    t,
  ) async {
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'com.arun.ascent.qa',
    );
    await t.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Notification grouping QA'))),
    );
    final service = NotificationService.instance;
    await service.initialize();
    expect(await service.areNotificationsEnabled(), isTrue);
    final plugin = FlutterLocalNotificationsPlugin();
    try {
      final at = DateTime.now().add(const Duration(seconds: 3));
      for (final id in [91001, 91002]) {
        expect(
          await service.scheduleMedicineReminderChecked(
            id: id,
            medicineName: 'QA dose $id',
            dosage: 'Recorded dose',
            instructions: 'Recorded instructions',
            scheduledAt: at,
          ),
          isTrue,
        );
      }
      expect(
        await service.scheduleReminderNotificationChecked(
          id: 91003,
          title: 'QA ordinary reminder',
          scheduledAt: at,
        ),
        isTrue,
      );
      var active = await plugin.getActiveNotifications();
      for (var i = 0; i < 40 && !active.any((n) => n.id == -1900000001); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        active = await plugin.getActiveNotifications();
      }
      expect(
        active.where((n) => n.groupKey == NotificationService.groupMedicine),
        hasLength(3),
      );
      expect(
        active.singleWhere((n) => n.id == 91001).body,
        contains('Recorded instructions'),
      );
      expect(
        active.singleWhere((n) => n.id == 91003).groupKey,
        NotificationService.groupReminders,
      );
      expect(await service.cancelChecked(91001), isTrue);
      active = await plugin.getActiveNotifications();
      expect(
        active.where((n) => n.groupKey == NotificationService.groupMedicine),
        hasLength(2),
      );
      expect(await service.cancelChecked(91002), isTrue);
      active = await plugin.getActiveNotifications();
      expect(
        active.where((n) => n.groupKey == NotificationService.groupMedicine),
        isEmpty,
      );
      expect(active.any((n) => n.id == 91003), isTrue);
    } finally {
      for (final id in [91001, 91002, 91003]) {
        await service.cancelChecked(id);
      }
    }
  });
}
