import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import 'study_streak_models.dart';
export 'study_streak_models.dart';

const String _kStudySecondsPrefix = 'ascent_study_seconds_';
const String _kLongestStreakKey = 'ascent_longest_streak_days_v1';
const String _kShortestStreakKey = 'ascent_shortest_streak_days_v1';
const String _kCelebrationShownDateKey =
    'ascent_streak_celebration_shown_date_v1';

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
        : historicalLongestStreak;

    final int shortestStreakDays = historicalShortestStreak > 0
        ? historicalShortestStreak
        : 1;

    // 5. Urgency evaluation (Snapchat-style):
    final int hoursRemainingInDay = (24 - now.hour).clamp(1, 24);
    final bool isUrgent =
        !isTodaySecured &&
        displayStreakDays > 0 &&
        (now.hour >= 18 || hoursRemainingInDay <= 6);

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

/// Calendar dates, not elapsed 24-hour windows, determine study continuity.
/// One missed day can be recovered on the next day by making up its deficit.
int priorStreakFromHistory(SharedPreferences prefs, DateTime now) =>
    studyHistoryFromPreferences(prefs, now).$1;

(int, int) studyHistoryFromPreferences(SharedPreferences prefs, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final records = <DateTime, int>{};
  for (final key in prefs.getKeys()) {
    if (!key.startsWith(_kStudySecondsPrefix)) continue;
    final parts = key.substring(_kStudySecondsPrefix.length).split('_');
    if (parts.length != 3) continue;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) continue;
    final date = DateTime(year, month, day);
    if (date.isBefore(today)) records[date] = prefs.getInt(key) ?? 0;
  }
  if (records.isEmpty) return (0, 0);
  final dates = records.keys.toList()..sort();
  var cursor = dates.first;
  var streak = 0;
  var longest = 0;
  int? deficit;
  while (cursor.isBefore(today)) {
    final seconds = records[cursor] ?? 0;
    final target =
        StudyStreakCalculator.defaultDailyTargetSeconds + (deficit ?? 0);
    if (seconds >= target) {
      streak++;
      if (streak > longest) longest = streak;
      deficit = null;
    } else if (streak > 0 && deficit == null) {
      deficit = (StudyStreakCalculator.defaultDailyTargetSeconds - seconds)
          .clamp(0, StudyStreakCalculator.defaultDailyTargetSeconds);
    } else {
      streak = 0;
      deficit = null;
    }
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return (streak, longest);
}

final studyClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

class StudyStreakNotifier extends Notifier<StudyStreakStatus> {
  final StudyStreakCalculator _calculator = StudyStreakCalculator();
  Timer? _midnightWatcher;

  DateTime _now() => ref.read(studyClockProvider)();

  String _dateKey(DateTime dt) {
    return '$_kStudySecondsPrefix${dt.year}_${dt.month.toString().padLeft(2, '0')}_${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  StudyStreakStatus build() {
    final now = _now();
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

    final yesterday = DateTime(now.year, now.month, now.day - 1);

    final todayKey = _dateKey(now);
    final yesterdayKey = _dateKey(yesterday);

    final todaySecs = prefs.getInt(todayKey) ?? 0;
    final yesterdaySecs = prefs.getInt(yesterdayKey) ?? 0;
    final history = studyHistoryFromPreferences(prefs, now);
    final priorStreak = history.$1;
    final longestStreak = (prefs.getInt(_kLongestStreakKey) ?? 0) > history.$2
        ? prefs.getInt(_kLongestStreakKey)!
        : history.$2;
    final shortestStreak = prefs.getInt(_kShortestStreakKey) ?? 1;

    _midnightWatcher?.cancel();
    _midnightWatcher = Timer.periodic(const Duration(minutes: 1), (_) {
      final current = _now();
      final currentHistory = studyHistoryFromPreferences(prefs!, current);
      state = _calculator.calculate(
        todaySeconds: prefs.getInt(_dateKey(current)) ?? 0,
        yesterdaySeconds:
            prefs.getInt(
              _dateKey(DateTime(current.year, current.month, current.day - 1)),
            ) ??
            0,
        priorStreakDays: currentHistory.$1,
        historicalLongestStreak:
            ((prefs.getInt(_kLongestStreakKey) ?? 0) > currentHistory.$2)
            ? prefs.getInt(_kLongestStreakKey)!
            : currentHistory.$2,
        now: current,
      );
    });
    ref.onDispose(() => _midnightWatcher?.cancel());

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

    final now = _now();
    final todayKey = _dateKey(now);
    final yesterdayKey = _dateKey(DateTime(now.year, now.month, now.day - 1));

    final currentToday = ((prefs?.getInt(todayKey)) ?? 0) + deltaSeconds;
    prefs?.setInt(todayKey, currentToday);

    final yesterdaySecs = prefs?.getInt(yesterdayKey) ?? 0;
    final history = prefs == null
        ? (0, 0)
        : studyHistoryFromPreferences(prefs, now);
    final priorStreak = history.$1;
    final longestStreak = prefs == null
        ? 0
        : ((prefs.getInt(_kLongestStreakKey) ?? 0) > history.$2
              ? prefs.getInt(_kLongestStreakKey)!
              : history.$2);
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
            await ref
                .read(consistencyDaoProvider)
                .logDay(
                  now,
                  true,
                  hoursStudied: currentToday / 3600.0,
                  note: newStatus.isRescuedToday
                      ? 'Streak Rescued! 🛡️'
                      : 'Study Goal Met 🔥',
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

final studyStreakProvider =
    NotifierProvider<StudyStreakNotifier, StudyStreakStatus>(() {
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

/// Controls visibility/expansion of the StudyStreakMeterCard on HomeScreen
class StudyStreakCardVisibilityNotifier extends Notifier<bool> {
  @override
  bool build() => true; // Default expanded when entering Home

  void toggle() {
    state = !state;
  }

  void setVisible(bool visible) {
    state = visible;
  }
}

final studyStreakCardVisibleProvider =
    NotifierProvider<StudyStreakCardVisibilityNotifier, bool>(() {
      return StudyStreakCardVisibilityNotifier();
    });
