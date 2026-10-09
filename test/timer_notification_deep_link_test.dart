import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/walk/walk_tracking_service.dart';

void main() {
  group('Timer Notification Deep Link and Action Tests', () {
    test('Notification tap with payload invokes onNotificationNavigate callback for all 4 timer domains', () {
      String? routedPath;
      NotificationService.onNotificationNavigate = (path) {
        routedPath = path;
      };

      // 1. Walk Timer
      const walkResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/walk',
      );
      NotificationService.instance.handleNotificationResponse(walkResponse);
      expect(routedPath, equals('/walk'));

      // 2. Activity / Todo Focus Timer
      const focusResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/focus',
      );
      NotificationService.instance.handleNotificationResponse(focusResponse);
      expect(routedPath, equals('/focus'));

      // 3. Learning Hub Lecture Timer
      const learningResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/learning',
      );
      NotificationService.instance.handleNotificationResponse(learningResponse);
      expect(routedPath, equals('/learning'));

      // 4. Chai & Coffee Break Timer
      const chaiResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/chai-break',
      );
      NotificationService.instance.handleNotificationResponse(chaiResponse);
      expect(routedPath, equals('/chai-break'));
    });

    test('Action button taps invoke onNotificationAction and NEVER trigger onNotificationNavigate', () {
      String? triggeredAction;
      String? triggeredPayload;
      String? navigatedRoute;

      NotificationService.onNotificationAction = (actionId, payload) {
        triggeredAction = actionId;
        triggeredPayload = payload;
      };
      NotificationService.onNotificationNavigate = (route) {
        navigatedRoute = route;
      };

      const actionResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotificationAction,
        actionId: 'action_pause',
        payload: '/learning',
      );

      NotificationService.instance.handleNotificationResponse(actionResponse);

      // Action must be dispatched
      expect(triggeredAction, equals('action_pause'));
      expect(triggeredPayload, equals('/learning'));

      // Navigation must NEVER be triggered by an action tap (prevents app foregrounding & flickering)
      expect(navigatedRoute, isNull);
    });

    test('IsolateNameServer port name matches NotificationService.isolatePortName', () {
      expect(NotificationService.isolatePortName, equals('ascent_notification_actions_port'));
    });

    test('Buffered cold start navigation flushes immediately upon handler registration', () {
      NotificationService.onNotificationNavigate = null;

      const launchResponse = NotificationResponse(
        notificationResponseType: NotificationResponseType.selectedNotification,
        payload: '/learning',
      );

      // Notification arrives before router handler is mounted
      NotificationService.instance.handleNotificationResponse(launchResponse);

      String? lateRoutedPath;
      NotificationService.setNotificationNavigateHandler((path) {
        lateRoutedPath = path;
      });

      expect(lateRoutedPath, equals('/learning'));
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
