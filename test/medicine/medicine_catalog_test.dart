import 'package:ascent/core/medicine/medicine_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('search', () {
    test('brand names find the medicine', () {
      expect(searchKnownMedicines('dolo').first.name, 'Dolo 650');
      expect(searchKnownMedicines('pan 4').first.name, 'Pantoprazole');
      expect(searchKnownMedicines('thyro').first.name, 'Levothyroxine');
      expect(searchKnownMedicines('crocin').first.name, 'Paracetamol');
    });
    test('one letter is not enough', () {
      expect(searchKnownMedicines('p'), isEmpty);
    });
  });

  group('parse', () {
    test('Dolo 650 twice a day after food for 5 days', () {
      final d = parseMedicineText('Dolo 650 twice a day after food for 5 days');
      expect(d.name, 'Dolo 650');
      expect(d.frequency, DoseFrequency.twice);
      expect(d.food, FoodTiming.after);
      expect(d.days, 5);
      expect(d.purpose, 'Fever and pain');
    });

    test('known defaults fill what is not said', () {
      final d = parseMedicineText('Thyronorm');
      expect(d.name, 'Levothyroxine');
      expect(d.frequency, DoseFrequency.morning);
      expect(d.food, FoodTiming.empty);
      expect(d.days, 90);
    });

    test('strength, form and weeks', () {
      final d = parseMedicineText('Amoxicillin 250 mg syrup thrice for 1 week');
      expect(d.strength, '250 mg');
      expect(d.form, 'syrup');
      expect(d.frequency, DoseFrequency.thrice);
      expect(d.days, 7);
      expect(d.dosage, '250 mg syrup');
    });

    test('an unknown medicine keeps its name', () {
      final d = parseMedicineText('Zyrex 10mg at bedtime 10 days');
      expect(d.name, 'Zyrex');
      expect(d.strength, '10 mg');
      expect(d.frequency, DoseFrequency.bedtime);
      expect(d.days, 10);
    });
  });
}
