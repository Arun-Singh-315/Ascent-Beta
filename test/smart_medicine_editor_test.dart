import 'dart:convert';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/medicine/care_repository.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_editor_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async => db.close());

  Future<void> mount(
    WidgetTester t, {
    Medicine? medicine,
    bool dark = false,
    double scale = 1,
  }) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          medicineServiceProvider.overrideWithValue(
            MedicineService(db, syncAlerts: false),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () =>
                      showMedicineEditor(context, medicine: medicine),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
  }

  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 12; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'custom medicine, dose and instructions save without preset restrictions',
    (t) async {
      await mount(t);
      final rect = t.getRect(find.byType(MedicineEditorSheet));
      expect(rect.width, lessThan(390));
      expect(rect.height, lessThan(650));
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      expect(find.textContaining('Enter a medicine'), findsOneWidget);
      await t.enterText(
        find.byKey(const ValueKey('medicine_name')),
        'QA custom remedy',
      );
      await t.enterText(
        find.byKey(const ValueKey('medicine_dosage')),
        '3 prescribed drops',
      );
      await t.enterText(
        find.byKey(const ValueKey('medicine_instructions')),
        'Custom note',
      );
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('medicine_duration')), '12');
      await t.tap(find.text('Save medicine'));
      await flush(t);
      final meds = await db.select(db.medicineTable).get();
      expect(meds.single.name, 'QA custom remedy');
      expect(meds.single.dosage, '3 prescribed drops');
      expect(meds.single.instructions, 'Custom note');
      expect(meds.single.durationDays, 12);
    },
  );
  testWidgets(
    'editing preserves exact existing schedule, start, duration and type',
    (t) async {
      final start = DateTime(2026, 11, 1);
      final id = await MedicineService(db, syncAlerts: false).addMedicine(
        name: 'QA existing',
        dosage: 'Recorded dose',
        scheduledTimes: ['07:15', '12:45', '18:10', '23:05'],
        durationDays: 42,
        startDate: start,
        instructions: 'Recorded instructions',
        type: 'drops',
      );
      final med = (await db.medicineDao.getMedicineById(id))!;
      await mount(t, medicine: med);
      await t.enterText(
        find.byKey(const ValueKey('medicine_name')),
        'QA renamed',
      );
      await t.tap(find.text('Continue'));
      await t.pumpAndSettle();
      for (final time in ['07:15', '12:45', '18:10', '23:05']) {
        expect(find.text(time), findsOneWidget);
      }
      await t.tap(find.text('Save medicine'));
      await flush(t);
      final updated = (await db.medicineDao.getMedicineById(id))!;
      expect(jsonDecode(updated.scheduledTimes), [
        '07:15',
        '12:45',
        '18:10',
        '23:05',
      ]);
      expect(updated.durationDays, 42);
      expect(updated.startDate, start);
      expect(updated.type, 'drops');
    },
  );
  testWidgets(
    'care context can move between concerns without changing dose evidence',
    (t) async {
      final repo = CareRepository(db);
      final first = await repo.savePlan(
        title: 'First concern',
        person: 'My care',
        clinician: '',
        notes: '',
      );
      final second = await repo.savePlan(
        title: 'Recovery care',
        person: 'My care',
        clinician: '',
        notes: '',
      );
      final service = MedicineService(db, syncAlerts: false);
      final id = await service.addMedicine(
        name: 'My medicine',
        dosage: 'Recorded dose',
        scheduledTimes: ['07:15'],
        durationDays: 7,
        startDate: DateTime.now(),
        carePlanId: first,
      );
      final before = await t.runAsync(
        () => db.medicineDao.watchLogsForMedicine(id).first,
      );
      await mount(
        t,
        medicine: await t.runAsync<Medicine>(
          () async => (await db.medicineDao.getMedicineById(id))!,
        ),
      );
      await t.tap(find.text('Care'));
      await flush(t);
      await t.enterText(
        find.byKey(const ValueKey('medicine_purpose')),
        'Purpose from my prescription',
      );
      await t.tap(find.byType(DropdownButtonFormField<int>));
      await t.pumpAndSettle();
      await t.tap(find.text('Recovery care').last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Save medicine'));
      await t.tap(find.text('Save medicine'));
      await flush(t);
      final updated = (await db.medicineDao.getMedicineById(id))!;
      expect(updated.carePlanId, second);
      expect(updated.purpose, 'Purpose from my prescription');
      expect(updated.scheduledTimes, '["07:15"]');
      expect(
        await t.runAsync(() => db.medicineDao.watchLogsForMedicine(id).first),
        before,
      );
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    },
  );
  for (final dark in [false, true]) {
    testWidgets('large text and keyboard remain accessible dark=$dark', (
      t,
    ) async {
      await mount(t, dark: dark, scale: 2);
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Continue'));
      expect(t.takeException(), isNull);
    });
  }
}
