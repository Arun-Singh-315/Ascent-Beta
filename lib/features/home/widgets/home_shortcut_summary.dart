import '../../../core/providers/local_day_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../challenge/challenge_providers.dart';
import '../../promises/providers/promise_providers.dart';
import '../../vault/providers/vault_providers.dart';

String _summary<T>(AsyncValue<T> value, String Function(T) format) => value
    .when(data: format, loading: () => '…', error: (_, _) => 'Unavailable');

final todayPauseCountProvider = StreamProvider.autoDispose<int>((ref) {
  ref.watch(localDayProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final next = DateTime(now.year, now.month, now.day + 1);
  return (db.select(db.historyEventTable)..where(
        (e) =>
            e.module.equals('breaks') &
            e.action.equals('completed') &
            e.occurredAt.isBiggerOrEqualValue(day) &
            e.occurredAt.isSmallerThanValue(next),
      ))
      .watch()
      .map((events) => events.map((event) => event.entityId).toSet().length);
});

final todayShortcutMessageCountProvider = StreamProvider.autoDispose<int>((
  ref,
) {
  ref.watch(localDayProvider);
  final db = ref.watch(databaseProvider);
  final now = DateTime.now();
  final day = DateTime(now.year, now.month, now.day);
  final next = DateTime(now.year, now.month, now.day + 1);
  return (db.select(db.aiChatMessageTable)..where(
        (m) =>
            m.sender.equals('user') &
            m.createdAt.isBiggerOrEqualValue(day) &
            m.createdAt.isSmallerThanValue(next),
      ))
      .watch()
      .map((messages) => messages.length);
});

/// Summaries follow the same saved sources as each destination, without writes.
/// Private vault contents stay hidden until the existing vault session unlocks.
final homeShortcutSummaryProvider = Provider.autoDispose.family<String, String>((
  ref,
  id,
) {
  ref.watch(localDayProvider);
  switch (id) {
    case 'hydration':
    case 'health':
      return _summary(
        ref.watch(todayWaterMlStreamProvider),
        (ml) => '$ml ml today',
      );
    case 'walk':
      return _summary(
        ref.watch(todayWalkDistanceStreamProvider),
        (m) => '${(m / 1000).toStringAsFixed(2)} km today',
      );
    case 'medicine':
      return _summary(
        ref.watch(todayMedicineLogsStreamProvider),
        (doses) => doses.isEmpty
            ? 'No doses scheduled'
            : '${doses.where((d) => d.isTaken).length} of ${doses.length} taken today',
      );
    case 'chai-break':
      return _summary(
        ref.watch(todayPauseCountProvider),
        (n) => '$n ${n == 1 ? 'pause' : 'pauses'} today',
      );
    case 'focus':
      return '${ref.watch(studyStreakProvider).todaySeconds ~/ 60} min today';
    case 'today':
      return _summary(
        ref.watch(todayActivitiesProvider),
        (items) =>
            '${items.where((a) => a.status == TodayActivityStatus.done).length}/${items.length} done today',
      );
    case 'thought-wall':
    case 'mind':
      return _summary(
        ref.watch(todayThoughtsCountStreamProvider),
        (n) => '$n ${n == 1 ? 'thought' : 'thoughts'} today',
      );
    case 'reminders':
      return _summary(ref.watch(allRemindersProvider), (items) {
        final now = DateTime.now();
        final today = items.where(
          (r) =>
              r.isActive &&
              r.scheduledAt.year == now.year &&
              r.scheduledAt.month == now.month &&
              r.scheduledAt.day == now.day,
        );
        return '${today.length} today';
      });
    case 'money':
      return _summary(
        ref.watch(todaySpendingStreamProvider),
        (amount) => '₹${NumberFormat.compact().format(amount)} today',
      );
    case 'assistant':
      return _summary(
        ref.watch(todayShortcutMessageCountProvider),
        (n) => '$n ${n == 1 ? 'message' : 'messages'} today',
      );
    case 'learning':
      final learning = ref.watch(learningHubProvider);
      if (!learning.hasStartedLearning) return 'Not started';
      final course = learning.course;
      return '${course.completedLectures}/${course.totalLectures} lessons';
    case 'promises':
      return _summary(
        ref.watch(activePromisesStreamProvider),
        (items) => '${items.where((p) => p.isDoneToday).length} done today',
      );
    case 'vault':
      if (!ref.watch(vaultSessionUnlockedProvider)) return 'Locked';
      return _summary(
        ref.watch(vaultItemsStreamProvider),
        (items) => '${items.length} saved',
      );
    case 'momentum':
    case 'challenge':
      final challenge = ref.watch(activeChallengeProvider);
      if (challenge.isLoading) return '…';
      if (challenge.hasError) return 'Unavailable';
      final active = challenge.value;
      if (active == null) return 'No active challenge';
      return _summary(ref.watch(challengeProofsProvider(active.id)), (proofs) {
        final day = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final amount = proofs
            .where((p) => p.day == day)
            .fold<double>(0, (sum, p) => sum + p.amount * p.trust.clamp(0, 1));
        return '${NumberFormat.compact().format(amount)} ${active.unit} today';
      });
    default:
      return 'Open';
  }
});
