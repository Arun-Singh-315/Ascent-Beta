import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/notifications/notification_service.dart';

void main() {
  group('NotificationService.destinationForPayload', () {
    test('routes standard screens directly without falling back to /home', () {
      expect(
        NotificationService.destinationForPayload('/ai-assistant'),
        '/ai-assistant',
      );
      expect(NotificationService.destinationForPayload('/vault'), '/vault');
      expect(NotificationService.destinationForPayload('/today'), '/today');
      expect(NotificationService.destinationForPayload('/things'), '/things');
      expect(NotificationService.destinationForPayload('/history'), '/history');
      expect(NotificationService.destinationForPayload('/plans'), '/plans');
      expect(
        NotificationService.destinationForPayload('/promises'),
        '/promises',
      );
      expect(
        NotificationService.destinationForPayload('/medicine'),
        '/medicine',
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
        NotificationService.destinationForPayload('/calendar'),
        '/calendar',
      );
      expect(NotificationService.destinationForPayload('/travel'), '/travel');
      expect(NotificationService.destinationForPayload('/you'), '/you');
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
          '/things?focus=42&mode=wrapup',
        ),
        '/things?focus=42&mode=wrapup',
      );
      expect(
        NotificationService.destinationForPayload('/history?module=hydration'),
        '/history?module=hydration',
      );
      expect(
        NotificationService.destinationForPayload(
          '/home?checkin=12&at=1700000000&occ=morning_chai&answer=done',
        ),
        '/home?checkin=12&at=1700000000&occ=morning_chai&answer=done',
      );
    });

    test('supports ascent:// custom scheme deep links', () {
      expect(
        NotificationService.destinationForPayload(
          'ascent://open/things?focus=99',
        ),
        '/things?focus=99',
      );
      expect(
        NotificationService.destinationForPayload('ascent://things'),
        '/things',
      );
      expect(
        NotificationService.destinationForPayload('ascent://open/history'),
        '/history',
      );
      expect(
        NotificationService.destinationForPayload('ascent://today?task=12'),
        '/today?task=12',
      );
    });

    test('retired screens open Home instead of a dead page', () {
      for (final dead in [
        '/learning',
        '/walk',
        '/chai-break',
        '/momentum',
        '/momentum-onboarding',
        '/momentum/onboarding',
        '/book-reader',
        '/pipeline',
        '/pipeline/101',
        '/analytics',
        '/analytics/series/24',
        '/study-plan',
        '/study-plan/course/dsa101',
        '/dsa',
        '/interview-prep',
        '/consistency',
        '/resume-vault',
      ]) {
        expect(
          NotificationService.destinationForPayload(dead),
          '/home',
          reason: dead,
        );
      }
    });

    test(
      'safely falls back to /home for invalid, malicious, or empty payloads',
      () {
        expect(NotificationService.destinationForPayload(null), '/home');
        expect(NotificationService.destinationForPayload(''), '/home');
        expect(NotificationService.destinationForPayload('   '), '/home');
        expect(
          NotificationService.destinationForPayload('/unregistered/route'),
          '/home',
        );
        expect(
          NotificationService.destinationForPayload(
            'https://malicious.site/today',
          ),
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
      },
    );
  });
}
