import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';
import 'package:ascent/core/ai/riya_intents.dart';
import 'package:ascent/core/ai/riya_alert_effects.dart';

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
  test(
    'Calendar validation rejects normalized impossible dates and keeps valid timezone dates',
    () async {
      for (final value in [
        '2027-02-31',
        '2027-13-01',
        '2027-02-01T24:00:00',
        '2027-02-01T12:60:00',
      ]) {
        await expectLater(
          executor.execute(
            RiyaCommand('tasks.create', {
              'title': 'Invalid date',
              'plannedDate': value,
            }),
            requestId: value,
            approved: true,
          ),
          throwsArgumentError,
        );
      }
      expect(await db.select(db.taskTable).get(), isEmpty);
      executor.validate(
        const RiyaCommand('tasks.create', {
          'title': 'Timezone valid',
          'plannedDate': '2027-02-01T00:30:00+14:00',
        }),
      );
      executor.validate(
        const RiyaCommand('tasks.create', {
          'title': 'Leap day',
          'plannedDate': '2028-02-29',
        }),
      );
    },
  );

  test(
    'Legacy task questions use bounded pages and preserve Show more context',
    () async {
      for (var i = 0; i < 7; i++) {
        await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Task $i',
            plannedDate: d.Value(now),
          ),
        );
      }
      final first = (await resolver.resolve(
        'What tasks do I have today?',
      ))!.command!;
      expect(first.id, 'tasks.today');
      final page = await executor.execute(first, requestId: 'tasks-read');
      expect(RegExp(r'#\d+').allMatches(page.message), hasLength(3));
      expect(page.options, contains('More tasks'));
      final next = (await resolver.resolve('More tasks'))!.command!;
      expect(next.arguments['offset'], 3);
      final second = await executor.execute(next, requestId: 'tasks-more');
      expect(RegExp(r'#\d+').allMatches(second.message), hasLength(3));
      expect(second.message, isNot(page.message));
    },
  );

  test(
    'Conversion asks a short time follow-up; another command and Cancel cannot submit it',
    () async {
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Convert safely'),
      );
      final request = await resolver.resolve('Convert note #$id to both');
      expect(request!.command, isNull);
      expect(request.message, contains('Today by default'));
      await resolver.resolve('Tomorrow');
      final command = (await resolver.resolve('7 PM'))!.command!;
      expect(command.id, 'thoughts.convert');
      expect(DateTime.parse(command.arguments['at']), DateTime(2027, 2, 1, 19));
      await executor.execute(command, requestId: 'conversion', approved: true);
      expect(await db.select(db.taskTable).get(), hasLength(1));
      expect(await db.select(db.reminderTable).get(), hasLength(1));
      await resolver.resolve('Convert note #$id to reminder');
      expect(
        (await resolver.resolve('Read note #$id'))!.command!.id,
        'thoughts.read',
      );
      expect((await resolver.resolve('8 PM'))?.command, isNull);
      await resolver.resolve('Convert note #$id to reminder');
      await resolver.resolve('Cancel');
      expect((await resolver.resolve('8 PM'))?.command, isNull);
    },
  );

  test(
    'Reminder lists default to today, bound previews and keep overdue separate',
    () async {
      for (var i = 0; i < 5; i++) {
        await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: 'Today $i',
            scheduledAt: now.add(Duration(minutes: 10 + i)),
          ),
        );
      }
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Tomorrow only',
          scheduledAt: DateTime(2027, 2, 1, 8),
        ),
      );
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Missed',
          scheduledAt: now.subtract(const Duration(hours: 1)),
        ),
      );
      final command = (await resolver.resolve('Show reminders'))!.command!;
      final result = await executor.execute(command, requestId: 'read');
      expect(result.message, contains('Today: 5 reminders'));
      expect(result.message, isNot(contains('Tomorrow only')));
      expect(result.message, contains('1 overdue'));
      expect(RegExp(r'#\d+').allMatches(result.message), hasLength(3));
      final tomorrow = (await resolver.resolve('Tomorrow'))!.command!;
      expect(
        (await executor.execute(tomorrow, requestId: 'tomorrow')).message,
        contains('Tomorrow only'),
      );
    },
  );
  test(
    'Reminder creation owns its date followup even after listing context',
    () async {
      await resolver.resolve('Show reminders');
      expect((await resolver.resolve('Remind me to call'))!.command, isNull);
      expect((await resolver.resolve('Tomorrow'))!.command, isNull);
      final created = (await resolver.resolve('7 PM'))!.command!;
      expect(created.id, 'reminders.create');
      expect(DateTime.parse(created.arguments['at']), DateTime(2027, 2, 1, 19));
      await resolver.resolve('Cancel');
      expect((await resolver.resolve('7 PM'))?.command, isNull);
    },
  );
  test(
    'Thought create/edit/pin/archive/delete share real records and replay once',
    () async {
      final command = (await resolver.resolve(
        'Save note: Keep steady',
      ))!.command!;
      final first = await executor.execute(
        command,
        requestId: 'note',
        approved: true,
      );
      final second = await executor.execute(
        command,
        requestId: 'note',
        approved: true,
      );
      expect(second.replayed, isTrue);
      expect(await db.select(db.thoughtTable).get(), hasLength(1));
      resolver.rememberResult(first);
      final edit = (await resolver.resolve(
        'Edit that to Keep moving',
      ))!.command!;
      await executor.execute(edit, requestId: 'edit', approved: true);
      final note = (await db.select(db.thoughtTable).get()).single;
      expect(note.content, 'Keep moving');
      await executor.execute(
        RiyaCommand('thoughts.pin', {'id': note.id, 'pinned': true}),
        requestId: 'pin',
        approved: true,
      );
      expect((await db.thoughtDao.getThoughtById(note.id))!.isPinned, isTrue);
      await executor.execute(
        RiyaCommand('thoughts.archive', {
          'noteIds': [note.id],
          'archived': true,
        }),
        requestId: 'archive',
        approved: true,
      );
      expect((await db.thoughtDao.getThoughtById(note.id))!.isArchived, isTrue);
      await executor.execute(
        RiyaCommand('thoughts.delete', {
          'noteIds': [note.id],
        }),
        requestId: 'delete',
        approved: true,
      );
      expect(await db.thoughtDao.getThoughtById(note.id), isNull);
    },
  );
  test(
    'Names with numbers and SQL wildcard characters resolve literally',
    () async {
      final wanted = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Save 50% for 2 books'),
      );
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Another note'),
      );
      final literal = (await resolver.resolve(
        'Delete note Save 50% for 2 books',
      ))!.command!;
      expect(literal.arguments['noteIds'], [wanted]);
      expect((await resolver.resolve('Delete note _'))!.command, isNull);
    },
  );
  test(
    'Ambiguous edits clarify and cancel prevents a queued mutation',
    () async {
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Coffee one'),
      );
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Coffee two'),
      );
      final choices = await resolver.resolve('Pin note Coffee');
      expect(choices!.command, isNull);
      expect(choices.options, hasLength(2));
      await resolver.resolve('Cancel');
      expect((await resolver.resolve('#1'))?.command, isNull);
      expect(
        (await db.select(db.thoughtTable).get()).every((n) => !n.isPinned),
        isTrue,
      );
    },
  );
  test(
    'Task completion and deletion cannot bypass duration or orphan links',
    () async {
      final task = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Study',
          estimatedMinutes: const d.Value(20),
        ),
      );
      final reminder = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Study',
          scheduledAt: DateTime(2028),
          linkedTaskId: d.Value(task),
        ),
      );
      await expectLater(
        executor.execute(
          RiyaCommand('tasks.complete', {'id': task}),
          requestId: 'complete',
          approved: true,
        ),
        throwsStateError,
      );
      final deleted = await executor.execute(
        RiyaCommand('tasks.delete', {'id': task}),
        requestId: 'remove',
        approved: true,
      );
      expect(deleted.cancelReminderIds, [reminder]);
      expect(await db.taskDao.getTaskById(task), isNull);
      expect(await db.reminderDao.getReminderById(reminder), isNull);
    },
  );
  test(
    'OS failure leaves a durable receipt; retry succeeds with the same ID',
    () async {
      final id = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Call',
          scheduledAt: DateTime(2028),
        ),
      );
      await executor.execute(
        RiyaCommand('reminders.delete', {'id': id}),
        requestId: 'cancel-native',
        approved: true,
      );
      var failed = true, calls = 0;
      final effects = RiyaAlertEffects(
        db,
        cancel: (_) async {
          calls++;
          return !failed;
        },
        schedule: (_) async => true,
      );
      expect(await effects.syncRequest('cancel-native'), isFalse);
      failed = false;
      expect(await effects.syncRequest('cancel-native'), isTrue);
      expect(calls, 2);
      expect(
        (await (db.select(
              db.aiCommandTable,
            )..where((r) => r.requestId.equals('cancel-native'))).getSingle())
            .resultJson,
        contains('"alertEffectsPending":false'),
      );
    },
  );
  test('New reflection is not persisted until explicit Save', () async {
    final suggestion = (await resolver.resolve('Give me a thought'))!;
    expect(suggestion.message, contains('separate from your saved notes'));
    expect(await db.select(db.thoughtTable).get(), isEmpty);
    final save = (await resolver.resolve('Save this thought'))!.command!;
    await executor.execute(save, requestId: 'reflection-save', approved: true);
    expect(await db.select(db.thoughtTable).get(), hasLength(1));
  });
  test(
    'Every write still requires confirmation and invalid fields fail before mutation',
    () async {
      await expectLater(
        executor.execute(
          const RiyaCommand('thoughts.create', {'content': 'No permission'}),
          requestId: 'blocked',
        ),
        throwsStateError,
      );
      await expectLater(
        executor.execute(
          const RiyaCommand('thoughts.create', {
            'content': ' ',
            'invented': true,
          }),
          requestId: 'invalid',
          approved: true,
        ),
        throwsArgumentError,
      );
      expect(await db.select(db.thoughtTable).get(), isEmpty);
    },
  );
}
