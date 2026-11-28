import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../today/models/things_sections.dart';
import 'now_focus.dart';
export 'now_focus.dart';

/// One picture of the day that every Home section reads (Day Page, step 3).
///
/// Everything here is computed by the pure [buildHomeDay] from plain inputs,
/// so the rules for "today", the day line, the rail and "Needs you" live in
/// one place and are unit-tested. Sections read only their slice through
/// `homeDayProvider.select(...)`; each slice has value equality so a
/// section rebuilds only when its own data changes.

/// Time of day (CLAUDE.md §2.6: morning 5–12, afternoon 12–17,
/// evening 17–21, night 21–5).
enum DayPeriod { morning, afternoon, evening, night }

DayPeriod dayPeriodAt(DateTime t) => switch (t.hour) {
  >= 5 && < 12 => DayPeriod.morning,
  >= 12 && < 17 => DayPeriod.afternoon,
  >= 17 && < 21 => DayPeriod.evening,
  _ => DayPeriod.night,
};

String greetingFor(DayPeriod p) => switch (p) {
  DayPeriod.morning => 'Good morning',
  DayPeriod.afternoon => 'Good afternoon',
  DayPeriod.evening => 'Good evening',
  DayPeriod.night => 'Good night',
};

/// How the day is going. Home's wording and order follow it.
enum DayMood {
  /// Nothing planned today.
  open,

  /// Plans for today, nothing done yet.
  ahead,

  /// Some done, some left.
  underway,

  /// A focus session is running or paused.
  live,

  /// Something from earlier is overdue.
  behind,

  /// Everything planned for today is done.
  allDone,

  /// Night with nothing planned.
  quiet,
}

/// The mood rule, in priority order. Pure; see `home_day_test.dart`.
DayMood resolveDayMood({
  required bool hasLiveSession,
  required int overdue,
  required int total,
  required int done,
  required DayPeriod period,
}) {
  if (hasLiveSession) return DayMood.live;
  if (overdue > 0) return DayMood.behind;
  if (total == 0) {
    return period == DayPeriod.night ? DayMood.quiet : DayMood.open;
  }
  if (done >= total) return DayMood.allDone;
  if (done == 0) return DayMood.ahead;
  return DayMood.underway;
}

/// A piece of the one-sentence day summary. Facts are set bolder.
@immutable
class DayLinePart {
  const DayLinePart(this.text, {this.fact = false});
  final String text;
  final bool fact;

  @override
  bool operator ==(Object other) =>
      other is DayLinePart && other.text == text && other.fact == fact;
  @override
  int get hashCode => Object.hash(text, fact);
  @override
  String toString() => fact ? '[$text]' : text;
}

@immutable
class DayLine {
  const DayLine(this.parts);
  final List<DayLinePart> parts;

  /// The sentence as plain text (for accessibility and tests).
  String get text => parts.map((p) => p.text).join();

  @override
  bool operator ==(Object other) =>
      other is DayLine && listEquals(other.parts, parts);
  @override
  int get hashCode => Object.hashAll(parts);
  @override
  String toString() => parts.join();
}

/// What a dot on the day rail stands for.
enum RailKind { task, timed, reminder, dose }

/// A dot on the day rail, placed between 6:00 (0) and midnight (1).
@immutable
class RailMark {
  const RailMark({
    required this.at,
    required this.kind,
    required this.done,
    required this.overdue,
  });
  final double at;
  final RailKind kind;
  final bool done;
  final bool overdue;

  @override
  bool operator ==(Object other) =>
      other is RailMark &&
      other.at == at &&
      other.kind == kind &&
      other.done == done &&
      other.overdue == overdue;
  @override
  int get hashCode => Object.hash(at, kind, done, overdue);
}

/// The rail runs from 6:00 to midnight. Times outside it are clamped.
const railStartHour = 6;

double railPosition(DateTime t) {
  final minutes = (t.hour - railStartHour) * 60 + t.minute;
  return (minutes / ((24 - railStartHour) * 60)).clamp(0.0, 1.0);
}

@immutable
class DayRail {
  const DayRail({required this.marks, required this.now});
  final List<RailMark> marks;

  /// Where "now" sits on the rail.
  final double now;

  @override
  bool operator ==(Object other) =>
      other is DayRail && other.now == now && listEquals(other.marks, marks);
  @override
  int get hashCode => Object.hash(now, Object.hashAll(marks));
}

