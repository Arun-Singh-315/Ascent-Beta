import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/ai/riya_intents.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late RiyaIntentResolver resolver;
  late RiyaExecutor executor;
  late PromiseRepository promiseRepo;
  final now = DateTime(2026, 10, 26, 12);
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    resolver = RiyaIntentResolver(db, clock: () => now);
    executor = RiyaExecutor(db, clock: () => now);
    promiseRepo = PromiseRepository(db, clock: () => now);
  });
  tearDown(() => db.close());
  Future<RiyaResult> run(String text, String request) async {
    final command = (await resolver.resolve(text))!.command!;
    final result = await executor.execute(
      command,
      requestId: request,
      approved: true,
    );
    resolver.rememberResult(result);
    return result;
  }

  test(
    'everyday create wording keeps user values and asks only missing title',
    () async {
      final todo = (await resolver.resolve(
        'Create a todo to call Mom',
      ))!.command!;
      expect(todo.arguments['title'], 'call Mom');
      expect(
        (await resolver.resolve(
          'todo banao call Mom',
        ))!.command!.arguments['title'],
        'call Mom',
      );
      expect((await resolver.resolve('New Promise'))!.command, isNull);
      final restored = RiyaIntentResolver(db, clock: () => now)
        ..restoreConversation(resolver.conversationState);
      expect(
        (await restored.resolve('Read for 20 minutes every day'))!.command!.id,
        'promises.create',
      );
      await resolver.resolve('New todo');
      await resolver.resolve('Cancel');
      expect(
        (await resolver.resolve('Call Mom'))?.command?.id,
        isNot('tasks.create'),
      );
    },
  );
  test(
    'timed Promise uses Promise records, schedules and exactly-once receipts',
    () async {
      final c = (await resolver.resolve(
        'Create a promise to read for 20 minutes every day at 7 PM',
      ))!.command!;
      expect(c.id, 'promises.create');
      expect(
        (await resolver.resolve('Create a Promise to walk daily'))!.command!.id,
        'promises.create',
      );
      final saved = await executor.execute(c, requestId: 'one', approved: true);
      final repeat = await executor.execute(
        c,
        requestId: 'one',
        approved: true,
      );
      expect(repeat.entityId, saved.entityId);
      expect(repeat.replayed, isTrue);
      final p = (await promiseRepo.getPromiseById(saved.entityId!))!;
      expect(p.trackingType, PromiseTrackingType.duration);
      expect(p.targetValue, 20);
      expect(p.schedule!.repeat, PromiseRepeat.daily);
      expect(p.schedule!.plannedTime, '19:00');
      expect(p.reminderEnabled, isFalse);
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.thoughtTable).get(), hasLength(1));
    },
  );
  test(
    'list identities support ordinal rescheduling and stale edits fail',
    () async {
      await run('Create a todo to call Mom', 'one');
      await run('Create a todo to finish application', 'two');
      final list = await run('Show my todos', 'list');
      expect(list.records, hasLength(2));
      final second = list.records[1]['id'] as int;
      final move = (await resolver.resolve('dusra wala kal kar do'))!.command!;
      expect(move.id, 'tasks.reschedule');
      expect(move.arguments['taskIds'], [second]);
      await executor.execute(move, requestId: 'move', approved: true);
      expect(
        (await db.taskDao.getTaskById(second))!.plannedDate,
        DateTime(2026, 10, 27),
      );
      final edit = (await resolver.resolve(
        'Edit task #$second to Call Dad',
      ))!.command!;
      await run('Edit task #$second to Call family', 'newer-edit');
      await expectLater(
        executor.execute(edit, requestId: 'stale', approved: true),
        throwsStateError,
      );
    },
  );
  test(
    'Promise edit, pause, resume and delete keep proper lifecycle metadata',
    () async {
      final p = await run('Create a promise to read daily', 'create');
      final id = p.entityId!;
      final ask = await resolver.resolve('Edit promise #$id');
      expect(ask!.command, isNull);
      final rename = (await resolver.resolve('Read a book daily'))!.command!;
      await executor.execute(rename, requestId: 'rename', approved: true);
      await run('Pause promise #$id', 'pause');
      expect(
        (await promiseRepo.getPromiseById(id))!.isPaused,
        isTrue,
      );
      await run('Resume promise #$id', 'resume');
      await run('Check in promise #$id', 'checkin');
      expect(
        (await promiseRepo.getPromiseById(id))!.isDoneToday,
        isTrue,
      );
      final deleted = await run('Delete promise #$id', 'delete');
      expect(deleted.promiseEffectIds, [id]);
      expect(await promiseRepo.getPromiseById(id), isNull);
      expect(
        await db
            .customSelect(
              'SELECT * FROM promise_metadata WHERE promise_id = $id',
            )
            .get(),
        isEmpty,
      );
      final replay = await executor.execute(
        RiyaCommand('promises.delete', {
          'id': id,
          'expectedTitle': 'Read a book daily',
        }),
        requestId: 'delete',
        approved: true,
      );
      expect(replay.replayed, isTrue);
    },
  );
  test(
    'writes require approval and private records do not leak into follow-up questions',
    () async {
      final c = (await resolver.resolve(
        'Create a promise to read daily',
      ))!.command!;
      await expectLater(
        executor.execute(c, requestId: 'unapproved'),
        throwsStateError,
      );
      expect(await db.select(db.thoughtTable).get(), isEmpty);
      final p = await run(
        'Create a promise to read daily keep this private',
        'private',
      );
      final edit = await resolver.resolve('Edit promise #${p.entityId}');
      expect(edit!.command, isNull);
      expect(edit.message, isNot(contains('read daily')));
    },
  );
}
