/// Natural-language quick add for Things (CLAUDE.md §1.5, §5.2).
///
/// Turns "gym 7am tomorrow 45m" into a title plus optional day, time,
/// duration, reminder and star. Pure and clock-injected so it can be tested.
library;

/// The details quick add can pull out of a line of text.
enum QuickAddField { day, time, duration, reminder, star }

/// One recognised piece of the text, for chips and for "remove this".
class QuickAddMatch {
  const QuickAddMatch(this.field, this.start, this.end);
  final QuickAddField field;
  final int start;
  final int end;
}

class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.day,
    this.hour,
    this.minute,
    this.durationMinutes,
    this.remind = false,
    this.starred = false,
    this.matches = const [],
  });

  /// The text with recognised details removed. Never empty.
  final String title;

  /// Calendar day (midnight), or null for "no date said".
  final DateTime? day;

  /// 24-hour time, or null when no time was said.
  final int? hour;
  final int? minute;

  /// Timer length in minutes (1–1440).
  final int? durationMinutes;
  final bool remind;
  final bool starred;
  final List<QuickAddMatch> matches;

  bool get hasTime => hour != null;
  bool get isEmpty =>
      day == null &&
      hour == null &&
      durationMinutes == null &&
      !remind &&
      !starred;
  Set<QuickAddField> get fields => {for (final m in matches) m.field};
}

const _months = {
  'jan': 1,
  'feb': 2,
  'mar': 3,
  'apr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'aug': 8,
  'sep': 9,
  'oct': 10,
  'nov': 11,
  'dec': 12,
};

const _weekdays = {
  'monday': 1,
  'mon': 1,
  'tuesday': 2,
  'tues': 2,
  'tue': 2,
  'wednesday': 3,
  'wed': 3,
  'thursday': 4,
  'thurs': 4,
  'thur': 4,
  'thu': 4,
  'friday': 5,
  'fri': 5,
  'saturday': 6,
  'sat': 6,
  'sunday': 7,
  'sun': 7,
};

final _monthWord =
    r'(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)';

RegExp _re(String pattern) => RegExp(pattern, caseSensitive: false);

