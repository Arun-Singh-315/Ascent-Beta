/// Keeps the user's words intact in expansion, with a compact collapsed preview.
class ReminderNotificationCopy {
  ReminderNotificationCopy(String content, {this.redacted = false})
      : expandedBody = content.trim();
  final String expandedBody;
  final bool redacted;

  String get title {
    if (redacted) return 'Ascent Reminder';
    final compact = expandedBody.replaceAll(RegExp(r'\s+'), ' ');
    final runes = compact.runes.toList();
    return runes.length <= 80
        ? compact
        : '${String.fromCharCodes(runes.take(79))}…';
  }

  String get body =>
      redacted ? 'Ascent is locked · Tap to unlock' : 'Due now · Tap to open Reminders';

  String bodyFor(String destination) {
    if (redacted) return 'Ascent is locked · Tap to unlock';
    if (destination.startsWith('/today')) {
      return '🎯 Time to focus · Tap to start this activity';
    }
    if (destination.startsWith('/hydration')) {
      return '💧 Time to hydrate · Keep your mind refreshed';
    }
    if (destination.startsWith('/thought-wall')) {
      return '✨ Mind Palace · Tap to reflect on your thought';
    }
    if (destination.startsWith('/home')) {
      return 'Due now · Tap to check in';
    }
    return body;
  }
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
