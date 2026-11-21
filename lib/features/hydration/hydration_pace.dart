/// How far behind a steady pace someone is, in ml, or null when on track.
///
/// Waking hours run 8:00–22:00; by each hour the goal is expected in equal
/// parts. Less than 250 ml behind counts as on track, so the nudge only shows
/// when it is worth a glass. Replaces the Home "Hydration check" pop-up: the
/// Water tile shows this quietly instead (CLAUDE.md §1.8).
int? hydrationBehindMl({
  required DateTime now,
  required int drankMl,
  required int goalMl,
}) {
  if (goalMl <= 0 || now.hour < 9 || now.hour >= 22) return null;
  final minutesAwake = (now.hour - 8) * 60 + now.minute;
  final expected = goalMl * minutesAwake / (14 * 60);
  final behind = expected - drankMl;
  if (behind < 250) return null;
  return (behind / 50).round() * 50;
}
