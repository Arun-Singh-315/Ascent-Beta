import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.reminderTable)
        .insert(
          ReminderTableCompanion.insert(
            title: 'Future',
            scheduledAt: DateTime.now().add(const Duration(days: 1)),
          ),
        );
    await db
        .into(db.reminderTable)
        .insert(
          ReminderTableCompanion.insert(
            title: 'Past',
            scheduledAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
        );
    await db
        .into(db.reminderTable)
        .insert(
          ReminderTableCompanion.insert(
            title: 'Inactive',
            scheduledAt: DateTime.now().add(const Duration(days: 1)),
            isActive: const Value(false),
          ),
        );
  });
  tearDown(() => db.close());
  test(
    'denied permission reports outstanding alerts without scheduling',
    () async {
      var calls = 0;
      final result = await ReminderAlertSync(
        db,
        enabled: () async => false,
        reset: () async => true,
        schedule: (_) async {
          calls++;
          return true;
        },
      ).sync();
      expect(result.total, 1);
      expect(result.complete, false);
      expect(calls, 0);
    },
  );
  test('failed reset preserves retry status and does not schedule', () async {
    var calls = 0;
    final result = await ReminderAlertSync(
      db,
      enabled: () async => true,
      reset: () async => false,
      schedule: (_) async {
        calls++;
        return true;
      },
    ).sync(replaceAll: true);
    expect(result.resetSucceeded, false);
    expect(result.complete, false);
    expect(calls, 0);
  });
  test(
    'failed scheduling can retry the same active future reminder ID',
    () async {
      final ids = <int>[];
      var fail = true;
      final sync = ReminderAlertSync(
        db,
        enabled: () async => true,
        reset: () async => true,
        schedule: (r) async {
          ids.add(r.id);
          if (fail) throw StateError('schedule failed');
          return true;
        },
      );
      expect((await sync.sync()).complete, false);
      fail = false;
      expect((await sync.sync()).complete, true);
      expect(ids, [1, 1]);
    },
  );
}
