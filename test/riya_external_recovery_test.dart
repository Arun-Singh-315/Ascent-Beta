import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';

void main() {
  late AppDatabase db;
  late RiyaExecutor executor;
  bool visible = false;
  int calls = 0;
  const command = RiyaCommand('home.visibility', {
    'section': 'mind',
    'visible': true,
  });
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    visible = false;
    calls = 0;
    executor = RiyaExecutor(
      db,
      external: (command) async {
        calls++;
        // A stateful adapter must see its prepare receipt outside the SQL TX.
        final rows = await db.select(db.aiCommandTable).get();
        expect(rows, isNotEmpty);
        visible = command.arguments['visible'] == true;
        return const RiyaResult('Home visibility saved.', '/home');
      },
      verifyExternal: (command) async => visible == command.arguments['visible']
          ? const RiyaResult('Home visibility verified.', '/home')
          : null,
    );
  });
  tearDown(() async => db.close());

  test('Concurrent and later retries publish one stateful change', () async {
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        executor.execute(command, requestId: 'same', approved: true),
    ]);
    expect(calls, 1);
    expect(visible, true);
    expect(results.last.replayed, true);
    expect(
      (await executor.execute(
        command,
        requestId: 'same',
        approved: true,
      )).replayed,
      true,
    );
    expect(calls, 1);
    expect(await db.select(db.aiCommandTable).get(), hasLength(1));
    await expectLater(
      executor.execute(
        const RiyaCommand('home.visibility', {
          'section': 'today',
          'visible': true,
        }),
        requestId: 'same',
        approved: true,
      ),
      throwsStateError,
    );
  });

  test('A prepare failure prevents the external domain change', () async {
    await db.customStatement(
      "CREATE TRIGGER reject_prepare BEFORE INSERT ON ${db.aiCommandTable.actualTableName} BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    await expectLater(
      executor.execute(command, requestId: 'prepare', approved: true),
      throwsA(anything),
    );
    expect(calls, 0);
    expect(visible, false);
  });

  test(
    'A failed confirmation receipt reports the committed change and verifies without repeating it',
    () async {
      await db.customStatement(
        "CREATE TRIGGER reject_receipt BEFORE UPDATE ON ${db.aiCommandTable.actualTableName} WHEN OLD.request_id = 'recover' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        executor.execute(command, requestId: 'recover', approved: true),
        throwsA(
          isA<RiyaCommittedActionError>().having(
            (e) => e.result.message,
            'saved result',
            contains('saved'),
          ),
        ),
      );
      expect(visible, true);
      expect(calls, 1);
      final receipt = (await db.select(db.aiCommandTable).get()).single;
      expect(jsonDecode(receipt.resultJson)['executionStatus'], 'prepared');
      await db.customStatement('DROP TRIGGER reject_receipt');
      expect(
        (await executor.execute(
          command,
          requestId: 'recover',
          approved: true,
        )).message,
        contains('verified'),
      );
      expect(calls, 1);
      expect(
        jsonDecode(
          (await db.select(db.aiCommandTable).get()).single.resultJson,
        )['message'],
        contains('verified'),
      );
    },
  );

  test(
    'Recovering an old uncertain request cannot overwrite a newer change',
    () async {
      await db.customStatement(
        "CREATE TRIGGER reject_receipt BEFORE UPDATE ON ${db.aiCommandTable.actualTableName} BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        executor.execute(command, requestId: 'old', approved: true),
        throwsA(isA<RiyaCommittedActionError>()),
      );
      await db.customStatement('DROP TRIGGER reject_receipt');
      visible = false; // A later explicit user change.
      await expectLater(
        executor.execute(command, requestId: 'old', approved: true),
        throwsStateError,
      );
      expect(visible, false);
      expect(calls, 1);
      await expectLater(
        executor.execute(command, requestId: 'unapproved'),
        throwsStateError,
      );
      expect(calls, 1);
    },
  );
}
