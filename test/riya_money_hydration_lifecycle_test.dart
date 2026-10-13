import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/ai/riya_intents.dart';

void main() {
  late AppDatabase db;
  late RiyaExecutor executor;
  late RiyaIntentResolver resolver;
  final now = DateTime(2027, 1, 31, 18);
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    executor = RiyaExecutor(db, clock: () => now);
    resolver = RiyaIntentResolver(db, clock: () => now);
  });
  tearDown(() async => db.close());
  Future<RiyaResult> say(String text, String request) async {
    final resolution = await resolver.resolve(text);
    expect(resolution?.command, isNotNull);
    final result = await executor.execute(
      resolution!.command!,
      requestId: request,
      approved: true,
    );
    resolver.rememberResult(result);
    return result;
  }

  test(
    'Budget create/update/edit/delete uses actual records and keeps unspecified daily limits',
    () async {
      final created = await say('Set monthly budget 5000 daily 200', 'budget');
      await say('Set monthly budget 6000', 'budget-update');
      final budget = (await db.select(db.financeBudgetTable).get()).single;
      expect(budget.monthlyLimit, 6000);
      expect(budget.dailyLimit, 200);
      expect(
        (await executor.execute(
          const RiyaCommand('budgets.list', {}),
          requestId: 'read',
        )).message,
        contains('2027-01'),
      );
      await say('Edit budget #${budget.id} monthly to 7000', 'edit');
      await executor.execute(
        RiyaCommand('budgets.edit', {'id': budget.id, 'clearDaily': true}),
        requestId: 'clear',
        approved: true,
      );
      expect(
        (await db.select(db.financeBudgetTable).get()).single.dailyLimit,
        isNull,
      );
      await say('Delete budget #${created.entityId}', 'delete');
      expect(await db.select(db.financeBudgetTable).get(), isEmpty);
    },
  );
  test(
    'Savings contribution replay is atomic and does not fabricate a transaction',
    () async {
      final created = await say(
        'Create savings goal Laptop target 10000',
        'goal',
      );
      final command = RiyaCommand('savings.contribute', {
        'id': created.entityId,
        'amount': 500,
      });
      await Future.wait([
        for (var i = 0; i < 2; i++)
          executor.execute(command, requestId: 'contribution', approved: true),
      ]);
      expect(
        (await db.select(db.savingsGoalTable).get()).single.savedAmount,
        500,
      );
      expect(await db.select(db.financeTransactionTable).get(), isEmpty);
      await say('Edit savings goal #${created.entityId} saved to 0', 'correct');
      expect(
        (await db.select(db.savingsGoalTable).get()).single.savedAmount,
        0,
      );
      await say('Delete savings goal #${created.entityId}', 'delete');
      expect(await db.select(db.savingsGoalTable).get(), isEmpty);
    },
  );
  test(
    'Savings edits preserve other fields and allow explicit date clearing',
    () async {
      final result = await executor.execute(
        const RiyaCommand('savings.create', {
          'title': 'Trip',
          'targetAmount': 2000,
          'targetDate': '2027-03-01',
        }),
        requestId: 'goal',
        approved: true,
      );
      await executor.execute(
        RiyaCommand('savings.edit', {'id': result.entityId, 'title': 'Travel'}),
        requestId: 'rename',
        approved: true,
      );
      expect(
        (await db.select(db.savingsGoalTable).get()).single.targetDate,
        DateTime(2027, 3, 1),
      );
      await executor.execute(
        RiyaCommand('savings.edit', {'id': result.entityId, 'clearDate': true}),
        requestId: 'clear',
        approved: true,
      );
      expect(
        (await db.select(db.savingsGoalTable).get()).single.targetDate,
        isNull,
      );
    },
  );
  test(
    'Edit that tracks the actual selected domain and never crosses into a matching ID',
    () async {
      final goal = await say('Create savings goal Laptop target 10000', 'goal');
      final edit = (await resolver.resolve(
        'Edit that to Better laptop',
      ))!.command!;
      expect(edit.id, 'savings.edit');
      expect(edit.arguments['id'], goal.entityId);
      await say('Save note: Keep this note safe', 'note');
      expect(
        (await resolver.resolve('Edit that to Keep moving'))!.command!.id,
        'thoughts.edit',
      );
      await resolver.resolve('Show savings goals');
      expect(
        (await resolver.resolve('Edit that to A new title'))!.command,
        isNull,
      );
    },
  );
  test(
    'Water corrections preserve dates, bounded lists use a real day, and goals log no water',
    () async {
      final yesterday = DateTime(2027, 1, 30);
      final old = await db.waterDao.addWaterForDate(250, yesterday);
      for (var i = 0; i < 5; i++) {
        await db.waterDao.addWaterForDate(100, now);
      }
      final listing = await say('Show water entries today', 'water-read');
      expect(RegExp(r'#\d+').allMatches(listing.message), hasLength(3));
      final more = (await resolver.resolve('More water entries'))!.command!;
      expect(more.arguments['offset'], 3);
      expect(
        (await executor.execute(more, requestId: 'more')).message,
        isNot(contains('#$old ')),
      );
      await say('Correct water entry #$old to 500 ml', 'correct');
      final original = await (db.select(
        db.waterLogTable,
      )..where((w) => w.id.equals(old))).getSingle();
      expect(original.amountMl, 500);
      expect(original.date, yesterday);
      await say('Set daily water goal 3000 ml', 'goal');
      expect(await db.select(db.waterLogTable).get(), hasLength(6));
      await say('Delete water entry #$old', 'remove');
      expect(await db.select(db.waterLogTable).get(), hasLength(5));
    },
  );
  test(
    'Invalid, unapproved, missing, conflicting and failed writes leave domain records intact',
    () async {
      await expectLater(
        executor.execute(
          const RiyaCommand('savings.create', {
            'title': 'No approval',
            'targetAmount': 100,
          }),
          requestId: 'blocked',
        ),
        throwsStateError,
      );
      await expectLater(
        executor.execute(
          const RiyaCommand('savings.contribute', {'id': 999, 'amount': 10}),
          requestId: 'missing',
          approved: true,
        ),
        throwsStateError,
      );
      await expectLater(
        executor.execute(
          const RiyaCommand('hydration.edit', {'id': 999, 'amountMl': 500}),
          requestId: 'water-missing',
          approved: true,
        ),
        throwsStateError,
      );
      await expectLater(
        executor.execute(
          const RiyaCommand('budgets.set', {
            'monthlyLimit': 100,
            'dailyLimit': 10,
            'clearDaily': true,
          }),
          requestId: 'conflict',
          approved: true,
        ),
        throwsArgumentError,
      );
      await expectLater(
        executor.execute(
          const RiyaCommand('hydration.goal', {'amountMl': 10001}),
          requestId: 'large',
          approved: true,
        ),
        throwsArgumentError,
      );
      await db.customStatement(
        "CREATE TRIGGER fail_savings BEFORE INSERT ON savings_goals BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      await expectLater(
        executor.execute(
          const RiyaCommand('savings.create', {
            'title': 'Fails',
            'targetAmount': 100,
          }),
          requestId: 'failed',
          approved: true,
        ),
        throwsA(anything),
      );
      expect(await db.select(db.savingsGoalTable).get(), isEmpty);
      expect(await db.select(db.financeBudgetTable).get(), isEmpty);
      expect(await db.select(db.aiCommandTable).get(), isEmpty);
    },
  );
}
