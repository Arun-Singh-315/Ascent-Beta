import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/challenge/domain/challenge_pace_engine.dart';
import 'package:ascent/features/challenge/domain/challenge_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  group('Challenge pace engine', () {
    test('uses stable inputs and exposes a deterministic pace estimate', () {
      final progress = ChallengePaceEngine.calculate(
        targetTotal: 600,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 10),
        today: DateTime(2026, 10, 3),
        evidence: [
          ChallengeEvidence(day: DateTime(2026, 10, 1), amount: 60),
          ChallengeEvidence(day: DateTime(2026, 10, 2), amount: 60),
          ChallengeEvidence(day: DateTime(2026, 10, 3), amount: 60),
        ],
      );

      expect(progress.completedAmount, 180);
      expect(progress.percent, 30);
      expect(progress.daysLeft, 8);
      expect(progress.verifiedDays, 3);
      expect(progress.chance, inInclusiveRange(1, 99));
      expect(progress.status, ChallengePaceStatus.ahead);
    });

    test('does not count future evidence before its local day', () {
      final progress = ChallengePaceEngine.calculate(
        targetTotal: 100,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 10),
        today: DateTime(2026, 10, 2),
        evidence: [
          ChallengeEvidence(day: DateTime(2026, 10, 4), amount: 100),
        ],
      );

      expect(progress.completedAmount, 0);
      expect(progress.percent, 0);
    });
  });

  group('Challenge persistence', () {
    test(
      'creates one active challenge with a stable source link and rejects a second',
      () async {
        final service = ChallengeService(db);
        final challengeId = await service.create(
          type: 'activity',
          title: 'Daily Focus',
          sourceType: 'task',
          sourceId: '42',
          targetTotal: 900,
          dailyMinimum: 45,
          durationDays: 20,
          now: DateTime(2026, 10, 11, 12),
        );

        final active = await db.challengeDao.getActiveChallenge();
        final links = await db.challengeDao.getLinks(challengeId);
        expect(active?.title, 'Daily Focus');
        expect(links.single.sourceType, 'task');
        expect(links.single.sourceId, '42');
        expect(active?.startDay, '2026-10-11');
        expect(active?.endDay, '2026-10-30');

        await expectLater(
          service.create(
            type: 'learning',
            title: 'Course',
            sourceType: 'learning_course',
            sourceId: 'course-1',
            targetTotal: 200,
            dailyMinimum: 10,
            durationDays: 20,
          ),
          throwsStateError,
        );
      },
    );

    test(
      'proof upsert is idempotent and challenge deletion cleans its records',
      () async {
        final service = ChallengeService(db);
        final id = await service.create(
          type: 'learning',
          title: 'Course',
          sourceType: 'learning_course',
          sourceId: 'course-1',
          targetTotal: 100,
          dailyMinimum: 5,
          durationDays: 20,
        );
        final first = ChallengeProofEventTableCompanion.insert(
          challengeId: id,
          kind: 'lecture',
          sourceId: 'course-1:lecture-1',
          day: '2026-10-11',
          amount: 20,
          trust: const drift.Value(1),
        );
        final updated = ChallengeProofEventTableCompanion.insert(
          challengeId: id,
          kind: 'lecture',
          sourceId: 'course-1:lecture-1',
          day: '2026-10-11',
          amount: 30,
          trust: const drift.Value(1),
        );
        await db.challengeDao.upsertProof(first);
        await db.challengeDao.upsertProof(updated);
        expect(await db.challengeDao.getProofs(id), hasLength(1));
        expect((await db.challengeDao.getProofs(id)).single.amount, 30);

        await service.delete(id);
        expect(await db.challengeDao.getLinks(id), isEmpty);
        expect(await db.challengeDao.getProofs(id), isEmpty);
        expect(await db.challengeDao.getActiveChallenge(), isNull);
      },
    );
  });
}
