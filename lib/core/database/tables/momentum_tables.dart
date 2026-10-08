import 'package:drift/drift.dart';

@DataClassName('MomentumChallenge')
class MomentumChallengeTable extends Table {
  @override
  String get tableName => 'momentum_challenges';

  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get targetEndDate => dateTime()();
  IntColumn get durationDays => integer().withDefault(const Constant(30))();
  RealColumn get startWeightKg => real().nullable()();
  RealColumn get targetWeightKg => real().nullable()();
  RealColumn get currentWeightKg => real().nullable()();
  IntColumn get age => integer().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get biologicalSex => text().withDefault(const Constant('male'))();
  IntColumn get targetWakeTimeMinutes => integer().withDefault(const Constant(360))(); // 06:00 AM = 360 min
  IntColumn get targetWindDownMinutes => integer().withDefault(const Constant(1320))(); // 10:00 PM = 1320 min
  IntColumn get baselineWakeTimeMinutes => integer().withDefault(const Constant(480))(); // e.g. 08:00 AM
  IntColumn get baselineBedTimeMinutes => integer().withDefault(const Constant(1410))(); // e.g. 11:30 PM
  TextColumn get gymSplit => text().withDefault(const Constant('upper_lower'))(); // upper_lower, full_body, push_pull_legs
  IntColumn get gymDaysPerWeek => integer().withDefault(const Constant(4))();
  IntColumn get workoutDurationMinutes => integer().withDefault(const Constant(45))();
  TextColumn get walkingBaselineLevel => text().withDefault(const Constant('moderate'))(); // light, moderate, active
  TextColumn get fitnessExperience => text().withDefault(const Constant('intermediate'))(); // beginner, intermediate, advanced
  TextColumn get physicalLimitations => text().withDefault(const Constant(''))();
  TextColumn get coachingPersonality => text().withDefault(const Constant('strict_supportive'))();
  TextColumn get status => text().withDefault(const Constant('active'))(); // active, completed, paused
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('MomentumCommitment')
class MomentumCommitmentTable extends Table {
  @override
  String get tableName => 'momentum_commitments';

  IntColumn get id => integer().autoIncrement()();
  IntColumn get challengeId => integer().references(MomentumChallengeTable, #id)();
  IntColumn get dayNumber => integer()(); // 1..30
  DateTimeColumn get scheduledDate => dateTime()(); // normalized to midnight
  TextColumn get commitmentType => text()(); // 'wake', 'walk', 'gym', 'habit', 'wind_down'
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  IntColumn get targetDurationMinutes => integer().nullable()();
  RealColumn get targetDistanceMeters => real().nullable()();
  IntColumn get scheduledTimeMinutes => integer().nullable()(); // Minutes from midnight (e.g. 360 = 06:00)
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get wasAdapted => boolean().withDefault(const Constant(false))();
  TextColumn get adaptationReason => text().nullable()();
  IntColumn get notificationId => integer().nullable()();
  IntColumn get linkedWalkSessionId => integer().nullable()();
  IntColumn get linkedHabitId => integer().nullable()();
  IntColumn get linkedTimeSessionId => integer().nullable()();
  RealColumn get metricLoggedValue => real().nullable()();
  TextColumn get metricLoggedType => text().nullable()(); // 'measured', 'entered', 'estimated'
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
}
