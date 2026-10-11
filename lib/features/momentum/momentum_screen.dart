import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../challenge/challenge_providers.dart';
import '../challenge/domain/challenge_pace_engine.dart';
import '../challenge/integration/challenge_proof_sync.dart';
import '../challenge/presentation/challenge_create_sheet.dart';

class MomentumScreen extends ConsumerWidget {
  const MomentumScreen({super.key, this.linkedPromise});

  final Thought? linkedPromise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(challengeProofSyncProvider);
    final active = ref.watch(activeChallengeProvider);
    return AscentScaffold(
      title: 'Challenge Partner',
      subtitle: 'A clear plan, measured by real progress',
      body: active.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _MessageCard(
          title: 'Challenge could not load',
          body:
              'Your saved challenge is safe. Return to this screen to try again.',
          action: TextButton.icon(
            onPressed: () => ref.invalidate(activeChallengeProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
        data: (challenge) => challenge == null
            ? _EmptyChallenge(
                linkedPromise: linkedPromise,
                onCreate: () => ChallengeCreateSheet.show(
                  context,
                  linkedPromise: linkedPromise,
                ),
              )
            : ref
                  .watch(challengeProofsProvider(challenge.id))
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _MessageCard(
                      title: 'Progress could not load',
                      body:
                          'Your challenge is still saved. Try refreshing the screen.',
                      action: TextButton.icon(
                        onPressed: () => ref.invalidate(
                          challengeProofsProvider(challenge.id),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ),
                    data: (proofs) => _ChallengeDetail(
                      challenge: challenge,
                      proofs: proofs,
                      onDelete: () => _confirmDelete(context, ref, challenge),
                      onArchive: () => _archive(context, ref, challenge),
                    ),
                  ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Challenge challenge,
  ) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this challenge?'),
        content: const Text(
          'Its Challenge progress and links will be removed. Learning, Focus, Todo, and Promise data will stay unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (delete == true) {
      await ref.read(challengeServiceProvider).delete(challenge.id);
    }
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Challenge challenge,
  ) async {
    await ref.read(challengeServiceProvider).archive(challenge.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Challenge moved to history.')),
      );
    }
  }
}

class _EmptyChallenge extends StatelessWidget {
  const _EmptyChallenge({required this.onCreate, this.linkedPromise});

  final VoidCallback onCreate;
  final Thought? linkedPromise;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: g.fill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: g.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: g.clay.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag_rounded, size: 27, color: g.clay),
              ),
              const SizedBox(height: 18),
              Text(
                linkedPromise == null
                    ? 'Make a promise measurable'
                    : 'Track your Promise',
                style: AscentTextStyles.displaySmall.copyWith(color: g.ink),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a course or a timed Todo. Challenge progress updates from completed lectures and Focus sessions, never from a manual checkmark.',
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: g.inkMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  linkedPromise == null
                      ? 'Create challenge'
                      : 'Build a progress plan',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _MessageCard(
          title: 'Works with Ascent',
          body:
              'Learning Hub provides lecture completions. Activity Hub and Focus provide timed sessions. Challenge reads both and keeps their original records untouched.',
        ),
      ],
    );
  }
}

class _ChallengeDetail extends StatelessWidget {
  const _ChallengeDetail({
    required this.challenge,
    required this.proofs,
    required this.onDelete,
    required this.onArchive,
  });

  final Challenge challenge;
  final List<ChallengeProofEvent> proofs;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final progress = progressForChallenge(challenge, proofs);
    final g = context.glass;
    final statusColor = switch (progress.status) {
      ChallengePaceStatus.ahead ||
      ChallengePaceStatus.onTrack ||
      ChallengePaceStatus.complete => const Color(0xFF4E9B6B),
      ChallengePaceStatus.atRisk => const Color(0xFFD99A37),
      ChallengePaceStatus.failed => const Color(0xFFCA5C54),
    };
    final totalDays =
        parseChallengeDay(
          challenge.endDay,
        ).difference(parseChallengeDay(challenge.startDay)).inDays +
        1;
    final elapsedDays = (totalDays - progress.daysLeft).clamp(1, totalDays);
    final label = switch (progress.status) {
      ChallengePaceStatus.ahead => 'Ahead',
      ChallengePaceStatus.onTrack => 'On track',
      ChallengePaceStatus.atRisk => 'At risk',
      ChallengePaceStatus.failed => 'Deadline passed',
      ChallengePaceStatus.complete => 'Target reached',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                challenge.title,
                style: AscentTextStyles.displaySmall.copyWith(color: g.ink),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (action) =>
                  action == 'archive' ? onArchive() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'archive', child: Text('Move to history')),
                PopupMenuItem(value: 'delete', child: Text('Delete challenge')),
              ],
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${challenge.type == 'learning' ? 'Learning Hub' : 'Activity Hub'} · Day $elapsedDays of $totalDays',
          style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: g.fill,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: g.line),
          ),
          child: Column(
            children: [
              SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress.percent / 100,
                        strokeWidth: 12,
                        backgroundColor: g.line,
                        valueColor: AlwaysStoppedAnimation(statusColor),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${progress.percent}%',
                          style: AscentTextStyles.displayLarge.copyWith(
                            color: g.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'complete',
                          style: AscentTextStyles.captionMedium.copyWith(
                            color: g.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: AscentTextStyles.labelMedium.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pace estimate: ${progress.chance}%',
                style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Needed each day',
                value: '${progress.requiredPerDay.ceil()} min',
                g: g,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Verified days',
                value: '${progress.verifiedDays}',
                g: g,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _MessageCard(
          title:
              '${progress.completedAmount.floor()} / ${challenge.targetTotal.ceil()} min verified',
          body: challenge.type == 'learning'
              ? 'Completed lectures from the linked course count once, using Learning Hub records.'
              : 'Completed Focus sessions linked to the selected Todo count once. The Todo checkbox does not add minutes.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: challenge.type == 'learning'
              ? () => context.push('/learning')
              : () => context.push('/today'),
          icon: Icon(
            challenge.type == 'learning'
                ? Icons.school_outlined
                : Icons.play_arrow_rounded,
          ),
          label: Text(
            challenge.type == 'learning'
                ? 'Open Learning Hub'
                : 'Open linked activity',
          ),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onDelete, child: const Text('Delete challenge')),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.g,
  });

  final String label;
  final String value;
  final AscentGlass g;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: g.fill,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: g.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AscentTextStyles.captionMedium.copyWith(color: g.inkMuted),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: AscentTextStyles.headlineMedium.copyWith(
            color: g.ink,
            fontSize: 18,
          ),
        ),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.title, required this.body, this.action});

  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: g.fill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: g.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AscentTextStyles.labelLarge.copyWith(
              color: g.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: AscentTextStyles.bodySmall.copyWith(
              color: g.inkMuted,
              height: 1.4,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    );
  }
}
