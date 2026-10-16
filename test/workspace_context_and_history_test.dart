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
  test(
    'History pages are bounded, scoped, and keep their date across midnight',
    () async {
      for (var i = 0; i < 5; i++) {
        final id = await db.timeSessionDao.startSession(
          label: 'Focus $i',
          categoryId: 1,
          startedAt: now,
        );
        await db.timeSessionDao.heartbeat(id, 40);
      }
      await db.timeSessionDao.startSession(
        label: 'Lecture',
        categoryId: 1,
        activityRefType: 'lecture',
        learningCourseId: 'a',
        learningLectureId: 1,
        startedAt: now,
      );
      final initial = (await resolver.resolve('Show focus history'))!.command!;
      final page = await executor.execute(initial, requestId: 'history');
      expect(RegExp(r'#\d+').allMatches(page.message), hasLength(3));
      expect(page.message, isNot(contains('Lecture')));
      expect(page.message, contains('31/1/2027'));
      now = DateTime(2027, 2, 1, 1);
      final next = (await resolver.resolve('More focus history'))!.command!;
      expect(DateTime.parse(next.arguments['day']).day, 31);
      expect(
        (await executor.execute(next, requestId: 'more')).message,
        contains('31/1/2027'),
      );
      final tomorrow = (await resolver.resolve('Tomorrow'))!.command!;
      expect(tomorrow.id, 'focus.history');
      expect(DateTime.parse(tomorrow.arguments['day']), DateTime(2027, 2, 2));
      final lessons = await executor.execute(
        const RiyaCommand('learning.history', {'scope': 'all'}),
        requestId: 'learning',
      );
      expect(lessons.message, contains('Lecture'));
      expect(lessons.message, isNot(contains('Focus 0')));
    },
  );
  test(
    'History follow-ups cannot steal dates from a newer reminder list',
    () async {
      await resolver.resolve('Show focus history');
      final reminders = (await resolver.resolve('Show reminders'))!;
      expect(reminders.command!.id, 'reminders.list');
      final tomorrow = (await resolver.resolve('Tomorrow'))!;
      expect(tomorrow.command!.id, 'reminders.list');
      expect(tomorrow.command!.arguments['scope'], 'tomorrow');
    },
  );
  test(
    'Workspace replacement clears selected records and pending reminder drafts',
    () async {
      final result = await executor.execute(
        const RiyaCommand('thoughts.create', {'content': 'Old selected note'}),
        requestId: 'note',
        approved: true,
      );
      resolver.rememberResult(result);
      expect(
        (await resolver.resolve('Edit that to New title'))!.command,
        isNotNull,
      );
      await resolver.resolve('Remind me to call');
      db.markWorkspaceReplaced();
      expect((await resolver.resolve('7 PM'))?.command, isNull);
      expect(
        (await resolver.resolve('Edit that to New title'))!.command,
        isNull,
      );
      expect(
        (await db.select(db.thoughtTable).get()).single.content,
        'Old selected note',
      );
    },
  );
  test(
    'A reviewed command cannot cross into a replaced or recovering workspace',
    () async {
      final reviewed = RiyaExecutor(
        db,
        expectedWorkspaceRevision: db.workspaceRevision,
      );
      db.markWorkspaceReplaced();
      await expectLater(
        reviewed.execute(
          const RiyaCommand('thoughts.create', {'content': 'Old approval'}),
          requestId: 'stale',
          approved: true,
        ),
        throwsStateError,
      );
      await db
          .into(db.backupRestoreTable)
          .insert(
            BackupRestoreTableCompanion.insert(
              id: 'pending',
              preferencesJson: '{}',
            ),
          );
      await expectLater(
        executor.execute(
          const RiyaCommand('thoughts.create', {'content': 'During recovery'}),
          requestId: 'recovering',
          approved: true,
        ),
        throwsStateError,
      );
      expect(await db.select(db.thoughtTable).get(), isEmpty);
      expect(await db.select(db.aiCommandTable).get(), isEmpty);
    },
  );
  test(
    'Typed Learning completion uses recorded evidence and is idempotent',
    () async {
      final session = await db.timeSessionDao.startSession(
        label: 'Recorded lesson',
        categoryId: 1,
        activityRefType: 'lecture',
        learningCourseId: 'a',
        learningLectureId: 1,
        startedAt: now.subtract(const Duration(hours: 2)),
      );
      await db.timeSessionDao.heartbeat(session, 45);
      await db.timeSessionDao.completeSession(session, endedAt: now);
      await db.timeSessionDao.completeSession(
        session,
        endedAt: now.add(const Duration(hours: 1)),
      );
      final row = (await db.select(db.timeSessionTable).get()).single;
      expect(row.durationSeconds, 45);
      expect(row.endedAt, now);
    },
  );
}
