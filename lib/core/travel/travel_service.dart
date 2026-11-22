import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../utils/uuid.dart';

/// Where you are, from one GPS reading.
class LocationFix {
  const LocationFix(this.lat, this.lon);
  final double lat, lon;
}

/// A place the phone's map service suggests for a location.
class PlaceGuess {
  const PlaceGuess(this.name, {this.area, this.kind});
  final String name;
  final String? area;
  final String? kind;
}

/// One payment that evens up a trip: [from] pays [to] [amount].
class Settlement {
  const Settlement(this.from, this.to, this.amount);
  final String from, to;
  final double amount;
  @override
  String toString() => '$from→$to ${amount.toStringAsFixed(2)}';
}

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Net balance per person: positive = owed money, negative = owes.
Map<String, double> tripBalances(
  List<TripExpenseRow> expenses,
  List<TripShareRow> shares,
) {
  final net = <String, double>{};
  final live = {
    for (final e in expenses)
      if (e.deletedAt == null) e.id: e,
  };
  for (final e in live.values) {
    if (e.paidBy != null) net[e.paidBy!] = (net[e.paidBy!] ?? 0) + e.amount;
  }
  for (final s in shares) {
    if (s.deletedAt != null || !live.containsKey(s.expenseId)) continue;
    net[s.personId] = (net[s.personId] ?? 0) - s.amount;
  }
  return {for (final e in net.entries) e.key: _round2(e.value)};
}

/// The fewest payments that make everyone even (largest debtor pays the
/// largest creditor first). Amounts under one paisa are ignored.
List<Settlement> settleUp(Map<String, double> balances) {
  final creditors = [
    for (final e in balances.entries)
      if (e.value > 0.009) MapEntry(e.key, e.value),
  ]..sort((a, b) => b.value.compareTo(a.value));
  final debtors = [
    for (final e in balances.entries)
      if (e.value < -0.009) MapEntry(e.key, -e.value),
  ]..sort((a, b) => b.value.compareTo(a.value));
  final c = [
    for (final e in creditors) [e.key, e.value],
  ];
  final d = [
    for (final e in debtors) [e.key, e.value],
  ];
  final out = <Settlement>[];
  var i = 0, j = 0;
  while (i < d.length && j < c.length) {
    final pay = (d[i][1] as double) < (c[j][1] as double)
        ? d[i][1] as double
        : c[j][1] as double;
    out.add(Settlement(d[i][0] as String, c[j][0] as String, _round2(pay)));
    d[i][1] = (d[i][1] as double) - pay;
    c[j][1] = (c[j][1] as double) - pay;
    if ((d[i][1] as double) < 0.009) i++;
    if ((c[j][1] as double) < 0.009) j++;
  }
  return out;
}

/// Splits [amount] equally; leftover paise go to the first people so the
/// parts always add up exactly.
List<double> splitEqually(double amount, int people) {
  if (people <= 0) return const [];
  final paise = (amount * 100).round();
  final base = paise ~/ people;
  final extra = paise - base * people;
  return [for (var i = 0; i < people; i++) (base + (i < extra ? 1 : 0)) / 100];
}

/// Guesses what kind of place a name is, for its icon and the bill prompt.
String? guessPlaceKind(String name) {
  final n = name.toLowerCase();
  bool any(List<String> w) => w.any(n.contains);
  if (any([
    'restaurant',
    'cafe',
    'café',
    'coffee',
    'dhaba',
    'bar',
    'pub',
    'bistro',
    'kitchen',
    'bakery',
    'food',
    'pizza',
    'biryani',
    'shack',
    'diner',
  ])) {
    return 'food';
  }
  if (any(['beach', 'lake', 'falls', 'river', 'park', 'garden', 'hill'])) {
    return 'nature';
  }
  if (any(['hotel', 'resort', 'hostel', 'inn', 'homestay', 'villa'])) {
    return 'stay';
  }
  if (any(['fort', 'temple', 'church', 'museum', 'palace', 'mosque'])) {
    return 'sight';
  }
  if (any(['mall', 'market', 'store', 'shop', 'bazaar'])) return 'shop';
  if (any(['airport', 'station', 'terminal', 'bus stand'])) return 'transit';
  return null;
}

/// A trip with its people, visits and money, ready for the screens.
class TripView {
  const TripView({
    required this.trip,
    required this.people,
    required this.visits,
    required this.expenses,
    required this.shares,
  });
  final TripRow trip;
  final List<TripPersonRow> people;
  final List<VisitRow> visits;
  final List<TripExpenseRow> expenses;
  final List<TripShareRow> shares;

