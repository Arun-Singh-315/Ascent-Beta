import 'package:intl/intl.dart';

/// A date and time the way people say it: "today at 7:00 PM",
/// "tomorrow at 9:30 AM", "Sat 23 Nov at 7:00 PM", or with the year when it
/// is not this year. Never a raw timestamp.
String humanWhen(DateTime at, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = day.difference(today).inDays;
  final time = DateFormat('h:mm a').format(at);
  final date = switch (diff) {
    0 => 'today',
    1 => 'tomorrow',
    -1 => 'yesterday',
    _ when diff > 1 && diff < 7 => DateFormat('EEEE').format(at),
    _ when at.year == n.year => DateFormat('EEE d MMM').format(at),
    _ => DateFormat('d MMM y').format(at),
  };
  return '$date at $time';
}

/// Just the day part of [humanWhen], capitalised for labels: "Today",
/// "Tomorrow", "Saturday", "Sat 30 Nov".
String humanDay(DateTime at, {DateTime? now}) {
  final s = humanWhen(at, now: now);
  final d = s.substring(0, s.lastIndexOf(' at '));
  return '${d[0].toUpperCase()}${d.substring(1)}';
}
