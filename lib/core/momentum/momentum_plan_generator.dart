import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Intelligent 30-day schedule generator that produces a personalized,
/// scientifically sound day-by-day training, walking, and circadian plan.
class MomentumPlanGenerator {
  const MomentumPlanGenerator();

  /// Generates the complete 30-day commitment plan for a newly created challenge.
  static List<MomentumCommitmentTableCompanion> generate30DayPlan({
    required int challengeId,
    required DateTime startDate,
    required int targetWakeMinutes, // e.g. 360 = 06:00 AM
    required int baselineWakeMinutes, // e.g. 480 = 08:00 AM
    required int targetWindDownMinutes, // e.g. 1320 = 10:00 PM
    required String gymSplit, // 'upper_lower', 'full_body', 'push_pull_legs'
    required int gymDaysPerWeek, // 3, 4, 5
    required int workoutDurationMinutes, // 30, 45, 60
    required String walkingBaselineLevel, // 'light', 'moderate', 'active'
    required String fitnessExperience, // 'beginner', 'intermediate', 'advanced'
    String physicalLimitations = '',
  }) {
    final List<MomentumCommitmentTableCompanion> commitments = [];

    // Calculate baseline walking volume
    double baseDistanceMeters;
    int baseWalkMinutes;
    switch (walkingBaselineLevel) {
      case 'light':
        baseDistanceMeters = 2000.0; // 2.0 km
        baseWalkMinutes = 20;
        break;
      case 'active':
        baseDistanceMeters = 4500.0; // 4.5 km
        baseWalkMinutes = 45;
        break;
      case 'moderate':
      default:
        baseDistanceMeters = 3000.0; // 3.0 km
        baseWalkMinutes = 30;
        break;
    }

    final normalizedStartDate = DateTime(startDate.year, startDate.month, startDate.day);

    for (int day = 1; day <= 30; day++) {
      final scheduledDate = normalizedStartDate.add(Duration(days: day - 1));
      final weekNumber = ((day - 1) ~/ 7) + 1; // Week 1 to 5
      final dayOfWeek = scheduledDate.weekday; // 1 = Monday, 7 = Sunday

      // 1. Calculate Gradual Wake-up Time for this day
      // If user currently wakes at 08:00 AM and target is 06:00 AM (120 min diff),
      // ramp wake-up earlier over first 6 days by ~20 mins/day.
      final int wakeTimeMinutes;
      if (day <= 6 && baselineWakeMinutes > targetWakeMinutes) {
        final step = ((baselineWakeMinutes - targetWakeMinutes) / 6.0).round();
        wakeTimeMinutes = baselineWakeMinutes - (step * day);
      } else {
        wakeTimeMinutes = targetWakeMinutes; // Locked at target (e.g. 06:00 AM)
      }

      // ── Commitment 1: Wake-up & Circadian Target ──────────────────────────
      final wakeHour = wakeTimeMinutes ~/ 60;
      final wakeMin = wakeTimeMinutes % 60;
      final wakeTimeFormatted = '${wakeHour.toString().padLeft(2, '0')}:${wakeMin.toString().padLeft(2, '0')}';
      commitments.add(
        MomentumCommitmentTableCompanion.insert(
          challengeId: challengeId,
          dayNumber: day,
          scheduledDate: scheduledDate,
          commitmentType: 'wake',
          title: 'Wake-Up Target ($wakeTimeFormatted)',
          description: Value(day <= 6 && baselineWakeMinutes > targetWakeMinutes
              ? 'Phase 1 Circadian Entrainment: Stepping wake-up towards 06:00 AM.'
              : 'Target 06:00 AM wake-up. Drink 500ml water to kickstart metabolic rate.'),
          scheduledTimeMinutes: Value(wakeTimeMinutes),
          notificationId: Value(_generateNotificationId(day, 1)),
          targetDurationMinutes: const Value(15),
          metadataJson: Value(jsonEncode({'phase': weekNumber, 'targetWake': wakeTimeMinutes})),
        ),
      );

      // ── Commitment 2: Daily Morning Hydration Routine ─────────────────────
      commitments.add(
        MomentumCommitmentTableCompanion.insert(
          challengeId: challengeId,
          dayNumber: day,
          scheduledDate: scheduledDate,
          commitmentType: 'hydration',
          title: 'Morning Hydration (500ml)',
          description: const Value('Hydrate immediately upon rising to elevate alertness and digestion.'),
          scheduledTimeMinutes: Value(wakeTimeMinutes + 10),
          notificationId: Value(_generateNotificationId(day, 2)),
          metadataJson: const Value('{"volumeMl": 500}'),
        ),
      );

      // ── Commitment 3: Outdoor Walking Session ─────────────────────────────
      // Progressive volume increase: +10% per week
      final volumeMultiplier = 1.0 + ((weekNumber - 1) * 0.12);
      final dayDistanceMeters = (baseDistanceMeters * volumeMultiplier).clamp(2000.0, 7000.0);
      final dayWalkMinutes = (baseWalkMinutes * volumeMultiplier).round().clamp(20, 60);
      final walkTimeMinutes = wakeTimeMinutes + 35; // 35 mins after waking

      commitments.add(
        MomentumCommitmentTableCompanion.insert(
          challengeId: challengeId,
          dayNumber: day,
          scheduledDate: scheduledDate,
          commitmentType: 'walk',
          title: 'Outdoor Morning Walk (${(dayDistanceMeters / 1000).toStringAsFixed(1)} km)',
          description: Value('Week $weekNumber progression: $dayWalkMinutes mins brisk pace to maximize fat oxidation.'),
          targetDurationMinutes: Value(dayWalkMinutes),
          targetDistanceMeters: Value(dayDistanceMeters),
          scheduledTimeMinutes: Value(walkTimeMinutes),
          notificationId: Value(_generateNotificationId(day, 3)),
          metadataJson: Value(jsonEncode({
            'targetPace': '9:30/km',
            'estimatedCalories': (dayWalkMinutes * 4.5 * 1.1).round(),
          })),
        ),
      );

      // ── Commitment 4: Gym Workout / Active Recovery ───────────────────────
      // Tailored according to gym split and day of week
      final _WorkoutSpec workout = _determineWorkoutForDay(
        dayOfWeek: dayOfWeek,
        gymSplit: gymSplit,
        gymDaysPerWeek: gymDaysPerWeek,
        workoutDurationMinutes: workoutDurationMinutes,
        experience: fitnessExperience,
      );

      final gymTimeMinutes = 1050; // 05:30 PM default afternoon gym time

      commitments.add(
        MomentumCommitmentTableCompanion.insert(
          challengeId: challengeId,
          dayNumber: day,
          scheduledDate: scheduledDate,
          commitmentType: workout.isRecovery ? 'recovery' : 'gym',
          title: workout.title,
          description: Value(workout.description),
          targetDurationMinutes: Value(workout.durationMinutes),
          scheduledTimeMinutes: Value(gymTimeMinutes),
          notificationId: Value(_generateNotificationId(day, 4)),
          metadataJson: Value(jsonEncode({
            'exercises': workout.exercises,
            'isRecovery': workout.isRecovery,
          })),
        ),
      );

      // ── Commitment 5: Evening Wind-Down & Sleep Protection ────────────────
      commitments.add(
        MomentumCommitmentTableCompanion.insert(
          challengeId: challengeId,
          dayNumber: day,
          scheduledDate: scheduledDate,
          commitmentType: 'wind_down',
          title: 'Evening Wind-Down & Digital Curfew',
          description: const Value('Protect your 8-hour sleep recovery window. Dim lights and review tomorrow’s plan.'),
          scheduledTimeMinutes: Value(targetWindDownMinutes),
          notificationId: Value(_generateNotificationId(day, 5)),
          targetDurationMinutes: const Value(20),
          metadataJson: const Value('{"sleepTargetHours": 8}'),
        ),
      );
    }

    return commitments;
  }