/// Parses [text] relative to [now].
///
/// [ignore] skips fields the user removed, so their words stay in the title.
QuickAddResult parseQuickAdd(
  String text,
  DateTime now, {
  Set<QuickAddField> ignore = const {},
}) {
  final today = DateTime(now.year, now.month, now.day);
  final taken = List<bool>.filled(text.length, false);
  final matches = <QuickAddMatch>[];

  /// Claims the first match of [re] that doesn't overlap an earlier claim.
  RegExpMatch? claim(QuickAddField field, RegExp re) {
    if (ignore.contains(field)) return null;
    for (final m in re.allMatches(text)) {
      if (m.end == m.start) continue;
      var free = true;
      for (var i = m.start; i < m.end; i++) {
        if (taken[i]) {
          free = false;
          break;
        }
      }
      if (!free) continue;
      for (var i = m.start; i < m.end; i++) {
        taken[i] = true;
      }
      matches.add(QuickAddMatch(field, m.start, m.end));
      return m;
    }
    return null;
  }

  // Star: a standalone "!" (or "!!", "!!!").
  final starred = claim(QuickAddField.star, _re(r'(?<=^|\s)!{1,3}(?=\s|$)'));

  // Reminder: "remind me", "remind".
  final remind = claim(QuickAddField.reminder, _re(r'\bremind(?:\s+me)?\b'));

  // Duration before time, so "45m" never reads as a clock time.
  int? duration;
  final hoursAndMinutes = claim(
    QuickAddField.duration,
    _re(
      r'\b(?:for\s+)?(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)\b(?:\s*(\d{1,2})\s*(?:m|min|mins|minutes?)\b)?',
    ),
  );
  if (hoursAndMinutes != null) {
    final hours = double.parse(hoursAndMinutes.group(1)!);
    duration =
        (hours * 60).round() + int.parse(hoursAndMinutes.group(2) ?? '0');
  } else {
    final minutesOnly = claim(
      QuickAddField.duration,
      _re(r'\b(?:for\s+)?(\d{1,4})\s*(?:m|min|mins|minute|minutes)\b'),
    );
    if (minutesOnly != null) duration = int.parse(minutesOnly.group(1)!);
  }
  if (duration != null && (duration < 1 || duration > 1440)) {
    matches.removeWhere((m) => m.field == QuickAddField.duration);
    duration = null;
  }

  // Day.
  DateTime? day;
  final relative = claim(
    QuickAddField.day,
    _re(
      r'\b(?:(today|aaj|tonight)|(tomorrow|tmrw|tmr|tmw|kal)|in\s+(\d{1,3})\s+days?|(next\s+week))\b',
    ),
  );
  if (relative != null) {
    if (relative.group(1) != null) {
      day = today;
    } else if (relative.group(2) != null) {
      day = today.add(const Duration(days: 1));
    } else if (relative.group(3) != null) {
      day = today.add(Duration(days: int.parse(relative.group(3)!)));
    } else {
      day = today.add(const Duration(days: 7));
    }
  } else {
    // Full weekday names anywhere; short forms only after on/next/this, so
    // "sun cream" and "sat down" stay in the title.
    final weekday = claim(
      QuickAddField.day,
      _re(
        r'\b(?:(on|next|this)\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b|\b(on|next|this)\s+(mon|tues?|wed|thu(?:rs?)?|fri|sat|sun)\b',
      ),
    );
    if (weekday != null) {
      final prefix = (weekday.group(1) ?? weekday.group(3))?.toLowerCase();
      final name = (weekday.group(2) ?? weekday.group(4))!.toLowerCase();
      var ahead = (_weekdays[name]! - today.weekday + 7) % 7;
      if (ahead == 0 && prefix == 'next') ahead = 7;
      day = today.add(Duration(days: ahead));
    } else {
      final dayMonth = claim(
        QuickAddField.day,
        _re('\\b(?:on\\s+)?(\\d{1,2})(?:st|nd|rd|th)?\\s+$_monthWord\\b'),
      );
      final monthDay = dayMonth == null
          ? claim(
              QuickAddField.day,
              _re('\\b(?:on\\s+)?$_monthWord\\s+(\\d{1,2})(?:st|nd|rd|th)?\\b'),
            )
          : null;
      final dateDay = dayMonth != null
          ? int.parse(dayMonth.group(1)!)
          : monthDay != null
          ? int.parse(monthDay.group(2)!)
          : null;
      final monthName = (dayMonth?.group(2) ?? monthDay?.group(1))
          ?.toLowerCase();
      if (dateDay != null && monthName != null) {
        final month = _months[monthName.substring(0, 3)]!;
        var candidate = DateTime(today.year, month, dateDay);
        if (candidate.month != month) {
          // e.g. 31 Feb: not a real date, leave the words in the title.
          matches.removeWhere((m) => m.field == QuickAddField.day);
        } else {
          if (candidate.isBefore(today)) {
            candidate = DateTime(today.year + 1, month, dateDay);
          }
          day = candidate;
        }
      }
    }
  }

  // Time.
  int? hour;
  var minute = 0;
  final meridiem = claim(
    QuickAddField.time,
    _re(
      r'(?:\b(?:at|by)\s+|@\s*)?\b(\d{1,2})(?:[:.](\d{2}))?\s*(a\.?m\.?|p\.?m\.?)(?=\s|$|[,.;!?])',
    ),
  );
  if (meridiem != null) {
    final h = int.parse(meridiem.group(1)!);
    final m = int.parse(meridiem.group(2) ?? '0');
    if (h >= 1 && h <= 12 && m < 60) {
      final pm = meridiem.group(3)!.toLowerCase().startsWith('p');
      hour = (h % 12) + (pm ? 12 : 0);
      minute = m;
    } else {
      matches.removeWhere((x) => x.field == QuickAddField.time);
    }
  } else {
    final clock = claim(
      QuickAddField.time,
      _re(r'(?:\b(?:at|by)\s+|@\s*)?\b([01]?\d|2[0-3]):([0-5]\d)\b'),
    );
    if (clock != null) {
      hour = int.parse(clock.group(1)!);
      minute = int.parse(clock.group(2)!);
    } else {
      final named = claim(
        QuickAddField.time,
        _re(r'\b(?:at\s+)?(noon|midday|midnight)\b'),
      );
      if (named != null) {
        hour = named.group(1)!.toLowerCase() == 'midnight' ? 0 : 12;
      } else {
        final bare = claim(
          QuickAddField.time,
          _re(r'(?:\b(?:at|by)\s+|@\s*)(\d{1,2})\b(?!\s*(?:%|/|\.\d))'),
        );
        if (bare != null) {
          final h = int.parse(bare.group(1)!);
          if (h > 23) {
            matches.removeWhere((x) => x.field == QuickAddField.time);
          } else {
            hour = _guessHour(h, day ?? today, now);
          }
        }
      }
    }
  }
  // "tonight" with no time means this evening.
  if (hour == null &&
      relative?.group(1)?.toLowerCase() == 'tonight' &&
      !ignore.contains(QuickAddField.time)) {
    hour = 20;
  }

  // A time already gone today, with no day said, means tomorrow.
  if (hour != null && day == null) {
    final at = DateTime(today.year, today.month, today.day, hour, minute);
    if (!at.isAfter(now)) day = today.add(const Duration(days: 1));
  }
  // Title: original text minus claimed spans and dangling connectors.
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    buffer.write(taken[i] ? ' ' : text[i]);
  }
  var title = buffer
      .toString()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll(RegExp(r'\s+([,.;:!?])'), r'$1')
      .trim();
  final connector = _re(
    // Whole words only, so "to-do list" and "sign-on" keep their words.
    r'^(?:at|on|by|for|in|next|this|from|to)\s+|\s+(?:at|on|by|for|in|next|this|from)$|^[,\-–—:;]\s*|\s*[,\-–—:;]$',
  );
  String previous;
  do {
    previous = title;
    title = title.replaceAll(connector, '').trim();
  } while (title != previous);

  if (title.isEmpty || matches.isEmpty) {
    return QuickAddResult(title: text.trim());
  }
  matches.sort((a, b) => a.start.compareTo(b.start));
  return QuickAddResult(
    title: title,
    day: day,
    hour: hour,
    minute: hour == null ? null : minute,
    durationMinutes: duration,
    remind: remind != null,
    starred: starred != null,
    matches: matches,
  );
}

/// "at 6" has no am/pm. Small hours are usually evening plans ("call mom at
/// 6"), 7–11 usually morning; if that time has already passed today, the
/// later half of the day is meant.
int _guessHour(int h, DateTime day, DateTime now) {
  if (h == 0 || h >= 12) return h;
  var hour = h <= 6 ? h + 12 : h;
  final today = DateTime(now.year, now.month, now.day);
  if (day == today && hour < 12 && hour <= now.hour && h + 12 > now.hour) {
    hour = h + 12;
  }
  return hour;
}
