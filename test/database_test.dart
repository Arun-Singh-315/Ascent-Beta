import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/database/tables/enums.dart';
import 'package:ascent/core/database/demo_data_seeder.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Database & DAOs Tests', () {
    test('Can insert and retrieve UserProfile', () async {
      final profileId = await db.userProfileDao.upsertProfile(
        UserProfileTableCompanion.insert(
          name: 'Jane Doe',
          targetRole: const drift.Value('Senior Flutter Engineer'),
          targetCompanies: drift.Value(jsonEncode(['Google', 'Stripe'])),
          interviewDate: drift.Value(DateTime.now().add(const Duration(days: 45))),
        ),
      );

      expect(profileId, isNonZero);

      final profile = await db.userProfileDao.getProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'Jane Doe');
      expect(profile.targetRole, 'Senior Flutter Engineer');
      expect(profile.targetCompanies, contains('Google'));
    });

    test('TaskDao supports task lifecycle (insert, complete, uncomplete, delete)', () async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Implement LeetCode 3Sum',
          plannedDate: drift.Value(DateTime.now()),
          priority: const drift.Value('high'),
        ),
      );

      final task = await db.taskDao.getTaskById(taskId);
      expect(task, isNotNull);
      expect(task!.title, 'Implement LeetCode 3Sum');
      expect(task.actualCompletedDate, isNull);

      // Mark complete
      await db.taskDao.markComplete(taskId);
      final completed = await db.taskDao.getTaskById(taskId);
      expect(completed!.actualCompletedDate, isNotNull);

      // Mark incomplete
      await db.taskDao.markIncomplete(taskId);
      final uncompleted = await db.taskDao.getTaskById(taskId);
      expect(uncompleted!.actualCompletedDate, isNull);

      // Delete
      final deletedCount = await db.taskDao.deleteTask(taskId);
      expect(deletedCount, 1);
      final missing = await db.taskDao.getTaskById(taskId);
      expect(missing, isNull);
    });

    test('ApplicationDao supports pipeline progression', () async {
      final appId = await db.applicationDao.insertApplication(
        ApplicationTableCompanion.insert(
          company: 'Google',
          role: 'Mobile Engineer',
          currentStage: drift.Value(ApplicationStage.wishlist.name),
        ),
      );

      final app = await db.applicationDao.getApplicationById(appId);
      expect(app, isNotNull);
      expect(app!.company, 'Google');
      expect(app.currentStage, ApplicationStage.wishlist.name);

      // Transition stage
      await db.applicationDao.moveToStage(appId, ApplicationStage.interview);
      final updated = await db.applicationDao.getApplicationById(appId);
      expect(updated!.currentStage, ApplicationStage.interview.name);
    });

    test('ConsistencyDao computes streak and logs day accurately', () async {
      final today = DateTime.now();
      await db.consistencyDao.logDay(today, true, note: 'Solved 2 hard problems');

      final todayLog = await db.consistencyDao.getTodayLog();
      expect(todayLog, isNotNull);
      expect(todayLog!.present, isTrue);
      expect(todayLog.note, 'Solved 2 hard problems');

      final streak = await db.consistencyDao.watchCurrentStreak().first;
      expect(streak, 1);
    });

    test('DsaDao logs solved problem and tracks revisit flag', () async {
      final logId = await db.dsaDao.insertLog(
        DsaLogTableCompanion.insert(
          problemName: 'Trapping Rain Water',
          topic: DsaTopic.arrays.name,
          difficulty: DsaDifficulty.hard.name,
          dateSolved: DateTime.now(),
          revisitFlag: const drift.Value(true),
        ),
      );

      final all = await db.dsaDao.watchAllLogs().first;
      expect(all.length, 1);
      // Toggle revisit
      await db.dsaDao.toggleRevisit(logId);
      final updatedAll = await db.dsaDao.watchAllLogs().first;
      expect(updatedAll.first.revisitFlag, isFalse);
    });

    test('ApplicationDao records status history and streams updates reactively', () async {
      final appId = await db.applicationDao.insertApplication(
        ApplicationTableCompanion.insert(
          company: 'Stripe',
          role: 'Staff Engineer',
          currentStage: drift.Value(ApplicationStage.applied.name),
        ),
      );

      await db.applicationDao.recordStatusChange(
        appId,
        ApplicationStage.interview,
        notes: 'Recruiter screen scheduled',
      );

      final updatedApp = await db.applicationDao.watchApplicationById(appId).first;
      expect(updatedApp, isNotNull);
      expect(updatedApp!.currentStage, ApplicationStage.interview.name);

      final history = await db.applicationDao.watchStatusHistory(appId).first;
      expect(history.length, 2);
      expect(history.first.stage, ApplicationStage.interview.name);
      expect(history.first.notes, 'Recruiter screen scheduled');
      expect(history.last.stage, ApplicationStage.applied.name);
    });

    test('DemoDataSeeder seeds all interconnected modules accurately', () async {
      await DemoDataSeeder.seedRealisticBetaData(db);

      // Verify Profile
      final profile = await db.userProfileDao.getProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'Alex Chen');

      // Verify Tasks
      final todayTasks = await db.taskDao.watchTasksByDate(DateTime.now()).first;
      expect(todayTasks.isNotEmpty, isTrue);

      // Verify Pipeline Applications
      final apps = await db.applicationDao.watchAllApplications().first;
      expect(apps.length, greaterThanOrEqualTo(5));

      // Verify Consistency Logs & Streak
      final streak = await db.consistencyDao.watchCurrentStreak().first;
      expect(streak, greaterThanOrEqualTo(1));

      // Verify DSA Logs
      final dsa = await db.dsaDao.watchAllLogs().first;
      expect(dsa.length, greaterThanOrEqualTo(6));

      // Verify Interview Prep
      final questions = await db.interviewPrepDao.watchAllQuestions().first;
      expect(questions.length, greaterThanOrEqualTo(4));

      // Verify Notes and Tags
      final notes = await db.notesDao.watchAllNotes().first;
      expect(notes.length, greaterThanOrEqualTo(3));
      final tags = await db.notesDao.getTagsForNote(notes.first.id);
      expect(tags, isNotEmpty);
    });

    test('TimeSessionDao tracks session lifecycle and duration', () async {
      await db.timeSessionDao.ensureDefaultCategories();
      final categories = await db.timeSessionDao.getAllCategories();
      expect(categories, isNotEmpty);
      final catId = categories.first.id;

      // Start session
      final sessionId = await db.timeSessionDao.startSession(
        label: 'Deep Work',
        categoryId: catId,
      );
      expect(sessionId, isNonZero);

      var active = await db.timeSessionDao.getActiveSession();
      expect(active, isNotNull);
      expect(active!.status, 'running');

      // Pause session
      await db.timeSessionDao.pauseSession(sessionId);
      active = await db.timeSessionDao.getActiveSession();
      expect(active!.status, 'paused');

      // Resume session
      await db.timeSessionDao.resumeSession(sessionId);
      active = await db.timeSessionDao.getActiveSession();
      expect(active!.status, 'running');

      // Complete session
      await db.timeSessionDao.completeSession(sessionId);
      active = await db.timeSessionDao.getActiveSession();
      expect(active, isNull);

      final dateSessions = await db.timeSessionDao.getSessionsForDate(DateTime.now());
      final session = dateSessions.firstWhere((s) => s.id == sessionId);
      expect(session.status, 'completed');
      expect(session.endedAt, isNotNull);
    });

    test('TaskDao watchTasksForApplication filters by linkedApplicationId', () async {
      final task1 = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Review Google offer',
          linkedApplicationId: const drift.Value(42),
        ),
      );
      final task2 = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Review Stripe offer',
          linkedApplicationId: const drift.Value(99),
        ),
      );

      final googleTasks = await db.taskDao.watchTasksForApplication(42).first;
      expect(googleTasks.length, 1);
      expect(googleTasks.first.id, task1);

      final stripeTasks = await db.taskDao.watchTasksForApplication(99).first;
      expect(stripeTasks.length, 1);
      expect(stripeTasks.first.id, task2);
    });
  });
}
