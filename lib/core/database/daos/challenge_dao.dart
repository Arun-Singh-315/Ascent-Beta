part of '../app_database.dart';

@DriftAccessor(
  tables: [
    ChallengeTable,
    ChallengeLinkTable,
    ChallengeProofEventTable,
    ChallengeAmendmentTable,
  ],
)
class ChallengeDao extends DatabaseAccessor<AppDatabase>
    with _$ChallengeDaoMixin {
  ChallengeDao(super.db);

  Stream<List<Challenge>> watchChallenges() =>
      (select(challengeTable)
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .watch();

  Stream<List<Challenge>> watchActiveChallenges() =>
      (select(challengeTable)
            ..where((row) => row.status.equals('active'))
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]))
          .watch();

  Stream<Challenge?> watchActiveChallenge() =>
      (select(challengeTable)
            ..where((row) => row.status.equals('active'))
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
            ..limit(1))
          .watchSingleOrNull();

  Future<Challenge?> getActiveChallenge() =>
      (select(challengeTable)
            ..where((row) => row.status.equals('active'))
            ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertChallenge(ChallengeTableCompanion entry) =>
      into(challengeTable).insert(entry);

  Future<void> insertLink(ChallengeLinkTableCompanion entry) async {
    await into(
      challengeLinkTable,
    ).insert(entry, mode: InsertMode.insertOrIgnore);
  }

  Stream<List<ChallengeLink>> watchLinks(int challengeId) =>
      (select(challengeLinkTable)
            ..where((row) => row.challengeId.equals(challengeId))
            ..orderBy([(row) => OrderingTerm.asc(row.sourceType)]))
          .watch();

  Future<List<ChallengeLink>> getLinks(int challengeId) => (select(
    challengeLinkTable,
  )..where((row) => row.challengeId.equals(challengeId))).get();

  Stream<List<ChallengeProofEvent>> watchProofs(int challengeId) =>
      (select(challengeProofEventTable)
            ..where((row) => row.challengeId.equals(challengeId))
            ..orderBy([
              (row) => OrderingTerm.asc(row.day),
              (row) => OrderingTerm.asc(row.sourceId),
            ]))
          .watch();

  Future<List<ChallengeProofEvent>> getProofs(int challengeId) => (select(
    challengeProofEventTable,
  )..where((row) => row.challengeId.equals(challengeId))).get();

  Future<void> upsertProof(ChallengeProofEventTableCompanion entry) async {
    await into(
      challengeProofEventTable,
    ).insert(entry, mode: InsertMode.insertOrReplace);
  }

  Future<void> replaceProofsForKind(
    int challengeId,
    String kind,
    List<ChallengeProofEventTableCompanion> entries,
  ) async {
    await transaction(() async {
      await (delete(challengeProofEventTable)..where(
            (row) =>
                row.challengeId.equals(challengeId) & row.kind.equals(kind),
          ))
          .go();
      if (entries.isNotEmpty) {
        await batch(
          (batch) => batch.insertAll(challengeProofEventTable, entries),
        );
      }
    });
  }

  Future<void> setStatus(int id, String status) async {
    await (update(challengeTable)..where((row) => row.id.equals(id))).write(
      ChallengeTableCompanion(status: Value(status)),
    );
  }

  Future<void> deleteChallenge(int id) async {
    await transaction(() async {
      await (delete(
        challengeAmendmentTable,
      )..where((row) => row.challengeId.equals(id))).go();
      await (delete(
        challengeProofEventTable,
      )..where((row) => row.challengeId.equals(id))).go();
      await (delete(
        challengeLinkTable,
      )..where((row) => row.challengeId.equals(id))).go();
      await (delete(challengeTable)..where((row) => row.id.equals(id))).go();
    });
  }
}
