import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/hydration/hydration_screen.dart';
import 'package:ascent/features/chai_break/chai_break_provider.dart';
import 'package:ascent/features/chai_break/chai_break_screen.dart';
import 'package:ascent/features/money/money_screen.dart';
import 'package:ascent/shared/widgets/ascent_segmented_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({
    required Widget child,
    bool dark = false,
    double textScale = 1.0,
    Size size = const Size(390, 844),
    List<dynamic> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: child,
        ),
      ),
    );
  }

  group('Apple Theme Hydration Screen Tests', () {
    testWidgets('Hydration renders Apple Health ring gauge and quick intake presets', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const HydrationScreen(),
          extraOverrides: [
            todayWaterLogsStreamProvider.overrideWith((ref) => Stream.value(<WaterLog>[])),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
            dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
            past7DaysHydrationStreamProvider.overrideWith((ref) => Stream.value(<DailyHydrationRecord>[])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header & subtitles
      expect(find.text('Hydration'), findsOneWidget);
      expect(find.text('TODAY\'S INTAKE'), findsOneWidget);
      expect(find.text('QUICK LOG'), findsOneWidget);

      // Quick presets
      expect(find.text('+150'), findsOneWidget);
      expect(find.text('Cup'), findsOneWidget);
      expect(find.text('+250'), findsOneWidget);
      expect(find.text('Glass'), findsOneWidget);
      expect(find.text('+500'), findsOneWidget);
      expect(find.text('Bottle'), findsOneWidget);
      expect(find.text('+750'), findsOneWidget);
      expect(find.text('Flask'), findsOneWidget);
      expect(find.text('+ Custom mL'), findsOneWidget);

      // Empty state
      expect(find.text('No drinks logged yet today'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Hydration handles high-volume logs with preview capping & expansion', (tester) async {
      final now = DateTime.now();
      final logs = List<WaterLog>.generate(
        10,
        (i) => WaterLog(
          id: i + 1,
          amountMl: 250,
          timestamp: now.subtract(Duration(minutes: i * 30)),
          date: now,
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const HydrationScreen(),
          extraOverrides: [
            todayWaterLogsStreamProvider.overrideWith((ref) => Stream.value(logs)),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(2500)),
            dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
            past7DaysHydrationStreamProvider.overrideWith((ref) => Stream.value(<DailyHydrationRecord>[])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('10 entries'), findsOneWidget);
      final expandFinder = find.text('Show All 10 Entries');
      await tester.scrollUntilVisible(
        expandFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(expandFinder);
      await tester.pumpAndSettle();
      expect(expandFinder, findsOneWidget);
      expect(find.text('View Full Hydration History'), findsOneWidget);

      // Tap to expand
      await tester.tap(expandFinder);
      await tester.pumpAndSettle();

      expect(find.text('Show Less'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Hydration screen is immune to overflows at 320px width & 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final logs = List<WaterLog>.generate(
        6,
        (i) => WaterLog(
          id: i + 1,
          amountMl: 300,
          timestamp: now.subtract(Duration(minutes: i * 40)),
          date: now,
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const HydrationScreen(),
          dark: true,
          textScale: 2.0,
          size: const Size(320, 800),
          extraOverrides: [
            todayWaterLogsStreamProvider.overrideWith((ref) => Stream.value(logs)),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(1800)),
            dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
            past7DaysHydrationStreamProvider.overrideWith((ref) => Stream.value(<DailyHydrationRecord>[])),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Hydration'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('Apple Mindfulness Chai & Coffee Screen Tests', () {
    testWidgets('Chai screen renders canonical AscentSegmentedControl and serene timer dial', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const ChaiBreakScreen(),
          extraOverrides: [
            todayBreaksProvider.overrideWith((ref) => Future.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('Chai & Coffee'), findsOneWidget);

      // Canonical segmented control
      expect(find.byType(AscentSegmentedControl<ChaiBreakMode>), findsOneWidget);
      expect(find.text('Mindful Pause'), findsOneWidget);
      expect(find.text('Brew With Me'), findsOneWidget);

      // Duration pills
      expect(find.text('5m Chai'), findsOneWidget);
      expect(find.text('10m Coffee'), findsOneWidget);
      expect(find.text('15m Reset'), findsOneWidget);

      // Controls
      expect(find.text('Resume'), findsOneWidget);

      final historyTitle = find.text('PAUSE HISTORY');
      await tester.scrollUntilVisible(
        historyTitle,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(historyTitle, findsOneWidget);
      expect(find.text('View Full Pause History'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Chai screen switches seamlessly to Brew With Me mode', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const ChaiBreakScreen(),
          extraOverrides: [
            todayBreaksProvider.overrideWith((ref) => Future.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Brew With Me
      await tester.tap(find.text('Brew With Me'));
      await tester.pumpAndSettle();

      expect(find.text('Follow a step-by-step artisanal brewing guide.'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Chai screen is immune to overflows at 320px width & 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestApp(
          child: const ChaiBreakScreen(),
          dark: true,
          textScale: 2.0,
          size: const Size(320, 800),
          extraOverrides: [
            todayBreaksProvider.overrideWith((ref) => Future.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Chai & Coffee'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('Money Screen High-Volume Protection Tests', () {
    testWidgets('Money screen caps high-volume transactions and provides Show All & History link', (tester) async {
      final now = DateTime.now();
      // Insert 12 transactions across 4 days
      for (var dayOffset = 0; dayOffset < 4; dayOffset++) {
        final txDate = now.subtract(Duration(days: dayOffset));
        for (var i = 0; i < 3; i++) {
          await db.financeDao.insertTransaction(
            FinanceTransactionTableCompanion.insert(
              title: 'Purchase $dayOffset-$i',
              amount: 150.0 * (i + 1),
              date: txDate,
              category: const drift.Value('Food & Groceries'),
              account: const drift.Value('UPI'),
              type: const drift.Value('expense'),
            ),
          );
        }
      }

      await tester.pumpWidget(
        buildTestApp(child: const MoneyScreen()),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.text('Show All 12 Transactions');
      await tester.scrollUntilVisible(
        toggleFinder,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(toggleFinder);
      await tester.pumpAndSettle();
      expect(toggleFinder, findsOneWidget);
      expect(find.text('View Full Ledger in History (12 records)'), findsOneWidget);

      // Tap to expand all
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.text('Show Recent Only'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Money screen is immune to overflows at 320px width & 2.0x font scaling with 12 transactions', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      for (var i = 0; i < 8; i++) {
        await db.financeDao.insertTransaction(
          FinanceTransactionTableCompanion.insert(
            title: 'Very long transaction title that wraps comfortably $i',
            amount: 9999.0,
            date: now.subtract(Duration(days: i % 3)),
            category: const drift.Value('Shopping'),
            account: const drift.Value('Credit Card'),
            type: const drift.Value('expense'),
          ),
        );
      }

      await tester.pumpWidget(
        buildTestApp(
          child: const MoneyScreen(),
          dark: true,
          textScale: 2.0,
          size: const Size(320, 800),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Money & Budgets'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
