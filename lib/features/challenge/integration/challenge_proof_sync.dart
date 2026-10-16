import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/learning_hub/learning_hub_models.dart';
import '../../../core/providers/database_provider.dart';
import '../domain/challenge_pace_engine.dart';
import '../challenge_providers.dart';

/// Projects evidence from existing modules into Challenge without writing back.
/// It avoids rebuilding proof rows when only a timer tick changed.
final challengeProofSyncProvider = Provider<void>((ref) {
  final challenges =
      ref.watch(allChallengesProvider).value ?? const <Challenge>[];
  for (final challenge in challenges.where((c) => c.status == 'active')) {
    ref.watch(_challengeProofSyncProvider(challenge.id));
  }
});

final _challengeProofSyncProvider = Provider.autoDispose.family<void, int>((
  ref,
  id,
) {
  final challengeDao = ref.read(challengeDaoProvider);
  final sessionDao = ref.read(timeSessionDaoProvider);
  final taskDao = ref.read(taskDaoProvider);
  StreamSubscription<Challenge?>? activeSubscription;
  StreamSubscription<List<TimeSession>>? activitySubscription;
  StreamSubscription<List<Task>>? taskSubscription;
  Challenge? activeChallenge;
  String? lastLearningSignature;
  var generation = 0;

  Future<void> replaceOnlyWhenChanged(
    int challengeId,
    String kind,
    List<ChallengeProofEventTableCompanion> entries,
  ) async {
    final current = (await challengeDao.getProofs(
      challengeId,
    )).where((event) => event.kind == kind).toList();
    final oldById = {for (final event in current) event.sourceId: event};
    final newById = {for (final entry in entries) entry.sourceId.value: entry};
    final unchanged =
        oldById.length == newById.length &&
        newById.entries.every((item) {
          final old = oldById[item.key];
          final next = item.value;
          return old != null &&
              old.day == next.day.value &&
              (old.amount - next.amount.value).abs() < 0.001 &&
              (old.trust - next.trust.value).abs() < 0.001;
        });
    if (!unchanged) {
      await challengeDao.replaceProofsForKind(challengeId, kind, entries);
    }
  }

  Future<void> syncLearning(Challenge challenge, LearningHubState state) async {
    if (challenge.type != 'learning') return;
    final links = await challengeDao.getLinks(challenge.id);
    ChallengeLink? link;
    for (final candidate in links) {
      if (candidate.sourceType == 'learning_course') {
        link = candidate;
        break;
      }
    }
    if (link == null) return;
    Course? course;
    for (final candidate in state.courses) {
      if (candidate.id == link.sourceId) {
        course = candidate;
        break;
      }
    }
    final events = <ChallengeProofEventTableCompanion>[];
    if (course != null) {
      final start = parseChallengeDay(challenge.startDay);
      final end = parseChallengeDay(
        challenge.endDay,
      ).add(const Duration(days: 1));
      for (final module in course.modules) {
        for (final lecture in module.lectures) {
          final completedAt = lecture.lastPlayedAt;
          if (!lecture.isCompleted ||
              completedAt == null ||
              completedAt.isBefore(link.linkedAt) ||
              completedAt.isBefore(start) ||
              !completedAt.isBefore(end)) {
            continue;
          }
          events.add(
            ChallengeProofEventTableCompanion.insert(
              challengeId: challenge.id,
              kind: 'lecture',
              sourceId: '${course.id}:${lecture.id}',
              day: formatChallengeDay(completedAt),
              amount: (lecture.durationSeconds / 60)
                  .clamp(0.1, double.infinity)
                  .toDouble(),
              trust: const drift.Value(1),
            ),
          );
        }
      }
    }
    await replaceOnlyWhenChanged(challenge.id, 'lecture', events);
  }

  Future<void> syncActivity(
    Challenge challenge,
    ChallengeLink link,
    List<TimeSession> sessions,
  ) async {
    final start = parseChallengeDay(challenge.startDay);
    final end = parseChallengeDay(
      challenge.endDay,
    ).add(const Duration(days: 1));
    final entries = <ChallengeProofEventTableCompanion>[];
    for (final session in sessions) {
      final proofAt = session.endedAt ?? session.startedAt;
      final amountSeconds = session.durationSeconds > 0
          ? session.durationSeconds
          : TimeSessionDao.computeActiveDurationSeconds(
              session.startedAt,
              proofAt,
              session.pausedIntervals,
            );
      if (proofAt.isBefore(link.linkedAt) ||
          proofAt.isBefore(start) ||
          !proofAt.isBefore(end) ||
          amountSeconds <= 0) {
        continue;
      }
      entries.add(
        ChallengeProofEventTableCompanion.insert(
          challengeId: challenge.id,
          kind: 'focus_session',
          sourceId: session.id.toString(),
          day: formatChallengeDay(proofAt),
          amount: amountSeconds / 60,
          trust: const drift.Value(1),
        ),
      );
    }
    await replaceOnlyWhenChanged(challenge.id, 'focus_session', entries);
  }

  String learningSignature(LearningHubState state) {
    final completed = <String>[];
    for (final course in state.courses) {
      for (final module in course.modules) {
        for (final lecture in module.lectures.where(
          (item) => item.isCompleted,
        )) {
          completed.add(
            '${course.id}:${lecture.id}:${lecture.lastPlayedAt == null ? '' : formatChallengeDay(lecture.lastPlayedAt!)}:${lecture.durationSeconds}',
          );
        }
      }
    }
    completed.sort();
    return completed.join('|');
  }

  Future<void> attachChallenge(
    Challenge? challenge,
    LearningHubState state,
  ) async {
    generation++;
    final currentGeneration = generation;
    activeChallenge = challenge;
    lastLearningSignature = learningSignature(state);
    await activitySubscription?.cancel();
    await taskSubscription?.cancel();
    activitySubscription = null;
    taskSubscription = null;
    if (challenge == null) return;
    if (challenge.type == 'learning') {
      unawaited(syncLearning(challenge, state));
      return;
    }
    final links = await challengeDao.getLinks(challenge.id);
    if (currentGeneration != generation) return;
    ChallengeLink? link;
    for (final candidate in links) {
      if (candidate.sourceType == 'task') {
        link = candidate;
        break;
      }
    }
    final taskId = int.tryParse(link?.sourceId ?? '');
    if (link == null || taskId == null) return;
    taskSubscription = taskDao.watchAllTasks().listen((tasks) {
      if (!tasks.any((task) => task.id == taskId)) {
        unawaited(
          challengeDao.replaceProofsForKind(
            challenge.id,
            'focus_session',
            const [],
          ),
        );
      }
    });
    final start = parseChallengeDay(challenge.startDay);
    final end = parseChallengeDay(
      challenge.endDay,
    ).add(const Duration(days: 1));
    activitySubscription = sessionDao
        .watchCompletedSessionsForTask(taskId, start, end)
        .listen(
          (sessions) => unawaited(syncActivity(challenge, link!, sessions)),
        );
  }

  activeSubscription = challengeDao
      .watchActiveChallenges()
      .map((challenges) {
        for (final challenge in challenges) {
          if (challenge.id == id) return challenge;
        }
        return null;
      })
      .distinct()
      .listen((challenge) {
        unawaited(attachChallenge(challenge, ref.read(learningHubProvider)));
      });

  ref.listen<LearningHubState>(learningHubProvider, (previous, next) {
    final signature = learningSignature(next);
    if (signature == lastLearningSignature) return;
    lastLearningSignature = signature;
    final challenge = activeChallenge;
    if (challenge != null && challenge.type == 'learning') {
      unawaited(syncLearning(challenge, next));
    }
  });

  ref.onDispose(() {
    generation++;
    activeSubscription?.cancel();
    activitySubscription?.cancel();
    taskSubscription?.cancel();
  });
});
