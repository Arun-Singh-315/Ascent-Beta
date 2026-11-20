import 'package:flutter/material.dart';

import '../../core/services/plan_collection_service.dart';
import '../../core/services/quick_add_parser.dart';

/// How often one step of a plan repeats. Matches the recurrence rules the
/// plan engine understands for collection items.
enum PlanRepeat {
  daily('daily', 'Every day'),
  weekdays('weekdays', 'Weekdays');

  const PlanRepeat(this.rule, this.label);
  final String rule;
  final String label;

  int get daysPerWeek => this == PlanRepeat.daily ? 7 : 5;
}

/// One step of a template ("Study session at 7:00, every day, 60 min").
@immutable
class PlanStep {
  const PlanStep({
    required this.title,
    required this.time,
    this.repeat = PlanRepeat.daily,
    this.minutes,
    this.enabled = true,
  });

  final String title;
  final TimeOfDay time;
  final PlanRepeat repeat;

  /// Timed steps get a timer in Things; null keeps it a plain to-do.
  final int? minutes;
  final bool enabled;

  PlanStep copyWith({
    String? title,
    TimeOfDay? time,
    PlanRepeat? repeat,
    int? minutes,
    bool clearMinutes = false,
    bool? enabled,
  }) => PlanStep(
    title: title ?? this.title,
    time: time ?? this.time,
    repeat: repeat ?? this.repeat,
    minutes: clearMinutes ? null : (minutes ?? this.minutes),
    enabled: enabled ?? this.enabled,
  );
}

/// A ready-made plan the user can start in one tap and adjust in place.
@immutable
class PlanTemplate {
  const PlanTemplate({
    required this.id,
    required this.title,
    required this.blurb,
    required this.icon,
    required this.steps,
    this.weeks = 4,
  });

  final String id;
  final String title;
  final String blurb;
  final IconData icon;
  final List<PlanStep> steps;
  final int weeks;
}

/// Starter plans (CLAUDE.md §1.7: starters that create real, editable items).
const planTemplates = <PlanTemplate>[
  PlanTemplate(
    id: 'study',
    title: 'Study routine',
    blurb: 'A daily session and an evening revision.',
    icon: Icons.school_outlined,
    steps: [
      PlanStep(
        title: 'Study session',
        time: TimeOfDay(hour: 7, minute: 0),
        minutes: 60,
      ),
      PlanStep(
        title: 'Revise today’s topic',
        time: TimeOfDay(hour: 21, minute: 0),
        repeat: PlanRepeat.weekdays,
        minutes: 30,
      ),
    ],
  ),
  PlanTemplate(
    id: 'meals',
    title: 'Meal routine',
    blurb: 'Regular meals and a little prep the night before.',
    icon: Icons.restaurant_outlined,
    steps: [
      PlanStep(title: 'Breakfast', time: TimeOfDay(hour: 8, minute: 0)),
      PlanStep(title: 'Lunch', time: TimeOfDay(hour: 13, minute: 0)),
      PlanStep(title: 'Dinner', time: TimeOfDay(hour: 20, minute: 0)),
      PlanStep(
        title: 'Prep tomorrow’s lunch',
        time: TimeOfDay(hour: 21, minute: 30),
        repeat: PlanRepeat.weekdays,
        minutes: 15,
      ),
    ],
  ),
  PlanTemplate(
    id: 'fitness',
    title: 'Fitness',
    blurb: 'Workouts on weekdays, a walk and a stretch every day.',
    icon: Icons.fitness_center_outlined,
    steps: [
      PlanStep(
        title: 'Workout',
        time: TimeOfDay(hour: 7, minute: 0),
        repeat: PlanRepeat.weekdays,
        minutes: 45,
      ),
      PlanStep(
        title: 'Evening walk',
        time: TimeOfDay(hour: 18, minute: 30),
        minutes: 30,
      ),
      PlanStep(
        title: 'Stretch',
        time: TimeOfDay(hour: 22, minute: 0),
        minutes: 10,
      ),
    ],
  ),
  PlanTemplate(
    id: 'morning',
    title: 'Morning routine',
    blurb: 'Water, a quiet minute and a plan for the day.',
    icon: Icons.wb_twilight_outlined,
    weeks: 2,
    steps: [
      PlanStep(title: 'Glass of water', time: TimeOfDay(hour: 6, minute: 30)),
      PlanStep(
        title: 'Meditate',
        time: TimeOfDay(hour: 6, minute: 40),
        minutes: 10,
      ),
      PlanStep(
        title: 'Plan the day',
        time: TimeOfDay(hour: 7, minute: 0),
        minutes: 5,
      ),
    ],
  ),
];

