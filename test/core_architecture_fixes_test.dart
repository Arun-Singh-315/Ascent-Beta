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

    test('HabitDao.patchHabit preserves creation date and frequency while updating title/category', () async {
      final initialDate = DateTime(2026, 1, 15);
      final habitId = await db.habitDao.insertHabit(
        HabitTableCompanion.insert(
          title: 'Drink 2L Water',
          category: const drift.Value('Health'),
          frequency: const drift.Value('daily'),
          createdAt: drift.Value(initialDate),
        ),
      );

      final before = (await db.habitDao.watchAllHabits().first).firstWhere((h) => h.id == habitId);
      expect(before.title, 'Drink 2L Water');
      expect(before.category, 'Health');
      expect(before.frequency, 'daily');
      expect(before.createdAt, initialDate);

      // Patch title and category
      await db.habitDao.patchHabit(
        habitId,
        title: 'Drink 3L Water & Electrolytes',
        category: 'Fitness',
      );

      final after = (await db.habitDao.watchAllHabits().first).firstWhere((h) => h.id == habitId);
      expect(after.title, 'Drink 3L Water & Electrolytes');
      expect(after.category, 'Fitness');
      // Verify frequency and createdAt were strictly preserved
      expect(after.frequency, 'daily');
      expect(after.createdAt, initialDate);
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