/// Things that slipped and need an answer, most urgent first.
enum NeedsYouKind {
  overdue,
  missedDose,
  overdueReminder,
  promiseWaiting,
  backup,
}

@immutable
class NeedsYouItem {
  const NeedsYouItem({
    required this.kind,
    required this.title,
    required this.detail,
    required this.action,
    this.targetId,
  });
  final NeedsYouKind kind;
  final String title;
  final String detail;

  /// Button label, verb first ("Take").
  final String action;

  /// The record the action works on (activity id, reminder id, promise id).
  final String? targetId;

  @override
  bool operator ==(Object other) =>
      other is NeedsYouItem &&
      other.kind == kind &&
      other.title == title &&
      other.detail == detail &&
      other.action == action &&
      other.targetId == targetId;
  @override
  int get hashCode => Object.hash(kind, title, detail, action, targetId);
}

/// Home previews show at most 4 items (CLAUDE.md §1.9).
const needsYouCap = 4;

/// Water, focus, medicine and money, each against its goal.
@immutable
class Vitals {
  const Vitals({
    required this.waterMl,
    required this.waterGoalMl,
    required this.focusMinutes,
    required this.focusGoalMinutes,
    required this.dosesTaken,
    required this.dosesTotal,
    required this.spentToday,
    required this.dailyBudget,
  });
  final int waterMl, waterGoalMl;
  final int focusMinutes, focusGoalMinutes;
  final int dosesTaken, dosesTotal;
  final double spentToday;
  final double? dailyBudget;

  double get waterProgress =>
      waterGoalMl <= 0 ? 0 : (waterMl / waterGoalMl).clamp(0.0, 1.0);
  double get focusProgress => focusGoalMinutes <= 0
      ? 0
      : (focusMinutes / focusGoalMinutes).clamp(0.0, 1.0);

  @override
  bool operator ==(Object other) =>
      other is Vitals &&
      other.waterMl == waterMl &&
      other.waterGoalMl == waterGoalMl &&
      other.focusMinutes == focusMinutes &&
      other.focusGoalMinutes == focusGoalMinutes &&
      other.dosesTaken == dosesTaken &&
      other.dosesTotal == dosesTotal &&
      other.spentToday == spentToday &&
      other.dailyBudget == dailyBudget;
  @override
  int get hashCode => Object.hash(
    waterMl,
    waterGoalMl,
    focusMinutes,
    focusGoalMinutes,
    dosesTaken,
    dosesTotal,
    spentToday,
    dailyBudget,
  );
}

/// Today's list for the "Today and plans" zone.
@immutable
class TodayList {
  const TodayList({
    required this.pending,
    required this.done,
    required this.total,
    required this.overdue,
    required this.anytime,
  });

  /// Not done yet, overdue first, then by time.
  final List<TodayActivityItem> pending;
  final int done, total, overdue, anytime;

  @override
  bool operator ==(Object other) =>
      other is TodayList &&
      other.done == done &&
      other.total == total &&
      other.overdue == overdue &&
      other.anytime == anytime &&
      listEquals(
        other.pending.map((a) => (a.id, a.status, a.scheduledTime)).toList(),
        pending.map((a) => (a.id, a.status, a.scheduledTime)).toList(),
      );
  @override
  int get hashCode => Object.hash(
    done,
    total,
    overdue,
    anytime,
    Object.hashAll(pending.map((a) => (a.id, a.status))),
  );
}

/// A promise as Home needs it (kept separate from the database row so the
/// day model stays pure).
@immutable
class PromiseToday {
  const PromiseToday({
    required this.id,
    required this.title,
    required this.day,
    required this.length,
    required this.answeredToday,
    required this.yesterdayOpen,
    required this.streak,
  });
  final String id;
  final String title;
  final int day;
  final int? length;
  final bool answeredToday, yesterdayOpen;
  final int streak;
}

@immutable
class HomeDay {
  const HomeDay({
    required this.now,
    required this.period,
    required this.mood,
    required this.focus,
    required this.today,
    required this.rail,
    required this.dayLine,
    required this.needsYou,
    required this.vitals,
  });

  final DateTime now;
  final DayPeriod period;
  final DayMood mood;

