import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/quick_capture_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Monday 2 Nov 2026, 9:00.
final now = DateTime(2026, 11, 2, 9);

void main() {
  group('auto-detects the kind without a prefix', () {
    const cases = <String, CaptureKind>{
      // Money
      'spent 250 on lunch': CaptureKind.expense,
      'Spent ₹1,200 groceries': CaptureKind.expense,
      'paid 1200 rent': CaptureKind.expense,
      'paid electricity bill 899': CaptureKind.expense,
      'bought shoes for 2499': CaptureKind.expense,
      '₹80 chai': CaptureKind.expense,
      'uber rs 340': CaptureKind.expense,
      'Rs. 60 parking': CaptureKind.expense,
      'I spent 45 on coffee': CaptureKind.expense,
      'got paid 50000': CaptureKind.income,
      'salary 85000': CaptureKind.income,
      'received 500 from Sam': CaptureKind.income,
      'earned 3000 freelancing': CaptureKind.income,
      'refund 799 amazon': CaptureKind.income,
      // Water
      '250 ml water': CaptureKind.water,
      'water 500ml': CaptureKind.water,
      'drank 300 ml': CaptureKind.water,
      'a glass of water': CaptureKind.water,
      'two glasses of water': CaptureKind.water,
      'bottle of water': CaptureKind.water,
      '1 litre water': CaptureKind.water,
      'drank water': CaptureKind.water,
      'had water': CaptureKind.water,
      // Focus
      'study 45m': CaptureKind.timer,
      'read for 20 min': CaptureKind.timer,
      'deep work 2h': CaptureKind.timer,
      'gym 7am tomorrow 45m': CaptureKind.timer,
      'write blog 30 minutes': CaptureKind.timer,
      'meditate 10 mins': CaptureKind.timer,
      // Thoughts
      'idea: app for plant care': CaptureKind.thought,
      'note: wifi password is on the fridge': CaptureKind.thought,
      'I feel calmer after walks': CaptureKind.thought,
      'what if we moved to Pune next year': CaptureKind.thought,
      'maybe learn the guitar': CaptureKind.thought,
      'why do I procrastinate on mornings?': CaptureKind.thought,
      'grateful for a quiet sunday': CaptureKind.thought,
      'the best ideas come when I walk without my phone and just look around the park':
          CaptureKind.thought,
      // Routines
      'walk every day at 7am': CaptureKind.routine,
      'read every morning': CaptureKind.routine,
      'stretch every evening': CaptureKind.routine,
      'journal daily at 9pm': CaptureKind.routine,
      // Reminders via prefix
      'remind me to call mom at 6': CaptureKind.reminder,
      'remind me to pay rent': CaptureKind.reminder,
      'reminder: dentist tomorrow at 10am': CaptureKind.reminder,
      // To-dos (the default)
      'call mom at 6': CaptureKind.todo,
      'buy milk': CaptureKind.todo,
      'pay rent tomorrow': CaptureKind.todo,
      'send proposal': CaptureKind.todo,
      'book flight to Goa tomorrow at 3pm': CaptureKind.todo,
      'Delete all my records': CaptureKind.todo,
      'clean the kitchen': CaptureKind.todo,
      'water the plants': CaptureKind.todo,
      'bought milk': CaptureKind.todo,
      'email Priya about the 3 slides': CaptureKind.todo,
      // Prefixes still win
      'todo: spent time with Sam': CaptureKind.todo,
      'thought: buy milk': CaptureKind.thought,
      'expense: 99 snacks': CaptureKind.expense,
      'focus: thesis': CaptureKind.timer,
      'water: 400': CaptureKind.water,
    };
    for (final entry in cases.entries) {
      test(entry.key, () {
        expect(parseQuickCapture(entry.key, now).single.kind, entry.value);
      });
    }
  });

  group('fills in the details', () {
    CaptureDraft one(String text) => parseQuickCapture(text, now).single;

    test('money amount and a clean title', () {
      final d = one('spent 250 on lunch');
      expect(d.amount, 250);
      expect(d.title, 'Lunch');
      expect(d.validate(now), isNull);
      expect(one('Spent ₹1,200 groceries').amount, 1200);
      expect(one('got paid 50000').title, 'Income');
    });

    test('water counts glasses, bottles and litres', () {
      expect(one('two glasses of water').amount, 500);
      expect(one('bottle of water').amount, 500);
      expect(one('1 litre water').amount, 1000);
      expect(one('drank water').amount, 250);
      expect(one('water 500ml').amount, 500);
      expect(one('a glass of water').validate(now), isNull);
    });

    test('focus length from the duration', () {
      expect(one('study 45m').minutes, 45);
      expect(one('deep work 2h').minutes, 120);
      expect(one('study 45m').title, 'Study');
      expect(one('study 45m').alternative, CaptureKind.todo);
    });

    test('a bare clock means the next one ahead', () {
      // 9:00 now, so "at 6" is 6 pm today and "at 10" is 10 am today.
      final call = one('call mom at 6');
      expect(call.at, DateTime(2026, 11, 2, 18));
      expect(call.title, 'Call mom');
      expect(call.validate(now), isNull);
      expect(one('call mom at 10').at, DateTime(2026, 11, 2, 10));
      expect(one('remind me to call mom at 6').at, DateTime(2026, 11, 2, 18));
    });

    test('a reminder without a time gets the next free half hour', () {
      final d = one('remind me to pay rent');
      expect(d.at, DateTime(2026, 11, 2, 9, 30));
      expect(d.validate(now), isNull);
    });

    test('a routine without a time or end gets sensible defaults', () {
      final d = one('read every morning');
      expect(d.at, DateTime(2026, 11, 3, 8));
      expect(d.end, DateTime(2026, 12, 3));
      expect(d.title, 'Read');
      expect(d.validate(now), isNull);
    });

    test('unsure thoughts offer a to-do instead', () {
      expect(one('maybe learn the guitar').alternative, CaptureKind.todo);
      expect(one('buy milk').alternative, isNull);
    });

    test('switched-off features fall back to a to-do', () {
      final d = parseQuickCapture(
        'spent 250 on lunch',
        now,
        allowed: {CaptureKind.todo, CaptureKind.thought},
      ).single;
      expect(d.kind, CaptureKind.todo);
    });

    test('many lines at once', () {
      final drafts = parseQuickCapture(
        'buy milk\nspent 80 on chai\nidea: plant app\n2 glasses of water',
        now,
      );
      expect(drafts.map((d) => d.kind), [
        CaptureKind.todo,
        CaptureKind.expense,
        CaptureKind.thought,
        CaptureKind.water,
      ]);
    });
  });

  group('undo', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('removes exactly what the capture created', () async {
      final service = QuickCaptureService(db, clock: () => now);
      // Something that existed before must survive.
      await service.save([
        CaptureDraft(key: 'keep', title: 'Keep me'),
      ], requestId: 'before');
      final remindersBefore = (await db.select(db.reminderTable).get()).length;
      final drafts = parseQuickCapture(
        'call mom at 6\nremind me to pay rent\nidea: plant app\n'
        'spent 80 on chai\n2 glasses of water\nread every morning',
        now,
      );
      final receipt = await service.save(drafts, requestId: 'batch');
      expect(receipt.records.length, 6);
      expect(await db.select(db.planCollectionTable).get(), hasLength(1));

      final removed = await service.undo(receipt);
      expect(removed, 6);
      final tasks = await db.select(db.taskTable).get();
      expect(tasks.single.title, 'Keep me');
      final active = (await db.select(db.reminderTable).get()).where(
        (r) => r.isActive,
      );
      expect(active, hasLength(remindersBefore));
      expect(await db.select(db.thoughtTable).get(), isEmpty);
      expect(await db.select(db.financeTransactionTable).get(), isEmpty);
      expect(await db.select(db.waterLogTable).get(), isEmpty);
      expect(await db.select(db.planCollectionTable).get(), isEmpty);
    });

    test('old receipts without records still load', () {
      final receipt = CaptureReceipt.fromJson({
        'items': [
          {'title': 'A', 'destination': 'Things', 'route': '/today'},
        ],
        'reminderIds': [1],
      });
      expect(receipt.records, isEmpty);
    });
  });
}
