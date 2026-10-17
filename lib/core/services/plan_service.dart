import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'plan_recurrence_engine.dart';

/// Single unified coordinator for plan and routine lifecycles, occurrence materialization,
/// check-in answer resolution, and owner-aware protected actions.
class PlanService {
  PlanService(this.db, {DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() clock;

  /// Creates a plan or routine definition and materializes bounded session occurrences atomically.
  Future<PlanDefinition> createPlan({
    required String title,
    required String startDate,
    required String endDate,
    String recurrenceRule = 'once',
    List<int>? customDays,
    required String localTime,
    int? sourceThoughtId,
    int? sourceTaskId,
    String activityType = 'todo',
    int? targetMinutes,
    int? expectedDurationMinutes,
    String timezonePolicy = 'device_local',
    String reminderPolicy = 'at_start',
    String checkInPolicy = 'off',
    bool addTodo = true,
  }) =>
      db.transaction(() async {
        final cleanTitle = title.trim();
        if (cleanTitle.isEmpty || cleanTitle.length > 300) {
          throw ArgumentError('Choose an activity title from 1 to 300 characters.');
        }

        final planId = 'plan_${clock().microsecondsSinceEpoch}';
        final dates = PlanRecurrenceEngine.calculateEligibleDates(
          startDate: startDate,
          endDate: endDate,
          recurrenceRule: recurrenceRule,
          customDays: customDays,
        );

        if (dates.isEmpty) {
          throw ArgumentError('The selected schedule produces no eligible sessions.');
        }

        final planCompanion = PlanDefinitionTableCompanion.insert(
          id: planId,
          title: cleanTitle,
          sourceThoughtId: Value(sourceThoughtId),
          sourceTaskId: Value(sourceTaskId),
          activityType: Value(activityType),
          targetMinutes: Value(targetMinutes),
          expectedDurationMinutes: Value(expectedDurationMinutes),
          startDate: startDate,
          endDate: endDate,
          recurrenceRule: Value(recurrenceRule),
          customDaysJson: Value(customDays == null ? null : jsonEncode(customDays)),
          localTime: localTime,
          timezonePolicy: Value(timezonePolicy),
          reminderPolicy: Value(reminderPolicy),
          checkInPolicy: Value(checkInPolicy),
          status: const Value('active'),
          revision: const Value(1),
          createdAt: Value(clock()),
          updatedAt: Value(clock()),
        );

        await db.planDao.insertPlan(planCompanion);

        final existingLinkedTask = sourceThoughtId != null
            ? await db.taskDao.getTaskLinkedToThought(sourceThoughtId)
            : null;
        var thoughtIdClaimed = existingLinkedTask != null;

        // Materialize occurrences and atomic child links for each eligible date
        for (final dateStr in dates) {
          final occId = 'occ_${planId}_${dateStr}_0';
          final startTime = PlanRecurrenceEngine.calculateStartTime(
            dateStr: dateStr,
            localTime: localTime,
          );

          final checkIns = PlanRecurrenceEngine.calculateCheckInTimes(
            startTime: startTime,
            policy: checkInPolicy,
            expectedDurationMinutes: expectedDurationMinutes ?? targetMinutes,
          );

          final closeTime = PlanRecurrenceEngine.calculateCloseTime(
            startTime: startTime,
            lastCheckInTime: checkIns.isNotEmpty ? checkIns.last.time : null,
          );

          int? linkedTaskId;
          if (addTodo) {
            final shouldLinkThought = sourceThoughtId != null && !thoughtIdClaimed;
            if (shouldLinkThought) {
              thoughtIdClaimed = true;
            }
            linkedTaskId = await db.taskDao.insertTask(
              TaskTableCompanion.insert(
                title: cleanTitle,
                plannedDate: Value(startTime),
                estimatedMinutes: Value(targetMinutes),
                linkedThoughtId: Value(shouldLinkThought ? sourceThoughtId : null),
              ),
            );
          }

          final occCompanion = PlanOccurrenceTableCompanion.insert(
            id: occId,
            planId: planId,
            eligibleLocalDate: dateStr,
            slotIndex: const Value(0),
            definitionRevision: const Value(1),
            scheduledStartTime: startTime,
            scheduledEndTime: targetMinutes != null
                ? Value(startTime.add(Duration(minutes: targetMinutes)))
                : const Value.absent(),
            closeTime: closeTime,
            linkedTaskId: Value(linkedTaskId),
            outcome: const Value('scheduled'),
            createdAt: Value(clock()),
            updatedAt: Value(clock()),
          );

          await db.planDao.insertOccurrence(occCompanion);

          // 1. Start reminder (if enabled)
          if (reminderPolicy == 'at_start') {
            final startRemId = await db.reminderDao.insertReminder(
              ReminderTableCompanion.insert(
                title: cleanTitle,
                scheduledAt: startTime,
                linkedTaskId: Value(linkedTaskId),
                alertSyncPending: const Value(true),
              ),
            );

            await db.planDao.insertAlertLink(
              OccurrenceAlertLinkTableCompanion.insert(
                occurrenceId: occId,
                reminderId: startRemId,
                role: 'start',
                attemptIndex: const Value(0),
                expectedVersion: const Value(1),
              ),
            );
          }

          // 2. Check-in reminders (if enabled)
          for (final checkTiming in checkIns) {
            final checkRemId = await db.reminderDao.insertReminder(
              ReminderTableCompanion.insert(
                title: 'Did you finish: $cleanTitle',
                scheduledAt: checkTiming.time,
                linkedTaskId: Value(linkedTaskId),
                alertSyncPending: const Value(true),
              ),
            );

            await db.planDao.insertAlertLink(
              OccurrenceAlertLinkTableCompanion.insert(
                occurrenceId: occId,
                reminderId: checkRemId,
                role: 'check_in',
                attemptIndex: Value(checkTiming.attemptIndex),
                expectedVersion: const Value(1),
              ),
            );
          }
        }

        return (await db.planDao.getPlanById(planId))!;
      });

  /// Get occurrences for a specific calendar date 'YYYY-MM-DD'.
  Future<List<PlanOccurrence>> getOccurrencesForDate(String dateStr) {
    return db.planDao.getOccurrencesForDate(dateStr);
  }

  /// Get occurrences for a plan by its ID.
  Future<List<PlanOccurrence>> getOccurrencesForPlan(String planId) {
    return db.planDao.getOccurrencesForPlan(planId);
  }

  /// Watch occurrences for a specific calendar date.
  Stream<List<PlanOccurrence>> watchOccurrencesForDate(String dateStr) {
    return db.planDao.watchOccurrencesForDate(dateStr);
  }

  /// Completes an occurrence and cancels all remaining check-ins for that session.
  Future<bool> completeOccurrence(String occurrenceId) =>
      db.transaction(() async {
        final occ = await db.planDao.getOccurrenceById(occurrenceId);
        if (occ == null) return false;

        final now = clock();
        await db.planDao.updateOccurrence(
          PlanOccurrenceTableCompanion(
            id: Value(occ.id),
            outcome: const Value('done'),
            completedAt: Value(now),
            answeredAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        if (occ.linkedTaskId != null) {
          final task = await db.taskDao.getTaskById(occ.linkedTaskId!);
          if (task != null && task.actualCompletedDate == null) {
            await (db.update(db.taskTable)..where((t) => t.id.equals(task.id)))
                .write(
              TaskTableCompanion(
                actualCompletedDate: Value(now),
                updatedAt: Value(now),
              ),
            );
          }
        }

        // Cancel remaining check-in alerts for this session
        final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
        for (final link in links) {
          if (link.role == 'check_in') {
            await (db.update(db.reminderTable)
                  ..where((r) => r.id.equals(link.reminderId)))
                .write(
              const ReminderTableCompanion(
                isActive: Value(false),
                alertSyncPending: Value(true),
              ),
            );
          }
        }

        return true;
      });

  /// Answer check-in for an occurrence with 'done', 'skip_this_time', 'skip_check_in', or 'later'.
  Future<bool> answerCheckIn(
    String occurrenceId,
    String answer, {
    Duration delay = const Duration(minutes: 30),
  }) =>
      db.transaction(() async {
        final occ = await db.planDao.getOccurrenceById(occurrenceId);
        if (occ == null) return false;

        if (answer == 'done') {
          return completeOccurrence(occurrenceId);
        } else if (answer == 'skip_this_time' || answer == 'skip') {
          return skipOccurrence(occurrenceId);
        } else if (answer == 'skip_check_in') {
          return stopAskingForOccurrence(occurrenceId);
        } else if (answer == 'later') {
          if (delay.inMinutes <= 0) {
            throw ArgumentError('Choose a positive delay for Later.');
          }

          final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
          final checkLinks = links.where((l) => l.role == 'check_in').toList();
          if (checkLinks.isEmpty) return false;

          final primaryLink = checkLinks.first;
          final currentReminder =
              await db.reminderDao.getReminderById(primaryLink.reminderId);
          if (currentReminder == null) return false;

          final now = clock();
          final base = currentReminder.scheduledAt.isAfter(now)
              ? currentReminder.scheduledAt
              : now;
          final nextCheckAt = base.add(delay);

          // Update the first active check-in reminder
          await (db.update(db.reminderTable)
                ..where((r) => r.id.equals(primaryLink.reminderId)))
              .write(
            ReminderTableCompanion(
              scheduledAt: Value(nextCheckAt),
              isActive: const Value(true),
              alertSyncPending: const Value(true),
            ),
          );

          // Deactivate other retries so they do not interrupt prematurely
          for (var i = 1; i < checkLinks.length; i++) {
            await (db.update(db.reminderTable)
                  ..where((r) => r.id.equals(checkLinks[i].reminderId)))
                .write(
              const ReminderTableCompanion(
                isActive: Value(false),
                alertSyncPending: Value(true),
              ),
            );
          }

          return true;
        }

        return false;
      });

  /// Marks a single occurrence as skipped and cancels all alerts for this occurrence.
  /// Task remains unfinished (no completion credit).
  Future<bool> skipOccurrence(String occurrenceId) =>
      db.transaction(() async {
        final occ = await db.planDao.getOccurrenceById(occurrenceId);
        if (occ == null) return false;

        final now = clock();
        await db.planDao.updateOccurrence(
          PlanOccurrenceTableCompanion(
            id: Value(occ.id),
            outcome: const Value('skipped'),
            answeredAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        // Cancel all alerts for this occurrence
        final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
        for (final link in links) {
          await (db.update(db.reminderTable)
                ..where((r) => r.id.equals(link.reminderId)))
              .write(
            const ReminderTableCompanion(
              isActive: Value(false),
              alertSyncPending: Value(true),
            ),
          );
        }

        return true;
      });

  /// Disables only the start reminder for a session, keeping task and check-ins intact.
  Future<bool> turnOffOccurrenceReminder(
    String occurrenceId,
    int reminderId,
  ) =>
      db.transaction(() async {
        await (db.update(db.reminderTable)..where((r) => r.id.equals(reminderId)))
            .write(
          const ReminderTableCompanion(
            isActive: Value(false),
            alertSyncPending: Value(true),
          ),
        );
        return true;
      });

  /// Stops all check-in questions for a session, preserving task and start reminder.
  Future<bool> stopAskingForOccurrence(String occurrenceId) =>
      db.transaction(() async {
        final links = await db.planDao.getAlertLinksForOccurrence(occurrenceId);
        for (final link in links.where((l) => l.role == 'check_in')) {
          await (db.update(db.reminderTable)
                ..where((r) => r.id.equals(link.reminderId)))
              .write(
            const ReminderTableCompanion(
              isActive: Value(false),
              alertSyncPending: Value(true),
            ),
          );
        }
        return true;
      });

  /// Pauses a routine, stopping pending alerts for future sessions.
  Future<bool> pausePlan(String planId) => db.transaction(() async {
        final plan = await db.planDao.getPlanById(planId);
        if (plan == null) return false;

        await db.planDao.updatePlan(
          PlanDefinitionTableCompanion(
            id: Value(plan.id),
            status: const Value('paused'),
            updatedAt: Value(clock()),
          ),
        );

        // Deactivate alerts for future/pending sessions
        final occurrences = await db.planDao.getOccurrencesForPlan(planId);
        for (final occ in occurrences) {
          if (occ.outcome == 'scheduled') {
            final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
            for (final link in links) {
              await (db.update(db.reminderTable)
                    ..where((r) => r.id.equals(link.reminderId)))
                .write(
                const ReminderTableCompanion(
                  isActive: Value(false),
                  alertSyncPending: Value(true),
                ),
              );
            }
          }
        }
        return true;
      });

  /// Resumes a paused routine from [effectiveStartDate].
  Future<bool> resumePlan(String planId, {String? effectiveStartDate}) =>
      db.transaction(() async {
        final plan = await db.planDao.getPlanById(planId);
        if (plan == null) return false;

        final start = effectiveStartDate ??
            PlanRecurrenceEngine.formatDate(clock());

        await db.planDao.updatePlan(
          PlanDefinitionTableCompanion(
            id: Value(plan.id),
            status: const Value('active'),
            updatedAt: Value(clock()),
          ),
        );

        // Reactivate future scheduled occurrences on or after effectiveStartDate
        final occurrences = await db.planDao.getOccurrencesForPlan(planId);
        for (final occ in occurrences) {
          if (occ.outcome == 'scheduled' &&
              occ.eligibleLocalDate.compareTo(start) >= 0) {
            final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
            for (final link in links) {
              await (db.update(db.reminderTable)
                    ..where((r) => r.id.equals(link.reminderId)))
                .write(
                const ReminderTableCompanion(
                  isActive: Value(true),
                  alertSyncPending: Value(true),
                ),
              );
            }
          }
        }

        return true;
      });

  /// Permanently ends a routine, deactivating future pending alerts.
  Future<bool> endPlan(String planId) => db.transaction(() async {
        final plan = await db.planDao.getPlanById(planId);
        if (plan == null) return false;

        await db.planDao.updatePlan(
          PlanDefinitionTableCompanion(
            id: Value(plan.id),
            status: const Value('ended'),
            updatedAt: Value(clock()),
          ),
        );

        final occurrences = await db.planDao.getOccurrencesForPlan(planId);
        for (final occ in occurrences) {
          if (occ.outcome == 'scheduled') {
            final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
            for (final link in links) {
              await (db.update(db.reminderTable)
                    ..where((r) => r.id.equals(link.reminderId)))
                .write(
                const ReminderTableCompanion(
                  isActive: Value(false),
                  alertSyncPending: Value(true),
                ),
              );
            }
          }
        }
        return true;
      });
}