/// The first time [step] happens on or after [start] (today: only if its
/// time is still ahead of [now]).
DateTime firstSession(PlanStep step, DateTime start, DateTime now) {
  var day = DateTime(start.year, start.month, start.day);
  for (var i = 0; i < 8; i++) {
    final at = DateTime(
      day.year,
      day.month,
      day.day,
      step.time.hour,
      step.time.minute,
    );
    final weekdayOk =
        step.repeat == PlanRepeat.daily || at.weekday <= DateTime.friday;
    if (weekdayOk && at.isAfter(now)) return at;
    day = day.add(const Duration(days: 1));
  }
  return day;
}

/// Turns the enabled steps into plan items. The plan runs [weeks] weeks
/// from [start] (capped at the engine's 90 days).
List<PlanItemDraft> draftsFor(
  List<PlanStep> steps, {
  required DateTime start,
  required int weeks,
  required DateTime now,
}) {
  final end = DateTime(
    start.year,
    start.month,
    start.day,
  ).add(Duration(days: (weeks * 7 - 1).clamp(0, 89)));
  return [
    for (final s in steps.where((s) => s.enabled && s.title.trim().isNotEmpty))
      if (!firstSession(
        s,
        start,
        now,
      ).isAfter(DateTime(end.year, end.month, end.day, 23, 59)))
        PlanItemDraft(
          title: s.title.trim(),
          at: firstSession(s, start, now),
          recurrence: s.repeat.rule,
          endDate: end,
          minutes: s.minutes,
        ),
  ];
}

/// "18 sessions a week" for the preview line.
int sessionsPerWeek(List<PlanStep> steps) => steps
    .where((s) => s.enabled)
    .fold(0, (sum, s) => sum + s.repeat.daysPerWeek);

/// Builds a one-step plan from a sentence such as "Study DSA 1 hour daily
/// till 15 Jan" or "Gym every weekday at 7am for 45 min for 6 weeks". The
/// result opens in the same sheet as a template, so the user reviews it.
PlanTemplate planFromSentence(String text, DateTime now) {
  final lower = text.toLowerCase();
  final repeat =
      RegExp(
        r'\b(week ?days?|every weekday|mon(day)?\s*(-|to)\s*fri(day)?)\b',
      ).hasMatch(lower)
      ? PlanRepeat.weekdays
      : PlanRepeat.daily;

  // How long: "for 6 weeks", "for 10 days", "till/until/by <date>".
  var weeks = 4;
  final forWeeks = RegExp(r'\bfor (\d{1,2}) weeks?\b').firstMatch(lower);
  final forDays = RegExp(r'\bfor (\d{1,3}) days?\b').firstMatch(lower);
  final until = RegExp(r'\b(till|until|by|upto|up to)\b').firstMatch(lower);
  if (forWeeks != null) {
    weeks = int.parse(forWeeks.group(1)!);
  } else if (forDays != null) {
    weeks = (int.parse(forDays.group(1)!) / 7).ceil();
  } else if (until != null) {
    final endText = text.substring(until.end);
    final iso = RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(endText);
    final end = iso != null
        ? DateTime.tryParse(iso.group(0)!)
        : parseQuickAdd(text.substring(until.start).trim(), now).day;
    if (end != null) {
      final days =
          DateTime(
            end.year,
            end.month,
            end.day,
          ).difference(DateTime(now.year, now.month, now.day)).inDays +
          1;
      weeks = (days / 7).ceil();
    }
  }
  weeks = weeks.clamp(1, 12);

  // What and when: everything before the duration/end words.
  final cut = RegExp(
    r'\b(till|until|by|upto|up to|for \d{1,3} (weeks?|days?))\b',
  ).firstMatch(lower);
  final head = cut == null ? text : text.substring(0, cut.start);
  final q = parseQuickAdd(head.trim(), now);
  final title = q.title
      .replaceAll(
        RegExp(
          r'\b(daily|every ?day|each day|every weekday|week ?days?|every morning|every evening|every night|at)\b',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  final time = q.hour != null
      ? TimeOfDay(hour: q.hour!, minute: q.minute ?? 0)
      : RegExp(r'\b(evening|night|tonight)\b').hasMatch(lower)
      ? const TimeOfDay(hour: 20, minute: 0)
      : RegExp(r'\bmorning\b').hasMatch(lower)
      ? const TimeOfDay(hour: 7, minute: 0)
      : const TimeOfDay(hour: 9, minute: 0);
  final name = title.isEmpty
      ? 'My plan'
      : '${title[0].toUpperCase()}${title.substring(1)}';
  return PlanTemplate(
    id: 'custom',
    title: name,
    blurb: '',
    icon: Icons.event_repeat_rounded,
    weeks: weeks,
    steps: [
      PlanStep(
        title: name,
        time: time,
        repeat: repeat,
        minutes: q.durationMinutes,
      ),
    ],
  );
}
