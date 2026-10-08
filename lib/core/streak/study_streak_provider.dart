import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import 'study_streak_models.dart';
export 'study_streak_models.dart';

const String _kStudySecondsPrefix = 'ascent_study_seconds_';
const String _kPriorStreakKey = 'ascent_prior_streak_days_v1';
const String _kLongestStreakKey = 'ascent_longest_streak_days_v1';
const String _kShortestStreakKey = 'ascent_shortest_streak_days_v1';
const String _kCelebrationShownDateKey = 'ascent_streak_celebration_shown_date_v1';

class StudyStreakCalculator {
  static const int defaultDailyTargetSeconds = 7200; // 120 mins = 2 hours

  StudyStreakStatus calculate({
    required int todaySeconds,
    required int yesterdaySeconds,
    required int priorStreakDays,
    required int historicalLongestStreak,
    int historicalShortestStreak = 1,
    required DateTime now,
    int baseTargetSeconds = defaultDailyTargetSeconds,
  }) {
    // 1. Check yesterday's performance
    final bool yesterdayMet = yesterdaySeconds >= baseTargetSeconds;
    final int yesterdayDeficitSeconds = yesterdayMet
        ? 0
        : (baseTargetSeconds - yesterdaySeconds).clamp(0, baseTargetSeconds);

    // Rescue mode is active if:
    // User had an active prior streak (> 0), but missed yesterday's target
    final bool isRescueMode = !yesterdayMet && priorStreakDays > 0;

    // 2. Compute effective target for today
    final int targetSeconds = isRescueMode
        ? baseTargetSeconds + yesterdayDeficitSeconds
        : baseTargetSeconds;

    // 3. Did user secure today?
    final bool isTodaySecured = todaySeconds >= targetSeconds;
    final bool isRescuedToday = isRescueMode && isTodaySecured;

    // 4. Compute display streak:
    int currentStreakDays;
    int displayStreakDays;

    if (isTodaySecured) {
      currentStreakDays = priorStreakDays + 1;
      displayStreakDays = currentStreakDays;
    } else {
      if (yesterdayMet || isRescueMode) {
        currentStreakDays = priorStreakDays;
        displayStreakDays = priorStreakDays;
      } else {
        currentStreakDays = 0;
        displayStreakDays = 0;
      }
    }

    final int longestStreakDays = currentStreakDays > historicalLongestStreak
        ? currentStreakDays
        : (historicalLongestStreak > 0 ? historicalLongestStreak : (currentStreakDays > 0 ? currentStreakDays : 1));

    final int shortestStreakDays = historicalShortestStreak > 0
        ? historicalShortestStreak
        : 1;

    // 5. Urgency evaluation (Snapchat-style):
    final int hoursRemainingInDay = (24 - now.hour).clamp(1, 24);
    final bool isUrgent = !isTodaySecured && (now.hour >= 18 || hoursRemainingInDay <= 6);

    return StudyStreakStatus(
      todaySeconds: todaySeconds,
      targetSeconds: targetSeconds,
      priorStreakDays: priorStreakDays,
      currentStreakDays: currentStreakDays,
      displayStreakDays: displayStreakDays,
      longestStreakDays: longestStreakDays,
      shortestStreakDays: shortestStreakDays,
      isTodaySecured: isTodaySecured,
      isRescueMode: isRescueMode,
      isRescuedToday: isRescuedToday,
      yesterdayDeficitSeconds: yesterdayDeficitSeconds,
      isUrgent: isUrgent,
      hoursRemainingInDay: hoursRemainingInDay,
    );
  }
}

class StudyStreakNotifier extends Notifier<StudyStreakStatus> {
  final StudyStreakCalculator _calculator = StudyStreakCalculator();
  Timer? _midnightWatcher;