  static int _generateNotificationId(int day, int slot) {
    // Generates unique positive 32-bit int IDs like 70011 to 70305
    return 70000 + (day * 10) + slot;
  }

  static _WorkoutSpec _determineWorkoutForDay({
    required int dayOfWeek,
    required String gymSplit,
    required int gymDaysPerWeek,
    required int workoutDurationMinutes,
    required String experience,
  }) {
    if (gymSplit == 'full_body' || gymDaysPerWeek <= 3) {
      // 3-Day Full Body Split (Mon, Wed, Fri)
      switch (dayOfWeek) {
        case 1: // Monday
          return _WorkoutSpec(
            title: 'Gym: Full Body A (Compound Strength)',
            description: 'Barbell/Goblet Squats, Flat Dumbbell Bench Press, Lat Pulldowns, Plank Holds.',
            durationMinutes: workoutDurationMinutes,
            exercises: [
              'Goblet/Barbell Squats (3 sets x 8-10 reps)',
              'Dumbbell Bench Press (3 sets x 10 reps)',
              'Lat Pulldown (3 sets x 10-12 reps)',
              'Plank Holds (3 sets x 45s)',
            ],
            isRecovery: false,
          );
        case 3: // Wednesday
          return _WorkoutSpec(
            title: 'Gym: Full Body B (Hinge & Push)',
            description: 'Romanian Deadlifts, Overhead Shoulder Press, Seated Cable Rows, Core Crunches.',
            durationMinutes: workoutDurationMinutes,
            exercises: [
              'Romanian Deadlift (3 sets x 8-10 reps)',
              'Dumbbell Overhead Press (3 sets x 10 reps)',
              'Seated Cable Rows (3 sets x 10-12 reps)',
              'Walking Lunges (3 sets x 12 reps/leg)',
            ],
            isRecovery: false,
          );
        case 5: // Friday
          return _WorkoutSpec(
            title: 'Gym: Full Body C (Hypertrophy & Mobility)',
            description: 'Leg Press, Incline Dumbbell Press, Facepulls, Biceps & Triceps superset.',
            durationMinutes: workoutDurationMinutes,
            exercises: [
              'Leg Press / Hack Squat (3 sets x 10-12 reps)',
              'Incline DB Press (3 sets x 10 reps)',
              'Facepulls (3 sets x 15 reps)',
              'Arm Superset (3 sets x 12 reps)',
            ],
            isRecovery: false,
          );
        default:
          return _WorkoutSpec(
            title: 'Active Recovery & Core Mobility',
            description: 'Light mobility stretches, hip openers, hydration, and central nervous system recovery.',
            durationMinutes: 20,
            exercises: [
              'Cat-Cow & Child’s Pose (5 mins)',
              'Hip Flexor & Hamstring Stretch (5 mins)',
              'Thoracic Spine Rotations (5 mins)',
              'Deep Diaphragmatic Breathing (5 mins)',
            ],
            isRecovery: true,
          );
      }
    } else {
      // 4-Day Upper / Lower Split (Default Recommended)
      switch (dayOfWeek) {
        case 1: // Monday
          return _WorkoutSpec(
            title: 'Gym: Upper Body A (Chest & Back Focus)',
            description: 'Flat DB Press, Chest-Supported Rows, Overhead Press, Cable Lat Pulldowns.',
            durationMinutes: workoutDurationMinutes,
            exercises: [
              'Flat Dumbbell Bench Press (3 sets x 8-10 reps)',
              'Chest-Supported Row (3 sets x 10-12 reps)',
              'Seated DB Shoulder Press (3 sets x 10 reps)',
              'Lat Pulldowns (3 sets x 10-12 reps)',
              'Tricep Pushdowns (2 sets x 12-15 reps)',
            ],
            isRecovery: false,
          );
        case 2: // Tuesday
          return _WorkoutSpec(
            title: 'Gym: Lower Body A (Quad & Core Focus)',
            description: 'Back / Goblet Squats, Romanian Deadlifts, Leg Extensions, Hanging Knee Raises.',
            durationMinutes: workoutDurationMinutes,
            exercises: [
              'Barbell / Goblet Squats (3 sets x 8-10 reps)',
              'Romanian Deadlifts (3 sets x 10 reps)',
              'Leg Extensions (3 sets x 12-15 reps)',
              'Calf Raises (3 sets x 15 reps)',
              'Hanging Knee Raises (3 sets x 12 reps)',
            ],
            isRecovery: false,
          );
        case 4: // Thursday
          return _WorkoutSpec(
            title: 'Gym: Upper Body B (Shoulders & Hypertrophy)',
            description: 'Incline DB Press, Neutral Grip Cable Pulls, Lateral Raises, Bicep Curls.',
            durationMinutes: workoutDurationMinutes,
            exercises: [
              'Incline Dumbbell Press (3 sets x 10 reps)',
              'Single-Arm Cable Rows (3 sets x 10-12 reps)',
              'Dumbbell Lateral Raises (4 sets x 12-15 reps)',
              'Incline DB Bicep Curls (3 sets x 12 reps)',
              'Overhead Rope Extensions (3 sets x 12 reps)',
            ],
            isRecovery: false,
          );
        case 5: // Friday
          return _WorkoutSpec(
            title: 'Gym: Lower Body B (Hamstring & Glute Focus)',
            description: 'Leg Press, Hamstring Curls, Walking Lunges, Ab Wheel / Planks.',
            durationMinutes: workoutDurationMinutes,
            exercises: [
              'Leg Press (3 sets x 10-12 reps)',
              'Lying Hamstring Curls (3 sets x 12 reps)',
              'Walking Dumbbell Lunges (3 sets x 10 reps/side)',
              'Standing Calf Raises (3 sets x 15 reps)',
              'Plank Hold (3 sets x 60s)',
            ],
            isRecovery: false,
          );
        default:
          return _WorkoutSpec(
            title: 'Active Recovery & Joint Mobility',
            description: 'Active rest day to replenish glycogen, reduce delayed onset muscle soreness, and rest.',
            durationMinutes: 20,
            exercises: [
              'Full-body dynamic mobility flow (10 mins)',
              'Static hamstring & quad stretch (5 mins)',
              'Hydration & recovery reflection (5 mins)',
            ],
            isRecovery: true,
          );
      }
    }
  }
}

class _WorkoutSpec {
  final String title;
  final String description;
  final int durationMinutes;
  final List<String> exercises;
  final bool isRecovery;

  const _WorkoutSpec({
    required this.title,
    required this.description,
    required this.durationMinutes,
    required this.exercises,
    required this.isRecovery,
  });
}
