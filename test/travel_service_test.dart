import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/travel/travel_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('money maths', () {
    test('equal split always adds up', () {
      expect(splitEqually(100, 3), [33.34, 33.33, 33.33]);
      expect(splitEqually(100, 3).reduce((a, b) => a + b), closeTo(100, 1e-9));
      expect(splitEqually(1200, 4), [300, 300, 300, 300]);
      expect(splitEqually(10, 0), isEmpty);
    });

    test('settle up uses the fewest payments', () {
      // A paid 900 for A, B, C; C paid 300 for A, B, C.
      final s = settleUp({'A': 500, 'B': -400, 'C': -100});
      expect(s.map((x) => x.toString()), ['B→A 400.00', 'C→A 100.00']);
      expect(settleUp({'A': 0, 'B': 0}), isEmpty);
      final many = settleUp({'A': 50, 'B': 50, 'C': -60, 'D': -40});
      expect(many.fold<double>(0, (sum, x) => sum + x.amount), 100);
      expect(many.length, lessThanOrEqualTo(3));
    });

    test('place kinds from names', () {
      expect(guessPlaceKind('Thalassa Restaurant'), 'food');
      expect(guessPlaceKind('Baga Beach'), 'nature');
      expect(guessPlaceKind('Fort Aguada'), 'sight');
      expect(guessPlaceKind('Taj Resort'), 'stay');
      expect(guessPlaceKind('Somewhere'), isNull);
    });
  });

  group('service', () {
    late AppDatabase db;
    var now = DateTime(2026, 12, 13, 20);
    late TravelService travel;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      now = DateTime(2026, 12, 13, 20);
      travel = TravelService(db, clock: () => now);
    });
    tearDown(() => db.close());

    test('a trip needs only a name and adds you', () async {
      final id = await travel.createTrip(
        name: 'goa',
        start: DateTime(2026, 12, 12),
        end: DateTime(2026, 12, 15),
        people: ['Ravi', 'Neha', ' '],
      );
      final t = (await travel.trip(id))!;
      expect(t.trip.name, 'Goa');
      expect(t.people.map((p) => p.name), ['You', 'Ravi', 'Neha']);
      expect(t.me!.name, 'You');
      expect(t.isLive(now), isTrue);
      expect(t.dayLabel(now), 'Day 2 of 4');
      expect(() => travel.createTrip(name: ''), throwsArgumentError);
    });

    test('visits join the live trip; everyday visits stay alone', () async {
      final id = await travel.createTrip(
        name: 'Goa',
        start: DateTime(2026, 12, 12),
        end: DateTime(2026, 12, 15),
      );
      final v = await travel.addVisit(
        name: 'Thalassa',
        fix: const LocationFix(15.6, 73.7),
      );
      expect((await travel.visit(v))!.tripId, id);
      expect((await travel.visit(v))!.kind, isNull);
      now = DateTime(2026, 12, 20);
      final cafe = await travel.addVisit(name: 'Blue cafe');
      expect((await travel.visit(cafe))!.tripId, isNull);
      expect((await travel.visit(cafe))!.kind, 'food');
    });

    test('bills split, balance and settle to zero', () async {
      final id = await travel.createTrip(name: 'Goa', people: ['Ravi', 'Neha']);
      final t = (await travel.trip(id))!;
      final me = t.me!.id;
      final ravi = t.people[1].id;
      final neha = t.people[2].id;
      await travel.addBill(
        tripId: id,
        title: 'Hotel',
        amount: 9000,
        paidBy: ravi,
      );
      await travel.addBill(tripId: id, title: 'Lunch', amount: 1200);
      await travel.addBill(
        tripId: id,
        title: 'Scooter',
        amount: 600,
        paidBy: neha,
        sharedWith: [neha, me],
      );
      var view = (await travel.trip(id))!;
      expect(view.total, 10800);
      expect(view.myShare, 3000 + 400 + 300);
      // You paid 1200, your share 3700: you owe 2500 net.
      expect(view.myNet, 2500);
      expect(
        view.balances.values.fold<double>(0, (a, b) => a + b),
        closeTo(0, 0.01),
      );
      await travel.markSettled(id);
      view = (await travel.trip(id))!;
      expect(view.settlements, isEmpty);
      expect(view.total, 10800, reason: 'pay-backs are not spending');
    });

    test('bills need a sensible amount and payer', () async {
      final id = await travel.createTrip(name: 'Goa');
      expect(
        () => travel.addBill(tripId: id, title: 'X', amount: 0),
        throwsArgumentError,
      );
      expect(
        () => travel.addBill(tripId: id, title: 'X', amount: 5, paidBy: 'z'),
        throwsArgumentError,
      );
      // A personal bill with no trip is fine.
      await travel.addBill(title: 'Coffee', amount: 180);
    });

    test('Home asks about recent visits until answered', () async {
      final v = await travel.addVisit(name: 'Thalassa');
      var prompts = await travel.prompts();
      expect(prompts.single.visit.id, v);
      expect(prompts.single.hasBill, isFalse);
      await travel.addBill(visitId: v, title: 'Dinner', amount: 2400);
      await travel.addPhotos(v, ['/a.jpg']);
      expect(await travel.prompts(), isEmpty, reason: 'bill and photos done');
      final old = await travel.addVisit(
        name: 'Fort',
        at: now.subtract(const Duration(days: 5)),
      );
      expect((await travel.prompts()).map((p) => p.visit.id), isNot([old]));
      final skip = await travel.addVisit(name: 'Beach');
      await travel.settleVisit(skip);
      expect(await travel.prompts(), isEmpty);
    });

    test(
      'deleting a visit takes its bills and photos; Undo brings them back',
      () async {
        final v = await travel.addVisit(name: 'Thalassa');
        await travel.addBill(visitId: v, title: 'Dinner', amount: 2400);
        await travel.addPhotos(v, ['/a.jpg', '/b.jpg']);
        final at = await travel.deleteVisit(v);
        expect(await travel.visit(v), isNull);
        expect(await travel.billsFor(v), isEmpty);
        expect(await travel.photos(visitId: v), isEmpty);
        await travel.restoreVisit(v, at);
        expect(await travel.billsFor(v), hasLength(1));
        expect(await travel.photos(visitId: v), hasLength(2));
      },
    );

    test('a person in a bill cannot be removed', () async {
      final id = await travel.createTrip(name: 'Goa', people: ['Ravi']);
      final ravi = (await travel.trip(id))!.people[1].id;
      await travel.addBill(tripId: id, title: 'Hotel', amount: 100);
      final extra = await travel.addPerson(id, 'Amit');
      expect(() => travel.removePerson(ravi), throwsArgumentError);
      await travel.removePerson(extra);
      expect((await travel.trip(id))!.people, hasLength(2));
    });

    test('deleting a trip keeps its visits as everyday visits', () async {
      final id = await travel.createTrip(name: 'Goa');
      final v = await travel.addVisit(name: 'Beach', tripId: Value(id));
      await travel.deleteTrip(id);
      expect(await travel.trip(id), isNull);
      expect((await travel.visit(v))!.tripId, isNull);
    });

    test('100 visits and bills load', () async {
      final id = await travel.createTrip(name: 'Long trip', people: ['A']);
      for (var i = 0; i < 100; i++) {
        await travel.addVisit(name: 'Place $i', tripId: Value(id));
        await travel.addBill(tripId: id, title: 'Bill $i', amount: 10);
      }
      final t = (await travel.trip(id))!;
      expect(t.visits, hasLength(100));
      expect(t.total, 1000);
    });
  });
}
