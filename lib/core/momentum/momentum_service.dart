import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../notifications/notification_service.dart';
import '../providers/database_provider.dart';
import 'momentum_plan_generator.dart';

final momentumServiceProvider = Provider<MomentumService>((ref) {
  final dao = ref.watch(momentumDaoProvider);
  return MomentumService(dao: dao);
});

class MomentumService {
  final MomentumDao _dao;
  final NotificationService _notifications = NotificationService.instance;

  MomentumService({required MomentumDao dao}) : _dao = dao;

  /// Starts a new 30-day Momentum challenge.
  /// Generates the day-by-day plan, persists all commitments, and schedules
  /// real exact wake and session notifications.
  Future<int> startChallenge({
    required double currentWeightKg,
    double? targetWeightKg,
    int? age,
    double? heightCm,
    String biologicalSex = 'male',
    int targetWakeMinutes = 360, // 06:00 AM
    int baselineWakeMinutes = 480, // 08:00 AM
    int targetWindDownMinutes = 1320, // 10:00 PM
    String gymSplit = 'upper_lower',
    int gymDaysPerWeek = 4,
    int workoutDurationMinutes = 45,
    String walkingBaselineLevel = 'moderate',
    String fitnessExperience = 'intermediate',
    String physicalLimitations = '',
  }) async {
    // 1. Archive any existing active challenge and cancel its notifications
    final existing = await _dao.getActiveChallenge();
    if (existing != null) {
      await cancelAndArchiveChallenge(existing.id);
    }

    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final targetEndDate = startDate.add(const Duration(days: 30));

    // 2. Insert challenge record
    final challengeId = await _dao.insertChallenge(
      MomentumChallengeTableCompanion.insert(
        startDate: startDate,
        targetEndDate: targetEndDate,
        startWeightKg: Value(currentWeightKg),
        currentWeightKg: Value(currentWeightKg),
        targetWeightKg: Value(targetWeightKg),
        age: Value(age),
        heightCm: Value(heightCm),
        biologicalSex: Value(biologicalSex),
        targetWakeTimeMinutes: Value(targetWakeMinutes),
        targetWindDownMinutes: Value(targetWindDownMinutes),
        baselineWakeTimeMinutes: Value(baselineWakeMinutes),
        gymSplit: Value(gymSplit),
        gymDaysPerWeek: Value(gymDaysPerWeek),
        workoutDurationMinutes: Value(workoutDurationMinutes),
        walkingBaselineLevel: Value(walkingBaselineLevel),
        fitnessExperience: Value(fitnessExperience),
        physicalLimitations: Value(physicalLimitations),
        status: const Value('active'),
      ),
    );

    // 3. Generate 30-day commitments
    final generatedCommitments = MomentumPlanGenerator.generate30DayPlan(
      challengeId: challengeId,
      startDate: startDate,
      targetWakeMinutes: targetWakeMinutes,
      baselineWakeMinutes: baselineWakeMinutes,
      targetWindDownMinutes: targetWindDownMinutes,
      gymSplit: gymSplit,
      gymDaysPerWeek: gymDaysPerWeek,
      workoutDurationMinutes: workoutDurationMinutes,
      walkingBaselineLevel: walkingBaselineLevel,
      fitnessExperience: fitnessExperience,
      physicalLimitations: physicalLimitations,
    );

    final currentMinutes = now.hour * 60 + now.minute;

    // Day 1 mid-day adaptation: if user starts challenge during the day,
    // mark Day 1 commitments scheduled prior to current time as completed and adapted
    // so they are not asked to complete 06:00 AM wake-up in the afternoon.
    final commitments = generatedCommitments.map((c) {
      if (c.dayNumber.value == 1 &&
          c.scheduledTimeMinutes.value != null &&
          c.scheduledTimeMinutes.value! < currentMinutes) {
        return c.copyWith(
          isCompleted: const Value(true),
          completedAt: Value(now),
          wasAdapted: const Value(true),
          adaptationReason: const Value('Auto-completed: challenge started mid-day after scheduled time'),
        );
      }
      return c;
    }).toList();

    // 4. Batch persist to SQLite
    await _dao.batchInsertCommitments(commitments);

    // 5. Schedule real notifications for upcoming commitments (e.g. Next 7 days)
    await scheduleUpcomingNotifications(challengeId, daysAhead: 7);

    return challengeId;
  }

  /// Schedules actual Android and iOS alarms for the upcoming days.
  Future<void> scheduleUpcomingNotifications(int challengeId, {int daysAhead = 7}) async {
    final allCommitments = await _dao.getAllCommitments(challengeId);
    final now = DateTime.now();

    for (final commitment in allCommitments) {
      if (commitment.isCompleted) continue;
      if (commitment.notificationId == null || commitment.scheduledTimeMinutes == null) continue;

      final diffDays = commitment.scheduledDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (diffDays < 0 || diffDays > daysAhead) continue;

      final hour = commitment.scheduledTimeMinutes! ~/ 60;
      final minute = commitment.scheduledTimeMinutes! % 60;
      final scheduledDateTime = DateTime(
        commitment.scheduledDate.year,
        commitment.scheduledDate.month,
        commitment.scheduledDate.day,
        hour,
        minute,
      );

      // Only schedule if scheduledDateTime is in future or within 1 minute
      if (scheduledDateTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
        continue;
      }

      switch (commitment.commitmentType) {
        case 'wake':
          await _notifications.scheduleMomentumWakeAlarm(
            id: commitment.notificationId!,
            scheduledAt: scheduledDateTime,
            title: '⏰ Momentum 06:00 AM Wake Call',
            body: 'Rise and conquer. Drink 500ml water and lace up for morning momentum.',
          );
          break;
        case 'walk':
          await _notifications.scheduleMomentumCommitmentReminder(
            id: commitment.notificationId!,
            scheduledAt: scheduledDateTime,
            title: '🏃 ${commitment.title}',
            body: 'Time for your outdoor walk. Keep your daily fat-loss streak alive!',
            summaryText: '👟 Outdoor Walk',
          );
          break;
        case 'gym':
          await _notifications.scheduleMomentumCommitmentReminder(
            id: commitment.notificationId!,
            scheduledAt: scheduledDateTime,
            title: '🏋️ ${commitment.title}',
            body: commitment.description ?? 'Scheduled gym session is approaching. Consistency compounds!',
            summaryText: '💪 Gym Workout',
          );
          break;
        case 'wind_down':
          await _notifications.scheduleMomentumWindDownReminder(
            id: commitment.notificationId!,
            scheduledAt: scheduledDateTime,
            title: '🌙 10:00 PM Wind-Down Call',
            body: 'Dim lights and disconnect. Protect your 8-hour sleep opportunity for tomorrow.',
          );
          break;
        default:
          break;
      }
    }
  }

