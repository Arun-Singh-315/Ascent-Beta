import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/travel/here_locator.dart';
import 'package:ascent/core/travel/travel_providers.dart';
import 'package:ascent/core/travel/travel_service.dart';
import 'package:ascent/features/travel/bill_sheet.dart';
import 'package:ascent/features/travel/home_travel_card.dart';
import 'package:ascent/features/travel/travel_screen.dart';
import 'package:ascent/features/travel/trip_screen.dart';
import 'package:ascent/features/travel/visit_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHere implements HereLocator {
  _FakeHere(this.result);
  HereResult result;
  @override
  Future<HereResult> locate() async => result;
  @override
  Future<List<PlaceGuess>> name(LocationFix fix) async => result.guesses;
}

const _found = HereResult(
  fix: LocationFix(15.6, 73.73),
  guesses: [
    PlaceGuess('Thalassa', area: 'Small Vagator, Goa', kind: 'food'),
    PlaceGuess('Small Vagator', area: 'Goa'),
  ],
  weather: '27°, clear sky',
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  test('place guesses skip codes and numbers and de-duplicate', () {
    final g = placeGuessesFrom([
      (
        name: '7QJ2+4V',
        street: 'Vagator Beach Rd',
        subLocality: 'Small Vagator',
        locality: 'Anjuna',
        area: 'Goa',
      ),
      (
        name: 'Thalassa',
        street: '12',
        subLocality: 'Small Vagator',
        locality: 'Anjuna',
        area: 'Goa',
      ),
    ]);
    expect(g.map((x) => x.name), [
      'Small Vagator',
      'Vagator Beach Rd',
      'Thalassa',
    ]);
    expect(g.first.area, 'Anjuna');
    expect(g.last.area, 'Small Vagator, Anjuna');
  });

  late AppDatabase db;
  late ProviderContainer container;
  late TravelService travel;
  late _FakeHere here;
  var ready = false;

  Future<void> setUpWith({bool travelOn = true}) async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      unlockedFeaturesKey: [
        AscentFeature.things.name,
        if (travelOn) AscentFeature.travel.name,
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    here = _FakeHere(_found);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        hereLocatorProvider.overrideWithValue(here),
      ],
    );
    travel = TravelService(db);
    ready = true;
  }

  Future<void> tearDownAll(WidgetTester t) async {
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  }

  tearDown(() async {
    if (!ready) return;
    ready = false;
    container.dispose();
    await db.close();
  });

  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  Widget app(Widget home, {bool dark = false, double scale = 1}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, c) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: c!,
          ),
          home: home,
        ),
      );

  Widget opener(void Function(BuildContext) open) => Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => open(context),
          child: const Text('go'),
        ),
      ),
    ),
  );

  testWidgets("I'm here fills in the place, time, weather and options", (
    t,
  ) async {
    await setUpWith();
    await t.pumpWidget(app(opener(showHereSheet)));
    await t.tap(find.text('go'));
    await flush(t);
    expect(find.byKey(const ValueKey('visit_name')), findsOneWidget);
    expect(find.text('Thalassa'), findsOneWidget);
    expect(find.text('Small Vagator, Goa'), findsOneWidget);
    expect(find.text('27°, clear sky'), findsOneWidget);
    final saved = (await t.runAsync(() => travel.visits()))!.single;
    expect(saved.lat, 15.6);
    expect(saved.kind, 'food');
    // Not the right place: one tap picks another.
    await t.tap(find.byKey(const ValueKey('visit_guess_Small Vagator')));
    await flush(t);
    expect(
      (await t.runAsync(() => travel.visit(saved.id)))!.name,
      'Small Vagator',
    );
    await tearDownAll(t);
  });

  testWidgets('without location permission you type the place', (t) async {
    await setUpWith();
    here.result = const HereResult(problem: HereProblem.permissionDenied);
    await t.pumpWidget(app(opener(showHereSheet)));
    await t.tap(find.text('go'));
    await flush(t);
    expect(find.text('Where are you?'), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('visit_manual_name')),
      'baga beach',
    );
    await t.tap(find.byKey(const ValueKey('visit_manual_save')));
    await flush(t);
    expect(
      (await t.runAsync(() => travel.visits()))!.single.name,
      'Baga beach',
    );
    expect(find.byKey(const ValueKey('visit_add_bill')), findsOneWidget);
    await tearDownAll(t);
  });

  testWidgets('a trip bill: who paid and who shares it', (t) async {
    await setUpWith();
    final id = (await t.runAsync(
      () => travel.createTrip(name: 'Goa', people: ['Ravi', 'Neha']),
    ))!;
    await t.pumpWidget(
      app(opener((c) => showBillSheet(c, tripId: id, title: 'Dinner'))),
    );
    await t.tap(find.text('go'));
    await flush(t);
    await t.enterText(find.byKey(const ValueKey('bill_amount')), '1500');
    await t.tap(find.byKey(const ValueKey('bill_payer_Ravi')));
    await t.tap(find.byKey(const ValueKey('bill_share_Neha')));
    await t.pump();
    expect(find.text('₹750 each, split 2 ways.'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('bill_save')));
    await flush(t);
    expect(find.byType(BillSheet), findsNothing);
    final trip = (await t.runAsync(() => travel.trip(id)))!;
    expect(trip.total, 1500);
    expect(trip.nameOf(trip.expenses.single.paidBy), 'Ravi');
    expect(trip.myNet, 750);
    await tearDownAll(t);
  });

  testWidgets('trip Money shows who pays whom and settles', (t) async {
    await setUpWith();
    final id = (await t.runAsync(() async {
      final id = await travel.createTrip(name: 'Goa', people: ['Ravi']);
      final ravi = (await travel.trip(id))!.people[1].id;
      await travel.addBill(
        tripId: id,
        title: 'Hotel',
        amount: 4000,
        paidBy: ravi,
      );
      return id;
    }))!;
    await t.pumpWidget(app(TripScreen(id: id, tab: TripTab.money)));
    await flush(t);
    expect(find.text('You pay Ravi'), findsOneWidget);
    expect(find.text('₹2,000'), findsWidgets);
    await t.ensureVisible(find.byKey(const ValueKey('trip_settle')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('trip_settle')));
    await flush(t);
    expect(find.text('Everyone is even.'), findsOneWidget);
    await tearDownAll(t);
  });

  testWidgets('trip Plan groups places by day', (t) async {
    await setUpWith();
    final id = (await t.runAsync(() async {
      final id = await travel.createTrip(name: 'Goa');
      await travel.addVisit(name: 'Fort Aguada');
      await travel.addVisit(name: 'Thalassa');
      return id;
    }))!;
    await t.pumpWidget(app(TripScreen(id: id)));
    await flush(t);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Fort Aguada'), findsOneWidget);
    expect(find.text('Thalassa'), findsOneWidget);
    await tearDownAll(t);
  });

  testWidgets('Travel starts with an invitation, then lists trips and places', (
    t,
  ) async {
    await setUpWith(travelOn: false);
    await t.pumpWidget(app(const TravelScreen()));
    await flush(t);
    expect(find.text('Remember where you’ve been'), findsOneWidget);
    expect(
      container.read(unlockedFeaturesProvider),
      contains(AscentFeature.travel),
      reason: 'opening Travel switches it on',
    );
    // Write from the test's own clock, like the screen's queries.
    travel
        .createTrip(name: 'Goa')
        .then((_) => travel.addVisit(name: 'Baga beach'));
    await flush(t);
    await flush(t);
    expect(find.text('Trips'), findsOneWidget);
    expect(find.text('Places'), findsOneWidget);
    expect(find.byKey(const ValueKey('travel_here')), findsOneWidget);
    await tearDownAll(t);
  });

  testWidgets('Home card: hidden until a visit waits, then asks once', (
    t,
  ) async {
    await setUpWith();
    await t.pumpWidget(app(const Scaffold(body: HomeTravelCard())));
    await flush(t);
    expect(find.byKey(const ValueKey('home_travel_card')), findsNothing);
    late String v;
    travel.addVisit(name: 'Thalassa').then((id) => v = id);
    await flush(t);
    await flush(t);
    expect(find.text('Any bill to add?'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('prompt_skip')));
    await flush(t);
    expect((await t.runAsync(() => travel.visit(v)))!.settled, isTrue);
    expect(find.byKey(const ValueKey('home_travel_card')), findsNothing);
    await tearDownAll(t);
  });

  testWidgets('Home card stays away when Travel is off', (t) async {
    await setUpWith(travelOn: false);
    await t.runAsync(() => travel.addVisit(name: 'Thalassa'));
    await t.pumpWidget(app(const Scaffold(body: HomeTravelCard())));
    await flush(t);
    expect(find.byKey(const ValueKey('home_travel_card')), findsNothing);
    await tearDownAll(t);
  });

  for (final dark in [false, true]) {
    testWidgets('fits 320 px at text scale 2 (${dark ? 'dark' : 'light'})', (
      t,
    ) async {
      await setUpWith();
      t.view.physicalSize = const Size(320, 1600);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final id = (await t.runAsync(() async {
        final id = await travel.createTrip(
          name: 'A long weekend in North Goa',
          people: ['Ravi', 'Neha', 'Amit'],
        );
        final v = await travel.addVisit(
          name: 'Thalassa Greek taverna by the cliff',
          area: 'Small Vagator, Anjuna, North Goa',
        );
        await travel.addBill(
          tripId: id,
          visitId: v,
          title: 'Dinner',
          amount: 4321.5,
        );
        return id;
      }))!;
      await t.pumpWidget(
        app(
          TripScreen(id: id, tab: TripTab.money),
          dark: dark,
          scale: 2,
        ),
      );
      await flush(t);
      expect(t.takeException(), isNull);
      await t.pumpWidget(app(const TravelScreen(), dark: dark, scale: 2));
      await flush(t);
      expect(t.takeException(), isNull);
      await tearDownAll(t);
    });
  }
}
