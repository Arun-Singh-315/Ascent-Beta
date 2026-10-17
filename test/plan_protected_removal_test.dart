import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/plan_child_protection.dart';
import 'package:ascent/core/services/plan_service.dart';

void main() {
  late AppDatabase db;
  late PlanService planService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    planService = PlanService(db);
  });

  tearDown(() => db.close());

  group('Protected Removal of Plan-Owned Tasks & Reminders', () {
    test('Standalone tasks and reminders can be deleted normally without restriction', () async {
      final taskId = await db.taskDao.insertTask(
        const TaskTableCompanion(title: drift.Value('Standalone errand')),
      );
      final reminderId = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Standalone alarm',
          scheduledAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );

      expect(await db.taskDao.getTaskProtection(taskId), isNull);
      expect(await db.reminderDao.getReminderProtection(reminderId), isNull);

      final deletedTaskCount = await db.taskDao.deleteTask(taskId);
      expect(deletedTaskCount, 1);
      expect(await db.taskDao.getTaskById(taskId), isNull);

      final deletedReminderCount = await db.reminderDao.deleteReminder(reminderId);
      expect(deletedReminderCount, 1);
      expect(await db.reminderDao.getReminderById(reminderId), isNull);
    });

    test('Routine-created task is protected from direct TaskDao deletion', () async {
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-24',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
        reminderPolicy: 'at_start',
        checkInPolicy: 'gentle',
        expectedDurationMinutes: 30,
      );

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      expect(occurrences.isNotEmpty, isTrue);
      final taskId = occurrences.first.linkedTaskId!;
      expect(taskId, isNotNull);

      // Verify protection details
      final protection = await db.taskDao.getTaskProtection(taskId);
      expect(protection, isNotNull);
      expect(protection!.planId, plan.id);
      expect(protection.planTitle, 'Morning walk');
      expect(protection.isRoutine, isTrue);
      expect(protection.targetType, 'task');
      expect(protection.allowedActions, contains('skip_session'));
      expect(protection.allowedActions, contains('open_routine'));

      // Attempting direct deletion throws PlanChildProtectionException
      expect(
        () => db.taskDao.deleteTask(taskId),
        throwsA(isA<PlanChildProtectionException>()),
      );

      // Task is untouched
      final task = await db.taskDao.getTaskById(taskId);
      expect(task, isNotNull);
    });

    test('Routine-created start reminder and check-in reminder are protected from direct ReminderDao deletion', () async {
      final plan = await planService.createPlan(
        title: 'Study math',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        recurrenceRule: 'daily',
        localTime: '08:00',
        addTodo: true,
        reminderPolicy: 'at_start',
        checkInPolicy: 'once',
      );

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      final occ = occurrences.first;
      final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
      expect(links.length, 2); // 1 start, 1 check_in

      final startLink = links.firstWhere((l) => l.role == 'start');
      final checkLink = links.firstWhere((l) => l.role == 'check_in');

      // Start reminder protection
      final startProt = await db.reminderDao.getReminderProtection(startLink.reminderId);
      expect(startProt, isNotNull);
      expect(startProt!.targetType, 'start_reminder');
      expect(startProt.allowedActions, contains('turn_off_reminder'));
      expect(startProt.allowedActions, contains('open_routine'));

      expect(
        () => db.reminderDao.deleteReminder(startLink.reminderId),
        throwsA(isA<PlanChildProtectionException>()),
      );

      // Check-in reminder protection
      final checkProt = await db.reminderDao.getReminderProtection(checkLink.reminderId);
      expect(checkProt, isNotNull);
      expect(checkProt!.targetType, 'checkin_reminder');
      expect(checkProt.allowedActions, contains('stop_asking'));
      expect(checkProt.allowedActions, contains('open_routine'));

      expect(
        () => db.reminderDao.deleteReminder(checkLink.reminderId),
        throwsA(isA<PlanChildProtectionException>()),
      );
    });

    test('Owner-aware skip session marks only this occurrence skipped and keeps future sessions active', () async {
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
        reminderPolicy: 'at_start',
        checkInPolicy: 'gentle',
      );

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      final firstOcc = occurrences[0];
      final secondOcc = occurrences[1];

      // Perform owner-aware skip for the first session
      final skipped = await planService.skipOccurrence(firstOcc.id);
      expect(skipped, isTrue);

      final updatedFirst = await db.planDao.getOccurrenceById(firstOcc.id);
      expect(updatedFirst!.outcome, 'skipped');

      // First session reminders are deactivated
      final links = await db.planDao.getAlertLinksForOccurrence(firstOcc.id);
      for (final link in links) {
        final r = await db.reminderDao.getReminderById(link.reminderId);
        expect(r!.isActive, isFalse);
      }

      // Second session remains scheduled and active!
      final updatedSecond = await db.planDao.getOccurrenceById(secondOcc.id);
      expect(updatedSecond!.outcome, 'scheduled');
      final secondLinks = await db.planDao.getAlertLinksForOccurrence(secondOcc.id);
      for (final link in secondLinks) {
        final r = await db.reminderDao.getReminderById(link.reminderId);
        expect(r!.isActive, isTrue);
      }
    });

    test('Owner-aware turn off reminder disables only start reminder, keeping task and check-in', () async {
      final plan = await planService.createPlan(
        title: 'Read book',
        startDate: '2026-10-18',
        endDate: '2026-10-18',
        recurrenceRule: 'once',
        localTime: '15:00',
        addTodo: true,
        reminderPolicy: 'at_start',
        checkInPolicy: 'once',
      );

      final occ = (await db.planDao.getOccurrencesForPlan(plan.id)).single;
      final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
      final startLink = links.firstWhere((l) => l.role == 'start');
      final checkLink = links.firstWhere((l) => l.role == 'check_in');

      await planService.turnOffOccurrenceReminder(occ.id, startLink.reminderId);

      final startReminder = await db.reminderDao.getReminderById(startLink.reminderId);
      expect(startReminder!.isActive, isFalse);

      final checkReminder = await db.reminderDao.getReminderById(checkLink.reminderId);
      expect(checkReminder!.isActive, isTrue); // Check-in kept active

      final task = await db.taskDao.getTaskById(occ.linkedTaskId!);
      expect(task, isNotNull);
      expect(task!.actualCompletedDate, isNull);
    });

    test('Owner-aware stop asking disables check-in reminders, keeping task and start reminder', () async {
      final plan = await planService.createPlan(
        title: 'Evening jog',
        startDate: '2026-10-18',
        endDate: '2026-10-18',
        recurrenceRule: 'once',
        localTime: '18:00',
        addTodo: true,
        reminderPolicy: 'at_start',
        checkInPolicy: 'gentle',
      );

      final occ = (await db.planDao.getOccurrencesForPlan(plan.id)).single;
      final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
      final startLink = links.firstWhere((l) => l.role == 'start');

      await planService.stopAskingForOccurrence(occ.id);

      final startReminder = await db.reminderDao.getReminderById(startLink.reminderId);
      expect(startReminder!.isActive, isTrue); // Start reminder preserved

      final checkLinks = links.where((l) => l.role == 'check_in');
      for (final link in checkLinks) {
        final r = await db.reminderDao.getReminderById(link.reminderId);
        expect(r!.isActive, isFalse);
      }
    });
  });
}
