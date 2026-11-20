import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/reminders/widgets/in_app_reminder_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

void main() {
  for (final dark in [false, true]) {

    testWidgets('Reminder popup retains every action at 2x text ($dark)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: InAppReminderDialog(
                reminder: Reminder(
                  id: 5,
                  title: 'Review your system design notes before the interview',
                  scheduledAt: DateTime(2026),
                  createdAt: DateTime(2026),
                  alarmEnabled: false,
                  isActive: true,
                  alertSyncPending: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final label in ['+10m', '+1h', 'Tomorrow', 'Mark as Done']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

  }
}
