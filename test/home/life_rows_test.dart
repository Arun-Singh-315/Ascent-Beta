import 'package:ascent/features/home/model/life_rows.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int h, [int m = 0]) => DateTime(2026, 11, 28, h, m);

void main() {
  test('buckets by two hours from 6:00, clamping the edges', () {
    final b = dayBuckets([
      (_at(5), 100),
      (_at(7), 250),
      (_at(7, 50), 250),
      (_at(13), 300),
      (_at(23, 30), 200),
    ]);
    expect(b.length, 9);
    expect(b[0], 600); // 5:00 clamps into 6–8
    expect(b[3], 300); // 12–14
    expect(b.last, 200);
  });

  test('litres and rupees never say 0', () {
    expect(litres(0), '–');
    expect(litres(1800), '1.8');
    expect(litres(2000), '2');
    expect(rupees(0), '–');
    expect(rupees(350), '₹350');
    expect(rupees(1200), '₹1.2k');
    expect(rupees(12000), '₹12k');
    expect(rupees(250000), '₹2.5L');
  });

  test('missed doses are those 30 min past their time and not taken', () {
    final now = _at(14);
    expect(
      missedDoses([
        ('08:00', true),
        ('13:00', false),
        ('13:45', false),
        ('20:00', false),
      ], now),
      1,
    );
  });

  test('on-track label', () {
    expect(onTrackLabel(const []), isNull);
    expect(onTrackLabel([true, true]), 'All on track');
    expect(onTrackLabel([true, false, true]), '1 needs a look');
    expect(onTrackLabel([false, false]), '2 need a look');
  });
}
