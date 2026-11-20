import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';

/// Lifecycle rules for the Mindspace.
///
/// One thought is one record in one state. Today, Earlier, Done, Archive and
/// History are views over four dates (createdAt, carriedOn, completedAt,
/// archivedAt). Nothing here copies or moves a record.

DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

bool _onDay(DateTime? at, DateTime day) => at != null && dayOf(at) == day;

/// The tabs of the Mindspace.
enum PalaceTab { today, done, archive, history }

/// Where a thought is drawn on a given day.
enum ThoughtPlace {
  /// Today tab: open, or finished today.
  today,

  /// Today tab, dimmed with an "Archived" tag until midnight.
  archivedToday,

  /// The "Earlier" row on top of Today.
  earlier,

  /// Done tab (finished on an earlier day, not archived).
  done,

  /// Archive tab only.
  archive,
}

/// The day an open thought belongs to: when it was last brought to Today, or
/// the day it was written.
DateTime effectiveDay(Thought t) {
  final carried = t.carriedOn;
  final base = carried != null && carried.isAfter(t.createdAt)
      ? carried
      : t.createdAt;
  return dayOf(base);
}

/// The place a thought has on [now]. Pure: the same thought and day always
/// give the same answer.
ThoughtPlace placeOf(Thought t, DateTime now) {
  final today = dayOf(now);
  if (t.isArchived) {
    return _onDay(t.archivedAt, today)
        ? ThoughtPlace.archivedToday
        : ThoughtPlace.archive;
  }
  if (t.isCompleted) {
    final doneOn = dayOf(t.completedAt ?? t.createdAt);
    return doneOn.isBefore(today) ? ThoughtPlace.done : ThoughtPlace.today;
  }
  return effectiveDay(t).isBefore(today)
      ? ThoughtPlace.earlier
      : ThoughtPlace.today;
}

bool isInToday(Thought t, DateTime now) {
  final p = placeOf(t, now);
  return p == ThoughtPlace.today || p == ThoughtPlace.archivedToday;
}

/// Done tab lists every ticked thought that is not archived, including the
/// ones finished today (they also show in Today).
bool isInDoneTab(Thought t) => t.isCompleted && !t.isArchived;

bool isInArchiveTab(Thought t) => t.isArchived;

bool isInEarlier(Thought t, DateTime now) =>
    placeOf(t, now) == ThoughtPlace.earlier;

/// What the Today tab draws, already grouped.
class TodayContent {
  const TodayContent({
    required this.pinned,
    required this.open,
    required this.doneToday,
    required this.archivedToday,
    required this.earlier,
  });

  final List<Thought> pinned;
  final List<Thought> open;
  final List<Thought> doneToday;
  final List<Thought> archivedToday;
  final List<Thought> earlier;

  bool get isEmpty =>
      pinned.isEmpty &&
      open.isEmpty &&
      doneToday.isEmpty &&
      archivedToday.isEmpty;
}

int _newestFirst(Thought a, Thought b) {
  final byDate = b.createdAt.compareTo(a.createdAt);
  return byDate != 0 ? byDate : b.id.compareTo(a.id);
}

/// Groups [all] for the Today tab. Pinned applies to open thoughts only.
TodayContent buildTodayContent(Iterable<Thought> all, DateTime now) {
  final pinned = <Thought>[];
  final open = <Thought>[];
  final doneToday = <Thought>[];
  final archivedToday = <Thought>[];
  final earlier = <Thought>[];
  for (final t in all) {
    switch (placeOf(t, now)) {
      case ThoughtPlace.today:
        if (t.isCompleted) {
          doneToday.add(t);
        } else if (t.isPinned) {
          pinned.add(t);
        } else {
          open.add(t);
        }
      case ThoughtPlace.archivedToday:
        archivedToday.add(t);
      case ThoughtPlace.earlier:
        earlier.add(t);
      case ThoughtPlace.done:
      case ThoughtPlace.archive:
        break;
    }
  }
  for (final list in [pinned, open, doneToday, archivedToday, earlier]) {
    list.sort(_newestFirst);
  }
  return TodayContent(
    pinned: pinned,
    open: open,
    doneToday: doneToday,
    archivedToday: archivedToday,
    earlier: earlier,
  );
}