  String get id => trip.id;
  TripPersonRow? get me => people.where((p) => p.isMe).firstOrNull;
  String nameOf(String? personId) => personId == null
      ? 'Someone'
      : people.where((p) => p.id == personId).firstOrNull?.name ?? 'Someone';

  /// Real spending (pay-backs excluded).
  double get total => expenses
      .where((e) => e.kind == 'expense')
      .fold(0, (sum, e) => sum + e.amount);

  /// Your part of the real spending.
  double get myShare {
    final ids = {
      for (final e in expenses)
        if (e.kind == 'expense') e.id,
    };
    return shares
        .where((s) => s.personId == me?.id && ids.contains(s.expenseId))
        .fold(0, (sum, s) => sum + s.amount);
  }

  Map<String, double> get balances => tripBalances(expenses, shares);
  List<Settlement> get settlements => settleUp(balances);

  /// What you owe (positive) or are owed (negative), net.
  double get myNet => -(balances[me?.id] ?? 0);

  /// True between the start and end day (inclusive), or from the start day
  /// on for a trip with no end.
  bool isLive(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final s = trip.startDay;
    final e = trip.endDay;
    if (s == null) return false;
    if (today.isBefore(s)) return false;
    return e == null || !today.isAfter(e);
  }

  /// "Day 2 of 4", "Day 3", or null when the trip isn't on.
  String? dayLabel(DateTime now) {
    if (!isLive(now)) return null;
    final today = DateTime.utc(now.year, now.month, now.day);
    final s = trip.startDay!;
    final day = today.difference(DateTime.utc(s.year, s.month, s.day)).inDays;
    final e = trip.endDay;
    if (e == null) return 'Day ${day + 1}';
    final len =
        DateTime.utc(
          e.year,
          e.month,
          e.day,
        ).difference(DateTime.utc(s.year, s.month, s.day)).inDays +
        1;
    return 'Day ${day + 1} of $len';
  }
}

/// A visit Home should ask about: add the bill, photos or a note.
class VisitPrompt {
  const VisitPrompt(this.visit, {required this.hasBill, required this.photos});
  final VisitRow visit;
  final bool hasBill;
  final int photos;
}

