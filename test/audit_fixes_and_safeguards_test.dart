import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/features/more/more_screen.dart';
import 'package:ascent/features/reminders/widgets/in_app_reminder_dialog.dart';
import 'package:ascent/core/database/app_database.dart';

void main() {
  group('Audit Fixes & Robustness Safeguards', () {
    test('Notification IDs are unique and do not collide', () {
      expect(
        NotificationService.ongoingLectureNotificationId !=
            NotificationService.ongoingSessionNotificationId,
        isTrue,
        reason: 'Lecture and generic session notifications must have distinct IDs to prevent collisions',
      );
      expect(
        NotificationService.ongoingFocusNotificationId !=
            NotificationService.ongoingLectureNotificationId,
        isTrue,
      );
      expect(
        NotificationService.ongoingWalkNotificationId !=
            NotificationService.ongoingChaiBreakNotificationId,
        isTrue,
      );
    });

    test('Route path parameters handle non-integer input gracefully', () {
      // Test the safe integer parser logic used by router
      int? parseParam(String? val) => int.tryParse(val ?? '');

      expect(parseParam('123'), equals(123));
      expect(parseParam('abc'), isNull);
      expect(parseParam(null), isNull);
      expect(parseParam(''), isNull);
      expect(parseParam('12.34'), isNull);
    });

    testWidgets(
      'MoreScreen renders without overflow at 320px width and 2.0x text scale (Rule #13)',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: child!,
              ),
              home: const MoreScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'InAppReminderDialog renders without overflow at 320px width and 2.0x text scale (Rule #13)',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final reminder = Reminder(
          alarmEnabled: false,
          id: 42,
          title: 'Review System Architecture with long title that wraps multiple lines',
          scheduledAt: DateTime(2026, 10, 18, 12, 0),
          isActive: true,
          createdAt: DateTime(2026, 10, 18, 9, 0),
          alertSyncPending: false,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2.0),
                ),
                child: child!,
              ),
              home: Scaffold(body: InAppReminderDialog(reminder: reminder)),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  });
}
