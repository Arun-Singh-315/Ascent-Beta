import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/reminders/widgets/in_app_reminder_dialog.dart';

void main() {
  testWidgets(
    'InAppReminderDialog displays reminder title and snooze buttons',
    (tester) async {
      final reminder = Reminder(
        alarmEnabled: false,
        id: 101,
        title: 'Review System Design Chapter 4',
        scheduledAt: DateTime(2026, 10, 9, 14, 0),
        isActive: true,
        createdAt: DateTime(2026, 10, 9, 10, 0),
        alertSyncPending: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: InAppReminderDialog(reminder: reminder)),
          ),
        ),
      );

      expect(find.text('REMINDER DUE'), findsOneWidget);
      expect(find.text('Review System Design Chapter 4'), findsOneWidget);
      expect(find.text('+10m'), findsOneWidget);
      expect(find.text('+1h'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('Mark as Done'), findsOneWidget);
    },
  );
}
