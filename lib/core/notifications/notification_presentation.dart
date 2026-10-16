/// Keeps the user's words intact in expansion, with a compact collapsed preview.
class ReminderNotificationCopy {
  ReminderNotificationCopy(String content) : expandedBody = content.trim();
  final String expandedBody;
  String get title {
    final compact = expandedBody.replaceAll(RegExp(r'\s+'), ' ');
    final runes = compact.runes.toList();
    return runes.length <= 80
        ? compact
        : '${String.fromCharCodes(runes.take(79))}…';
  }

  String get body => 'Due now · Tap to open Reminders';
}

String notificationClock(int seconds) {
  final safe = seconds.clamp(0, 359999);
  final h = safe ~/ 3600;
  final m = (safe % 3600) ~/ 60;
  final s = safe % 60;
  return h > 0
      ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
      : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
