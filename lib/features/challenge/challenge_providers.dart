import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import 'domain/challenge_pace_engine.dart';
import 'domain/challenge_service.dart';

final allChallengesProvider = StreamProvider<List<Challenge>>((ref) {
  return ref.watch(challengeDaoProvider).watchChallenges();
});

final homeChallengeIdProvider = AsyncNotifierProvider<HomeChallengeId, int?>(
  HomeChallengeId.new,
);

class HomeChallengeId extends AsyncNotifier<int?> {
  @override
  Future<int?> build() async =>
      (await SharedPreferences.getInstance()).getInt('home_challenge_id');

  Future<void> select(int id) async {
    await (await SharedPreferences.getInstance()).setInt(
      'home_challenge_id',
      id,
    );
    state = AsyncData(id);
  }
}

final activeChallengeProvider = Provider<AsyncValue<Challenge?>>((ref) {
  final selected = ref.watch(homeChallengeIdProvider).value;
  return ref.watch(allChallengesProvider).whenData((challenges) {
    final active = challenges.where((c) => c.status == 'active').toList();
    for (final challenge in active) {
      if (challenge.id == selected) return challenge;
    }
    return active.isEmpty ? null : active.first;
  });
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
