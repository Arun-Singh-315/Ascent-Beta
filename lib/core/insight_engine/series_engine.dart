import 'dart:math';
import '../database/tables/enums.dart';

/// Represents the status of a single task.
enum TaskComputedStatus {
  ahead,
  onTrack,
  lagging,
  atRisk,
  done,
}

/// Helper model for burn-up chart and series progress report.
class SeriesReportCardData {
  final int seriesId;
  final String title;
  final int totalItems;
  final int completedItems;
  final int onTimeCount;
  final double onTimePercentage;
  final double currentPacePerWeek;
  final double requiredPacePerWeek;
  final SeriesComputedStatus seriesStatus;
  final List<BurnUpPoint> burnUpPoints;

  SeriesReportCardData({
    required this.seriesId,
    required this.title,
    required this.totalItems,
    required this.completedItems,
    required this.onTimeCount,
    required this.onTimePercentage,
    required this.currentPacePerWeek,
    required this.requiredPacePerWeek,
    required this.seriesStatus,
    required this.burnUpPoints,
  });
}

class BurnUpPoint {
  final DateTime date;
  final int plannedCumulative;
  final int actualCumulative;

  BurnUpPoint({
    required this.date,
    required this.plannedCumulative,
    required this.actualCumulative,
  });
}

/// Adaptive scheduling and status engine for Tasks and Series.
/// All logic is pure and deterministic.
class SeriesEngine {
  /// Computes a single task's status based on plannedDate, completion date, and current date.
  static TaskComputedStatus computeTaskStatus({
    required DateTime? plannedDate,
    required DateTime? actualCompletedDate,
    DateTime? now,
    bool isSeriesAtRisk = false,
  }) {
    final effectiveNow = now ?? DateTime.now();

    if (actualCompletedDate != null) {
      if (plannedDate != null && actualCompletedDate.isBefore(plannedDate)) {
        return TaskComputedStatus.ahead;
      }
      return TaskComputedStatus.done;
    }

    if (plannedDate == null) {
      return TaskComputedStatus.onTrack;
    }

    final today = DateTime(effectiveNow.year, effectiveNow.month, effectiveNow.day);
    final deadlineDay = DateTime(plannedDate.year, plannedDate.month, plannedDate.day);

    if (today.isAfter(deadlineDay)) {
      return TaskComputedStatus.lagging;
    }

    if (isSeriesAtRisk) {
      return TaskComputedStatus.atRisk;
    }

    return TaskComputedStatus.onTrack;
  }

  /// Computes series status: onTrack, atRisk, recovering, or completed.
  static SeriesComputedStatus computeSeriesStatus({
    required int totalItems,
    required int completedCount,
    required DateTime? startDate,
    required DateTime? endDate,
    required bool hasLaggingItems,
    DateTime? now,
  }) {
    if (totalItems > 0 && completedCount >= totalItems) {
      return SeriesComputedStatus.completed;
    }

    if (hasLaggingItems) {
      return SeriesComputedStatus.recovering;
    }

    if (endDate == null || startDate == null) {
      return SeriesComputedStatus.onTrack;
    }

    final effectiveNow = now ?? DateTime.now();
    final totalDuration = endDate.difference(startDate).inDays;
    final elapsedDays = effectiveNow.difference(startDate).inDays;

    if (totalDuration <= 0 || elapsedDays <= 0) {
      return SeriesComputedStatus.onTrack;
    }

    // Fraction of time passed vs fraction of items completed
    final timeFraction = (elapsedDays / totalDuration).clamp(0.0, 1.0);
    final completionFraction = totalItems > 0 ? (completedCount / totalItems) : 0.0;

    // If 30%+ behind time elapsed, it's at risk
    if (timeFraction - completionFraction > 0.3) {
      return SeriesComputedStatus.atRisk;
    }

    return SeriesComputedStatus.onTrack;
  }

  /// Calculates the next deadline for an upcoming task in a series based on its pacing rule.
  static DateTime calculateNextDeadline({
    required PacingRule pacingRule,
    required DateTime fromDate,
    int? fixedIntervalDays,
    DateTime? seriesEndDate,
    int remainingItems = 1,
  }) {
    switch (pacingRule) {
      case PacingRule.fixedInterval:
        final interval = (fixedIntervalDays != null && fixedIntervalDays > 0)
            ? fixedIntervalDays
            : 2;
        return fromDate.add(Duration(days: interval));

      case PacingRule.evenlyByEndDate:
        if (seriesEndDate == null || seriesEndDate.isBefore(fromDate) || remainingItems <= 0) {
          return fromDate.add(const Duration(days: 2));
        }
        final daysLeft = seriesEndDate.difference(fromDate).inDays;
        final step = max(1, (daysLeft / remainingItems).floor());
        return fromDate.add(Duration(days: step));

      case PacingRule.manualPerItem:
        return fromDate.add(const Duration(days: 1));
    }
  }

  /// Recompresses deadlines for remaining tasks in a series when a deadline was missed
  /// but there's a hard deadline (e.g. interview date).
  static List<DateTime> recompressDeadlines({
    required DateTime startDate,
    required DateTime seriesEndDate,
    required int remainingItemCount,
  }) {
    if (remainingItemCount <= 0) return [];
    final daysRemaining = max(1, seriesEndDate.difference(startDate).inDays);
    final interval = daysRemaining / remainingItemCount;

    return List.generate(remainingItemCount, (index) {
      final daysOffset = ((index + 1) * interval).round();
      return startDate.add(Duration(days: max(1, daysOffset)));
    });
  }
}
