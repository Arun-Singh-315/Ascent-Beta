import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/reminder_alarm_bridge.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  test(
    'quiet remains the default and native actions never create missing reminders',
    () async {
      final id = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Quiet',
          scheduledAt: DateTime.now(),
        ),
      );
      expect((await db.reminderDao.getReminderById(id))!.alarmEnabled, false);
      await ReminderAlarmBridge.applyEvent(db, {
        'id': 999,
        'action': 'done',
        'token': 'missing',
      });
      expect((await db.reminderDao.watchAllReminders().first), hasLength(1));
    },
  );
  test('absolute snooze recovery and repeated Done are idempotent', () async {
    final id = await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Alarm',
        scheduledAt: DateTime.now(),
        alarmEnabled: const Value(true),
      ),
    );
    final at = DateTime(2026, 10, 12, 11, 20);
    final event = {
      'id': id,
      'action': 'snooze',
      'at': at.millisecondsSinceEpoch,
      'token': 'once',
    };
    await ReminderAlarmBridge.applyEvent(db, event);
    await ReminderAlarmBridge.applyEvent(db, event);
    expect((await db.reminderDao.getReminderById(id))!.scheduledAt, at);
    await ReminderAlarmBridge.applyEvent(db, {'id': id, 'action': 'done'});
    await ReminderAlarmBridge.applyEvent(db, {'id': id, 'action': 'done'});
    expect((await db.reminderDao.getReminderById(id))!.isActive, false);
  });
}
