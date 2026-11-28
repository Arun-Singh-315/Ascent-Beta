import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backup/backup_providers.dart';
import '../../../core/promises/promise_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/local_day_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import 'day_summary.dart';
import 'home_day.dart';

export 'day_summary.dart';
export 'home_day.dart';

/// The wall clock, refreshed on each new minute while Home is listening, so
/// the rail's "now" mark and missed doses stay current without a per-second
/// timer.
final homeMinuteProvider = StreamProvider.autoDispose<DateTime>((ref) {
  ref.watch(localClockProvider);
  final controller = StreamController<DateTime>();
  controller.add(DateTime.now());
  Timer? timer;
  void schedule() {
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    timer = Timer(next.difference(now), () {
      controller.add(DateTime.now());
      schedule();
    });
  }

  schedule();
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Today, computed once from real data. Sections should read one of the
/// slice providers below rather than this, so they rebuild only when their
/// own part of the day changes.
final homeDayProvider = Provider<HomeDay>((ref) {
  final now = ref.watch(homeMinuteProvider).value ?? DateTime.now();
  final live = ref.watch(
    timeTrackingProvider.select(
      (s) => (
        on: s.activeSession != null && (s.isRunning || s.isPaused),
        title: s.activeSession?.label,
      ),
    ),
  );
  final streak = ref.watch(
    studyStreakProvider.select(
      (s) => (minutes: s.todaySeconds ~/ 60, goal: s.targetSeconds ~/ 60),
    ),
  );
  final promises = ref.watch(homePromisesProvider).value ?? const [];
  final backups = ref.watch(backupListProvider).value;

  return buildHomeDay(
    now: now,
    activities: ref.watch(todayActivitiesProvider).value ?? const [],
    reminders: ref.watch(homeVisibleRemindersProvider),
    hasLiveSession: live.on,
    liveTitle: live.title,
    promises: [
      for (final p in promises)
        if (p.isActive)
          PromiseToday(
            id: p.id,
            title: p.title,
            day: p.progress.dayNumber,
            length: p.progress.length,
            answeredToday: p.progress.answeredToday,
            yesterdayOpen: p.progress.yesterdayOpen,
            streak: p.progress.streak,
          ),
    ],
    lastBackupAt: backups == null || backups.isEmpty
        ? null
        : backups.first.createdAt,
    waterMl: ref.watch(todayWaterMlStreamProvider).value ?? 0,
    waterGoalMl: ref.watch(dailyWaterGoalStreamProvider).value ?? 2000,
    focusMinutes: streak.minutes,
    focusGoalMinutes: streak.goal,
    spentToday: ref.watch(todaySpendingStreamProvider).value ?? 0,
    dailyBudget: ref.watch(overallBudgetStreamProvider).value?.dailyLimit,
  );
});

// ── Slices: each rebuilds its readers only when its value changes. ────────

final homeMoodProvider = Provider<DayMood>(
  (ref) => ref.watch(homeDayProvider.select((d) => d.mood)),
);

final homePeriodProvider = Provider<DayPeriod>(
  (ref) => ref.watch(homeDayProvider.select((d) => d.period)),
);

final homeDayLineProvider = Provider<DayLine>(
  (ref) => ref.watch(homeDayProvider.select((d) => d.dayLine)),
);

final homeRailProvider = Provider<DayRail>(
  (ref) => ref.watch(homeDayProvider.select((d) => d.rail)),
);

final homeTodayListProvider = Provider<TodayList>(
  (ref) => ref.watch(homeDayProvider.select((d) => d.today)),
);

final homeNeedsYouProvider = Provider<List<NeedsYouItem>>(
  (ref) => ref.watch(homeDayProvider.select((d) => _Items(d.needsYou))).items,
);

final homeVitalsProvider = Provider<Vitals>(
  (ref) => ref.watch(homeDayProvider.select((d) => d.vitals)),
);

/// Value-equal wrapper so a rebuilt but identical list doesn't notify.
class _Items {
  const _Items(this.items);
  final List<NeedsYouItem> items;
  @override
  bool operator ==(Object other) =>
      other is _Items &&
      other.items.length == items.length &&
      Iterable.generate(items.length).every((i) => other.items[i] == items[i]);
  @override
  int get hashCode => Object.hashAll(items);
}

/// Yesterday's totals, for the summary's "compared with yesterday". Read
/// once per day; null while loading or if anything fails (the summary then
/// simply leaves the comparison out).
final homeYesterdayProvider = FutureProvider<YesterdayStats?>((ref) async {
  final today = ref.watch(localDayProvider);
  final y = today.subtract(const Duration(days: 1));
  try {
    final things = await ref.watch(taskDaoProvider).countCompletedOn(y);
    final water = await ref.watch(waterDaoProvider).getWaterForDate(y);
    final sessions = await ref
        .watch(timeSessionDaoProvider)
        .watchSessionsForDate(y)
        .first;
    final focus =
        sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds) ~/ 60;
    return YesterdayStats(
      thingsDone: things,
      waterMl: water,
      focusMinutes: focus,
    );
  } catch (_) {
    return null;
  }
});

/// The header summary (rings, three lines, insight).
final homeSummaryProvider = Provider<DaySummary>((ref) {
  final day = ref.watch(homeDayProvider);
  final y = ref.watch(homeYesterdayProvider).value;
  return buildDaySummary(day, y);
});
