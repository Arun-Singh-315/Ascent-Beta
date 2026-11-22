import 'dart:math';

import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// How one day of a promise looks on the dot row.
enum DayMark {
  /// Kept that day.
  kept,

  /// Missed, and no grace was left: the streak restarted.
  missed,

  /// Missed (or never answered) but forgiven by a grace day.
  grace,

  /// Today or yesterday, not answered yet. It can still be answered.
  open,

  /// Still ahead.
  future,
}

/// Everything the UI needs about one promise, computed on the device.
class PromiseProgress {
  const PromiseProgress({
    required this.dayNumber,
    required this.length,
    required this.kept,
    required this.missed,
    required this.graceAllowance,
    required this.graceUsed,
    required this.streak,
    required this.best,
    required this.today,
    required this.yesterdayOpen,
    required this.finished,
    required this.days,
  });

  /// Today's day number, 1-based, never past [length].
  final int dayNumber;

  /// Run length in days, or null for an ongoing promise.
  final int? length;
  final int kept, missed, graceAllowance, graceUsed, streak, best;

  /// Today's answer: 'kept', 'missed' or null.
  final String? today;

  /// Yesterday is in the run and still unanswered.
  final bool yesterdayOpen;

  /// Every day of the run has passed or been answered.
  final bool finished;

  /// One mark per day from day 1 to the end (or to today when ongoing).
  final List<DayMark> days;

  int get graceLeft => max(0, graceAllowance - graceUsed);
  int? get daysLeft => length == null ? null : max(0, length! - dayNumber);
  bool get keptToday => today == 'kept';
  bool get answeredToday => today != null;
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Whole calendar days from [a] to [b] (daylight-saving safe).
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// Works out streaks, grace and the dot row. Pure: same input, same output.
///
/// Grace (CLAUDE.md §1.8, never shame): one forgiven day per 7 days of the
/// run (at least one). A missed day uses a grace if one is left, so the
/// streak carries on. Days older than yesterday that were never answered
/// count as missed; yesterday can still be answered.
PromiseProgress promiseProgress(
  PromiseRow promise,
  List<PromiseCheckInRow> checkIns,
  DateTime now,
) {
  final start = dayOf(promise.startDay);
  final today = dayOf(now);
  final length = promise.lengthDays;
  final answers = <int, String>{
    for (final c in checkIns)
      if (c.deletedAt == null) _daysBetween(start, c.day): c.result,
  };
  final todayIndex = max(0, _daysBetween(start, today));
  final lastIndex = length == null ? todayIndex : length - 1;
  final graceAllowance = max(1, (length ?? (todayIndex + 1)) ~/ 7);

  var kept = 0, missed = 0, graceUsed = 0, streak = 0, best = 0;
  final days = <DayMark>[];
  for (var i = 0; i <= lastIndex; i++) {
    final answer = answers[i];
    if (i > todayIndex) {
      days.add(DayMark.future);
      continue;
    }
    final isOpenDay = i == todayIndex || i == todayIndex - 1;
    if (answer == 'kept') {
      kept++;
      streak++;
      best = max(best, streak);
      days.add(DayMark.kept);
    } else if (answer == null && isOpenDay) {
      days.add(DayMark.open);
    } else {
      // 'missed', or an old day nobody answered.
      missed++;
      if (graceUsed < graceAllowance) {
        graceUsed++;
        days.add(DayMark.grace);
      } else {
        streak = 0;
        days.add(DayMark.missed);
      }
    }
  }
  final inRun = length == null || todayIndex < length;
  final yesterdayIndex = todayIndex - 1;
  final finished =
      length != null &&
      (todayIndex >= length ||
          (todayIndex == length - 1 &&
              answers[todayIndex] != null &&
              (length < 2 || answers[yesterdayIndex] != null)));
  return PromiseProgress(
    dayNumber: length == null ? todayIndex + 1 : min(todayIndex + 1, length),
    length: length,
    kept: kept,
    missed: missed,
    graceAllowance: graceAllowance,
    graceUsed: graceUsed,
    streak: streak,
    best: best,
    today: inRun ? answers[todayIndex] : null,
    yesterdayOpen:
        yesterdayIndex >= 0 &&
        yesterdayIndex <= lastIndex &&
        answers[yesterdayIndex] == null,
    finished: finished,
    days: days,
  );
}

/// A promise with its check-ins and computed progress.
class PromiseView {
  const PromiseView(this.promise, this.checkIns, this.progress);
  final PromiseRow promise;
  final List<PromiseCheckInRow> checkIns;
  final PromiseProgress progress;
  String get id => promise.id;
  String get title => promise.title;
  bool get isActive => promise.status == 'active';
}

/// Where daily nudges go. The app uses device notifications; tests pass a
/// fake.
abstract class PromiseNudger {
  Future<void> schedule(int id, String title, String body, DateTime at);
  Future<void> cancel(int id);
}

/// Suggested lengths, in the order the create sheet shows them.
const promiseLengths = <int?>[7, 21, 30, 66, null];

String promiseLengthLabel(int? days) => days == null ? 'Ongoing' : '$days days';

/// The one write path for promises (CLAUDE.md §7: single DAO path).
class PromiseService {
  PromiseService(this.db, {DateTime Function()? clock, this.nudger})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;
  final PromiseNudger? nudger;

