import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/notifications/boost_notification_copy.dart';

void main() {
  group('Category and Intent Aware Reminder Notification Copy Tests', () {
    test('Payment & Finance reminders produce polite payment copy, not study/work copy', () {
      final samples = [
        'HDFC SI',
        'Pay SIP for Mutual Fund',
        'Electricity Bill Due',
        'Monthly Rent Payment',
        'Credit Card Bill Payment',
        'Pay EMI on time',
        'Recharge broadband',
        'School fee payment',
      ];

      for (final title in samples) {
        final msg = BoostNotificationCopy.forScheduledTask(title);
        expect(msg.title.toLowerCase().contains('pay') ||
               msg.title.toLowerCase().contains('payment') ||
               msg.summary.toLowerCase().contains('pay'), isTrue,
               reason: 'Failed for title: $title');
        expect(msg.body.toLowerCase().contains('pay') ||
               msg.body.toLowerCase().contains('due') ||
               msg.body.toLowerCase().contains('bill') ||
               msg.body.toLowerCase().contains('financ'), isTrue,
               reason: 'Failed for title: $title');
        // Must NOT contain study/sit down commands
        expect(msg.body.toLowerCase().contains('sit down, open it up'), isFalse);
      }
    });

    test('Medicine & Health reminders produce healthcare copy, not deep work copy', () {
      final samples = [
        'Take BP medicine',
        'Thyroid tablet morning',
        'Evening Vitamin D capsule',
        'Cough syrup 10ml',
        'Eye drops dose',
      ];

      for (final title in samples) {
        final msg = BoostNotificationCopy.forScheduledTask(title);
        expect(msg.title.toLowerCase().contains('medicine') ||
               msg.title.toLowerCase().contains('health') ||
               msg.title.toLowerCase().contains('dose') ||
               msg.summary.toLowerCase().contains('health'), isTrue,
               reason: 'Failed for title: $title');
        expect(msg.body.toLowerCase().contains('health') ||
               msg.body.toLowerCase().contains('take') ||
               msg.body.toLowerCase().contains('medicine'), isTrue,
               reason: 'Failed for title: $title');
        expect(msg.body.toLowerCase().contains('sit down, open it up'), isFalse);
      }
    });

    test('Call & People reminders produce communication copy', () {
      final samples = [
        'Call Mom',
        'Meeting with team',
        'Ring client for project update',
      ];

      for (final title in samples) {
        final msg = BoostNotificationCopy.forScheduledTask(title);
        expect(msg.title.toLowerCase().contains('call') ||
               msg.title.toLowerCase().contains('connect') ||
               msg.title.toLowerCase().contains('reminder'), isTrue,
               reason: 'Failed for title: $title, title was: ${msg.title}');
        expect(msg.body.toLowerCase().contains('sit down, open it up'), isFalse);
      }
    });

    test('Study, Coding and General tasks retain energetic 5-minute rule momentum boost', () {
      final samples = [
        'Study Spring Boot architecture',
        'Solve 3 LeetCode problems',
        'Flutter animation revision',
        'Gym workout session',
      ];

      for (final title in samples) {
        final msg = BoostNotificationCopy.forScheduledTask(title);
        expect(msg.body.toLowerCase().contains('5 min') ||
               msg.body.toLowerCase().contains('momentum') ||
               msg.body.toLowerCase().contains('timer') ||
               msg.body.toLowerCase().contains('hardest part') ||
               msg.summary.toLowerCase().contains('5-min'), isTrue,
               reason: 'Failed for title: $title, body was: ${msg.body}, summary was: ${msg.summary}');
      }
    });

    test('Follow-up nudges are also category aware', () {
      final paymentFollowUp = BoostNotificationCopy.forMissingYouFollowUp('HDFC SIP');
      expect(paymentFollowUp.body.toLowerCase().contains('pay') ||
             paymentFollowUp.body.toLowerCase().contains('due') ||
             paymentFollowUp.body.toLowerCase().contains('pending'), isTrue);

      final medicineFollowUp = BoostNotificationCopy.forMissingYouFollowUp('BP Medicine');
      expect(medicineFollowUp.body.toLowerCase().contains('medicine') ||
             medicineFollowUp.body.toLowerCase().contains('health'), isTrue);
    });
  });
}
