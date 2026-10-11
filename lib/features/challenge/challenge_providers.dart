import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import 'domain/challenge_pace_engine.dart';
import 'domain/challenge_service.dart';

final activeChallengeProvider = StreamProvider<Challenge?>((ref) {
  return ref.watch(challengeDaoProvider).watchActiveChallenge();
});

final challengeLinksProvider = StreamProvider.family<List<ChallengeLink>, int>((
  ref,
  challengeId,
) {
  return ref.watch(challengeDaoProvider).watchLinks(challengeId);
});

final challengeProofsProvider =
    StreamProvider.family<List<ChallengeProofEvent>, int>((ref, challengeId) {
      return ref.watch(challengeDaoProvider).watchProofs(challengeId);
    });

ChallengeProgress progressForChallenge(
  Challenge challenge,
  List<ChallengeProofEvent> proofs, {
  DateTime? today,
}) {
  return ChallengePaceEngine.calculate(
    targetTotal: challenge.targetTotal,
    startDate: parseChallengeDay(challenge.startDay),
    endDate: parseChallengeDay(challenge.endDay),
    today: today ?? DateTime.now(),
    evidence: proofs
        .map(
          (proof) => ChallengeEvidence(
            day: parseChallengeDay(proof.day),
            amount: proof.amount,
            trust: proof.trust,
          ),
        )
        .toList(growable: false),
  );
}

final challengeServiceProvider = Provider<ChallengeService>((ref) {
  return ChallengeService(ref.watch(databaseProvider));
});
