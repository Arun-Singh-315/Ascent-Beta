/// Pure helpers for Home's Life list (see `life_rows_test.dart`).
library;

/// Today's amounts in two-hour buckets from [startHour] to midnight, for
/// the small bar charts (water by time of day, focus minutes by time).
List<double> dayBuckets(
  Iterable<(DateTime, num)> points, {
  int startHour = 6,
  int step = 2,
}) {
  final n = ((24 - startHour) / step).ceil();
  final out = List<double>.filled(n, 0);
  for (final (at, v) in points) {
    final i = ((at.hour - startHour) / step).floor().clamp(0, n - 1);
    out[i] += v.toDouble();
  }
  return out;
}

/// "1.8" litres, "2" when whole, "–" for none.
String litres(int ml) {
  if (ml <= 0) return '–';
  final l = ml / 1000;
  return l == l.roundToDouble() ? l.toStringAsFixed(0) : l.toStringAsFixed(1);
}

/// "₹350", "₹1.2k", "–" for nothing.
String rupees(num v) {
  if (v <= 0) return '–';
  if (v < 1000) return '₹${v.round()}';
  if (v < 100000) {
    final k = v / 1000;
    return '₹${k >= 10 ? k.round() : k.toStringAsFixed(1)}k'.replaceAll(
      '.0k',
      'k',
    );
  }
  return '₹${(v / 100000).toStringAsFixed(1)}L';
}

/// Doses whose time has passed and are still not taken.
int missedDoses(Iterable<(String slot, bool taken)> doses, DateTime now) {
  var n = 0;
  for (final (slot, taken) in doses) {
    if (taken) continue;
    final p = slot.split(':');
    if (p.length != 2) continue;
    final at = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(p[0]) ?? 0,
      int.tryParse(p[1]) ?? 0,
    );
    if (at.add(const Duration(minutes: 30)).isBefore(now)) n++;
  }
  return n;
}

/// "All on track", "1 needs a look", or null with nothing to judge. Never
/// "0 of n".
String? onTrackLabel(List<bool> rows) {
  if (rows.isEmpty) return null;
  final off = rows.where((r) => !r).length;
  if (off == 0) return 'All on track';
  return '$off ${off == 1 ? 'needs' : 'need'} a look';
}
