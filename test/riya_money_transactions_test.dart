import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/ai/riya_intents.dart';

void main() {
  late AppDatabase db;
  late RiyaExecutor executor;
  late RiyaIntentResolver resolver;
  var now = DateTime(2027, 1, 31, 18);
  setUp(() {
    now = DateTime(2027, 1, 31, 18);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    executor = RiyaExecutor(db, clock: () => now);
    resolver = RiyaIntentResolver(db, clock: () => now);
  });
  tearDown(() async => db.close());
  Future<RiyaResult> run(
    String id,
    Map<String, dynamic> fields,
    String request,
  ) => executor.execute(
    RiyaCommand(id, fields),
    requestId: request,
    approved: true,
  );
  test(
    'Income CRUD is confirmed, retry-safe, and preserves unedited metadata',
    () async {
      final command = (await resolver.resolve(
        'Record income 25000 from Salary on 2027-01-31',
      ))!.command!;
      await expectLater(
        executor.execute(command, requestId: 'unconfirmed'),
        throwsStateError,
      );
      expect(await db.select(db.financeTransactionTable).get(), isEmpty);
      final result = await executor.execute(
        command,
        requestId: 'salary',
        approved: true,
      );
      expect(
        (await executor.execute(
          command,
          requestId: 'salary',
          approved: true,
        )).replayed,
        true,
      );
      final id = result.entityId!;
      resolver.rememberResult(result);
      final edit = (await resolver.resolve(
        'Edit that account to bank account',
      ))!.command!;
      await executor.execute(edit, requestId: 'account', approved: true);
      await run('transactions.edit', {
        'id': id,
        'notes': 'Payslip',
        'category': 'other',
      }, 'notes');
      await run('transactions.edit', {'id': id, 'amount': 26000}, 'correction');
      final row = (await db.select(db.financeTransactionTable).get()).single;
      expect(row.type, 'income');
      expect(row.amount, 26000);
      expect(row.account, 'Bank Account');
      expect(row.notes, 'Payslip');
      expect(row.date, DateTime(2027, 1, 31));
      expect(await db.financeDao.watchMonthSpending(2027, 1).first, 0);
      expect(await db.financeDao.watchMonthIncome(2027, 1).first, 26000);
      await run('transactions.edit', {'id': id, 'clearNotes': true}, 'clear');
      expect(
        (await db.select(db.financeTransactionTable).get()).single.notes,
        isNull,
      );
      await run('transactions.delete', {'id': id}, 'delete');
      expect(await db.select(db.financeTransactionTable).get(), isEmpty);
      expect(
        (await run('transactions.delete', {'id': id}, 'delete')).replayed,
        true,
      );
      await expectLater(
        run('transactions.read', {'id': id}, 'readmissing'),
        throwsStateError,
      );
    },
  );
  test(
    'Lists stay bounded, date-anchored, and domain-specific across midnight',
    () async {
      for (var i = 0; i < 5; i++) {
        await run('transactions.create', {
          'title': 'Income $i',
          'amount': 100,
          'type': 'income',
        }, 'income$i');
      }
      await run('transactions.create', {
        'title': 'Snack',
        'amount': 40,
        'type': 'expense',
      }, 'snack');
      final list = (await resolver.resolve('Show income'))!.command!;
      final result = await executor.execute(list, requestId: 'list');
      expect(RegExp(r'#\d+').allMatches(result.message), hasLength(3));
      expect(result.message, isNot(contains('Snack')));
      now = DateTime(2027, 2, 1);
      final more = (await resolver.resolve('More income'))!.command!;
      expect(DateTime.parse(more.arguments['day']), DateTime(2027, 1, 31));
      expect(
        RegExp(
          r'#\d+',
        ).allMatches((await executor.execute(more, requestId: 'more')).message),
        hasLength(2),
      );
      await resolver.resolve('Show reminders');
      expect(
        (await resolver.resolve('Tomorrow'))!.command!.id,
        'reminders.list',
      );
      await resolver.resolve('Show focus history');
      expect(
        (await resolver.resolve('Tomorrow'))!.command!.id,
        'focus.history',
      );
    },
  );
  test(
    'Summary separates income, spending, and legacy transfer records',
    () async {
      await run('transactions.create', {
        'title': 'Salary',
        'amount': 1000,
        'type': 'income',
      }, 'income');
      await run('transactions.create', {
        'title': 'Food',
        'amount': 150,
        'type': 'expense',
      }, 'expense');
      await db.financeDao.insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: 'Legacy transfer',
          amount: 400,
          date: now,
          type: const drift.Value('transfer'),
        ),
      );
      final result = await run('transactions.summary', {
        'from': '2027-01-31',
        'to': '2027-02-01',
      }, 'summary');
      expect(result.message, contains('income ₹1000.00'));
      expect(result.message, contains('spending ₹150.00'));
      expect(result.message, contains('net ₹850.00'));
      expect(
        (await run('transactions.list', {'scope': 'all'}, 'all')).message,
        contains('Legacy transfer'),
      );
    },
  );
  test('Invalid writes leave rows and receipts untouched', () async {
    final cases = <Map<String, dynamic>>[
      {'type': 'transfer'},
      {'amount': double.infinity},
      {'amount': 0},
      {'title': 'x' * 201},
      {'category': 'Imaginary'},
      {'account': 'Imaginary'},
      {'date': '2027-02-30'},
      {'clearNotes': true},
    ];
    for (var i = 0; i < cases.length; i++) {
      await expectLater(
        run('transactions.create', {
          'title': 'Test',
          'amount': 1,
          'type': 'income',
          ...cases[i],
        }, 'bad$i'),
        throwsA(anything),
      );
    }
    expect(await db.select(db.financeTransactionTable).get(), isEmpty);
    expect(await db.select(db.aiCommandTable).get(), isEmpty);
    await expectLater(
      run('transactions.summary', {
        'from': '2027-02-01',
        'to': '2027-01-01',
      }, 'reverse'),
      throwsArgumentError,
    );
  });
  test(
    'Month totals include the final fractional second and exclude next month',
    () async {
      for (final type in ['expense', 'income']) {
        await db.financeDao.insertTransaction(
          FinanceTransactionTableCompanion.insert(
            title: 'Last',
            amount: 10,
            date: DateTime(2027, 1, 31, 23, 59, 59, 999),
            type: drift.Value(type),
          ),
        );
        await db.financeDao.insertTransaction(
          FinanceTransactionTableCompanion.insert(
            title: 'Next',
            amount: 100,
            date: DateTime(2027, 2, 1),
            type: drift.Value(type),
          ),
        );
      }
      expect(await db.financeDao.watchMonthSpending(2027, 1).first, 10);
      expect(await db.financeDao.watchMonthIncome(2027, 1).first, 10);
      expect(
        (await db.financeDao.watchCategorySpending(2027, 1).first)['Other'],
        10,
      );
    },
  );
  test(
    'Existing expense commands default to Today and offer scoped follow-ups',
    () async {
      await run('transactions.create', {
        'title': 'Old expense',
        'amount': 10,
        'type': 'expense',
        'date': '2027-01-30',
      }, 'oldexpense');
      await run('transactions.create', {
        'title': 'Today expense',
        'amount': 20,
        'type': 'expense',
      }, 'todayexpense');
      final initial = (await resolver.resolve('Show expenses'))!.command!;
      final result = await executor.execute(initial, requestId: 'expenses');
      expect(result.message, contains('Today expense'));
      expect(result.message, isNot(contains('Old expense')));
      final all = (await resolver.resolve('Show expenses all'))!.command!;
      expect(
        (await executor.execute(all, requestId: 'allexpenses')).message,
        contains('Old expense'),
      );
      final tomorrow = (await resolver.resolve('Tomorrow'))!.command!;
      expect(tomorrow.id, 'expenses.list');
      expect(
        (await executor.execute(
          tomorrow,
          requestId: 'tomorrowexpenses',
        )).message,
        contains('No recorded'),
      );
    },
  );
  test(
    'Selected transactions cannot leak into thought edits or replacement',
    () async {
      final result = await run('transactions.create', {
        'title': 'Salary',
        'amount': 1,
        'type': 'income',
      }, 'salary');
      resolver.rememberResult(result);
      await resolver.resolve('Show thoughts');
      expect(
        (await resolver.resolve('Edit that amount to 2'))!.command,
        isNull,
      );
      resolver.rememberResult(result);
      db.markWorkspaceReplaced();
      expect(
        (await resolver.resolve('Edit that amount to 2'))!.command,
        isNull,
      );
    },
  );
}