  /// Toggles completion of a commitment, and cancels any pending reminder so
  /// the user isn't notified after already completing it.
  Future<bool> toggleCommitment(
    int commitmentId, {
    double? metricValue,
    String? metricType,
  }) async {
    final nextStatus = await _dao.toggleCommitment(
      commitmentId,
      metricValue: metricValue,
      metricType: metricType,
    );

    // If marked completed, cancel pending notification
    final commitment = await (selectWhereCommitmentId(commitmentId));
    if (nextStatus && commitment?.notificationId != null) {
      await _notifications.cancel(commitment!.notificationId!);
    }

    return nextStatus;
  }

  /// Helper to get single commitment
  Future<MomentumCommitment?> selectWhereCommitmentId(int id) async {
    final challenge = await _dao.getActiveChallenge();
    if (challenge == null) return null;
    final all = await _dao.getAllCommitments(challenge.id);
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Adaptive rescheduling options for missed or tight-schedule sessions.
  Future<void> adaptCommitment({
    required int commitmentId,
    required String adaptationType, // 'shorten', 'reschedule_evening', 'swap_rest_day'
  }) async {
    final commitment = await selectWhereCommitmentId(commitmentId);
    if (commitment == null) return;

    // Cancel existing notification
    if (commitment.notificationId != null) {
      await _notifications.cancel(commitment.notificationId!);
    }

    switch (adaptationType) {
      case 'shorten':
        // Shorten to high-efficiency condensed 20-min session
        await _dao.adaptCommitment(
          commitmentId: commitmentId,
          newDurationMinutes: 20,
          newTargetDistanceMeters: commitment.targetDistanceMeters != null ? (commitment.targetDistanceMeters! * 0.5) : null,
          adaptationReason: 'Condensed to 20-min express session due to limited time.',
        );
        break;
      case 'reschedule_evening':
        // Move time to 06:30 PM (1110 minutes)
        await _dao.adaptCommitment(
          commitmentId: commitmentId,
          newScheduledTimeMinutes: 1110,
          adaptationReason: 'Rescheduled to 06:30 PM evening window.',
        );
        // Reschedule notification for evening
        if (commitment.notificationId != null) {
          final eveningTime = DateTime(
            commitment.scheduledDate.year,
            commitment.scheduledDate.month,
            commitment.scheduledDate.day,
            18,
            30,
          );
          if (eveningTime.isAfter(DateTime.now())) {
            await _notifications.scheduleMomentumCommitmentReminder(
              id: commitment.notificationId!,
              scheduledAt: eveningTime,
              title: '⚡ ${commitment.title}',
              body: 'Evening session starting now. Let’s get it done!',
            );
          }
        }
        break;
      case 'swap_rest_day':
        await _dao.adaptCommitment(
          commitmentId: commitmentId,
          adaptationReason: 'Swapped today’s session with active recovery to honor fatigue.',
        );
        break;
    }
  }

  /// Records weight log and updates active challenge current weight.
  Future<void> recordWeight(int challengeId, double weightKg) async {
    await _dao.updateCurrentWeight(challengeId, weightKg);
  }

  /// Cancel all pending notifications and archive an ongoing challenge.
  Future<void> cancelAndArchiveChallenge(int challengeId) async {
    final commitments = await _dao.getAllCommitments(challengeId);
    for (final c in commitments) {
      if (c.notificationId != null) {
        await _notifications.cancel(c.notificationId!);
      }
    }
    await _dao.setChallengeStatus(challengeId, 'archived');
  }

  /// Full cascading deletion of a challenge and all its records and notifications.
  Future<void> deleteChallengeCascading(int challengeId) async {
    final commitments = await _dao.getAllCommitments(challengeId);
    for (final c in commitments) {
      if (c.notificationId != null) {
        await _notifications.cancel(c.notificationId!);
      }
    }
    await _dao.deleteChallengeCascading(challengeId);
  }

  /// Computes estimated calories burned via validated MET formulas.
  /// [ESTIMATED] via MET method:
  /// Walk/Jog: MET 4.0 - 5.0
  /// Resistance training: MET 5.0 - 6.0
  static int estimateCaloriesBurned({
    required String type,
    required double userWeightKg,
    required int durationMinutes,
  }) {
    final double met = (type == 'gym') ? 5.5 : 4.2;
    final hours = durationMinutes / 60.0;
    return (met * userWeightKg * hours).round();
  }
}
