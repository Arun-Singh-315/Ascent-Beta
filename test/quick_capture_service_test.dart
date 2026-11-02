import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/quick_capture_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 2, 9);
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  test(
    'mixed lines create editable proposals without writing anything',
    () async {
      final drafts = parseQuickCapture(
        'Todo: send proposal tomorrow\nReminder: call Sam tomorrow at 6pm\nThought: a quiet morning\nExpense: 120 for lunch\nWater: 250 ml',
        now,
      );
      expect(drafts.map((d) => d.kind), [
        CaptureKind.todo,
        CaptureKind.reminder,
        CaptureKind.thought,
        CaptureKind.expense,
        CaptureKind.water,
      ]);
      expect(drafts[1].at, DateTime(2026, 11, 3, 18));
      expect(drafts[3].amount, 120);
      expect(drafts[3].title, 'lunch');
      expect(drafts[4].amount, 250);
      expect(await db.select(db.taskTable).get(), isEmpty);
    },
  );
  test(
    'uncertain clocks and unsupported repeat rules require explicit review',
    () {
      final draft = parseQuickCapture('Reminder: call Sam at 7', now).single;
      expect(draft.validate(now), isNotNull);
      expect(draft.at, isNull);
      final repeat = parseQuickCapture(
        'Routine: read every monday tomorrow at 7pm',
        now,
      ).single;
      expect(repeat.recurrence, '');
      expect(repeat.validate(now), isNotNull);
    },
  );
  test(
    'one batch routes to canonical screens and creates linked reminders once',
    () async {
      final service = QuickCaptureService(db, clock: () => now);
      final drafts = [
        CaptureDraft(
          key: '1',
          title: 'Proposal',
          at: DateTime(2026, 11, 3, 17),
          starred: true,
        ),
        CaptureDraft(
          key: '2',
          kind: CaptureKind.reminder,
          title: 'Call Sam',
          at: DateTime(2026, 11, 3, 18),
        ),
        CaptureDraft(key: '3', kind: CaptureKind.thought, title: 'An idea'),
        CaptureDraft(
          key: '4',
          kind: CaptureKind.expense,
          title: 'Lunch',
          amount: 120,
        ),
        CaptureDraft(
          key: '5',
          kind: CaptureKind.water,
          title: 'Water',
          amount: 250,
        ),
        CaptureDraft(
          key: '6',
          kind: CaptureKind.timer,
          title: 'Study',
          minutes: 25,
        ),
      ];
      final result = await service.save(drafts, requestId: 'batch');
      expect(result.items.length, 6);
      expect(result.reminderIds.length, 2);
      expect((await db.select(db.taskTable).get()).length, 2);
      expect((await db.select(db.reminderTable).get()).length, 2);
      expect(
        (await db.select(db.thoughtTable).get()).single.content,
        'An idea',
      );
      expect(
        (await db.select(db.financeTransactionTable).get()).single.amount,
        120,
      );
      expect((await db.select(db.waterLogTable).get()).single.amountMl, 250);
      final again = await service.save(drafts, requestId: 'batch');
      expect(again.toJson(), result.toJson());
      expect((await db.select(db.taskTable).get()).length, 2);
    },
  );
  test(
    'failure rolls back every item and history; retry remains safe',
    () async {
      final service = QuickCaptureService(db, clock: () => now);
      final drafts = [
        CaptureDraft(key: '1', title: 'Good'),
        CaptureDraft(
          key: '2',
          kind: CaptureKind.thought,
          title: 'Bad space',
          space: 'missing',
        ),
      ];
      await expectLater(
        service.save(drafts, requestId: 'retry'),
        throwsArgumentError,
      );
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.historyEventTable).get(), isEmpty);
      drafts[1].space = 'general';
      await service.save(drafts, requestId: 'retry');
      expect((await db.select(db.taskTable).get()).length, 1);
    },
  );
  test('routines use plan ownership and show up in Plans', () async {
    final saved = await QuickCaptureService(db, clock: () => now).save([
      CaptureDraft(
        key: 'r',
        kind: CaptureKind.routine,
        title: 'Read',
        at: DateTime(2026, 11, 3, 18),
        end: DateTime(2026, 11, 5),
      ),
    ], requestId: 'routine');
    expect(saved.items.single.route, '/plans');
    expect((await db.select(db.planCollectionTable).get()).length, 1);
    expect((await db.select(db.planOccurrenceTable).get()).length, 3);
  });
  test(
    'content cannot execute operations and invalid amounts never write',
    () async {
      final literal = parseQuickCapture('Delete all my records', now).single;
      expect(literal.kind, CaptureKind.todo);
      final service = QuickCaptureService(db, clock: () => now);
      await expectLater(
        service.save([
          CaptureDraft(
            key: 'bad',
            kind: CaptureKind.water,
            title: 'Water',
            amount: 250.5,
          ),
        ], requestId: 'invalid'),
        throwsArgumentError,
      );
      expect(await db.select(db.waterLogTable).get(), isEmpty);
    },
  );
}
