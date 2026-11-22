import '../../core/promises/promise_service.dart';

String _plural(int n, String one, String many) => n == 1 ? one : many;

/// "Day 8 of 21", or "Day 8" for an ongoing promise.
String promiseDayLabel(PromiseProgress p) => p.length == null
    ? 'Day ${p.dayNumber}'
    : 'Day ${p.dayNumber} of ${p.length}';

/// Short facts under the dots, most motivating first.
List<String> promiseFacts(PromiseProgress p) => [
  if (p.streak > 1) '${p.streak}-day streak',
  if (p.daysLeft != null && p.daysLeft! > 0)
    '${p.daysLeft} ${_plural(p.daysLeft!, 'day', 'days')} to go'
  else if (p.daysLeft == 0 && !p.finished)
    'Last day',
  if (p.graceLeft > 0)
    '${p.graceLeft} grace ${_plural(p.graceLeft, 'day', 'days')} left',
];

/// The line shown once today is answered.
String promiseAnsweredLine(PromiseProgress p) {
  if (p.keptToday) {
    if (p.daysLeft == 0) return 'Kept today. That was the last day!';
    return 'Kept today. See you tomorrow.';
  }
  final todayMark = p.days.length >= p.dayNumber
      ? p.days[p.dayNumber - 1]
      : DayMark.missed;
  return todayMark == DayMark.grace
      ? 'Not today. A grace day keeps your streak safe.'
      : 'Not today. Tomorrow is a fresh start.';
}

/// The finish line: "You kept 19 of 21 days."
String promiseFinishLine(PromiseProgress p) =>
    'You kept ${p.kept} of ${p.length ?? p.days.length} days.';

/// Streaks worth one small celebration.
const promiseMilestones = {7, 14, 21, 30, 50, 66, 100, 365};

/// Examples that create a real promise in one tap.
const promiseStarters = [
  'Walk 20 minutes',
  'No phone after 10 pm',
  'Read 10 pages',
];
