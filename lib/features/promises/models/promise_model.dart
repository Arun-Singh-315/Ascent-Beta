import 'package:flutter/material.dart';
import 'promise_schedule.dart';
export 'promise_schedule.dart';

const _notProvided = Object();

/// Tracking strategies for distinct commitment types.
enum PromiseTrackingType {
  /// Simple check-off (one-time or recurring without strict duration).
  completion,

  /// Timed practice or duration accumulation (e.g., 45 minutes of study).
  duration,

  /// Target occurrences per week (e.g., 4 gym sessions a week).
  frequency,

  /// Target date or measurable milestone (e.g., finish course by Nov 30).
  milestone,

  /// Behavioral or personal mindset reflection (e.g., stop scrolling at night).
  reflection,
}

/// Lifecycle states of a promise.
enum PromiseStatus { active, paused, completed, archived }

/// Types of recorded progress events.
enum PromiseEventType {
  completion,
  durationSession,
  frequencyCheckIn,
  milestoneAdvance,
  reflectionNote,
}

/// Model representing a rich personal commitment in Ascent.
class PromiseModel {
  const PromiseModel({
    required this.id,
    required this.title,
    required this.intention,
    required this.category,
    required this.trackingType,
    this.targetValue = 1.0,
    this.unit = '',
    this.frequencyPerWeek = 0,
    this.targetDate,
    this.schedule,
    this.isPrivate = false,
    this.reminderTime,
    this.reminderDays = const [],
    this.reminderEnabled = true,
    this.currentValue = 0.0,
    this.status = PromiseStatus.active,
    required this.createdAt,
    this.completedAt,
    this.nextActionPrompt,
    this.isDoneToday = false,
    this.reminderIssue,
  });

  final int id;
  final String title;
  final String intention;
  final String category;
  final PromiseTrackingType trackingType;
  final double targetValue;
  final String unit;
  final int frequencyPerWeek;
  final DateTime? targetDate;
  final PromiseSchedule? schedule;
  final bool isPrivate;
  final String? reminderTime;
  final List<int> reminderDays;
  final bool reminderEnabled;
  final double currentValue;
  final PromiseStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? nextActionPrompt;
  final bool isDoneToday;
  final String? reminderIssue;

  bool get isCompleted => status == PromiseStatus.completed;
  bool get isPaused => status == PromiseStatus.paused;
  bool get isActive => status == PromiseStatus.active;
  bool get isArchived => status == PromiseStatus.archived;

  bool canActAt(DateTime now) {
    if (!isActive || isDoneToday) return false;
    final s = schedule;
    if (s == null) return true;
    final day = promiseDay(now);
    if (day.isBefore(promiseDay(s.startDate)) ||
        (s.endDate != null && day.isAfter(promiseDay(s.endDate!)))) {
      return false;
    }
    return s.repeat == PromiseRepeat.once || s.includes(day);
  }

  /// Progress normalized between 0.0 and 1.0.
  double get progressFraction {
    if (isCompleted) return 1.0;
    switch (trackingType) {
      case PromiseTrackingType.completion:
        return isCompleted || isDoneToday ? 1.0 : 0.0;
      case PromiseTrackingType.duration:
      case PromiseTrackingType.milestone:
        if (targetValue <= 0) return 0.0;
        return (currentValue / targetValue).clamp(0.0, 1.0);
      case PromiseTrackingType.frequency:
        final target = frequencyPerWeek > 0 ? frequencyPerWeek.toDouble() : 1.0;
        return (currentValue / target).clamp(0.0, 1.0);
      case PromiseTrackingType.reflection:
        return (currentValue > 0) ? 1.0 : 0.0;
    }
  }

  /// Label for the direct contextual 1-tap action.
  String get contextualActionLabel {
    if (isCompleted) return 'Completed';
    if (schedule != null && isDoneToday) return 'Done today';
    switch (trackingType) {
      case PromiseTrackingType.duration:
        return currentValue > 0 ? 'Resume Session' : 'Start Session';
      case PromiseTrackingType.completion:
        return schedule == null
            ? 'Mark Completed'
            : (schedule!.repeats ? 'Mark today done' : 'Mark done');
      case PromiseTrackingType.frequency:
        return 'Log Session';
      case PromiseTrackingType.milestone:
        return 'Update Progress';
      case PromiseTrackingType.reflection:
        return 'Quick Reflection';
    }
  }

  /// Icon for the direct contextual action.
  IconData get contextualActionIcon {
    if (isCompleted) return Icons.check_circle_rounded;
    switch (trackingType) {
      case PromiseTrackingType.duration:
        return Icons.play_arrow_rounded;
      case PromiseTrackingType.completion:
        return Icons.check_rounded;
      case PromiseTrackingType.frequency:
        return Icons.add_task_rounded;
      case PromiseTrackingType.milestone:
        return Icons.trending_up_rounded;
      case PromiseTrackingType.reflection:
        return Icons.self_improvement_rounded;
    }
  }