/// The one write path for Travel (CLAUDE.md §7).
class TravelService {
  TravelService(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

  // ── Reads ──────────────────────────────────────────────────────────────

  /// Re-emits whenever any travel table changes.
  Stream<void> changes() => db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          db.tripTable,
          db.tripPersonTable,
          db.visitTable,
          db.tripExpenseTable,
          db.tripShareTable,
          db.visitPhotoTable,
        },
      )
      .watch()
      .map((_) {});

  Future<List<TripView>> trips() async {
    final rows =
        await (db.select(db.tripTable)
              ..where((t) => t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.startDay)]))
            .get();
    return [for (final t in rows) await _view(t)];
  }

  Future<TripView?> trip(String id) async {
    final t = await (db.select(
      db.tripTable,
    )..where((r) => r.id.equals(id) & r.deletedAt.isNull())).getSingleOrNull();
    return t == null ? null : _view(t);
  }

  Future<TripView> _view(TripRow t) async {
    final people =
        await (db.select(db.tripPersonTable)
              ..where((p) => p.tripId.equals(t.id) & p.deletedAt.isNull())
              ..orderBy([
                (p) => OrderingTerm.desc(p.isMe),
                (p) => OrderingTerm.asc(p.createdAt),
              ]))
            .get();
    final visits =
        await (db.select(db.visitTable)
              ..where((v) => v.tripId.equals(t.id) & v.deletedAt.isNull())
              ..orderBy([(v) => OrderingTerm.asc(v.at)]))
            .get();
    final expenses =
        await (db.select(db.tripExpenseTable)
              ..where((e) => e.tripId.equals(t.id) & e.deletedAt.isNull())
              ..orderBy([(e) => OrderingTerm.desc(e.at)]))
            .get();
    final ids = expenses.map((e) => e.id).toList();
    final shares = ids.isEmpty
        ? <TripShareRow>[]
        : await (db.select(
            db.tripShareTable,
          )..where((s) => s.expenseId.isIn(ids) & s.deletedAt.isNull())).get();
    return TripView(
      trip: t,
      people: people,
      visits: visits,
      expenses: expenses,
      shares: shares,
    );
  }

  /// The trip happening now, if any.
  Future<TripView?> liveTrip() async {
    final now = clock();
    for (final t in await trips()) {
      if (t.isLive(now)) return t;
    }
    return null;
  }

  /// Every visit, newest first.
  Future<List<VisitRow>> visits({int? limit}) {
    final q = db.select(db.visitTable)
      ..where((v) => v.deletedAt.isNull())
      ..orderBy([(v) => OrderingTerm.desc(v.at)]);
    if (limit != null) q.limit(limit);
    return q.get();
  }

  Future<VisitRow?> visit(String id) => (db.select(
    db.visitTable,
  )..where((v) => v.id.equals(id) & v.deletedAt.isNull())).getSingleOrNull();

  Future<List<VisitPhotoRow>> photos({String? visitId, String? tripId}) async {
    final q = db.select(db.visitPhotoTable)
      ..where((p) => p.deletedAt.isNull())
      ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]);
    final all = await q.get();
    if (visitId != null) return all.where((p) => p.visitId == visitId).toList();
    if (tripId != null) {
      final ids = (await (db.select(
        db.visitTable,
      )..where((v) => v.tripId.equals(tripId))).get()).map((v) => v.id).toSet();
      return all.where((p) => ids.contains(p.visitId)).toList();
    }
    return all;
  }

  /// Bills attached to a visit (trip or personal).
  Future<List<TripExpenseRow>> billsFor(String visitId) => (db.select(
    db.tripExpenseTable,
  )..where((e) => e.visitId.equals(visitId) & e.deletedAt.isNull())).get();

  /// Visits from the last 3 days that Home should ask about, newest first.
  Future<List<VisitPrompt>> prompts() async {
    final since = clock().subtract(const Duration(days: 3));
    final recent =
        await (db.select(db.visitTable)
              ..where(
                (v) =>
                    v.deletedAt.isNull() &
                    v.settled.equals(false) &
                    v.at.isBiggerOrEqualValue(since),
              )
              ..orderBy([(v) => OrderingTerm.desc(v.at)]))
            .get();
    final out = <VisitPrompt>[];
    for (final v in recent) {
      final bills = await billsFor(v.id);
      final photos = await this.photos(visitId: v.id);
      if (bills.isNotEmpty && photos.isNotEmpty) continue;
      out.add(VisitPrompt(v, hasBill: bills.isNotEmpty, photos: photos.length));
    }
    return out;
  }

  // ── Trips and people ───────────────────────────────────────────────────

  /// Makes a trip. Only [name] is needed; you are added automatically.
  Future<String> createTrip({
    required String name,
    DateTime? start,
    DateTime? end,
    List<String> people = const [],
  }) async {
    final n = _clean(name, 'Give the trip a name.');
    if (start != null && end != null && end.isBefore(start)) {
      throw ArgumentError('The trip ends before it starts.');
    }
    final now = clock();
    final id = newUuid();
    await db.transaction(() async {
      await db
          .into(db.tripTable)
          .insert(
            TripTableCompanion.insert(
              id: id,
              name: n,
              startDay: Value(start == null ? _day(now) : _day(start)),
              endDay: Value(end == null ? null : _day(end)),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _insertPerson(id, 'You', isMe: true);
      for (final p in people) {
        if (p.trim().isNotEmpty) await _insertPerson(id, p);
      }
    });
    return id;
  }

  Future<void> editTrip(
    String id, {
    String? name,
    Value<DateTime?> start = const Value.absent(),
    Value<DateTime?> end = const Value.absent(),
  }) => (db.update(db.tripTable)..where((t) => t.id.equals(id))).write(
    TripTableCompanion(
      name: name == null
          ? const Value.absent()
          : Value(_clean(name, 'Give the trip a name.')),
      startDay: start.present
          ? Value(start.value == null ? null : _day(start.value!))
          : const Value.absent(),
      endDay: end.present
          ? Value(end.value == null ? null : _day(end.value!))
          : const Value.absent(),
      updatedAt: Value(clock()),
    ),
  );

  /// Soft-deletes a trip. Its visits stay as everyday visits; its bills go.
  Future<DateTime> deleteTrip(String id) async {
    final now = clock();
    await db.transaction(() async {
      await (db.update(db.tripTable)..where((t) => t.id.equals(id))).write(
        TripTableCompanion(updatedAt: Value(now), deletedAt: Value(now)),
      );
      await (db.update(
        db.tripExpenseTable,
      )..where((e) => e.tripId.equals(id) & e.deletedAt.isNull())).write(
        TripExpenseTableCompanion(updatedAt: Value(now), deletedAt: Value(now)),
      );
      await (db.update(db.visitTable)..where((v) => v.tripId.equals(id))).write(
        VisitTableCompanion(tripId: const Value(null), updatedAt: Value(now)),
      );
    });
    return now;
  }

  Future<String> addPerson(String tripId, String name) =>
      _insertPerson(tripId, name);

  Future<String> _insertPerson(
    String tripId,
    String name, {
    bool isMe = false,
  }) async {
    final now = clock();
    final id = newUuid();
    await db
        .into(db.tripPersonTable)
        .insert(
          TripPersonTableCompanion.insert(
            id: id,
            tripId: tripId,
            name: _clean(name, 'Add a name.'),
            isMe: Value(isMe),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Removes a person who isn't in any bill yet.
  Future<void> removePerson(String personId) async {
    final paid = await (db.select(
      db.tripExpenseTable,
    )..where((e) => e.paidBy.equals(personId) & e.deletedAt.isNull())).get();
    final shared = await (db.select(
      db.tripShareTable,
    )..where((s) => s.personId.equals(personId) & s.deletedAt.isNull())).get();
    if (paid.isNotEmpty || shared.isNotEmpty) {
      throw ArgumentError('They are part of a bill. Remove those bills first.');
    }
    final now = clock();
    await (db.update(
      db.tripPersonTable,
    )..where((p) => p.id.equals(personId))).write(
      TripPersonTableCompanion(updatedAt: Value(now), deletedAt: Value(now)),
    );
  }

  // ── Visits ─────────────────────────────────────────────────────────────

  /// Saves a visit. [tripId] defaults to the live trip.
  Future<String> addVisit({
    required String name,
    String? area,
    LocationFix? fix,
    DateTime? at,
    String? kind,
    String? weather,
    bool named = true,
    Value<String?> tripId = const Value.absent(),
  }) async {
    final now = clock();
    final id = newUuid();
    final trip = tripId.present ? tripId.value : (await liveTrip())?.id;
    await db
        .into(db.visitTable)
        .insert(
          VisitTableCompanion.insert(
            id: id,
            tripId: Value(trip),
            name: _clean(name, 'Name this place.'),
            area: Value(area),
            lat: Value(fix?.lat),
            lon: Value(fix?.lon),
            at: at ?? now,
            kind: Value(kind ?? guessPlaceKind(name)),
            weather: Value(weather),
            named: Value(named),
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> editVisit(
    String id, {
    String? name,
    Value<String?> area = const Value.absent(),
    Value<String?> note = const Value.absent(),
    Value<int?> rating = const Value.absent(),
    Value<String?> tripId = const Value.absent(),
    Value<String?> kind = const Value.absent(),
  }) => (db.update(db.visitTable)..where((v) => v.id.equals(id))).write(
    VisitTableCompanion(
      name: name == null
          ? const Value.absent()
          : Value(_clean(name, 'Name this place.')),
      named: name == null ? const Value.absent() : const Value(true),
      area: area,
      note: note,
      rating: rating,
      tripId: tripId,
      kind: kind,
      updatedAt: Value(clock()),
    ),
  );

  /// Home stops asking about this visit.
  Future<void> settleVisit(String id, {bool settled = true}) =>
      (db.update(db.visitTable)..where((v) => v.id.equals(id))).write(
        VisitTableCompanion(settled: Value(settled), updatedAt: Value(clock())),
      );

  /// Soft-deletes a visit with its bills and photos (Undo: [restoreVisit]).
  Future<DateTime> deleteVisit(String id) async {
    final now = clock();
    final gone = VisitTableCompanion(
      updatedAt: Value(now),
      deletedAt: Value(now),
    );
    await db.transaction(() async {
      await (db.update(
        db.visitTable,
      )..where((v) => v.id.equals(id))).write(gone);
      await (db.update(
        db.tripExpenseTable,
      )..where((e) => e.visitId.equals(id) & e.deletedAt.isNull())).write(
        TripExpenseTableCompanion(updatedAt: Value(now), deletedAt: Value(now)),
      );
      await (db.update(
        db.visitPhotoTable,
      )..where((p) => p.visitId.equals(id) & p.deletedAt.isNull())).write(
        VisitPhotoTableCompanion(updatedAt: Value(now), deletedAt: Value(now)),
      );
    });
    return now;
  }

  Future<void> restoreVisit(String id, DateTime deletedAt) async {
    final now = clock();
    await db.transaction(() async {
      await (db.update(db.visitTable)..where((v) => v.id.equals(id))).write(
        VisitTableCompanion(
          updatedAt: Value(now),
          deletedAt: const Value(null),
        ),
      );
      await (db.update(
            db.tripExpenseTable,
          )..where((e) => e.visitId.equals(id) & e.deletedAt.equals(deletedAt)))
          .write(
            TripExpenseTableCompanion(
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
          );
      await (db.update(
            db.visitPhotoTable,
          )..where((p) => p.visitId.equals(id) & p.deletedAt.equals(deletedAt)))
          .write(
            VisitPhotoTableCompanion(
              updatedAt: Value(now),
              deletedAt: const Value(null),
            ),
          );
    });
  }

  /// Names visits that were captured offline, once a name is available.
  Future<List<VisitRow>> unnamedVisits() => (db.select(
    db.visitTable,
  )..where((v) => v.named.equals(false) & v.deletedAt.isNull())).get();

  // ── Bills ──────────────────────────────────────────────────────────────

  /// Adds a bill split equally between [sharedWith] (everyone on the trip
  /// by default). Without a trip it is simply yours.
  Future<String> addBill({
    String? tripId,
    String? visitId,
    required String title,
    required double amount,
    String? paidBy,
    List<String>? sharedWith,
    DateTime? at,
  }) async {
    if (!amount.isFinite || amount <= 0 || amount > 100000000) {
      throw ArgumentError('Enter an amount above zero.');
    }
    final t = _clean(title, 'What was it for?');
    final now = clock();
    final id = newUuid();
    await db.transaction(() async {
      List<String> members = const [];
      String? payer = paidBy;
      if (tripId != null) {
        final view = await trip(tripId);
        if (view == null) throw ArgumentError('This trip no longer exists.');
        final ids = view.people.map((p) => p.id).toSet();
        members = (sharedWith ?? ids.toList()).where(ids.contains).toList();
        if (members.isEmpty) {
          throw ArgumentError('Choose who shares this bill.');
        }
        payer ??= view.me?.id;
        if (payer == null || !ids.contains(payer)) {
          throw ArgumentError('Choose who paid.');
        }
      }
      await db
          .into(db.tripExpenseTable)
          .insert(
            TripExpenseTableCompanion.insert(
              id: id,
              tripId: Value(tripId),
              visitId: Value(visitId),
              title: t,
              amount: _round2(amount),
              paidBy: Value(payer),
              at: at ?? now,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final parts = splitEqually(amount, members.length);
      for (var i = 0; i < members.length; i++) {
        await db
            .into(db.tripShareTable)
            .insert(
              TripShareTableCompanion.insert(
                id: newUuid(),
                expenseId: id,
                personId: members[i],
                amount: parts[i],
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
    return id;
  }

  Future<void> deleteBill(String id, {bool undo = false}) {
    final now = clock();
    return (db.update(
      db.tripExpenseTable,
    )..where((e) => e.id.equals(id))).write(
      TripExpenseTableCompanion(
        updatedAt: Value(now),
        deletedAt: Value(undo ? null : now),
      ),
    );
  }

  /// Records the settle-up payments so every balance returns to zero.
  /// Returns the ids of the pay-back rows (for Undo).
  Future<List<String>> markSettled(String tripId) async {
    final view = await trip(tripId);
    if (view == null) return const [];
    final ids = <String>[];
    final now = clock();
    await db.transaction(() async {
      for (final s in view.settlements) {
        final id = newUuid();
        ids.add(id);
        await db
            .into(db.tripExpenseTable)
            .insert(
              TripExpenseTableCompanion.insert(
                id: id,
                tripId: Value(tripId),
                title: '${view.nameOf(s.from)} paid ${view.nameOf(s.to)}',
                amount: s.amount,
                paidBy: Value(s.from),
                kind: const Value('settlement'),
                at: now,
                createdAt: now,
                updatedAt: now,
              ),
            );
        await db
            .into(db.tripShareTable)
            .insert(
              TripShareTableCompanion.insert(
                id: newUuid(),
                expenseId: id,
                personId: s.to,
                amount: s.amount,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
    return ids;
  }

  // ── Photos ─────────────────────────────────────────────────────────────

  /// Attaches photos already copied into the app's folder.
  Future<void> addPhotos(String visitId, List<String> paths) async {
    final now = clock();
    await db.batch((b) {
      for (final p in paths) {
        b.insert(
          db.visitPhotoTable,
          VisitPhotoTableCompanion.insert(
            id: newUuid(),
            visitId: visitId,
            path: p,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });
  }

  Future<void> removePhoto(String id) {
    final now = clock();
    return (db.update(db.visitPhotoTable)..where((p) => p.id.equals(id))).write(
      VisitPhotoTableCompanion(updatedAt: Value(now), deletedAt: Value(now)),
    );
  }

  static String _clean(String v, String error) {
    final t = v.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty || t.length > 120) throw ArgumentError(error);
    return t[0].toUpperCase() + t.substring(1);
  }
}
