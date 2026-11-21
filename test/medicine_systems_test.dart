import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_catalog.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/medicine/refill.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(
    () => drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true,
  );

  group('parser understands each system', () {
    test('homeopathic remedy with potency and pills', () {
      final d = parseMedicineText('Arnica 200C 4 pills thrice daily');
      expect(d.system, MedicineSystem.homeopathy);
      expect(d.strength, '200C');
      expect(d.form, 'globules');
      expect(d.amount, '4 pills');
      expect(d.frequency, DoseFrequency.thrice);
      expect(d.food, FoodTiming.apart);
      expect(d.dosage, '200C globules · 4 pills');
    });

    test('unknown homeopathic name is recognised by its potency', () {
      final d = parseMedicineText('Hepar sulph 30c 5 drops twice a day');
      expect(d.system, MedicineSystem.homeopathy);
      expect(d.strength, '30C');
      expect(d.form, 'dilution');
      expect(d.amount, '5 drops');
    });

    test('"3x a day" is a frequency, not a potency', () {
      final d = parseMedicineText('Crocin 3x a day');
      expect(d.system, MedicineSystem.allopathy);
      expect(d.strength, isNot('3X'));
      final h = parseMedicineText(
        'Kali phos 6x 3x a day',
        hint: MedicineSystem.homeopathy,
      );
      expect(h.strength, '6X');
    });

    test('ayurvedic churna by teaspoon at bedtime', () {
      final d = parseMedicineText('Triphala churna 1 tsp at bedtime');
      expect(d.system, MedicineSystem.ayurveda);
      expect(d.form, 'churna');
      expect(d.amount, '1 tsp');
      expect(d.frequency, DoseFrequency.bedtime);
    });

    test('weekly vitamin D is a supplement every 7 days', () {
      final d = parseMedicineText('Vitamin D3 60k once a week for 8 weeks');
      expect(d.system, MedicineSystem.supplement);
      expect(d.frequency, DoseFrequency.weekly);
      expect(d.everyDays, 7);
      expect(d.days, 56);
    });

    test('the picked system is used when the text names none', () {
      final d = parseMedicineText(
        'Kali phos 4 pills',
        hint: MedicineSystem.homeopathy,
      );
      expect(d.system, MedicineSystem.homeopathy);
      expect(d.form, 'globules');
    });

    test('switching system moves form, food and amount to its defaults', () {
      final d = const MedicineDraft(
        name: 'X',
      ).withSystem(MedicineSystem.ayurveda);
      expect(d.form, 'tablet');
      expect(d.food, FoodTiming.after);
      final h = d.withSystem(MedicineSystem.homeopathy);
      expect(h.form, 'tablet'); // tablet is valid in homeopathy too
      final s = const MedicineDraft(
        name: 'Y',
        form: 'syrup',
      ).withSystem(MedicineSystem.homeopathy);
      expect(s.form, 'globules');
      expect(s.amount, '4 pills');
    });

    test('every system has popular starters', () {
      for (final s in MedicineSystem.values) {
        expect(popularFor(s), isNotEmpty, reason: s.name);
        for (final m in popularFor(s)) {
          expect(s.forms, contains(m.form), reason: m.name);
        }
      }
    });
  });

  group('service schedules every N days', () {
    late AppDatabase db;
    late MedicineService service;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = MedicineService(db, syncAlerts: false);
    });
    tearDown(() => db.close());

    test('weekly for 8 weeks makes 8 doses, 7 days apart', () async {
      final id = await service.addMedicine(
        name: 'Vitamin D3',
        dosage: '60000 IU capsule',
        scheduledTimes: const ['09:00'],
        durationDays: 56,
        startDate: DateTime(2026, 11, 2),
        type: 'capsule',
        system: 'supplement',
        everyDays: 7,
      );
      final logs = await db.medicineDao.watchLogsForMedicine(id).first;
      expect(logs, hasLength(8));
      final days = logs.map((l) => DateTime.parse(l.dateStr)).toList()..sort();
      expect(days[1].difference(days[0]).inDays, 7);
      final m = await db.medicineDao.getMedicineById(id);
      expect(m!.system, 'supplement');
      expect(m.everyDays, 7);
    });

    test('homeopathic forms are accepted and stored', () async {
      final id = await service.addMedicine(
        name: 'Arnica Montana',
        dosage: '30C globules · 4 pills',
        scheduledTimes: const ['08:00', '20:00'],
        durationDays: 3,
        startDate: DateTime(2026, 11, 2),
        type: 'globules',
        system: 'homeopathy',
      );
      final m = await db.medicineDao.getMedicineById(id);
      expect(m!.type, 'globules');
      expect(m.system, 'homeopathy');
      expect(m.everyDays, 1);
      expect(await db.medicineDao.watchLogsForMedicine(id).first, hasLength(6));
    });

    test('weekly stock lasts a week per dose', () async {
      final id = await service.addMedicine(
        name: 'Vitamin D3',
        dosage: '60000 IU capsule',
        scheduledTimes: const ['09:00'],
        durationDays: 56,
        startDate: DateTime(2026, 11, 2),
        type: 'capsule',
        stockCount: 4,
        everyDays: 7,
      );
      final m = await db.medicineDao.getMedicineById(id);
      expect(refillInfo(m!, DateTime(2026, 11, 2))!.daysLeft, 28);
    });
  });
}
