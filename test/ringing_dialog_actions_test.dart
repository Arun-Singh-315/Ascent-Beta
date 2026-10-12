import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/alarm_lifecycle.dart';
import 'package:ascent/core/notifications/reminder_alarm_bridge.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final action in ['Done', 'Snooze 10 min']) {
    testWidgets(
      'in-app $action verifies native success and closes the ringing dialog',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        var active = true;
        Map? sent;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ReminderAlarmBridge.channel, (
              call,
            ) async {
              if (call.method == 'events') return [];
              if (call.method == 'ringing') {
                return active
                    ? [
                        {'id': 42, 'title': 'Call the accountant'},
                      ]
                    : [];
              }
              if (call.method == 'act') {
                sent = call.arguments as Map;
                active = false;
                return true;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(ReminderAlarmBridge.channel, null),
        );
        final key = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: key,
            home: const Scaffold(body: Text('Workspace')),
          ),
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        final lifecycle = AlarmLifecycle(() => db, () => key.currentContext);
        await lifecycle.refresh();
        await tester.pumpAndSettle();
        expect(find.text('Reminder alarm'), findsOneWidget);
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
        expect(sent, {
          'id': 42,
          'action': action == 'Done' ? 'done' : 'snooze',
        });
        expect(find.text('Reminder alarm'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'native action failure leaves ringing controls available to retry',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ReminderAlarmBridge.channel, (call) async {
            if (call.method == 'events') return [];
            if (call.method == 'ringing') {
              return [
                {'id': 42, 'title': 'Call the accountant'},
              ];
            }
            if (call.method == 'act') return false;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(ReminderAlarmBridge.channel, null),
      );
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: key, home: const Scaffold()),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await AlarmLifecycle(() => db, () => key.currentContext).refresh();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Reminder alarm'), findsOneWidget);
      expect(find.textContaining('Could not stop'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