  /// What the Now card shows.
  final NowFocus focus;
  final TodayList today;
  final DayRail rail;
  final DayLine dayLine;
  final List<NeedsYouItem> needsYou;
  final Vitals vitals;

  String get greeting => greetingFor(period);
}

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

String _clock(DateTime t) => DateFormat('H:mm').format(t);

/// Builds the day from plain inputs. Pure and deterministic for a given
/// [now]; everything Home says about the day comes from here.
HomeDay buildHomeDay({
  required DateTime now,
  required List<TodayActivityItem> activities,
  required List<Reminder> reminders,
  required bool hasLiveSession,
  String? liveTitle,
  List<PromiseToday> promises = const [],
  DateTime? lastBackupAt,
  int waterMl = 0,
  int waterGoalMl = 2000,
  int focusMinutes = 0,
  int focusGoalMinutes = 0,
  double spentToday = 0,
  double? dailyBudget,
}) {
  final period = dayPeriodAt(now);
  final onToday = activities.where(isOnTodayList).toList();
  bool isDone(TodayActivityItem a) => a.status == TodayActivityStatus.done;
  final pending = onToday.where((a) => !isDone(a)).toList()
    ..sort((a, b) {
      if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
      final at = a.scheduledTime, bt = b.scheduledTime;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return at.compareTo(bt);
    });
  final overdue = pending.where((a) => a.isOverdue).length;
  final today = TodayList(
    pending: pending,
    done: onToday.where(isDone).length,
    total: onToday.length,
    overdue: overdue,
    anytime: anytimeThings(activities).length,
  );

  final linkedTaskIds = {
    for (final a in activities)
      if (a.linkedTaskId != null) a.linkedTaskId!,
  };
  final overdueReminders =
      reminders
          .where(
            (r) =>
                r.isActive &&
                r.scheduledAt.isBefore(now) &&
                (r.linkedTaskId == null ||
                    !linkedTaskIds.contains(r.linkedTaskId)),
          )
          .toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  final mood = resolveDayMood(
    hasLiveSession: hasLiveSession,
    overdue: overdue + overdueReminders.length,
    total: today.total,
    done: today.done,
    period: period,
  );

  final waiting = promises
      .where((p) => !p.answeredToday || p.yesterdayOpen)
      .toList();

  // ── Day line: one sentence, at most two facts, never "0". ──────────────
  DayLine line() {
    final firstTimed = pending
        .where((a) => !a.isOverdue && a.scheduledTime != null)
        .map((a) => a.scheduledTime!)
        .where((t) => !t.isBefore(now))
        .fold<DateTime?>(null, (m, t) => m == null || t.isBefore(m) ? t : m);
    final promiseTail = waiting.isEmpty
        ? const <DayLinePart>[]
        : [
            const DayLinePart(' '),
            DayLinePart(_plural(waiting.length, 'promise'), fact: true),
            const DayLinePart(' to keep.'),
          ];
    switch (mood) {
      case DayMood.live:
        return DayLine([
          const DayLinePart('You’re focusing on '),
          DayLinePart(liveTitle ?? 'a session', fact: true),
          const DayLinePart('.'),
        ]);
      case DayMood.behind:
        final n = overdue + overdueReminders.length;
        return DayLine([
          DayLinePart('$n overdue', fact: true),
          const DayLinePart(' to catch up'),
          if (pending.length > overdue) ...[
            const DayLinePart(', then '),
            DayLinePart(_plural(pending.length - overdue, 'thing'), fact: true),
            const DayLinePart(' for today.'),
          ] else
            const DayLinePart('.'),
        ]);
      case DayMood.open:
        return DayLine([
          const DayLinePart('Your day is open.'),
          if (today.anytime > 0) ...[
            const DayLinePart(' '),
            DayLinePart(_plural(today.anytime, 'anytime to-do'), fact: true),
            const DayLinePart(' waiting.'),
          ],
        ]);
      case DayMood.quiet:
        return const DayLine([DayLinePart('A quiet night. Nothing planned.')]);
      case DayMood.allDone:
        return DayLine([
          DayLinePart('All ${today.total} done.', fact: true),
          ...promiseTail,
        ]);
      case DayMood.ahead:
        return DayLine([
          DayLinePart(_plural(today.total, 'thing'), fact: true),
          DayLinePart(
            firstTimed == null
                ? ' today.'
                : ' today, first at ${_clock(firstTimed)}.',
          ),
          ...promiseTail,
        ]);
      case DayMood.underway:
        return DayLine([
          DayLinePart('${today.done} of ${today.total}', fact: true),
          DayLinePart(
            firstTimed == null
                ? ' done.'
                : ' done. Next at ${_clock(firstTimed)}.',
          ),
          ...promiseTail,
        ]);
    }
  }

  // ── Rail ───────────────────────────────────────────────────────────────
  final marks = <RailMark>[
    for (final a in onToday)
      if (a.scheduledTime != null)
        RailMark(
          at: railPosition(a.scheduledTime!),
          kind: a.sourceType == 'medicine'
              ? RailKind.dose
              : (a.kind != ActivityKind.todo || (a.targetMinutes ?? 0) > 0)
              ? RailKind.timed
              : RailKind.task,
          done: isDone(a),
          overdue: a.isOverdue,
        ),
    for (final r in reminders)
      if (r.isActive &&
          r.scheduledAt.year == now.year &&
          r.scheduledAt.month == now.month &&
          r.scheduledAt.day == now.day &&
          (r.linkedTaskId == null || !linkedTaskIds.contains(r.linkedTaskId)))
        RailMark(
          at: railPosition(r.scheduledAt),
          kind: RailKind.reminder,
          done: false,
          overdue: r.scheduledAt.isBefore(now),
        ),
  ]..sort((a, b) => a.at.compareTo(b.at));

  // ── Needs you ──────────────────────────────────────────────────────────
  final needs = <NeedsYouItem>[];
  final overdueItems = pending.where((a) => a.isOverdue).toList();
  if (overdueItems.isNotEmpty) {
    needs.add(
      NeedsYouItem(
        kind: NeedsYouKind.overdue,
        title: '${overdueItems.length} overdue',
        detail: overdueItems.length == 1
            ? overdueItems.first.title
            : '${overdueItems.first.title} and more',
        action: 'Move to today',
      ),
    );
  }
  for (final a in pending) {
    final at = a.scheduledTime;
    if (a.sourceType == 'medicine' &&
        at != null &&
        now.difference(at) > const Duration(minutes: 30)) {
      needs.add(
        NeedsYouItem(
          kind: NeedsYouKind.missedDose,
          title: a.title,
          detail: 'Due ${_clock(at)}, not taken',
          action: 'Take',
          targetId: a.id,
        ),
      );
    }
  }
  for (final r in overdueReminders) {
    needs.add(
      NeedsYouItem(
        kind: NeedsYouKind.overdueReminder,
        title: r.title,
        detail: 'Was due ${_clock(r.scheduledAt)}',
        action: 'Done',
        targetId: '${r.id}',
      ),
    );
  }
  for (final p in promises.where((p) => p.yesterdayOpen)) {
    needs.add(
      NeedsYouItem(
        kind: NeedsYouKind.promiseWaiting,
        title: p.title,
        detail: 'Did you keep it yesterday?',
        action: 'Answer',
        targetId: p.id,
      ),
    );
  }
  if (lastBackupAt != null && now.difference(lastBackupAt).inDays >= 7) {
    final days = now.difference(lastBackupAt).inDays;
    needs.add(
      NeedsYouItem(
        kind: NeedsYouKind.backup,
        title: 'Backup',
        detail: 'Last one ${_plural(days, 'day')} ago',
        action: 'Back up',
      ),
    );
  }

  final doses = activities.where((a) => a.sourceType == 'medicine').toList();

  return HomeDay(
    now: now,
    period: period,
    mood: mood,
    focus: resolveNowFocus(
      activities: activities,
      reminders: reminders,
      hasLiveSession: hasLiveSession,
      now: now,
    ),
    today: today,
    rail: DayRail(marks: marks, now: railPosition(now)),
    dayLine: line(),
    needsYou: List.unmodifiable(needs.take(needsYouCap)),
    vitals: Vitals(
      waterMl: waterMl,
      waterGoalMl: waterGoalMl,
      focusMinutes: focusMinutes,
      focusGoalMinutes: focusGoalMinutes,
      dosesTaken: doses.where(isDone).length,
      dosesTotal: doses.length,
      spentToday: spentToday,
      dailyBudget: dailyBudget,
    ),
  );
}
