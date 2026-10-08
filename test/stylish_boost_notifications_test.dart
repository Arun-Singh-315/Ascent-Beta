import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/notifications/boost_notification_copy.dart';
import 'package:ascent/core/notifications/notification_service.dart';

void main() {
  group('Stylish Raw Boost Notifications Tests', () {
    test('BoostNotificationCopy generates energetic 5-minute rule prompts for scheduled tasks', () {
      final message = BoostNotificationCopy.forScheduledTask('Solve 3 LeetCode Mediums');

      expect(message.title, contains('Solve 3 LeetCode Mediums'));
      expect(message.body, isNotEmpty);
      expect(message.summary.isNotEmpty, isTrue);
    });

    test('BoostNotificationCopy generates brotherly "Missing you" follow-up nudges', () {
      final followUp = BoostNotificationCopy.forMissingYouFollowUp('System Design Chapter 4');

      expect(followUp.title, isNotEmpty);
      expect(followUp.body, contains('System Design Chapter 4'));
      expect(followUp.summary, isNotEmpty);
    });

    test('Mid-day and Evening Streak Guardian copy have non-empty titles and bodies', () {
      final mid = BoostNotificationCopy.forMiddayCheck();
      final evening = BoostNotificationCopy.forEveningStreakGuardian();

      expect(mid.title, isNotEmpty);
      expect(mid.body, isNotEmpty);
      expect(evening.title.toLowerCase(), contains('streak'));
      expect(
        evening.body.toLowerCase().contains('5 min') ||
            evening.body.toLowerCase().contains('streak'),
        isTrue,
      );
    });

    test('Test boost copy is punchy and highlights 5-minute rule', () {
      final testBoost = BoostNotificationCopy.forTestBoost();

      expect(testBoost.title, contains('ACTIVE'));
      expect(testBoost.body, contains('5 minutes'));
      expect(testBoost.summary, contains('Raw Boost'));
    });

    test('NotificationService uses consistent follow-up offset for accountability pairing', () {
      expect(NotificationService.followUpIdOffset, 500000);
      const reminderId = 42;
      const followUpId = reminderId + NotificationService.followUpIdOffset;
      expect(followUpId, 500042);
    });
  });
}