/// A day heading: "Today", "Yesterday", "Mon, 17 Nov" or "17 Nov 2025".
String dayHeading(DateTime day, DateTime now) {
  final d = dayOf(day);
  final days = dayOf(now).difference(d).inDays;
  if (days == 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (d.year == now.year) return DateFormat('EEE, d MMM').format(d);
  return DateFormat('d MMM y').format(d);
}

/// Thoughts of one day.
class DayGroup {
  const DayGroup(this.day, this.label, this.thoughts);
  final DateTime day;
  final String label;
  final List<Thought> thoughts;
}

/// Groups [thoughts] (already sorted newest first by [dateOf]) into day
/// groups, keeping their order.
List<DayGroup> groupByDay(
  Iterable<Thought> thoughts,
  DateTime now,
  DateTime Function(Thought) dateOf,
) {
  final groups = <DayGroup>[];
  for (final t in thoughts) {
    final day = dayOf(dateOf(t));
    if (groups.isEmpty || groups.last.day != day) {
      groups.add(DayGroup(day, dayHeading(day, now), <Thought>[]));
    }
    groups.last.thoughts.add(t);
  }
  return groups;
}

/// Day a done thought is filed under.
DateTime doneDate(Thought t) => t.completedAt ?? t.createdAt;

/// Day an archived thought is filed under.
DateTime archiveDate(Thought t) => t.archivedAt ?? t.createdAt;

/// "from 18 Nov" for a thought that was written on an earlier day than the
/// day it now belongs to; null otherwise.
String? originTag(Thought t, DateTime now) {
  final written = dayOf(t.createdAt);
  final carried = t.carriedOn;
  final belongs = carried != null && carried.isAfter(t.createdAt)
      ? dayOf(carried)
      : written;
  if (belongs == written) return null;
  return 'from ${DateFormat('d MMM').format(written)}';
}

/// What happened to a thought on a History day.
enum HistoryKind { written, finished, archived, carriedIn }

class HistoryEntry {
  const HistoryEntry(this.thought, this.kind, {this.note});
  final Thought thought;
  final HistoryKind kind;

  /// Pointer to the same record's other days, e.g. "finished 20 Nov".
  /// Never a copy of the thought.
  final String? note;
}

String _short(DateTime d) => DateFormat('d MMM').format(d);

/// Every lifecycle event of [all] that happened on [day], newest first. A
/// thought can appear once per kind (written and finished the same day shows
/// twice), but the entries always point at the one record.
List<HistoryEntry> historyForDay(Iterable<Thought> all, DateTime day) {
  final d = dayOf(day);
  final entries = <HistoryEntry>[];
  for (final t in all) {
    if (_onDay(t.createdAt, d)) {
      String? note;
      final done = t.completedAt;
      if (t.isCompleted && done != null && dayOf(done) != d) {
        note = 'finished ${_short(done)}';
      } else if (t.isArchived &&
          t.archivedAt != null &&
          dayOf(t.archivedAt!) != d) {
        note = 'archived ${_short(t.archivedAt!)}';
      }
      entries.add(HistoryEntry(t, HistoryKind.written, note: note));
    }
    final carried = t.carriedOn;
    if (carried != null && _onDay(carried, d) && dayOf(t.createdAt) != d) {
      entries.add(
        HistoryEntry(
          t,
          HistoryKind.carriedIn,
          note: 'from ${_short(t.createdAt)}',
        ),
      );
    }
    final done = t.completedAt;
    if (t.isCompleted && done != null && _onDay(done, d)) {
      final from = dayOf(t.createdAt) != d ? 'from ${_short(t.createdAt)}' : null;
      entries.add(HistoryEntry(t, HistoryKind.finished, note: from));
    }
    final archived = t.archivedAt;
    if (t.isArchived && archived != null && _onDay(archived, d)) {
      entries.add(HistoryEntry(t, HistoryKind.archived));
    }
  }
  entries.sort((a, b) {
    final byKind = a.kind.index.compareTo(b.kind.index);
    return byKind != 0 ? byKind : _newestFirst(a.thought, b.thought);
  });
  return entries;
}

/// Number of lifecycle events per day, for the History day strip.
Map<DateTime, int> historyDayCounts(Iterable<Thought> all) {
  final counts = <DateTime, int>{};
  void add(DateTime? at) {
    if (at == null) return;
    final d = dayOf(at);
    counts[d] = (counts[d] ?? 0) + 1;
  }

  for (final t in all) {
    add(t.createdAt);
    if (t.isCompleted) add(t.completedAt);
    if (t.isArchived) add(t.archivedAt);
    final carried = t.carriedOn;
    if (carried != null && dayOf(carried) != dayOf(t.createdAt)) add(carried);
  }
  return counts;
}

/// Result of a bulk action across mixed states, for the "3 done, 2 skipped"
/// snackbar.
class BulkResult {
  const BulkResult(this.applied, this.skipped);
  final int applied;
  final int skipped;

  String summary(String verb) {
    final done = '$applied $verb';
    return skipped == 0 ? done : '$done, $skipped skipped';
  }
}
