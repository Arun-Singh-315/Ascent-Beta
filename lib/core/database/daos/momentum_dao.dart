part of '../app_database.dart';

@DriftAccessor(tables: [
  MomentumChallengeTable,
  MomentumCommitmentTable,
])
class MomentumDao extends DatabaseAccessor<AppDatabase> with _$MomentumDaoMixin {
  MomentumDao(super.db);

  /// Watch the currently active 30-day challenge.
  Stream<MomentumChallenge?> watchActiveChallenge() {
    return (select(momentumChallengeTable)
          ..where((c) => c.status.equals('active'))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Get the currently active 30-day challenge.
  Future<MomentumChallenge?> getActiveChallenge() {
    return (select(momentumChallengeTable)
          ..where((c) => c.status.equals('active'))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Create a new challenge.
  Future<int> insertChallenge(MomentumChallengeTableCompanion challenge) {
    return into(momentumChallengeTable).insert(challenge);
  }

  /// Update challenge state.
  Future<bool> updateChallenge(MomentumChallengeTableCompanion challenge) {
    return update(momentumChallengeTable).replace(challenge);
  }

  /// Update current body weight for an ongoing challenge.
  Future<int> updateCurrentWeight(int challengeId, double weightKg) {
    return (update(momentumChallengeTable)..where((c) => c.id.equals(challengeId))).write(
      MomentumChallengeTableCompanion(
        currentWeightKg: Value(weightKg),
      ),
    );
  }

  /// Complete or archive an existing challenge.
  Future<int> setChallengeStatus(int challengeId, String status) {
    return (update(momentumChallengeTable)..where((c) => c.id.equals(challengeId))).write(
      MomentumChallengeTableCompanion(
        status: Value(status),
      ),
    );
  }

  /// Batch insert 30-day commitments.
  Future<void> batchInsertCommitments(List<MomentumCommitmentTableCompanion> commitments) {
    return batch((b) {
      b.insertAll(momentumCommitmentTable, commitments);
    });
  }

  /// Watch commitments for a specific normalized date.
  Stream<List<MomentumCommitment>> watchCommitmentsForDate(DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return (select(momentumCommitmentTable)
          ..where((c) =>
              c.scheduledDate.isBiggerOrEqualValue(startOfDay) &
              c.scheduledDate.isSmallerOrEqualValue(endOfDay))
          ..orderBy([
            (c) => OrderingTerm.asc(c.scheduledTimeMinutes),
            (c) => OrderingTerm.asc(c.id),
          ]))
        .watch();
  }

  /// Watch commitments for a specific challenge and day number (1..30).
  Stream<List<MomentumCommitment>> watchCommitmentsForDay(int challengeId, int dayNumber) {
    return (select(momentumCommitmentTable)
          ..where((c) => c.challengeId.equals(challengeId) & c.dayNumber.equals(dayNumber))
          ..orderBy([
            (c) => OrderingTerm.asc(c.scheduledTimeMinutes),
            (c) => OrderingTerm.asc(c.id),
          ]))
        .watch();
  }

  /// Get commitments for a specific day number.
  Future<List<MomentumCommitment>> getCommitmentsForDay(int challengeId, int dayNumber) {
    return (select(momentumCommitmentTable)
          ..where((c) => c.challengeId.equals(challengeId) & c.dayNumber.equals(dayNumber))
          ..orderBy([
            (c) => OrderingTerm.asc(c.scheduledTimeMinutes),
            (c) => OrderingTerm.asc(c.id),
          ]))
        .get();
  }

  /// Watch all commitments belonging to a challenge.
  Stream<List<MomentumCommitment>> watchAllCommitments(int challengeId) {
    return (select(momentumCommitmentTable)
          ..where((c) => c.challengeId.equals(challengeId))
          ..orderBy([
            (c) => OrderingTerm.asc(c.dayNumber),
            (c) => OrderingTerm.asc(c.scheduledTimeMinutes),
          ]))
        .watch();
  }

  /// Get all commitments for a challenge.
  Future<List<MomentumCommitment>> getAllCommitments(int challengeId) {
    return (select(momentumCommitmentTable)
          ..where((c) => c.challengeId.equals(challengeId))
          ..orderBy([
            (c) => OrderingTerm.asc(c.dayNumber),
            (c) => OrderingTerm.asc(c.scheduledTimeMinutes),
          ]))
        .get();
  }

  /// Toggle completion of a commitment.
  Future<bool> toggleCommitment(
    int commitmentId, {
    bool? forceCompleted,
    double? metricValue,
    String? metricType,
  }) async {
    final item = await (select(momentumCommitmentTable)..where((c) => c.id.equals(commitmentId))).getSingleOrNull();
    if (item == null) return false;

    final nextStatus = forceCompleted ?? !item.isCompleted;
    final now = DateTime.now();

    await (update(momentumCommitmentTable)..where((c) => c.id.equals(commitmentId))).write(
      MomentumCommitmentTableCompanion(
        isCompleted: Value(nextStatus),
        completedAt: Value(nextStatus ? now : null),
        metricLoggedValue: metricValue != null ? Value(metricValue) : const Value.absent(),
        metricLoggedType: metricType != null ? Value(metricType) : const Value.absent(),
      ),
    );
    return nextStatus;
  }

  /// Adapt / Reschedule a commitment (e.g. user chooses shorter session or moves to evening).
  Future<int> adaptCommitment({
    required int commitmentId,
    int? newScheduledTimeMinutes,
    int? newDurationMinutes,
    double? newTargetDistanceMeters,
    String? adaptationReason,
  }) {
    return (update(momentumCommitmentTable)..where((c) => c.id.equals(commitmentId))).write(
      MomentumCommitmentTableCompanion(
        scheduledTimeMinutes: newScheduledTimeMinutes != null ? Value(newScheduledTimeMinutes) : const Value.absent(),
        targetDurationMinutes: newDurationMinutes != null ? Value(newDurationMinutes) : const Value.absent(),
        targetDistanceMeters: newTargetDistanceMeters != null ? Value(newTargetDistanceMeters) : const Value.absent(),
        wasAdapted: const Value(true),
        adaptationReason: adaptationReason != null ? Value(adaptationReason) : const Value.absent(),
      ),
    );
  }

  /// Link a completed walk session to a walk commitment.
  Future<int> linkWalkSession(int commitmentId, int walkSessionId, double distanceMeters) {
    return (update(momentumCommitmentTable)..where((c) => c.id.equals(commitmentId))).write(
      MomentumCommitmentTableCompanion(
        linkedWalkSessionId: Value(walkSessionId),
        isCompleted: const Value(true),
        completedAt: Value(DateTime.now()),
        metricLoggedValue: Value(distanceMeters),
        metricLoggedType: const Value('measured'),
      ),
    );
  }

  /// Clean cascading deletion of a challenge and all associated commitments.
  Future<void> deleteChallengeCascading(int challengeId) async {
    await (delete(momentumCommitmentTable)..where((c) => c.challengeId.equals(challengeId))).go();
    await (delete(momentumChallengeTable)..where((c) => c.id.equals(challengeId))).go();
  }
}
