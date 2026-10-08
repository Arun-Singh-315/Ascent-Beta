import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/momentum/momentum_service.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../momentum/momentum_onboarding_screen.dart';

/// Lightweight, ultra-fast (<100ms) Momentum Card on the Home Screen.
/// Follows GEMINI.md Rule 2: Zero continuous GPS listeners, zero heavy animation loops.
class MomentumHomeCard extends ConsumerWidget {
  const MomentumHomeCard({super.key});

  int _calculateCurrentDayNumber(MomentumChallenge challenge) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(challenge.startDate.year, challenge.startDate.month, challenge.startDate.day);
    final diff = today.difference(start).inDays + 1;
    return diff.clamp(1, 30);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final challengeAsync = ref.watch(activeMomentumChallengeStreamProvider);

    return challengeAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (challenge) {
        if (challenge == null) {
          return _buildInactiveCard(context, g);
        }
        return _buildActiveChallengeCard(context, ref, challenge, g);
      },
    );
  }

  Widget _buildInactiveCard(BuildContext context, dynamic g) {
    return GlassSurface(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: g.clay.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.bolt_rounded, color: g.clay, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '30-Day Momentum Challenge',
                  style: TextStyle(
                    color: g.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '6:00 AM wake entrainment & gym/walk routine.',
                  style: TextStyle(
                    color: g.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MomentumOnboardingScreen()),
              );
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: g.clay,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Start ⚡',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChallengeCard(
    BuildContext context,
    WidgetRef ref,
    MomentumChallenge challenge,
    dynamic g,
  ) {
    final currentDayNumber = _calculateCurrentDayNumber(challenge);
    final todayCommitmentsAsync = ref.watch(todayMomentumCommitmentsStreamProvider);

    return todayCommitmentsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (commitments) {
        final totalCount = commitments.length;
        final doneCount = commitments.where((c) => c.isCompleted).length;
        final progressFraction = totalCount > 0 ? (doneCount / totalCount).clamp(0.0, 1.0) : 0.0;
        final nextPending = commitments.where((c) => !c.isCompleted).firstOrNull;

        IconData nextIcon = Icons.bolt_rounded;
        Color nextColor = g.clay;
        if (nextPending != null) {
          switch (nextPending.commitmentType) {
            case 'wake':
              nextIcon = Icons.alarm_rounded;
              nextColor = Colors.orange;
              break;
            case 'walk':
              nextIcon = Icons.directions_walk_rounded;
              nextColor = g.sage;
              break;
            case 'gym':
              nextIcon = Icons.fitness_center_rounded;
              nextColor = g.clay;
              break;
            case 'wind_down':
              nextIcon = Icons.bedtime_rounded;
              nextColor = Colors.indigoAccent;
              break;
            default:
              nextIcon = Icons.water_drop_rounded;
              nextColor = Colors.blue;
              break;
          }
        }

        final timeStr = nextPending?.scheduledTimeMinutes != null
            ? '${(nextPending!.scheduledTimeMinutes! ~/ 60).toString().padLeft(2, '0')}:${(nextPending.scheduledTimeMinutes! % 60).toString().padLeft(2, '0')}'
            : '';

        return InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/momentum');
          },
          borderRadius: BorderRadius.circular(20),
          child: GlassSurface(
            radius: 20,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bolt_rounded, size: 16, color: g.clay),
                        const SizedBox(width: 6),
                        Text(
                          'MOMENTUM • DAY $currentDayNumber OF 30',
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          '$doneCount / $totalCount Done',
                          style: TextStyle(
                            color: g.clay,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, size: 16, color: g.inkMuted),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Linear Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    minHeight: 4,
                    backgroundColor: g.fill,
                    valueColor: AlwaysStoppedAnimation(g.clay),
                  ),
                ),

                const SizedBox(height: 10),

                // Next Planned Action
                if (nextPending != null)
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: nextColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(nextIcon, size: 14, color: nextColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            text: timeStr.isNotEmpty ? '$timeStr • ' : '',
                            style: TextStyle(
                              color: g.clay,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: nextPending.title,
                                style: TextStyle(
                                  color: g.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await ref.read(momentumServiceProvider).toggleCommitment(nextPending.id);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: g.fill,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: g.edge),
                          ),
                          child: Text(
                            'Check-in',
                            style: TextStyle(color: g.inkSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: g.sage),
                      const SizedBox(width: 8),
                      Text(
                        'All Day $currentDayNumber commitments crushed! ⚡',
                        style: TextStyle(color: g.ink, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
