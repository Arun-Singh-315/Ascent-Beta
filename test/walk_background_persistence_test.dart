import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/walk/walk_tracking_service.dart';

void main() {
  group('Walk Background Persistence & Duration Computation Tests', () {
    test('WalkTrackingState computes duration from start time and pause duration accurately', () {
      final startTime = DateTime.now().subtract(const Duration(minutes: 15));
      const pausedSeconds = 120; // 2 minutes paused

      final totalElapsed = WalkTrackingNotifier.computeActiveDurationSeconds(
        startedAt: startTime,
        now: DateTime.now(),
        pausedSeconds: pausedSeconds,
      );

      // Should be approx 13 minutes (780 seconds)
      expect(totalElapsed >= 779 && totalElapsed <= 782, isTrue);
    });

    test('WalkTrackingState formatters return clean pace and duration values', () {
      const state = WalkTrackingState(
        durationSeconds: 1800, // 30 mins
        distanceMeters: 3000, // 3.0 km
        status: WalkTrackingStatus.tracking,
      );

      expect(state.distanceKm, 3.0);
      expect(state.formattedDuration, '30:00');
      // 1800s / 3km = 600s/km = 10:00 pace
      expect(state.formattedPace, '10:00');
    });
  });
}
