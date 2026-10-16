import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/thought_actions.dart';

void main() {
  late AppDatabase db;
  late ThoughtActions actions;
  Future<Thought> note(String text) async {
    final id = await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(content: text),
    );
    return (await db.thoughtDao.getThoughtById(id))!;
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    actions = ThoughtActions(db);
  });
  tearDown(() async => db.close());
  test(
    'Grouping cannot make a linked checklist parent its own child',
    () async {
      final first = await note('Parent note'),
          second = await note('Child note');
      final converted = await actions.convert([
        first,
        second,
      ], mode: ThoughtConversionMode.todo);
      await (db.update(
        db.taskTable,
      )..where((t) => t.id.equals(converted.taskIds.last))).write(
        TaskTableCompanion(parentTaskId: drift.Value(converted.taskIds.first)),
      );
      await expectLater(
        actions.convert(
          [first, second],
          mode: ThoughtConversionMode.todo,
          grouped: true,
        ),
        throwsStateError,
      );
      expect(
        (await db.taskDao.getTaskById(converted.taskIds.first))!.parentTaskId,
        isNull,
      );
    },
  );

  test(
    'Both is atomic, links actual sources and repeated execution reuses records',
    () async {
      final notes = [await note('Same words'), await note('Same words')];
      final at = DateTime.now().add(const Duration(days: 1));
      final first = await actions.convert(
        notes,
        mode: ThoughtConversionMode.both,
        at: at,
      );
      final second = await actions.convert(
        notes,
        mode: ThoughtConversionMode.both,
        at: at,
      );
      expect(first.taskIds, second.taskIds);
      expect(
        first.reminders.map((r) => r.id),
        second.reminders.map((r) => r.id),
      );
      expect(await db.select(db.taskTable).get(), hasLength(2));
      expect(await db.select(db.reminderTable).get(), hasLength(2));
      await db.taskDao.markComplete(first.taskIds.first);
      expect(
        (await db.thoughtDao.getThoughtById(notes.first.id))!.isCompleted,
        isTrue,
      );
      expect(
        (await db.thoughtDao.getThoughtById(notes.last.id))!.isCompleted,
        isFalse,
      );
    },
  );
  test(
    'Long notes create bounded task titles without losing source text',
    () async {
      final original = await note(List.filled(400, '界').join());
      final ids = await actions.addToTodo([original]);
      expect(
        (await db.taskDao.getTaskById(ids.single))!.title.length,
        lessThanOrEqualTo(300),
      );
      expect(
        (await db.thoughtDao.getThoughtById(original.id))!.content,
        original.content,
      );
    },
  );
  test('Invalid schedule rolls Both back before any task is saved', () async {
    final original = await note('Call');
    await expectLater(
      actions.convert(
        [original],
        mode: ThoughtConversionMode.both,
        at: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.taskTable).get(), isEmpty);
    expect(await db.select(db.reminderTable).get(), isEmpty);
  });
  test(
    'Grouped conversion has a checklist and parent cannot complete unfinished items',
    () async {
      final notes = [await note('First'), await note('Second')];
      final result = await actions.convert(
        notes,
        mode: ThoughtConversionMode.todo,
        grouped: true,
      );
      final parent = await db.taskDao.getTaskById(result.taskIds.single);
      final children = await (db.select(
        db.taskTable,
      )..where((t) => t.parentTaskId.equals(parent!.id))).get();
      expect(children, hasLength(2));
      expect(await db.taskDao.markComplete(parent!.id), isFalse);
      for (final child in children) {
        expect(await db.taskDao.markComplete(child.id), isTrue);
      }
      expect(await db.taskDao.markComplete(parent.id), isTrue);
    },
  );
  test('Reminder-only creates no tasks and links notes explicitly', () async {
    final notes = [await note('One'), await note('Two')];
    final result = await actions.convert(
      notes,
      mode: ThoughtConversionMode.reminder,
      grouped: true,
      at: DateTime.now().add(const Duration(hours: 1)),
    );
    expect(result.taskIds, isEmpty);
    expect(result.reminders, hasLength(1));
    expect(await db.select(db.taskTable).get(), isEmpty);
    expect(await db.select(db.thoughtReminderLinkTable).get(), hasLength(2));
  });
  test(
    'Merge preserves order, sources and links; Undo restores explicit archival',
    () async {
      final notes = [await note('First'), await note('Second')];
      final task = (await actions.addToTodo([notes.first])).single;
      final merged = await actions.merge(notes, archiveSources: true);
      expect(merged.content, 'First\n\nSecond');
      expect(
        (await db.thoughtDao.getThoughtById(notes.first.id))!.isArchived,
        isTrue,
      );
      expect(
        (await db.taskDao.getTaskById(task))!.linkedThoughtId,
        notes.first.id,
      );
      expect(await actions.undoMerge(merged.id), isTrue);
      expect(await db.thoughtDao.getThoughtById(merged.id), isNull);
      expect(
        (await db.thoughtDao.getThoughtById(notes.first.id))!.isArchived,
        isFalse,
      );
      expect(await db.taskDao.getTaskById(task), isNotNull);
    },
  );
  test(
    'Edited merged notes cannot be erased by Undo; stale sources cannot merge',
    () async {
      final notes = [await note('One'), await note('Two')];
      final merged = await actions.merge(notes);
      await db.thoughtDao.updateThought(
        merged
            .toCompanion(true)
            .copyWith(content: const drift.Value('New work')),
      );
      expect(await actions.undoMerge(merged.id), isFalse);
      await db.thoughtDao.updateThought(
        notes.first
            .toCompanion(true)
            .copyWith(content: const drift.Value('Changed')),
      );
      await expectLater(actions.merge(notes), throwsStateError);
      expect(
        (await db.thoughtDao.getThoughtById(merged.id))!.content,
        'New work',
      );
    },
  );
}
