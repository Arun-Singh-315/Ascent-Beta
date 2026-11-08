import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_first_moment.dart';
import 'package:ascent/features/home/widgets/home_life_shelf.dart';
import 'package:ascent/features/home/widgets/home_theme.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'ascent_first_moment_pending_v1': true,
    });
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Widget app(Widget child, {bool dark = false, double scale = 1}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: HomeTheme.from(
            dark ? AscentTheme.dark() : AscentTheme.light(),
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      );
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
    }
  }

  for (final thought in [false, true]) {
    testWidgets(
      'First ${thought ? 'thought' : 'task'} captures exactly one real record',
      (tester) async {
        await tester.pumpWidget(app(const HomeFirstMoment()));
        await settle(tester);
        expect(container.read(firstMomentPendingProvider), isTrue);
        expect(
          await tester.runAsync(() => db.select(db.taskTable).get()),
          isEmpty,
        );
        expect(
          await tester.runAsync(() => db.thoughtDao.watchAllThoughts().first),
          isEmpty,
        );
        if (thought) {
          await tester.tap(find.text('Thought'));
          await tester.pump();
        }
        await tester.enterText(
          find.byKey(const ValueKey('first_moment_input')),
          'Make room for a walk',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('first_moment_send')));
        await settle(tester);
        expect(container.read(firstMomentPendingProvider), isFalse);
        final tasks = await tester.runAsync(
          () => db.select(db.taskTable).get(),
        );
        final notes = await tester.runAsync(
          () => db.thoughtDao.watchAllThoughts().first,
        );
        expect(tasks!.length, thought ? 0 : 1);
        expect(notes!.length, thought ? 1 : 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('Explore first saves no sample records', (tester) async {
    await tester.pumpWidget(app(const HomeFirstMoment()));
    await settle(tester);
    await tester.tap(find.text('Explore first'));
    await settle(tester);
    expect(container.read(firstMomentPendingProvider), isFalse);
    expect(await tester.runAsync(() => db.select(db.taskTable).get()), isEmpty);
    expect(
      await tester.runAsync(() => db.thoughtDao.watchAllThoughts().first),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Water details log only the selected amount, then show actual progress',
    (tester) async {
      await tester.pumpWidget(app(const HomeLifeShelf()));
      await settle(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('0 ml'), findsOneWidget);
      expect(find.text('0.00 km'), findsOneWidget);
      expect(find.text('No doses scheduled'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home_routine_hydration')));
      await settle(tester);
      await tester.ensureVisible(find.text('500 ml'));
      await tester.tap(find.text('500 ml'));
      await tester.pump();
      await tester.ensureVisible(find.text('Log water'));
      await tester.tap(find.text('Log water'));
      await settle(tester);
      expect(
        await tester.runAsync(() => db.waterDao.watchTodayWaterMl().first),
        500,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const ValueKey('rhythm_summary_hydration')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('rhythm_summary_hydration')),
            )
            .data,
        '500 ml',
      );
      final shelf = tester.getRect(
        find.byKey(const ValueKey('home_life_shelf')),
      );
      final waterCard = tester.getRect(
        find.byKey(const ValueKey('rhythm_card_hydration')),
      );
      expect(waterCard.width, shelf.width);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('rhythm_card_hydration')),
          matching: find.byKey(const ValueKey('rhythm_detail_hydration')),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(await tester.runAsync(() => db.waterDao.watchTodayWaterMl().first), 0);
      final move = find.byKey(const ValueKey('home_routine_walk'));
      await tester.ensureVisible(move);
      await tester.tap(move);
      await settle(tester);
      expect(
        find.byKey(const ValueKey('rhythm_detail_hydration')),
        findsNothing,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('rhythm_card_walk'))).width,
        shelf.width,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('rhythm_card_hydration')))
            .width,
        lessThan(shelf.width),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Daily rhythm has no nested scroll and expands one panel in both themes and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        for (final scale in [1.0, 2.0]) {
          tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
          await tester.pumpWidget(
            app(const HomeLifeShelf(), dark: dark, scale: scale),
          );
          await settle(tester);
          expect(
            find.descendant(
              of: find.byType(HomeLifeShelf),
              matching: find.byType(Scrollable),
            ),
            findsNothing,
          );
          final water = find.byKey(const ValueKey('home_routine_hydration'));
          await tester.ensureVisible(water);
          await tester.tap(water);
          await settle(tester);
          final panel = find.byKey(const ValueKey('rhythm_detail_hydration'));
          expect(panel, findsOneWidget);
          await tester.ensureVisible(find.byTooltip('Close details'));
          await tester.tap(find.byTooltip('Close details'));
          await settle(tester);
          expect(panel, findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      }
    },
  );
}
