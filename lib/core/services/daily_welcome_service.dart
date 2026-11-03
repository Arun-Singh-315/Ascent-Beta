import 'package:shared_preferences/shared_preferences.dart';

/// Stores the calendar day (ISO string at midnight) the daily welcome was last
/// shown. The key is shared with the older briefing so existing installs do
/// not see it twice on the day they update.
const dailyWelcomeSeenKey = 'ascent_daily_briefing_seen_v1';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// True when the welcome should open now: the person has not turned it off and
/// it has not already been shown on [now]'s calendar day. A stored day in the
/// future (clock moved back) counts as already seen.
bool shouldShowDailyWelcome({
  required SharedPreferences prefs,
  required DateTime now,
  required bool autoOpen,
}) {
  if (!autoOpen) return false;
  final raw = prefs.getString(dailyWelcomeSeenKey);
  final seen = raw == null ? null : DateTime.tryParse(raw);
  return seen == null || _day(seen).isBefore(_day(now));
}

/// Call when the welcome is about to be shown (not when it is closed), so a
/// crash or a quick swipe-away can never make it reappear the same day.
Future<bool> markDailyWelcomeSeen(SharedPreferences prefs, DateTime now) =>
    prefs.setString(dailyWelcomeSeenKey, _day(now).toIso8601String());
