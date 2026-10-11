import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../challenge_providers.dart';
import '../domain/challenge_pace_engine.dart';

class ChallengeHomeTile extends ConsumerWidget {
  const ChallengeHomeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengeAsync = ref.watch(activeChallengeProvider);
    final g = context.glass;
    return challengeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (challenge) {
        final proofsAsync = challenge == null
            ? null
            : ref.watch(challengeProofsProvider(challenge.id));
        final proofs = proofsAsync?.value ?? const [];
        final progress = challenge == null
            ? null
            : progressForChallenge(challenge, proofs);
        final statusColor = switch (progress?.status) {
          ChallengePaceStatus.ahead ||
          ChallengePaceStatus.onTrack ||
          ChallengePaceStatus.complete => const Color(0xFF4E9B6B),
          ChallengePaceStatus.atRisk => const Color(0xFFD99A37),
          ChallengePaceStatus.failed => const Color(0xFFCA5C54),
          null => g.clay,
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push('/momentum'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: g.fill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: g.line),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress == null
                                ? null
                                : progress.percent / 100,
                            strokeWidth: 4,
                            backgroundColor: g.line,
                            valueColor: AlwaysStoppedAnimation(statusColor),
                          ),
                          Icon(
                            challenge == null
                                ? Icons.flag_outlined
                                : Icons.bolt_rounded,
                            color: statusColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            challenge == null ? 'Challenge' : challenge.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.labelLarge.copyWith(
                              color: g.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            challenge == null
                                ? 'Set a goal and track real progress'
                                : '${progress?.percent ?? 0}% complete · ${_statusLabel(progress?.status)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.captionMedium.copyWith(
                              color: g.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: g.inkMuted),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static String _statusLabel(ChallengePaceStatus? status) => switch (status) {
    ChallengePaceStatus.ahead => 'Ahead',
    ChallengePaceStatus.onTrack => 'On track',
    ChallengePaceStatus.atRisk => 'At risk',
    ChallengePaceStatus.failed => 'Finished',
    ChallengePaceStatus.complete => 'Complete',
    null => 'Loading',
  };
}