  static final _random = Random.secure();

  /// A random version-4 UUID.
  static String newId() {
    final b = List<int>.generate(16, (_) => _random.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
        '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// A stable notification id for a promise's nudge.
  static int nudgeId(String promiseId) =>
      880000 + (promiseId.hashCode & 0x7fffffff) % 100000;

  // ── Reads ──────────────────────────────────────────────────────────────

  /// Every promise that isn't deleted, oldest first, updating whenever a
  /// promise or a check-in changes.
  Stream<List<PromiseView>> watchAll() => db
      .customSelect(
        'SELECT 1',
        readsFrom: {db.promiseTable, db.promiseCheckInTable},
      )
      .watch()
      .asyncMap((_) => loadAll());

  Future<List<PromiseView>> loadAll() async {
    final rows =
        await (db.select(db.promiseTable)
              ..where((p) => p.deletedAt.isNull())
              ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
            .get();
    final checks = await (db.select(
      db.promiseCheckInTable,
    )..where((c) => c.deletedAt.isNull())).get();
    final now = clock();
    return [
      for (final p in rows)
        () {
          final mine = checks.where((c) => c.promiseId == p.id).toList();
          return PromiseView(p, mine, promiseProgress(p, mine, now));
        }(),
    ];
  }

  Future<PromiseView?> get(String id) async {
    final p = await (db.select(
      db.promiseTable,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    if (p == null) return null;
    final checks = await (db.select(
      db.promiseCheckInTable,
    )..where((c) => c.promiseId.equals(id) & c.deletedAt.isNull())).get();
    return PromiseView(p, checks, promiseProgress(p, checks, clock()));
  }

  // ── Writes ─────────────────────────────────────────────────────────────

  /// Makes a promise starting today. Only [title] is needed.
  Future<String> create({
    required String title,
    int? lengthDays = 21,
    int? nudgeMinute,
    String? why,
  }) async {
    final t = _cleanTitle(title);
    _checkLength(lengthDays);
    _checkNudge(nudgeMinute);
    final now = clock();
    final id = newId();
    await db
        .into(db.promiseTable)
        .insert(
          PromiseTableCompanion.insert(
            id: id,
            title: t,
            why: Value(_clean(why)),
            startDay: dayOf(now),
            lengthDays: Value(lengthDays),
            nudgeMinute: Value(nudgeMinute),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await syncNudge(id);
    return id;
  }

  Future<void> edit(
    String id, {
    String? title,
    Value<String?> why = const Value.absent(),
    Value<int?> nudgeMinute = const Value.absent(),
    Value<int?> lengthDays = const Value.absent(),
  }) async {
    if (lengthDays.present) _checkLength(lengthDays.value);
    if (nudgeMinute.present) _checkNudge(nudgeMinute.value);
    await (db.update(db.promiseTable)..where((p) => p.id.equals(id))).write(
      PromiseTableCompanion(
        title: title == null ? const Value.absent() : Value(_cleanTitle(title)),
        why: why.present ? Value(_clean(why.value)) : const Value.absent(),
        nudgeMinute: nudgeMinute,
        lengthDays: lengthDays,
        updatedAt: Value(clock()),
      ),
    );
    await syncNudge(id);
  }

  /// Answers [day] (today by default) with 'kept' or 'missed'. Answering
  /// again replaces the answer. Only today and yesterday can be answered.
  Future<void> checkIn(String id, String result, {DateTime? day}) async {
    if (result != 'kept' && result != 'missed') {
      throw ArgumentError('Answer kept or missed.');
    }
    final now = clock();
    final d = dayOf(day ?? now);
    final age = _daysBetween(d, now);
    if (age < 0 || age > 1) {
      throw ArgumentError('Only today or yesterday can be answered.');
    }
    final promise = await (db.select(
      db.promiseTable,
    )..where((p) => p.id.equals(id))).getSingleOrNull();
    if (promise == null || promise.deletedAt != null) {
      throw ArgumentError('This promise no longer exists.');
    }
    if (d.isBefore(dayOf(promise.startDay))) {
      throw ArgumentError('That day is before this promise started.');
    }
    await db.transaction(() async {
      final existing =
          await (db.select(db.promiseCheckInTable)
                ..where((c) => c.promiseId.equals(id) & c.day.equals(d)))
              .getSingleOrNull();
      if (existing == null) {
        await db
            .into(db.promiseCheckInTable)
            .insert(
              PromiseCheckInTableCompanion.insert(
                id: newId(),
                promiseId: id,
                day: d,
                result: result,
                createdAt: now,
                updatedAt: now,
              ),
            );
      } else {
        await (db.update(
          db.promiseCheckInTable,
        )..where((c) => c.id.equals(existing.id))).write(
          PromiseCheckInTableCompanion(
            result: Value(result),
            updatedAt: Value(now),
            deletedAt: const Value(null),
          ),
        );
      }
    });
    await _finishIfDone(id);
    await syncNudge(id);
  }

  /// Takes back an answer (Undo).
  Future<void> clearCheckIn(String id, DateTime day) async {
    final now = clock();
    await (db.update(
      db.promiseCheckInTable,
    )..where((c) => c.promiseId.equals(id) & c.day.equals(dayOf(day)))).write(
      PromiseCheckInTableCompanion(
        updatedAt: Value(now),
        deletedAt: Value(now),
      ),
    );
    // An undone last-day answer reopens the promise.
    final view = await get(id);
    if (view != null &&
        view.promise.status == 'done' &&
        !view.progress.finished) {
      await _setStatus(id, 'active', ended: null);
    }
    await syncNudge(id);
  }

  /// Ends a promise early. Nothing is deleted; it moves to Past.
  Future<void> release(String id) async {
    await _setStatus(id, 'released', ended: clock());
    await nudger?.cancel(nudgeId(id));
  }

  /// Brings a released or finished promise back to active.
  Future<void> reopen(String id) async {
    await _setStatus(id, 'active', ended: null);
    await syncNudge(id);
  }

  /// Starts the same promise again from today, as a new run.
  Future<String> renew(String id) async {
    final old = await get(id);
    if (old == null) throw ArgumentError('This promise no longer exists.');
    if (old.isActive) await _setStatus(id, 'done', ended: clock());
    await nudger?.cancel(nudgeId(id));
    return create(
      title: old.promise.title,
      lengthDays: old.promise.lengthDays,
      nudgeMinute: old.promise.nudgeMinute,
      why: old.promise.why,
    );
  }

  /// Soft-deletes a promise and its check-ins and cancels its nudge.
  /// Returns the deletion time, which [restore] needs for Undo.
  Future<DateTime> delete(String id) async {
    final now = clock();
    await db.transaction(() async {
      await (db.update(db.promiseTable)..where((p) => p.id.equals(id))).write(
        PromiseTableCompanion(updatedAt: Value(now), deletedAt: Value(now)),
      );
      await (db.update(
        db.promiseCheckInTable,
      )..where((c) => c.promiseId.equals(id) & c.deletedAt.isNull())).write(
        PromiseCheckInTableCompanion(
          updatedAt: Value(now),
          deletedAt: Value(now),
        ),
      );
    });
    await nudger?.cancel(nudgeId(id));
    return now;
  }

  /// Undo for [delete].
  Future<void> restore(String id, DateTime deletedAt) async {
    final now = clock();
    await db.transaction(() async {
      await (db.update(db.promiseTable)..where((p) => p.id.equals(id))).write(
        PromiseTableCompanion(
          updatedAt: Value(now),
          deletedAt: const Value(null),
        ),
      );
      await (db.update(db.promiseCheckInTable)..where(
            (c) => c.promiseId.equals(id) & c.deletedAt.equals(deletedAt),
          ))
          .write(
            PromiseCheckInTableCompanion(
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
          );
    });
    await syncNudge(id);
  }

  /// Schedules the next nudge: today at the nudge time if today is still
  /// unanswered and the time is ahead, otherwise the next day in the run.
  Future<void> syncNudge(String id) async {
    final n = nudger;
    if (n == null) return;
    final view = await get(id);
    final minute = view?.promise.nudgeMinute;
    await n.cancel(nudgeId(id));
    if (view == null || !view.isActive || minute == null) return;
    final now = clock();
    final today = dayOf(now);
    DateTime at(DateTime day) =>
        day.add(Duration(hours: minute ~/ 60, minutes: minute % 60));
    var next = at(today);
    if (view.progress.answeredToday || !next.isAfter(now)) {
      next = at(today.add(const Duration(days: 1)));
    }
    final length = view.promise.lengthDays;
    if (length != null && _daysBetween(view.promise.startDay, next) >= length) {
      return;
    }
    await n.schedule(
      nudgeId(id),
      view.promise.title,
      'Did you keep your promise today?',
      next,
    );
  }

  /// Re-schedules every active promise's nudge (app start).
  Future<void> syncAllNudges() async {
    final rows = await (db.select(
      db.promiseTable,
    )..where((p) => p.deletedAt.isNull() & p.status.equals('active'))).get();
    for (final p in rows) {
      await syncNudge(p.id);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  Future<void> _finishIfDone(String id) async {
    final view = await get(id);
    if (view != null && view.isActive && view.progress.finished) {
      await _setStatus(id, 'done', ended: clock());
    }
  }

  Future<void> _setStatus(
    String id,
    String status, {
    required DateTime? ended,
  }) => (db.update(db.promiseTable)..where((p) => p.id.equals(id))).write(
    PromiseTableCompanion(
      status: Value(status),
      endedAt: Value(ended),
      updatedAt: Value(clock()),
    ),
  );

  static String _cleanTitle(String title) {
    var t = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceFirst(
      RegExp(r'^i\s+promise\s+(?:to\s+|that\s+)?', caseSensitive: false),
      '',
    );
    if (t.isEmpty || t.length > 140) {
      throw ArgumentError('Write your promise in 1–140 characters.');
    }
    return t[0].toUpperCase() + t.substring(1);
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static void _checkLength(int? days) {
    if (days != null && (days < 1 || days > 365)) {
      throw ArgumentError('Choose 1 to 365 days, or ongoing.');
    }
  }

  static void _checkNudge(int? minute) {
    if (minute != null && (minute < 0 || minute >= 1440)) {
      throw ArgumentError('Choose a time in the day.');
    }
  }
}
