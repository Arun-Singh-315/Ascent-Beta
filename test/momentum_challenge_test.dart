import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/momentum/momentum_plan_generator.dart';
import 'package:ascent/core/momentum/momentum_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late MomentumDao dao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = MomentumDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Momentum Plan Generator Tests', () {
    test('Generates full 30-day schedule with exactly 5 commitments per day (150 total)', () {
      final now = DateTime.now();
      final commitments = MomentumPlanGenerator.generate30DayPlan(
        challengeId: 1,
        startDate: now,
        targetWakeMinutes: 360, // 06:00 AM
        baselineWakeMinutes: 480, // 08:00 AM
        targetWindDownMinutes: 1320, // 10:00 PM
        gymSplit: 'upper_lower',
        gymDaysPerWeek: 4,
        workoutDurationMinutes: 45,
        walkingBaselineLevel: 'moderate',
        fitnessExperience: 'intermediate',
      );

      expect(commitments.length, 150); // 30 days * 5 commitments

      // Check day numbers 1 to 30 exist
      final days = commitments.map((c) => c.dayNumber.value).toSet();
      expect(days.length, 30);
      expect(days.contains(1), isTrue);
      expect(days.contains(30), isTrue);
    });

    test('Implements realistic circadian transition: ramps wake-up time down from 8:00 AM to 6:00 AM', () {
      final now = DateTime.now();
      final commitments = MomentumPlanGenerator.generate30DayPlan(
        challengeId: 1,
        startDate: now,
        targetWakeMinutes: 360, // 06:00 AM
        baselineWakeMinutes: 480, // 08:00 AM
        targetWindDownMinutes: 1320,
        gymSplit: 'upper_lower',
        gymDaysPerWeek: 4,
        workoutDurationMinutes: 45,
        walkingBaselineLevel: 'moderate',
        fitnessExperience: 'intermediate',
      );

      final day1Wake = commitments.firstWhere((c) => c.dayNumber.value == 1 && c.commitmentType.value == 'wake');
      final day3Wake = commitments.firstWhere((c) => c.dayNumber.value == 3 && c.commitmentType.value == 'wake');
      final day7Wake = commitments.firstWhere((c) => c.dayNumber.value == 7 && c.commitmentType.value == 'wake');
      final day15Wake = commitments.firstWhere((c) => c.dayNumber.value == 15 && c.commitmentType.value == 'wake');

      // Day 1 wake time is stepped down from 480
      expect(day1Wake.scheduledTimeMinutes.value, lessThan(480));
      expect(day1Wake.scheduledTimeMinutes.value, greaterThan(360));

      // Day 3 wake time is earlier than Day 1
      expect(day3Wake.scheduledTimeMinutes.value!, lessThan(day1Wake.scheduledTimeMinutes.value!));

      // By Day 7+, wake time is locked at target 360 (06:00 AM)
      expect(day7Wake.scheduledTimeMinutes.value, equals(360));
      expect(day15Wake.scheduledTimeMinutes.value, equals(360));
    });

    test('Progresses outdoor walking volume across weeks', () {
      final now = DateTime.now();
      final commitments = MomentumPlanGenerator.generate30DayPlan(
        challengeId: 1,
        startDate: now,
        targetWakeMinutes: 360,
        baselineWakeMinutes: 360,
        targetWindDownMinutes: 1320,
        gymSplit: 'upper_lower',
        gymDaysPerWeek: 4,
        workoutDurationMinutes: 45,
        walkingBaselineLevel: 'moderate',
        fitnessExperience: 'intermediate',
      );

      final week1Walk = commitments.firstWhere((c) => c.dayNumber.value == 1 && c.commitmentType.value == 'walk');
      final week2Walk = commitments.firstWhere((c) => c.dayNumber.value == 8 && c.commitmentType.value == 'walk');
      final week3Walk = commitments.firstWhere((c) => c.dayNumber.value == 15 && c.commitmentType.value == 'walk');
      final week4Walk = commitments.firstWhere((c) => c.dayNumber.value == 22 && c.commitmentType.value == 'walk');

      expect(week2Walk.targetDistanceMeters.value!, greaterThan(week1Walk.targetDistanceMeters.value!));
      expect(week3Walk.targetDistanceMeters.value!, greaterThan(week2Walk.targetDistanceMeters.value!));
      expect(week4Walk.targetDistanceMeters.value!, greaterThan(week3Walk.targetDistanceMeters.value!));
    });
  });

  group('Momentum DAO & Database Lifecycle Tests', () {
    test('Challenge creation, querying, and completion tracking', () async {
      final now = DateTime.now();
      final challengeId = await dao.insertChallenge(
        MomentumChallengeTableCompanion.insert(
          startDate: now,
          targetEndDate: now.add(const Duration(days: 30)),
          startWeightKg: const Value(80.0),
          currentWeightKg: const Value(80.0),
          targetWeightKg: const Value(74.0),
        ),
      );

      expect(challengeId, isNonZero);

      final active = await dao.getActiveChallenge();
      expect(active, isNotNull);
      expect(active!.startWeightKg, 80.0);
      expect(active.currentWeightKg, 80.0);

      // Generate and batch insert commitments
      final list = MomentumPlanGenerator.generate30DayPlan(
        challengeId: challengeId,
        startDate: now,
        targetWakeMinutes: 360,
        baselineWakeMinutes: 480,
        targetWindDownMinutes: 1320,
        gymSplit: 'upper_lower',
        gymDaysPerWeek: 4,
        workoutDurationMinutes: 45,
        walkingBaselineLevel: 'moderate',
        fitnessExperience: 'intermediate',
      );

      await dao.batchInsertCommitments(list);

      final day1Items = await dao.getCommitmentsForDay(challengeId, 1);
      expect(day1Items.length, 5);

      // Toggle commitment completion
      final firstItemId = day1Items.first.id;
      final toggled = await dao.toggleCommitment(firstItemId);
      expect(toggled, isTrue);

      final updatedDay1 = await dao.getCommitmentsForDay(challengeId, 1);
      expect(updatedDay1.first.isCompleted, isTrue);
      expect(updatedDay1.first.completedAt, isNotNull);

      // Toggle back
      final untoggled = await dao.toggleCommitment(firstItemId);
      expect(untoggled, isFalse);
      final finalDay1 = await dao.getCommitmentsForDay(challengeId, 1);
      expect(finalDay1.first.isCompleted, isFalse);
    });

    test('Adaptive rescheduling: modifies session duration and marks wasAdapted', () async {
      final now = DateTime.now();
      final challengeId = await dao.insertChallenge(
        MomentumChallengeTableCompanion.insert(
          startDate: now,
          targetEndDate: now.add(const Duration(days: 30)),
        ),
      );

      final list = MomentumPlanGenerator.generate30DayPlan(
        challengeId: challengeId,
        startDate: now,
        targetWakeMinutes: 360,
        baselineWakeMinutes: 360,
        targetWindDownMinutes: 1320,
        gymSplit: 'upper_lower',
        gymDaysPerWeek: 4,
        workoutDurationMinutes: 45,
        walkingBaselineLevel: 'moderate',
        fitnessExperience: 'intermediate',
      );
      await dao.batchInsertCommitments(list);

      final day1Items = await dao.getCommitmentsForDay(challengeId, 1);
      final gymItem = day1Items.firstWhere((c) => c.commitmentType == 'gym' || c.commitmentType == 'recovery');

      // Adapt to 20 mins express
      await dao.adaptCommitment(
        commitmentId: gymItem.id,
        newDurationMinutes: 20,
        adaptationReason: 'Short on time today',
      );

      final day1Updated = await dao.getCommitmentsForDay(challengeId, 1);
      final adaptedItem = day1Updated.firstWhere((c) => c.id == gymItem.id);
      expect(adaptedItem.wasAdapted, isTrue);
      expect(adaptedItem.targetDurationMinutes, 20);
      expect(adaptedItem.adaptationReason, 'Short on time today');
    });

    test('Cascading deletion cleans up challenge and all commitments', () async {
      final now = DateTime.now();
      final challengeId = await dao.insertChallenge(
        MomentumChallengeTableCompanion.insert(
          startDate: now,
          targetEndDate: now.add(const Duration(days: 30)),
        ),
      );

      final list = MomentumPlanGenerator.generate30DayPlan(
        challengeId: challengeId,
        startDate: now,
        targetWakeMinutes: 360,
        baselineWakeMinutes: 360,
        targetWindDownMinutes: 1320,
        gymSplit: 'upper_lower',
        gymDaysPerWeek: 4,
        workoutDurationMinutes: 45,
        walkingBaselineLevel: 'moderate',
        fitnessExperience: 'intermediate',
      );
      await dao.batchInsertCommitments(list);

      var all = await dao.getAllCommitments(challengeId);
      expect(all.length, 150);

      // Perform clean cascading delete
      await dao.deleteChallengeCascading(challengeId);

      all = await dao.getAllCommitments(challengeId);
      expect(all.isEmpty, isTrue);

      final active = await dao.getActiveChallenge();
      expect(active, isNull);
    });
  });

  group('Momentum Energy Expenditure & Calorie Tests', () {
    test('Calculates estimated MET energy expenditure correctly', () {
      // 70 kg individual walking for 30 minutes (MET 4.2)
      // 4.2 * 70 * (30 / 60) = 147 calories
      final walkCalories = MomentumService.estimateCaloriesBurned(
        type: 'walk',
        userWeightKg: 70.0,
        durationMinutes: 30,
      );
      expect(walkCalories, equals(147));

      // 80 kg individual lifting weights for 45 minutes (MET 5.5)
      // 5.5 * 80 * (45 / 60) = 330 calories
      final gymCalories = MomentumService.estimateCaloriesBurned(
        type: 'gym',
        userWeightKg: 80.0,
        durationMinutes: 45,
      );
      expect(gymCalories, equals(330));
    });
  });
}
