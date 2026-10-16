import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/shared/widgets/ascent_atmosphere.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Architecture Audit Tests', () {
    test('Notification channel constants and IDs are properly configured', () {
      expect(NotificationService.channelBoostNudgesId, 'ascent_boost_nudges');
      expect(NotificationService.channelStudyId, 'ascent_study_reminders');
      expect(NotificationService.channelCatchUpId, 'ascent_catch_up');
      expect(NotificationService.channelTimerId, 'ascent_timer_alerts');
      expect(NotificationService.followUpIdOffset, 500000);
    });

    test(
      'NotificationService permission check methods return valid booleans',
      () async {
        final service = NotificationService.instance;
        final enabled = await service.areNotificationsEnabled();
        expect(enabled, isA<bool>());
      },
    );
  });

  group('Learning Hub & Activity Real-Time Timer Sync Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      await container.read(learningHubProvider.notifier).ready;
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test(
      'Learning Hub initializes with active lecture and proper target duration',
      () {
        final state = container.read(learningHubProvider);
        final active = state.activeLecture;

        expect(active.id, greaterThanOrEqualTo(1));
        expect(active.durationSeconds, greaterThan(0));
        expect(state.currentElapsedSeconds, equals(active.elapsedSeconds));
        expect(state.isPlaying, isFalse);
      },
    );

    test(
      'Lecture retains elapsed time upon pause and does not restart from 00:00',
      () {
        final notifier = container.read(learningHubProvider.notifier);
        notifier.startLearning();

        // Seek to 125 seconds (2 mins 5 secs in a 5:00 lecture)
        notifier.seekBy(125);
        final stateAfterSeek = container.read(learningHubProvider);
        expect(stateAfterSeek.currentElapsedSeconds, 125);

        // Play and pause
        notifier.play();
        expect(container.read(learningHubProvider).isPlaying, isTrue);

        notifier.pause();
        final stateAfterPause = container.read(learningHubProvider);
        expect(stateAfterPause.isPlaying, isFalse);
        // Crucial: Elapsed seconds must be preserved exactly at 125 seconds!
        expect(stateAfterPause.currentElapsedSeconds, 125);
        expect(stateAfterPause.sessionBaseElapsed, 125);

        // Re-trigger play (as if tapping play on Activity row)
        notifier.togglePlayPause();
        final stateAfterResume = container.read(learningHubProvider);
        expect(stateAfterResume.isPlaying, isTrue);
        expect(stateAfterResume.sessionBaseElapsed, 125);
      },
    );

    test(
      'TodayActivityItem accurately represents lecture target duration and elapsed seconds',
      () {
        final state = container.read(learningHubProvider);
        final active = state.activeLecture;
        final targetMins = (active.durationSeconds > 0)
            ? (active.durationSeconds / 60).round()
            : 5;

        final activity = TodayActivityItem(
          id: 'lecture_${active.id}',
          title: '${state.course.title}: ${active.title}',
          sourceType: 'lecture',
          status: state.isPlaying
              ? TodayActivityStatus.inProgress
              : TodayActivityStatus.paused,
          elapsedSecondsToday: state.currentElapsedSeconds,
          categoryTag: 'Study',
          kind: ActivityKind.duration,
          targetMinutes: targetMins,
          plannedDate: DateTime.now(),
          isOverdue: false,
        );

        expect(activity.sourceType, 'lecture');
        expect(activity.targetMinutes, targetMins);
        expect(activity.elapsedSecondsToday, state.currentElapsedSeconds);
        expect(activity.kind, ActivityKind.duration);
      },
    );
  });

  group('Atmosphere Ambient Softening Guard Tests', () {
    test(
      'Softens solid 100% opaque color (alpha 1.0) to gentle ambient level',
      () {
        const solidGreen = Color(0xFF63BA8B); // 100% opaque green
        expect(solidGreen.a, 1.0);

        final softened = AscentAtmosphereBackground.softenGlow(
          solidGreen,
          maxAlpha: 0.14,
        );
        expect(softened.a, closeTo(0.14, 0.01));
        expect(softened.r, solidGreen.r);
        expect(softened.g, solidGreen.g);
        expect(softened.b, solidGreen.b);
      },
    );

    test('Preserves already soft ambient color with alpha under threshold', () {
      const subtleAura = Color.fromRGBO(92, 114, 190, 0.10);
      final result = AscentAtmosphereBackground.softenGlow(
        subtleAura,
        maxAlpha: 0.14,
      );
      expect(result.a, closeTo(0.10, 0.01));
    });
  });
}
