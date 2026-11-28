import 'package:ascent/core/backup/backup_providers.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/model/home_day_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Idle extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _Streak extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 45 * 60,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

void main() {
  test('Home day reads real providers, and slices stay quiet', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.now();
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(_Idle.new),
        studyStreakProvider.overrideWith(_Streak.new),
        backupListProvider.overrideWith((ref) async => []),
        todayActivitiesProvider.overrideWith(
          (ref) => Stream.value([
            TodayActivityItem(
              id: 'a',
              title: 'Review PRs',
              sourceType: 'task',
              status: TodayActivityStatus.notStarted,
              elapsedSecondsToday: 0,
              categoryTag: 'work',
              plannedDate: DateTime(now.year, now.month, now.day),
            ),
          ]),
        ),
        todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(1800)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    var vitalsChanges = 0;
    container.listen(
      homeVitalsProvider,
      (_, _) => vitalsChanges++,
      fireImmediately: false,
    );
    // Let the streams deliver.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    final day = container.read(homeDayProvider);
    expect(day.today.total, 1);
    expect(day.vitals.waterMl, 1800);
    expect(day.vitals.focusMinutes, 45);
    expect(container.read(homeTodayListProvider).pending.single.id, 'a');

    final before = vitalsChanges;
    // Re-reading an unchanged day must not notify the vitals slice again.
    container.invalidate(homeDayProvider);
    container.read(homeDayProvider);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(vitalsChanges, before);
  });
}
