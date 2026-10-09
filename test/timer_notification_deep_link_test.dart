import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/walk/walk_tracking_service.dart';

void main() {
  group('Timer Notification Deep Link and Action Tests', () {
    test('Notification tap with payload invokes onNotificationNavigate callback', () {
      String? routedPath;
      NotificationService.onNotificationNavigate = (path) {
        routedPath = path;
      };

      const response = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/walk',
      );

      NotificationService.instance.handleNotificationResponse(response);
      expect(routedPath, equals('/walk'));

      const focusResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/focus',
      );

      NotificationService.instance.handleNotificationResponse(focusResponse);
      expect(routedPath, equals('/focus'));

      const chaiResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/chai-break',
      );

      NotificationService.instance.handleNotificationResponse(chaiResponse);
      expect(routedPath, equals('/chai-break'));
    });

    test('Notification action tap triggers onNotificationAction callback', () {
      String? triggeredAction;
      String? triggeredPayload;

      NotificationService.onNotificationAction = (actionId, payload) {
        triggeredAction = actionId;
        triggeredPayload = payload;
      };

      const actionResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        actionId: 'action_pause',
        payload: '/walk',
      );

      NotificationService.instance.handleNotificationResponse(actionResponse);
      expect(triggeredAction, equals('action_pause'));
      expect(triggeredPayload, equals('/walk'));
    });

    test('Buffered cold start navigation flushes immediately upon handler registration', () {
      NotificationService.onNotificationNavigate = null;

      const launchResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/walk',
      );

      // Notification arrives before router handler is mounted
      NotificationService.instance.handleNotificationResponse(launchResponse);

      String? lateRoutedPath;
      NotificationService.setNotificationNavigateHandler((path) {
        lateRoutedPath = path;
      });

      expect(lateRoutedPath, equals('/walk'));
    });

    test('Buffered cold start action flushes immediately upon handler registration', () {
      NotificationService.onNotificationAction = null;

      const launchActionResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        actionId: 'action_pause',
        payload: '/focus',
      );

      NotificationService.instance.handleNotificationResponse(launchActionResponse);

      String? lateActionId;
      String? latePayload;
      NotificationService.setNotificationActionHandler((actionId, payload) {
        lateActionId = actionId;
        latePayload = payload;
      });

      expect(lateActionId, equals('action_pause'));
      expect(latePayload, equals('/focus'));
    });

    test('WalkTracking duration computation accounts for elapsed wall-clock and pauses correctly', () {
      final startedAt = DateTime(2026, 10, 9, 10, 0, 0);
      final now1 = DateTime(2026, 10, 9, 10, 15, 0); // 15 minutes later = 900s
      final durationNoPause = WalkTrackingNotifier.computeActiveDurationSeconds(
        startedAt: startedAt,
        now: now1,
        pausedSeconds: 0,
      );
      expect(durationNoPause, equals(900));

      // With 120 seconds paused
      final durationWithPause = WalkTrackingNotifier.computeActiveDurationSeconds(
        startedAt: startedAt,
        now: now1,
        pausedSeconds: 120,
      );
      expect(durationWithPause, equals(780));
    });
  });
}
