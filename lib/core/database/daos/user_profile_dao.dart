part of '../app_database.dart';

@DriftAccessor(tables: [UserProfileTable])
class UserProfileDao extends DatabaseAccessor<AppDatabase>
    with _$UserProfileDaoMixin {
  UserProfileDao(super.db);

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  /// Returns the first (and only) user profile row, or null if the user
  /// has not completed onboarding yet.
  Future<UserProfile?> getProfile() =>
      (select(userProfileTable)..limit(1)).getSingleOrNull();

  /// Reactive stream of the user profile. Emits a new value whenever the
  /// profile row changes.
  Stream<UserProfile?> watchProfile() =>
      (select(userProfileTable)..limit(1)).watchSingleOrNull();

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Insert a new profile or replace all columns if the row already exists
  /// (matched by primary key).
  Future<int> upsertProfile(UserProfileTableCompanion companion) =>
      into(userProfileTable).insertOnConflictUpdate(companion);

  /// Patches only [updatedAt] to the current timestamp.
  Future<void> touchUpdatedAt() async {
    await (update(userProfileTable)).write(
      UserProfileTableCompanion(updatedAt: Value(DateTime.now())),
    );
  }

  /// Updates [lastOpenedAt] to now — call this in main.dart on app resume.
  Future<void> touchLastOpened() async {
    await (update(userProfileTable)).write(
      UserProfileTableCompanion(lastOpenedAt: Value(DateTime.now())),
    );
  }

  /// Mark onboarding as complete.
  Future<void> completeOnboarding() async {
    await (update(userProfileTable)).write(
      const UserProfileTableCompanion(onboardingComplete: Value(true)),
    );
  }
}
