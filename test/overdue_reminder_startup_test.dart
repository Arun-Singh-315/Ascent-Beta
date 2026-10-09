import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  late ReminderDao reminderDao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    reminderDao = ReminderDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Overdue Reminders on Startup Tests', () {
    test('getOverdueActiveReminders returns only active reminders with scheduledAt before now', () async {
      final now = DateTime.now();

      // 1. Overdue and active (must be returned)
      final id1 = await reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Pay Electricity Bill',
          scheduledAt: now.subtract(const Duration(hours: 2)),
          isActive: const drift.Value(true),
        ),
      );

      // 2. Overdue but marked inactive / done (must NOT be returned)
      await reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Morning Yoga',
          scheduledAt: now.subtract(const Duration(hours: 4)),
          isActive: const drift.Value(false),
        ),
      );

      // 3. Upcoming in future and active (must NOT be returned)
      await reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Evening Study session',
          scheduledAt: now.add(const Duration(hours: 3)),
          isActive: const drift.Value(true),
        ),
      );

      final overdueList = await reminderDao.getOverdueActiveReminders();
      expect(overdueList.length, 1);
      expect(overdueList.first.id, id1);
      expect(overdueList.first.title, 'Pay Electricity Bill');
    });
  });
}
