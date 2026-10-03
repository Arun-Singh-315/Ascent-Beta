import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('V3 — ReminderDao Tests', () {
    test('Can insert, query upcoming, toggle, and delete reminder', () async {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(hours: 3));
      final pastDate = now.subtract(const Duration(hours: 2));

      // Insert upcoming reminder
      final id1 = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Review System Design notes',
          scheduledAt: futureDate,
        ),
      );
      expect(id1, isNonZero);

      // Insert past reminder
      final id2 = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Morning check-in',
          scheduledAt: pastDate,
        ),
      );
      expect(id2, isNonZero);

      // Verify all reminders
      final all = await db.reminderDao.watchAllReminders().first;
      expect(all.length, 2);

      // Verify upcoming reminders filter
      final upcoming = await db.reminderDao.watchUpcomingReminders().first;
      expect(upcoming.length, 1);
      expect(upcoming.first.title, 'Review System Design notes');

      // Toggle inactive via updateReminder
      final rem1 = await db.reminderDao.getReminderById(id1);
      expect(rem1, isNotNull);
      await db.reminderDao.updateReminder(
        rem1!.toCompanion(true).copyWith(isActive: const drift.Value(false)),
      );
      final updatedUpcoming = await db.reminderDao.watchUpcomingReminders().first;
      expect(updatedUpcoming, isEmpty);

      // Delete reminder
      final deletedCount = await db.reminderDao.deleteReminder(id1);
      expect(deletedCount, 1);
      final remaining = await db.reminderDao.watchAllReminders().first;
      expect(remaining.length, 1);
      expect(remaining.first.id, id2);
    });

    test('watchNextReminder stream emits single nearest active future reminder', () async {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(days: 1));

      final id = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Interview with Stripe',
          scheduledAt: futureDate,
        ),
      );

      final next = await db.reminderDao.watchNextReminder().first;
      expect(next, isNotNull);
      expect(next!.title, 'Interview with Stripe');

      await db.reminderDao.deleteReminder(id);
      final nextAfterDelete = await db.reminderDao.watchNextReminder().first;
      expect(nextAfterDelete, isNull);
    });
  });

  group('V3 — Time Session Continuity (04:03 Timer Guarantee)', () {
    test('getTodayActiveOrPausedSessionForTask preserves elapsed duration across sessions', () async {
      final now = DateTime.now();
      const storedDurationSeconds = 243; // 4 minutes 3 seconds

      // Insert a paused session for taskId 42 with 243 seconds
      final sessionId = await db.into(db.timeSessionTable).insert(
        TimeSessionTableCompanion.insert(
          categoryId: 1,
          activityType: const drift.Value('DSA'),
          label: 'LeetCode #15 - 3Sum',
          startedAt: now.subtract(const Duration(minutes: 10)),
          status: const drift.Value('paused'),
          linkedTaskId: const drift.Value(42),
          durationSeconds: const drift.Value(storedDurationSeconds),
        ),
      );
      expect(sessionId, isNonZero);

      // Retrieve via getTodayActiveOrPausedSessionForTask
      final existingSession = await db.timeSessionDao.getTodayActiveOrPausedSessionForTask(42);
      expect(existingSession, isNotNull);
      expect(existingSession!.id, sessionId);
      expect(existingSession.durationSeconds, 243);
      expect(existingSession.label, 'LeetCode #15 - 3Sum');

      // Retrieve via label fallback
      final byLabel = await db.timeSessionDao.getTodayActiveOrPausedSessionByLabel('LeetCode #15 - 3Sum');
      expect(byLabel, isNotNull);
      expect(byLabel!.durationSeconds, 243);
    });

    test('Completed session does not get picked up as active/paused session', () async {
      final now = DateTime.now();
      await db.into(db.timeSessionTable).insert(
        TimeSessionTableCompanion.insert(
          categoryId: 1,
          activityType: const drift.Value('DSA'),
          label: 'Completed Task',
          startedAt: now.subtract(const Duration(minutes: 30)),
          endedAt: drift.Value(now.subtract(const Duration(minutes: 5))),
          status: const drift.Value('completed'),
          linkedTaskId: const drift.Value(99),
          durationSeconds: const drift.Value(1500),
        ),
      );

      final result = await db.timeSessionDao.getTodayActiveOrPausedSessionForTask(99);
      expect(result, isNull);
    });
  });

  group('V3 — Multi Upcoming Interview Rounds', () {
    test('Can manage multiple scheduled rounds and delete specific round', () async {
      final date1 = DateTime.now().add(const Duration(days: 2));
      final date2 = DateTime.now().add(const Duration(days: 5));

      final id1 = await db.upcomingInterviewDao.insertInterview(
        UpcomingInterviewTableCompanion.insert(
          companyName: 'Meta',
          interviewDate: date1,
          notes: const drift.Value('Screening Call'),
        ),
      );

      final id2 = await db.upcomingInterviewDao.insertInterview(
        UpcomingInterviewTableCompanion.insert(
          companyName: 'Google',
          interviewDate: date2,
          notes: const drift.Value('Technical Deep-dive'),
        ),
      );

      final all = await db.upcomingInterviewDao.watchUpcomingInterviews().first;
      expect(all.length, 2);
      expect(all.first.companyName, 'Meta');
      expect(all.last.companyName, 'Google');

      // Next interview is the earliest one (Meta)
      final next = await db.upcomingInterviewDao.getNextInterview();
      expect(next, isNotNull);
      expect(next!.companyName, 'Meta');

      // Delete Meta round
      await db.upcomingInterviewDao.deleteInterview(id1);

      final updatedAll = await db.upcomingInterviewDao.watchUpcomingInterviews().first;
      expect(updatedAll.length, 1);
      expect(updatedAll.first.id, id2);

      // Now next interview is Google
      final nextAfterDelete = await db.upcomingInterviewDao.getNextInterview();
      expect(nextAfterDelete!.companyName, 'Google');
    });
  });
}
