import 'package:ascent/core/services/quick_add_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// Friday 20 November 2026, 2:00 pm.
final _now = DateTime(2026, 11, 20, 14);
final _today = DateTime(2026, 11, 20);
DateTime _plus(int days) => _today.add(Duration(days: days));

QuickAddResult _p(String text, {Set<QuickAddField> ignore = const {}}) =>
    parseQuickAdd(text, _now, ignore: ignore);

void main() {
  test('the spec example: gym 7am tomorrow 45m', () {
    final r = _p('gym 7am tomorrow 45m');
    expect(r.title, 'gym');
    expect(r.day, _plus(1));
    expect((r.hour, r.minute), (7, 0));
    expect(r.durationMinutes, 45);
  });

  test('plain titles are left alone', () {
    for (final text in [
      'Buy milk',
      'Read chapter 7',
      'Sun cream',
      'Sat down with Ana',
      'Plan Q4 at work',
      'Room 101',
      'To-do list cleanup',
      'On-call handover',
    ]) {
      final r = _p(text);
      expect(r.title, text, reason: text);
      expect(r.isEmpty, isTrue, reason: text);
    }
  });

  group('time', () {
    test('am / pm forms', () {
      expect(_p('standup 9:30am').hour, 9);
      expect(_p('standup 9:30am').minute, 30);
      expect(_p('dinner 7 pm').hour, 19);
      expect(_p('dinner at 7.15 p.m.').minute, 15);
      expect(_p('lunch 12pm').hour, 12);
      expect(_p('lunch 12am tomorrow').hour, 0);
    });

    test('24-hour clock', () {
      final r = _p('flight 18:45');
      expect((r.hour, r.minute), (18, 45));
      expect(r.title, 'flight');
    });

    test('"call mom at 6" means this evening', () {
      final r = _p('call mom at 6');
      expect(r.title, 'call mom');
      expect(r.hour, 18);
      expect(r.day, isNull, reason: 'still later today');
    });

    test('bare morning hours are morning, rolling to tomorrow if past', () {
      final r = _p('run at 7 tomorrow');
      expect(r.hour, 7);
      expect(r.day, _plus(1));
      final past = _p('stretch at 9');
      expect(past.hour, 21, reason: '9 am is gone at 2 pm, 9 pm is not');
    });

    test('a time already past today moves to tomorrow', () {
      final r = _p('pills 8am');
      expect(r.day, _plus(1));
    });

    test('noon, midnight and tonight', () {
      expect(_p('lunch at noon').hour, 12);
      expect(_p('backup midnight tomorrow').hour, 0);
      final tonight = _p('pack bags tonight');
      expect(tonight.day, _today);
      expect(tonight.hour, 20);
    });

    test('impossible times stay in the title', () {
      expect(_p('meet at 13pm').hour, isNull);
      expect(_p('meet at 13pm').title, 'meet at 13pm');
    });
  });

  group('day', () {
    test('relative words', () {
      expect(_p('pay rent today').day, _today);
      expect(_p('pay rent tmrw').day, _plus(1));
      expect(_p('dentist kal').day, _plus(1));
      expect(_p('renew visa in 3 days').day, _plus(3));
      expect(_p('review next week').day, _plus(7));
    });

    test('weekdays: full names, or short with on/next/this', () {
      expect(_p('yoga monday').day, _plus(3));
      expect(_p('yoga on mon').day, _plus(3));
      expect(_p('team lunch friday').day, _today, reason: 'it is Friday');
      expect(_p('team lunch next friday').day, _plus(7));
      expect(_p('yoga monday').title, 'yoga');
    });

    test('dates with month names', () {
      expect(_p('mum birthday 25 dec').day, DateTime(2026, 12, 25));
      expect(_p('mum birthday on Dec 25th').day, DateTime(2026, 12, 25));
      expect(
        _p('tax return 3 feb').day,
        DateTime(2027, 2, 3),
        reason: 'past dates mean next year',
      );
      expect(_p('party 31 feb').day, isNull);
    });
  });

  group('duration', () {
    test('minutes and hours', () {
      expect(_p('read 20 min').durationMinutes, 20);
      expect(_p('read for 45 minutes').durationMinutes, 45);
      expect(_p('deep work 2h').durationMinutes, 120);
      expect(_p('deep work 1.5 hours').durationMinutes, 90);
      expect(_p('deep work 1h 30m').durationMinutes, 90);
      expect(_p('read for 45 minutes').title, 'read');
    });

    test('out-of-range durations are ignored', () {
      expect(_p('fast 2000 min').durationMinutes, isNull);
    });
  });

  test('reminder and star', () {
    final r = _p('remind me to call bank at 5 !');
    expect(r.remind, isTrue);
    expect(r.starred, isTrue);
    expect(r.hour, 17);
    expect(r.title, 'call bank');
  });

  test('ignored fields keep their words in the title', () {
    final r = _p('gym tomorrow 45m', ignore: {QuickAddField.day});
    expect(r.day, isNull);
    expect(r.durationMinutes, 45);
    expect(r.title, 'gym tomorrow');
  });

  test('text that is only a date is not consumed', () {
    final r = _p('tomorrow');
    expect(r.title, 'tomorrow');
    expect(r.isEmpty, isTrue);
  });

  test('matches are reported in reading order', () {
    final r = _p('gym 7am tomorrow 45m');
    expect(r.matches.map((m) => m.field), [
      QuickAddField.time,
      QuickAddField.day,
      QuickAddField.duration,
    ]);
  });
}
