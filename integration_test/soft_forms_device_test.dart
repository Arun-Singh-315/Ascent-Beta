import 'dart:io';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_editor_sheet.dart';
import 'package:ascent/features/home/widgets/smart_catch_up_banner.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/features/money/add_transaction_sheet.dart';
import 'package:ascent/features/promises/widgets/promise_chat_composer.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'centered forms save isolated fake medicine, money and promise on phone',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = PromiseRepository(
        db,
        cancelNotification: (_) async {},
        scheduleNotification: (_, title, body, at) async => true,
      );
      await repo.initialize();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          medicineServiceProvider.overrideWithValue(
            MedicineService(db, syncAlerts: false),
          ),
          promiseRepositoryProvider.overrideWithValue(repo),
        ],
      );
      var converted = false;
      Future<void> capture(String name) async {
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
        }
        await t.pump();
        final bytes = await binding.takeScreenshot(name);
        await File(
          '${(await getTemporaryDirectory()).path}/soft-forms-$name.png',
        ).writeAsBytes(bytes);
      }

      Future<void> flush() async {
        for (var i = 0; i < 15; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: Wrap(
                    spacing: 12,
                    children: [
                      TextButton(
                        onPressed: () => showMedicineEditor(context),
                        child: const Text('Medicine'),
                      ),
                      TextButton(
                        onPressed: () => AddTransactionSheet.show(context),
                        child: const Text('Money'),
                      ),
                      TextButton(
                        onPressed: () => PromiseChatComposer.show(context),
                        child: const Text('Promise'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await flush();
      await t.pumpAndSettle();
      await t.tap(find.text('Medicine'));
      await t.pumpAndSettle();
      await capture('medicine-details');
      await t.enterText(
        find.byKey(const ValueKey('medicine_name')),
        'QA custom medicine',
      );
      await t.enterText(
        find.byKey(const ValueKey('medicine_dosage')),
        'QA prescribed dose',
      );
      await t.enterText(
        find.byKey(const ValueKey('medicine_instructions')),
        'QA custom instructions',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await t.tap(find.text('Add time'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextFormField).first, '17');
      await t.enterText(find.byType(TextFormField).last, '35');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.tap(find.text('Save time'));
      await t.pumpAndSettle();
      await capture('medicine-schedule');
      await t.tap(find.text('Save medicine'));
      await flush();
      final meds = await db.select(db.medicineTable).get();
      expect(meds.single.name, 'QA custom medicine');
      expect(meds.single.scheduledTimes, '["09:00","17:35"]');
      expect(meds.single.instructions, 'QA custom instructions');
      await t.tap(find.text('Money'));
      await t.pumpAndSettle();
      await capture('money');
      await t.enterText(find.byType(TextField).first, '125.50');
      await t.enterText(find.byType(TextField).last, 'QA lunch');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.tap(find.text('Save transaction'));
      await flush();
      final transactions = await db.select(db.financeTransactionTable).get();
      expect(transactions.single.amount, 125.50);
      expect(transactions.single.title, 'QA lunch');
      await t.tap(find.text('Promise'));
      await t.pumpAndSettle();
      await capture('promise');
      await t.enterText(
        find.byType(TextField),
        'Read for 20 minutes every day',
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Send message'));
      await t.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await capture('promise-review');
      await t.tap(find.byKey(const ValueKey('promise_save')));
      await flush();
      expect(await repo.watchActivePromises().first, hasLength(1));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      container.dispose();
      await db.close();
    },
  );
  testWidgets(
    'switch check-in headings, skip and save a summary using fake data',
    (t) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.now();
      final day =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final id = await db.medicineDao.insertMedicine(
        MedicineTableCompanion.insert(
          name: 'QA check-in medicine',
          dosage: 'QA dose',
          scheduledTimes: '["08:00"]',
          startDate: now,
        ),
      );
      await db
          .into(db.medicineLogTable)
          .insert(
            MedicineLogTableCompanion.insert(
              medicineId: id,
              dateStr: day,
              timeSlot: '08:00',
              isTaken: const drift.Value(false),
            ),
          );
      final med = (await db.medicineDao.getMedicineById(id))!;
      final dose = (await db.select(db.medicineLogTable).get()).single;
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
          todayWaterLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          todayMedicineLogsStreamProvider.overrideWith(
            (ref) => Stream.value([dose]),
          ),
          activeMedicinesStreamProvider.overrideWith(
            (ref) => Stream.value([med]),
          ),
          todaySpendingStreamProvider.overrideWith((ref) => Stream.value(0.0)),
        ],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: SmartCatchUpBanner(
                clock: () => DateTime(now.year, now.month, now.day, 20),
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Medicine check'), findsOneWidget);
      await t.tap(find.text('Water'));
      await t.pumpAndSettle();
      expect(find.text('Hydration check'), findsOneWidget);
      await t.enterText(find.byType(TextField), '350');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.tap(find.text('Log water'));
      for (var i = 0; i < 15; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Logged 350 mL'), findsOneWidget);
      expect(await db.waterDao.getWaterForDate(now), 350);
      await t.tap(find.text('Money'));
      await t.pumpAndSettle();
      expect(find.text('Daily Money Check'), findsOneWidget);
      // Skipping another heading does not create a transaction or take a dose.
      await t.tap(find.text('Skip for now'));
      await t.pumpAndSettle();
      expect(await db.select(db.financeTransactionTable).get(), isEmpty);
      expect(
        (await db.select(db.medicineLogTable).get()).single.isTaken,
        false,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      container.dispose();
      await db.close();
    },
  );
}
