import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/notifications/notification_service.dart';

void main() {
  group('NotificationService.destinationForPayload', () {
    test('routes standard screens directly without falling back to /home', () {
      expect(
        NotificationService.destinationForPayload('/ai-assistant'),
        '/ai-assistant',
      );
      expect(
        NotificationService.destinationForPayload('/vault'),
        '/vault',
      );
      expect(
        NotificationService.destinationForPayload('/today'),
        '/today',
      );
      expect(
        NotificationService.destinationForPayload('/plans'),
        '/plans',
      );
      expect(
        NotificationService.destinationForPayload('/promises'),
        '/promises',
      );
      expect(
        NotificationService.destinationForPayload('/medicine'),
        '/medicine',
      );
      expect(
        NotificationService.destinationForPayload('/walk'),
        '/walk',
      );
      expect(
        NotificationService.destinationForPayload('/chai-break'),
        '/chai-break',
      );
      expect(
        NotificationService.destinationForPayload('/hydration'),
        '/hydration',
      );
      expect(
        NotificationService.destinationForPayload('/thought-wall'),
        '/thought-wall',
      );
      expect(
        NotificationService.destinationForPayload('/reminders'),
        '/reminders',
      );
      expect(
        NotificationService.destinationForPayload('/book-reader'),
        '/book-reader',
      );
      expect(
        NotificationService.destinationForPayload('/momentum'),
        '/momentum',
      );
      expect(
        NotificationService.destinationForPayload('/momentum-onboarding'),
        '/momentum-onboarding',
      );
      expect(
        NotificationService.destinationForPayload('/momentum/onboarding'),
        '/momentum/onboarding',
      );
    });

    test('preserves query parameters on valid destination routes', () {
      expect(
        NotificationService.destinationForPayload(
          '/ai-assistant?prompt=Review+my+commitments',
        ),
        '/ai-assistant?prompt=Review+my+commitments',
      );
      expect(
        NotificationService.destinationForPayload('/reminders?reminder=42'),
        '/reminders?reminder=42',
      );
      expect(
        NotificationService.destinationForPayload('/today?task=108'),
        '/today?task=108',
      );
      expect(
        NotificationService.destinationForPayload('/plans?id=77'),
        '/plans?id=77',
      );
      expect(
        NotificationService.destinationForPayload('/thought-wall?thought=5'),
        '/thought-wall?thought=5',
      );
      expect(
        NotificationService.destinationForPayload(
          '/home?checkin=12&at=1700000000&occ=morning_chai&answer=done',
        ),
        '/home?checkin=12&at=1700000000&occ=morning_chai&answer=done',
      );
    });

    test('supports recognized sub-paths', () {
      expect(
        NotificationService.destinationForPayload('/pipeline/101'),
        '/pipeline/101',
      );
      expect(
        NotificationService.destinationForPayload('/analytics/series/24'),
        '/analytics/series/24',
      );
      expect(
        NotificationService.destinationForPayload('/study-plan/course/dsa101'),
        '/study-plan/course/dsa101',
      );
    });

    test('safely falls back to /home for invalid, malicious, or empty payloads', () {
      expect(NotificationService.destinationForPayload(null), '/home');
      expect(NotificationService.destinationForPayload(''), '/home');
      expect(NotificationService.destinationForPayload('   '), '/home');
      expect(NotificationService.destinationForPayload('/unregistered/route'), '/home');
      expect(
        NotificationService.destinationForPayload('https://malicious.site/today'),
        '/home',
      );
      expect(
        NotificationService.destinationForPayload('javascript:alert(1)'),
        '/home',
      );
      expect(
        NotificationService.destinationForPayload('random_text_not_a_route'),
        '/home',
      );
    });
  });
}
