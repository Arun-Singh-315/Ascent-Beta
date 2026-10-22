import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/plan_service.dart';

void main() {
  late AppDatabase db;
  late PlanService planService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    planService = PlanService(db, clock: () => DateTime(2026, 10, 18, 8, 0));
  });

  tearDown(() => db.close());

  group('PlanService - Lifecycle & Daily Operations', () {
    test('Creates a 14-day routine with 14 materialized sessions and atomic links', () async {
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-31',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
        reminderPolicy: 'at_start',
        checkInPolicy: 'gentle',
        expectedDurationMinutes: 30,
      );

      expect(plan.id.startsWith('plan_'), isTrue);
      expect(plan.title, 'Morning walk');
      expect(plan.status, 'active');

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      expect(occurrences.length, 14);
      expect(occurrences.first.eligibleLocalDate, '2026-10-18');
      expect(occurrences.last.eligibleLocalDate, '2026-10-31');

      // Verify each occurrence has a linked task and reminders
      for (final occ in occurrences) {
        expect(occ.linkedTaskId, isNotNull);
        final task = await db.taskDao.getTaskById(occ.linkedTaskId!);
        expect(task!.title, 'Morning walk');

        final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
        expect(links.any((l) => l.role == 'start'), isTrue);
        expect(links.any((l) => l.role == 'check_in'), isTrue);
      }
    });

    test('Querying occurrences for today returns only today session', () async {
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-25',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
      );

      final todayOccurrences = await planService.getOccurrencesForDate('2026-10-18');
      expect(todayOccurrences.length, 1);
      expect(todayOccurrences.first.planId, plan.id);
      expect(todayOccurrences.first.eligibleLocalDate, '2026-10-18');

      final tomorrowOccurrences = await planService.getOccurrencesForDate('2026-10-19');
      expect(tomorrowOccurrences.length, 1);
      expect(tomorrowOccurrences.first.eligibleLocalDate, '2026-10-19');
    });

    test('Early completion of session task cancels remaining check-ins for this session', () async {
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
        checkInPolicy: 'gentle',
        expectedDurationMinutes: 30,
      );

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      final firstOcc = occurrences.first;
      final secondOcc = occurrences[1];

      // User finishes task early via task completion (e.g. at 7:25 am)
      await planService.completeOccurrence(firstOcc.id);

      final updatedFirst = await db.planDao.getOccurrenceById(firstOcc.id);
      expect(updatedFirst!.outcome, 'done');
      expect(updatedFirst.completedAt, isNotNull);

      // Check-ins for first session are deactivated
      final firstLinks = await db.planDao.getAlertLinksForOccurrence(firstOcc.id);
      for (final link in firstLinks.where((l) => l.role == 'check_in')) {
        final r = await db.reminderDao.getReminderById(link.reminderId);
        expect(r!.isActive, isFalse);
      }

      // Second session check-in is untouched!
      final secondLinks = await db.planDao.getAlertLinksForOccurrence(secondOcc.id);
      for (final link in secondLinks.where((l) => l.role == 'check_in')) {
        final r = await db.reminderDao.getReminderById(link.reminderId);
        expect(r!.isActive, isTrue);
      }
    });

    test('Check-in answer: Done completes today only; tomorrow remains scheduled', () async {
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
        checkInPolicy: 'once',
      );

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      final occ = occurrences.first;

      final success = await planService.answerCheckIn(occ.id, 'done');
      expect(success, isTrue);

      final updated = await db.planDao.getOccurrenceById(occ.id);
      expect(updated!.outcome, 'done');

      final task = await db.taskDao.getTaskById(occ.linkedTaskId!);
      expect(task!.actualCompletedDate, isNotNull);

      // Tomorrow session is still scheduled
      final tomorrow = await db.planDao.getOccurrenceById(occurrences[1].id);
      expect(tomorrow!.outcome, 'scheduled');
    });

    test('Check-in answer: Skip this time marks occurrence skipped, cancels alerts, leaves task unfinished', () async {
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
        checkInPolicy: 'once',
      );

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      final occ = occurrences.first;

      final success = await planService.answerCheckIn(occ.id, 'skip_this_time');
      expect(success, isTrue);

      final updated = await db.planDao.getOccurrenceById(occ.id);
      expect(updated!.outcome, 'skipped');

      // Task is NOT marked complete!
      final task = await db.taskDao.getTaskById(occ.linkedTaskId!);
      expect(task!.actualCompletedDate, isNull);

      // Remaining alerts for this session are cancelled
      final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
      for (final link in links) {
        final r = await db.reminderDao.getReminderById(link.reminderId);
        expect(r!.isActive, isFalse);
      }
    });

    test('Check-in answer: Later moves check-in within window without resetting attempt counter', () async {
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
        checkInPolicy: 'gentle',
      );

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      final occ = occurrences.first;

      final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
      final checkLink = links.firstWhere((l) => l.role == 'check_in');
      final originalCheckIn = (await db.reminderDao.getReminderById(checkLink.reminderId))!;

      final delay = const Duration(minutes: 30);
      final success = await planService.answerCheckIn(
        occ.id,
        'later',
        delay: delay,
      );
      expect(success, isTrue);

      // Check-in reminder moved forward by delay
      final updatedReminder = (await db.reminderDao.getReminderById(checkLink.reminderId))!;
      expect(
        updatedReminder.scheduledAt.isAfter(originalCheckIn.scheduledAt),
        isTrue,
      );

      // Occurrence stays scheduled and task stays unfinished
      final updatedOcc = await db.planDao.getOccurrenceById(occ.id);
      expect(updatedOcc!.outcome, 'scheduled');
      final task = await db.taskDao.getTaskById(occ.linkedTaskId!);
      expect(task!.actualCompletedDate, isNull);
    });

    test('Pause routine stops pending alerts; resume routine continues from next eligible date', () async {
      final plan = await planService.createPlan(
        title: 'Guitar practice',
        startDate: '2026-10-18',
        endDate: '2026-10-25',
        recurrenceRule: 'daily',
        localTime: '17:00',
        addTodo: true,
        reminderPolicy: 'at_start',
      );

      // Pause the routine
      await planService.pausePlan(plan.id);
      final pausedPlan = await db.planDao.getPlanById(plan.id);
      expect(pausedPlan!.status, 'paused');

      // Pending alerts for future sessions are deactivated
      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      for (final occ in occurrences) {
        final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
        for (final l in links) {
          final r = await db.reminderDao.getReminderById(l.reminderId);
          expect(r!.isActive, isFalse);
        }
      }

      // Resume the routine
      await planService.resumePlan(plan.id, effectiveStartDate: '2026-10-21');
      final resumedPlan = await db.planDao.getPlanById(plan.id);
      expect(resumedPlan!.status, 'active');

      // Occurrences on or after 2026-10-21 have active alerts restored
      final futureOccs = occurrences.where((o) => o.eligibleLocalDate.compareTo('2026-10-21') >= 0);
      for (final occ in futureOccs) {
        final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
        for (final l in links) {
          final r = await db.reminderDao.getReminderById(l.reminderId);
          expect(r!.isActive, isTrue);
        }
      }
    });

    test('End routine permanently stops future alerts and marks status ended', () async {
      final plan = await planService.createPlan(
        title: 'Meditation',
        startDate: '2026-10-18',
        endDate: '2026-10-22',
        recurrenceRule: 'daily',
        localTime: '06:00',
        addTodo: true,
      );

      await planService.endPlan(plan.id);

      final endedPlan = await db.planDao.getPlanById(plan.id);
      expect(endedPlan!.status, 'ended');

      final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
      for (final occ in occurrences) {
        final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
        for (final l in links) {
          final r = await db.reminderDao.getReminderById(l.reminderId);
          expect(r!.isActive, isFalse);
        }
      }
    });
  });
}