  String _dateKey(DateTime dt) {
    return '${_kStudySecondsPrefix}${dt.year}_${dt.month.toString().padLeft(2, '0')}_${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  StudyStreakStatus build() {
    final now = DateTime.now();
    SharedPreferences? prefs;
    try {
      prefs = ref.watch(sharedPreferencesProvider);
    } catch (_) {
      // In tests where sharedPreferencesProvider is not provided
    }

    if (prefs == null) {
      return _calculator.calculate(
        todaySeconds: 0,
        yesterdaySeconds: 0,
        priorStreakDays: 0,
        historicalLongestStreak: 0,
        historicalShortestStreak: 1,
        now: now,
      );
    }

    final yesterday = now.subtract(const Duration(days: 1));

    final todayKey = _dateKey(now);
    final yesterdayKey = _dateKey(yesterday);

    final todaySecs = prefs.getInt(todayKey) ?? 0;
    final yesterdaySecs = prefs.getInt(yesterdayKey) ?? 0;
    final priorStreak = prefs.getInt(_kPriorStreakKey) ?? 0;
    final longestStreak = prefs.getInt(_kLongestStreakKey) ?? 0;
    final shortestStreak = prefs.getInt(_kShortestStreakKey) ?? 1;

    ref.onDispose(() {
      _midnightWatcher?.cancel();
    });

    return _calculator.calculate(
      todaySeconds: todaySecs,
      yesterdaySeconds: yesterdaySecs,
      priorStreakDays: priorStreak,
      historicalLongestStreak: longestStreak,
      historicalShortestStreak: shortestStreak,
      now: now,
    );
  }

  /// Adds strictly verified study seconds (e.g. from Lecture player tick or active Study session).
  void addStudySeconds(int deltaSeconds) {
    if (deltaSeconds <= 0) return;

    SharedPreferences? prefs;
    try {
      prefs = ref.read(sharedPreferencesProvider);
    } catch (_) {}

    final now = DateTime.now();
    final todayKey = _dateKey(now);
    final yesterdayKey = _dateKey(now.subtract(const Duration(days: 1)));

    final currentToday = ((prefs?.getInt(todayKey)) ?? 0) + deltaSeconds;
    prefs?.setInt(todayKey, currentToday);

    final yesterdaySecs = prefs?.getInt(yesterdayKey) ?? 0;
    final priorStreak = prefs?.getInt(_kPriorStreakKey) ?? 0;
    final longestStreak = prefs?.getInt(_kLongestStreakKey) ?? 0;
    final shortestStreak = prefs?.getInt(_kShortestStreakKey) ?? 1;

    final newStatus = _calculator.calculate(
      todaySeconds: currentToday,
      yesterdaySeconds: yesterdaySecs,
      priorStreakDays: priorStreak,
      historicalLongestStreak: longestStreak,
      historicalShortestStreak: shortestStreak,
      now: now,
    );

    // If goal just got secured, check if celebration is needed
    if (newStatus.isTodaySecured) {
      if (newStatus.longestStreakDays > longestStreak) {
        prefs?.setInt(_kLongestStreakKey, newStatus.longestStreakDays);
      }

      final dateStr = '${now.year}-${now.month}-${now.day}';
      final lastCelebrated = prefs?.getString(_kCelebrationShownDateKey);

      if (lastCelebrated != dateStr) {
        prefs?.setString(_kCelebrationShownDateKey, dateStr);
        // Persist to Drift ConsistencyDao as present
        Future.microtask(() async {
          try {
            await ref.read(consistencyDaoProvider).logDay(
                  now,
                  true,
                  hoursStudied: currentToday / 3600.0,
                  note: newStatus.isRescuedToday ? 'Streak Rescued! 🛡️' : 'Study Goal Met 🔥',
                );
          } catch (_) {}
        });

        // Emit celebration state
        ref.read(streakCelebrationEventProvider.notifier).trigger(newStatus);
      }
    }

    state = newStatus;
  }
}

final studyStreakProvider = NotifierProvider<StudyStreakNotifier, StudyStreakStatus>(() {
  return StudyStreakNotifier();
});

/// Notifier for one-time celebration events
class StreakCelebrationEventNotifier extends Notifier<StudyStreakStatus?> {
  @override
  StudyStreakStatus? build() => null;

  void trigger(StudyStreakStatus status) {
    state = status;
  }

  void clear() {
    state = null;
  }
}

final streakCelebrationEventProvider =
    NotifierProvider<StreakCelebrationEventNotifier, StudyStreakStatus?>(() {
  return StreakCelebrationEventNotifier();
});
