import 'package:drift/drift.dart';

@DataClassName('UserProfile')
class UserProfileTable extends Table {
  @override
  String get tableName => 'user_profiles';

  IntColumn get id => integer().autoIncrement()();

  /// Full name of the user.
  TextColumn get name => text().withLength(min: 1, max: 100)();

  /// Target role the user is preparing for (e.g. "SDE-2").
  TextColumn get targetRole => text().withDefault(const Constant(''))();

  /// JSON-encoded list of target companies (e.g. '["Google","Meta"]').
  TextColumn get targetCompanies =>
      text().withDefault(const Constant('[]'))();

  /// Planned date of the interview (can be null if unknown).
  DateTimeColumn get interviewDate => dateTime().nullable()();

  /// How many hours per week the user plans to study.
  IntColumn get weeklyHoursAvailable =>
      integer().withDefault(const Constant(10))();

  /// Preferred study window: 'morning' | 'afternoon' | 'evening' | 'flexible'.
  TextColumn get preferredStudyWindow =>
      text().withDefault(const Constant('morning'))();

  /// JSON map of self-rated skill levels
  /// e.g. '{"dsa":3,"systemDesign":2,"coreStack":3}' (scale 1–5).
  TextColumn get skillSelfRatings => text().withDefault(
        const Constant('{"dsa":3,"systemDesign":2,"coreStack":3}'),
      )();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// Timestamp of the last time the user opened the app.
  DateTimeColumn get lastOpenedAt => dateTime().nullable()();

  /// Whether the user has completed the onboarding flow.
  BoolColumn get onboardingComplete =>
      boolean().withDefault(const Constant(false))();
}
