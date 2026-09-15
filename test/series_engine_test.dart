import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/insight_engine/series_engine.dart';
import 'package:ascent/core/database/tables/enums.dart';

void main() {
  group('SeriesEngine Pacing & Velocity Tests', () {
    test('computeTaskStatus returns lagging when planned date is in the past and not completed', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final status = SeriesEngine.computeTaskStatus(
        plannedDate: past,
        actualCompletedDate: null,
      );
      expect(status, TaskComputedStatus.lagging);
    });

    test('computeTaskStatus returns done when actualCompletedDate is set', () {
      final planned = DateTime.now().add(const Duration(days: 1));
      final completed = DateTime.now();
      final status = SeriesEngine.computeTaskStatus(
        plannedDate: planned,
        actualCompletedDate: completed,
      );
      expect(status, TaskComputedStatus.ahead);
    });

    test('computeTaskStatus returns onTrack when planned date is future and incomplete', () {
      final future = DateTime.now().add(const Duration(days: 3));
      final status = SeriesEngine.computeTaskStatus(
        plannedDate: future,
        actualCompletedDate: null,
      );
      expect(status, TaskComputedStatus.onTrack);
    });

    test('computeSeriesStatus returns completed when completedCount >= totalItems', () {
      final status = SeriesEngine.computeSeriesStatus(
        totalItems: 5,
        completedCount: 5,
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        hasLaggingItems: false,
      );
      expect(status, SeriesComputedStatus.completed);
    });

    test('computeSeriesStatus returns recovering when hasLaggingItems is true', () {
      final status = SeriesEngine.computeSeriesStatus(
        totalItems: 10,
        completedCount: 3,
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 15)),
        hasLaggingItems: true,
      );
      expect(status, SeriesComputedStatus.recovering);
    });
  });
}
