import 'package:ascent/core/utils/human_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 21, 21, 0);

  test('dates read the way people say them', () {
    expect(humanWhen(DateTime(2026, 11, 21, 19), now: now), 'today at 7:00 PM');
    expect(
      humanWhen(DateTime(2026, 11, 22, 19), now: now),
      'tomorrow at 7:00 PM',
    );
    expect(
      humanWhen(DateTime(2026, 11, 20, 9, 30), now: now),
      'yesterday at 9:30 AM',
    );
    expect(
      humanWhen(DateTime(2026, 11, 25, 8), now: now),
      'Wednesday at 8:00 AM',
    );
    expect(
      humanWhen(DateTime(2026, 12, 30, 8), now: now),
      'Wed 30 Dec at 8:00 AM',
    );
    expect(
      humanWhen(DateTime(2027, 1, 5, 8), now: now),
      '5 Jan 2027 at 8:00 AM',
    );
  });

  test('day labels are capitalised', () {
    expect(humanDay(DateTime(2026, 11, 22), now: now), 'Tomorrow');
    expect(humanDay(DateTime(2026, 11, 21), now: now), 'Today');
  });
}
