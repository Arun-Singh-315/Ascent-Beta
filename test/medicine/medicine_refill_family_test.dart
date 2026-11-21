import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/medicine/refill.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_quick_add_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('refills', () {
    late AppDatabase db;
    late MedicineService service;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = MedicineService(db);
    });
    tearDown(() => db.close());

    Future<Medicine> med(int id) async => (await (db.select(
      db.medicineTable,
    )..where((m) => m.id.equals(id))).getSingle());

    test('taking a dose counts stock down; un-taking gives it back', () async {
      final now = DateTime.now();
      final id = await service.addMedicine(
        name: 'Dolo 650',
        dosage: '650 mg tablet',
        scheduledTimes: ['00:01', '00:02'],
        durationDays: 5,
        startDate: now,
        stockCount: 10,
      );
      final logs = await (db.select(
        db.medicineLogTable,
      )..where((l) => l.medicineId.equals(id))).get();
      final first = logs.first;
      await service.toggleDose(first.id, true);
      expect((await med(id)).stockCount, 9);
      await service.toggleDose(first.id, false);
      expect((await med(id)).stockCount, 10);
    });

    test('untracked stock stays untracked', () async {
      final id = await service.addMedicine(
        name: 'Vitamin D3',
        dosage: '60000 IU capsule',
        scheduledTimes: ['00:01'],
        durationDays: 8,
        startDate: DateTime.now(),
      );
      final log = (await (db.select(
        db.medicineLogTable,
      )..where((l) => l.medicineId.equals(id))).get()).first;
      await service.toggleDose(log.id, true);
      expect((await med(id)).stockCount, isNull);
    });

    test('runs out, low and enough for the course', () async {
      final now = DateTime(2026, 11, 21, 9);
      final id = await service.addMedicine(
        name: 'Metformin',
        dosage: '500 mg tablet',
        scheduledTimes: ['09:00', '21:00'],
        durationDays: 30,
        startDate: now,
        stockCount: 4,
      );
      var info = refillInfo(await med(id), now)!;
      expect(info.daysLeft, 2);
      expect(info.runsOut, DateTime(2026, 11, 23));
      expect(info.low, isTrue);
      await service.setStock(id, 100);
      info = refillInfo(await med(id), now)!;
      expect(info.coversCourse, isTrue);
      expect(info.low, isFalse);
    });
  });

  testWidgets('add a medicine for Mum with its stock', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(body: MedicineQuickAddSheet()),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('medicine_quick_text')),
        matching: find.byType(EditableText),
      ),
      'Telma 40 every morning',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('medicine_person_add')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('medicine_person_add')));
    await settle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('medicine_person_name')),
        matching: find.byType(EditableText),
      ),
      'Mum',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('medicine_person_save')));
    await settle();
    expect(find.byKey(const ValueKey('medicine_person_Mum')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('medicine_quick_stock')),
    );
    await tester.pump();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('medicine_quick_stock')),
        matching: find.byType(EditableText),
      ),
      '30',
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('medicine_quick_save')),
    );
    await tester.tap(find.byKey(const ValueKey('medicine_quick_save')));
    await settle();

    final m = (await tester.runAsync(
      () => db.select(db.medicineTable).get(),
    ))!.single;
    expect(m.name, 'Telmisartan');
    expect(m.stockCount, 30);
    final plan = (await tester.runAsync(
      () => db.select(db.carePlanTable).get(),
    ))!.single;
    expect(plan.person, 'Mum');
    expect(m.carePlanId, plan.id);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
