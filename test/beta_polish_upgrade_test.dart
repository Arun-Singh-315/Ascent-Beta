import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/database/tables/enums.dart';

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

    test('Reader-to-Notes Integration in Database', () async {
      final noteId = await db.notesDao.insertNote(
        NoteTableCompanion.insert(
          title: const drift.Value('Key Takeaway: Spring Security Filter Chain'),
          content: 'DelegatingFilterProxy forwards to SecurityFilterChain with stateless JWT auth.',
          linkedTopic: const drift.Value('Spring Boot Architecture'),
          lastInteractedAt: drift.Value(DateTime.now()),
        ),
      );

      final notes = await db.notesDao.watchAllNotes().first;
      expect(notes.any((n) => n.id == noteId), isTrue);
      final note = notes.firstWhere((n) => n.id == noteId);
      expect(note.title, contains('Spring Security Filter Chain'));
      expect(note.linkedTopic, 'Spring Boot Architecture');
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
  });
}
