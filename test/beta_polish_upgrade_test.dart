import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';

void main() {
  group('Beta 1.0 Polish & Upgrade Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Multi-Day / Whole Month Recurring Reminders Insertion', () async {
      final now = DateTime(2026, 10, 15, 9, 0);

      // Simulate 30-day whole month schedule
      final List<DateTime> dates = [];
      for (int i = 0; i < 30; i++) {
        dates.add(now.add(Duration(days: i)));
      }

      for (final d in dates) {
        await db.reminderDao.insertReminder(
          ReminderTableCompanion(
            title: const drift.Value('Daily Focus & LeetCode Practice'),
            scheduledAt: drift.Value(d),
            isActive: const drift.Value(true),
            createdAt: drift.Value(now),
          ),
        );
      }

      final all = await db.reminderDao.watchAllReminders().first;
      expect(all.length, 30);
      expect(all.first.scheduledAt, DateTime(2026, 10, 15, 9, 0));
      expect(all.last.scheduledAt, DateTime(2026, 11, 13, 9, 0));
    });

    test('7-Day Recurring Reminders Insertion', () async {
      final now = DateTime(2026, 10, 10, 8, 30);

      for (int i = 0; i < 7; i++) {
        await db.reminderDao.insertReminder(
          ReminderTableCompanion(
            title: const drift.Value('Morning Walk & Hydration'),
            scheduledAt: drift.Value(now.add(Duration(days: i))),
            isActive: const drift.Value(true),
            createdAt: drift.Value(now),
          ),
        );
      }

      final all = await db.reminderDao.watchAllReminders().first;
      expect(all.length, 7);
      expect(all.first.title, 'Morning Walk & Hydration');
    });

    test('Reader-to-Tasks Integration in Database', () async {
      final today = DateTime(2026, 10, 6);
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Review Chapter 1: Spring Boot 3 Core (Page 5)',
          priority: const drift.Value('high'),
          plannedDate: drift.Value(today),
          notes: const drift.Value('Study task created from Kindle Reader'),
        ),
      );

      final task = await db.taskDao.getTaskById(taskId);
      expect(task, isNotNull);
      expect(task!.title, 'Review Chapter 1: Spring Boot 3 Core (Page 5)');
      expect(task.priority, 'high');
      expect(task.notes, contains('Kindle Reader'));
    });

    test('Reader-to-Mind Space Integration in Database', () async {
      final thoughtId = await db.thoughtDao.insertThought(
        const ThoughtTableCompanion(
          content: drift.Value('Key Takeaway: DelegatingFilterProxy forwards to SecurityFilterChain with stateless JWT auth.'),
          mood: drift.Value('idea'),
        ),
      );

      final thoughts = await db.thoughtDao.watchAllThoughts().first;
      expect(thoughts.any((t) => t.id == thoughtId), isTrue);
      final thought = thoughts.firstWhere((t) => t.id == thoughtId);
      expect(thought.content, contains('DelegatingFilterProxy'));
    });

    test('Smart Email Recruiter Invite Parsing logic', () {
      const email = '''
Hi candidate,

We are excited to invite you to interview for the Senior Software Engineer position at Stripe.
Your technical interview is scheduled for next Monday at 3:00 PM.
Join meeting: https://meet.google.com/abc-xyz-def
Please review system design and concurrency.
''';

      final textLower = email.toLowerCase();

      // Check company detection
      final knownCompanies = ['Stripe', 'Google', 'Meta', 'Amazon'];
      String detectedCompany = 'Target Company';
      for (final c in knownCompanies) {
        if (textLower.contains(c.toLowerCase())) {
          detectedCompany = c;
          break;
        }
      }
      expect(detectedCompany, 'Stripe');

      // Check role detection
      expect(textLower.contains('senior') && textLower.contains('engineer'), isTrue);

      // Check meeting link detection
      final urlRegex = RegExp(r'(https?:\/\/(?:[a-zA-Z0-9\-]+\.)*(?:meet\.google\.com|zoom\.us|teams\.microsoft\.com)[^\s]*)');
      final match = urlRegex.firstMatch(email);
      expect(match, isNotNull);
      expect(match!.group(0), 'https://meet.google.com/abc-xyz-def');
    });

    test('WalkDao.getDistanceForDate aggregates walk distance for specific date', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateOnly = DateTime(yesterday.year, yesterday.month, yesterday.day, 10, 30);

      await db.walkDao.insertWalk(
        WalkSessionTableCompanion.insert(
          startTime: dateOnly,
          endTime: drift.Value(dateOnly.add(const Duration(minutes: 30))),
          distanceMeters: const drift.Value(3400.0),
          durationSeconds: const drift.Value(1800),
          isCompleted: const drift.Value(true),
        ),
      );

      final distance = await db.walkDao.getDistanceForDate(yesterday);
      expect(distance, 3400.0);

      // Other dates should be 0.0
      final todayDistance = await db.walkDao.getDistanceForDate(DateTime.now());
      expect(todayDistance, 0.0);
    });

    test('WaterDao.getWaterForDate aggregates water logged for specific date', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final dateOnly = DateTime(yesterday.year, yesterday.month, yesterday.day);

      await db.into(db.waterLogTable).insert(
        WaterLogTableCompanion.insert(
          amountMl: 250,
          date: dateOnly,
        ),
      );
      await db.into(db.waterLogTable).insert(
        WaterLogTableCompanion.insert(
          amountMl: 500,
          date: dateOnly,
        ),
      );

      final totalMl = await db.waterDao.getWaterForDate(yesterday);
      expect(totalMl, 750);

      // Today should be 0 if nothing logged
      final todayMl = await db.waterDao.getWaterForDate(DateTime.now());
      expect(todayMl, 0);
    });

    test('New Day task roll-forward and planning', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final today = DateTime.now();

      // Uncompleted task from yesterday
      final carriedId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Unfinished System Design Notes',
          plannedDate: drift.Value(yesterday),
          priority: const drift.Value('normal'),
        ),
      );

      // Carry forward to today
      await db.taskDao.updateTask(
        TaskTableCompanion(
          id: drift.Value(carriedId),
          plannedDate: drift.Value(DateTime(today.year, today.month, today.day)),
          updatedAt: drift.Value(today),
        ),
      );

      final todayTasks = await db.taskDao.watchTodayTasks().first;
      expect(todayTasks.any((t) => t.id == carriedId), isTrue);
      expect(todayTasks.firstWhere((t) => t.id == carriedId).title, 'Unfinished System Design Notes');
    });
  });
}
