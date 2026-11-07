import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/smart_catch_up_banner.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 0,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('SmartCatchUpBanner Unit & Interaction Tests', () {
    testWidgets(
      'prompts hydration catch-up and logs +250 mL with 1-tap confirmation',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            // Initially 0 ml logged today
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
            todayWaterLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            todayMedicineLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            activeMedicinesStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            todaySpendingStreamProvider.overrideWith(
              (ref) => Stream.value(0.0),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: SmartCatchUpBanner(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Hydration is a centered check-in with explicit logging actions.
        expect(find.text('Hydration check'), findsOneWidget);
      expect(find.text('Just drank · 250 mL'), findsOneWidget);

      await tester.tap(find.text('Just drank · 250 mL'));
        await tester.pumpAndSettle();

        expect(find.text('A quick summary'), findsOneWidget);
      expect(find.textContaining('Logged 250 mL.'), findsOneWidget);

        // Database received 250 mL log
        final logs = await db.select(db.waterLogTable).get();
        expect(logs.length, 1);
        expect(logs.first.amountMl, 250);

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'prompts medicine check when dose is pending and marks taken on 1-tap',
      (tester) async {
        final now = DateTime.now();
        final medId = await db.medicineDao.insertMedicine(
          MedicineTableCompanion.insert(
            name: 'Thyroid Care',
            dosage: '50 mcg',
            scheduledTimes: '["08:00"]',
            durationDays: const drift.Value(30),
            startDate: now,
            instructions: const drift.Value('Before breakfast'),
            type: const drift.Value('tablet'),
          ),
        );

        final doseId = await db
            .into(db.medicineLogTable)
            .insert(
              MedicineLogTableCompanion.insert(
                medicineId: medId,
                dateStr: '2026-11-03',
                timeSlot: '08:00',
                isTaken: const drift.Value(false),
                createdAt: drift.Value(now),
              ),
            );

        final med = (await db.medicineDao.getMedicineById(medId))!;
        final doseLog = (await db.select(db.medicineLogTable).get()).first;

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            todayWaterMlStreamProvider.overrideWith(
              (ref) => Stream.value(2000),
            ),
            todayWaterLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            todayMedicineLogsStreamProvider.overrideWith(
              (ref) => Stream.value([doseLog]),
            ),
            activeMedicinesStreamProvider.overrideWith(
              (ref) => Stream.value([med]),
            ),
            todaySpendingStreamProvider.overrideWith(
              (ref) => Stream.value(0.0),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(16),
                  child: SmartCatchUpBanner(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Medicine banner rendered
        expect(find.text('Medicine check'), findsOneWidget);
        expect(find.textContaining('Thyroid Care is due'), findsOneWidget);
        expect(find.text('Taken'), findsOneWidget);

        // Tap Taken ✓
        await tester.tap(find.text('Taken'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Dose recorded as taken'), findsOneWidget);

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
      },
    );

    testWidgets('dismisses catch-up item when close icon is tapped', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
          todayWaterLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          todayMedicineLogsStreamProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
          activeMedicinesStreamProvider.overrideWith((ref) => Stream.value([])),
          todaySpendingStreamProvider.overrideWith((ref) => Stream.value(0.0)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: SmartCatchUpBanner(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hydration check'), findsOneWidget);

      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();

      // Banner is dismissed
      expect(find.text('Hydration check'), findsNothing);
    });

    testWidgets(
      'SmartCatchUpBanner fits 320px width at 2.0x text scale without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
            todayWaterLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            todayMedicineLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            activeMedicinesStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            todaySpendingStreamProvider.overrideWith(
              (ref) => Stream.value(0.0),
            ),
          ],
        );
        addTearDown(container.dispose);

        for (final dark in [false, true]) {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: MaterialApp(
                  theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                  home: const Scaffold(
                    body: Padding(
                      padding: EdgeInsets.all(16),
                      child: SmartCatchUpBanner(),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(SmartCatchUpBanner), findsOneWidget);
        }
      },
    );
  });
}
