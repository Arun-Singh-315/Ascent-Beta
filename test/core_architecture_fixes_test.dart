import 'dart:convert';
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

  group('Core Architecture Fixes — Drift SQLite & CRUD Integrity', () {
    test('CourseDao supports upsert, fetch, watch, and deletion of courses in SQLite', () async {
      final modulesJson = jsonEncode([
        {
          'id': 'm1',
          'title': 'Core Java Basics',
          'lectures': [
            {
              'id': 'l1',
              'title': 'JVM Internals',
              'durationSeconds': 1200,
              'videoUrl': 'https://youtube.com/watch?v=1',
              'isCompleted': false,
            }
          ]
        }
      ]);

      // Insert course
      await db.courseDao.upsertCourse(
        CourseTableCompanion.insert(
          id: 'java-2026',
          title: 'Java 2026 Masterclass',
          description: const drift.Value('Complete Core Java'),
          category: const drift.Value('Programming'),
          modulesJson: modulesJson,
          daysLeft: const drift.Value(45),
          targetMinutesPerDay: const drift.Value(60),
        ),
      );

      // Verify fetch
      final course = await db.courseDao.getCourseById('java-2026');
      expect(course, isNotNull);
      expect(course!.title, 'Java 2026 Masterclass');
      expect(course.modulesJson, modulesJson);
      expect(course.daysLeft, 45);
      expect(course.targetMinutesPerDay, 60);

      // Watch all courses
      final allCourses = await db.courseDao.watchAllCourses().first;
      expect(allCourses.length, 1);
      expect(allCourses.first.id, 'java-2026');

      // Update completion
      await db.courseDao.upsertCourse(
        CourseTableCompanion(
          id: const drift.Value('java-2026'),
          title: const drift.Value('Java 2026 Masterclass (Updated)'),
          daysLeft: const drift.Value(40),
          modulesJson: drift.Value(modulesJson),
        ),
      );

      final updated = await db.courseDao.getCourseById('java-2026');
      expect(updated!.title, 'Java 2026 Masterclass (Updated)');
      expect(updated.daysLeft, 40);

      // Delete course
      final deleted = await db.courseDao.deleteCourse('java-2026');
      expect(deleted, 1);
      final empty = await db.courseDao.getCourseById('java-2026');
      expect(empty, isNull);
    });

    test('ReminderTable.linkedTaskId allows clean cascading queries and deletion', () async {
      // Create a task
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Study Spring Boot Security',
          plannedDate: drift.Value(DateTime.now()),
        ),
      );

      // Add linked reminder
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Reminder: Study Spring Boot Security',
          scheduledAt: DateTime.now().add(const Duration(hours: 2)),
          linkedTaskId: drift.Value(taskId),
        ),
      );

      // Add another unrelated reminder
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Drink water',
          scheduledAt: DateTime.now().add(const Duration(minutes: 30)),
        ),
      );

      // Verify linked reminders found
      final linkedReminders = await db.reminderDao.getRemindersByTaskId(taskId);
      expect(linkedReminders.length, 1);
      expect(linkedReminders.first.title, contains('Spring Boot Security'));

      // Delete reminders by task ID (cascading delete)
      final deletedCount = await db.reminderDao.deleteRemindersByTaskId(taskId);
      expect(deletedCount, 1);

      // Verify only linked reminder was removed, unrelated reminder remains
      final remainingLinked = await db.reminderDao.getRemindersByTaskId(taskId);
      expect(remainingLinked, isEmpty);

      final allReminders = await db.reminderDao.watchAllReminders().first;
      expect(allReminders.length, 1);
      expect(allReminders.first.title, 'Drink water');
    });

    test('MedicineDao preserves start date and duration while updating instructions/dosage', () async {
      final startDate = DateTime(2026, 1, 15);
      final medId = await db.medicineDao.insertMedicine(
        MedicineTableCompanion.insert(
          name: 'Vitamin D3',
          dosage: '1000 IU',
          scheduledTimes: '["09:00"]',
          durationDays: const drift.Value(30),
          startDate: startDate,
          instructions: const drift.Value('Take with breakfast'),
        ),
      );

      final before = await db.medicineDao.getMedicineById(medId);
      expect(before, isNotNull);
      expect(before!.name, 'Vitamin D3');
      expect(before.dosage, '1000 IU');
      expect(before.durationDays, 30);
      expect(before.startDate, startDate);

      await db.medicineDao.updateMedicine(
        MedicineTableCompanion(
          id: drift.Value(medId),
          name: const drift.Value('Vitamin D3 + K2'),
          dosage: const drift.Value('2000 IU'),
          instructions: const drift.Value('Take with meal and water'),
        ),
      );

      final after = await db.medicineDao.getMedicineById(medId);
      expect(after, isNotNull);
      expect(after!.name, 'Vitamin D3 + K2');
      expect(after.dosage, '2000 IU');
      expect(after.instructions, 'Take with meal and water');
      expect(after.durationDays, 30);
      expect(after.startDate, startDate);
    });

    test('Activity classification integrity: to-do vs duration task distinction', () async {
      // Simple to-do (no duration)
      final todoId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Send feedback email',
          estimatedMinutes: const drift.Value(0),
        ),
      );

      // Timed activity (has duration)
      final timedId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Deep Focus DSA',
          estimatedMinutes: const drift.Value(45),
        ),
      );

      final todo = await db.taskDao.getTaskById(todoId);
      final timed = await db.taskDao.getTaskById(timedId);

      expect(todo!.estimatedMinutes, 0);
      expect(timed!.estimatedMinutes, 45);
    });
  });
}