  /// Friendly summary string for display.
  String get progressSummary {
    if (isCompleted) return 'Completed';
    if (schedule != null && isDoneToday) return 'Done today';
    switch (trackingType) {
      case PromiseTrackingType.duration:
        return '${currentValue.toInt()} / ${targetValue.toInt()} $unit';
      case PromiseTrackingType.frequency:
        return '${currentValue.toInt()} of $frequencyPerWeek this week';
      case PromiseTrackingType.milestone:
        if (targetDate != null) {
          final diff = targetDate!.difference(DateTime.now()).inDays;
          final timeStr = diff > 0
              ? '$diff days left'
              : (diff == 0 ? 'Due today' : 'Past due');
          return '${(progressFraction * 100).toInt()}% • $timeStr';
        }
        return '${(progressFraction * 100).toInt()}% done';
      case PromiseTrackingType.reflection:
        return currentValue > 0
            ? '${currentValue.toInt()} reflections logged'
            : 'Ready for reflection';
      case PromiseTrackingType.completion:
        return 'In progress';
    }
  }

  PromiseModel copyWith({
    int? id,
    String? title,
    String? intention,
    String? category,
    PromiseTrackingType? trackingType,
    double? targetValue,
    String? unit,
    int? frequencyPerWeek,
    Object? targetDate = _notProvided,
    Object? schedule = _notProvided,
    bool? isPrivate,
    Object? reminderTime = _notProvided,
    List<int>? reminderDays,
    bool? reminderEnabled,
    double? currentValue,
    PromiseStatus? status,
    DateTime? createdAt,
    DateTime? completedAt,
    String? nextActionPrompt,
    bool? isDoneToday,
    String? reminderIssue,
  }) {
    return PromiseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      intention: intention ?? this.intention,
      category: category ?? this.category,
      trackingType: trackingType ?? this.trackingType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      frequencyPerWeek: frequencyPerWeek ?? this.frequencyPerWeek,
      targetDate: identical(targetDate, _notProvided)
          ? this.targetDate
          : targetDate as DateTime?,
      schedule: identical(schedule, _notProvided)
          ? this.schedule
          : schedule as PromiseSchedule?,
      isPrivate: isPrivate ?? this.isPrivate,
      reminderTime: identical(reminderTime, _notProvided)
          ? this.reminderTime
          : reminderTime as String?,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      currentValue: currentValue ?? this.currentValue,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      nextActionPrompt: nextActionPrompt ?? this.nextActionPrompt,
      isDoneToday: isDoneToday ?? this.isDoneToday,
      reminderIssue: reminderIssue ?? this.reminderIssue,
    );
  }
}

/// Recorded granular event in a promise's lifecycle.
class PromiseProgressEvent {
  const PromiseProgressEvent({
    required this.id,
    required this.promiseId,
    required this.eventType,
    required this.amount,
    required this.occurredAt,
    this.note,
    this.dateKey,
  });

  final int id;
  final int promiseId;
  final PromiseEventType eventType;
  final double amount;
  final DateTime occurredAt;
  final String? note;
  final String? dateKey;
}

/// Structured commitment proposal generated by the conversational parser.
class PromiseProposal {
  const PromiseProposal({
    required this.title,
    required this.intention,
    required this.category,
    required this.trackingType,
    this.targetValue = 1.0,
    this.unit = '',
    this.frequencyPerWeek = 0,
    this.targetDate,
    this.schedule,
    this.isPrivate = false,
    this.reminderTime,
    this.reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    this.coachReflection = '',
    this.clarificationQuestion,
  });

  final String title;
  final String intention;
  final String category;
  final PromiseTrackingType trackingType;
  final double targetValue;
  final String unit;
  final int frequencyPerWeek;
  final DateTime? targetDate;
  final PromiseSchedule? schedule;
  final bool isPrivate;
  final String? reminderTime;
  final List<int> reminderDays;
  final String coachReflection;
  final String? clarificationQuestion;

  PromiseProposal copyWith({
    String? title,
    String? intention,
    String? category,
    PromiseTrackingType? trackingType,
    double? targetValue,
    String? unit,
    int? frequencyPerWeek,
    Object? targetDate = _notProvided,
    Object? schedule = _notProvided,
    bool? isPrivate,
    Object? reminderTime = _notProvided,
    List<int>? reminderDays,
    String? coachReflection,
    String? clarificationQuestion,
  }) {
    return PromiseProposal(
      title: title ?? this.title,
      intention: intention ?? this.intention,
      category: category ?? this.category,
      trackingType: trackingType ?? this.trackingType,
      targetValue: targetValue ?? this.targetValue,
      unit: unit ?? this.unit,
      frequencyPerWeek: frequencyPerWeek ?? this.frequencyPerWeek,
      targetDate: identical(targetDate, _notProvided)
          ? this.targetDate
          : targetDate as DateTime?,
      schedule: identical(schedule, _notProvided)
          ? this.schedule
          : schedule as PromiseSchedule?,
      isPrivate: isPrivate ?? this.isPrivate,
      reminderTime: identical(reminderTime, _notProvided)
          ? this.reminderTime
          : reminderTime as String?,
      reminderDays: reminderDays ?? this.reminderDays,
      coachReflection: coachReflection ?? this.coachReflection,
      clarificationQuestion:
          clarificationQuestion ?? this.clarificationQuestion,
    );
  }
}
