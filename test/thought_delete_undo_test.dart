import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<({Thought note, int task, int reminder, int merge, int other})>
  fixture() async {
    final note = await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(content: 'Linked thought'),
    );
    final other = await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(content: 'Merged note'),
    );
    final task = await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Linked Todo',
        linkedThoughtId: d.Value(note),
      ),
    );
    final reminder = await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Reminder',
        linkedTaskId: d.Value(task),
        scheduledAt: DateTime(2030),
      ),
    );
    await db
        .into(db.thoughtReminderLinkTable)
        .insert(
          ThoughtReminderLinkTableCompanion.insert(
            thoughtId: note,
            reminderId: reminder,
          ),
        );
    final merge = await db
        .into(db.thoughtMergeSourceTable)
        .insert(
          ThoughtMergeSourceTableCompanion.insert(
            mergedThoughtId: other,
            sourceThoughtId: d.Value(note),
            position: 0,
            sourceSnapshot: 'Linked thought',
            mergedSnapshot: 'Merged note',
          ),
        );
    return (
      note: (await db.thoughtDao.getThoughtById(note))!,
      task: task,
      reminder: reminder,
      merge: merge,
      other: other,
    );
  }

  Future<void> expectRestored(
    int note,
    int task,
    int reminder,
    int merge,
  ) async {
    expect(await db.thoughtDao.getThoughtById(note), isNotNull);
    expect((await db.taskDao.getTaskById(task))!.linkedThoughtId, note);
    expect(
      (await db.select(db.thoughtReminderLinkTable).get()).single.reminderId,
      reminder,
    );
    expect(
      (await db.select(db.thoughtMergeSourceTable).get()).single.id,
      merge,
    );
    expect(
      (await db.select(db.thoughtMergeSourceTable).get())
          .single
          .sourceThoughtId,
      note,
    );
    expect(
      (await db.reminderDao.getReminderById(reminder))!.linkedTaskId,
      task,
    );
  }

  test(
    'Undo restores note, Todo, reminder and both merge directions',
    () async {
      final f = await fixture();
      final outgoing = await db
          .into(db.thoughtMergeSourceTable)
          .insert(
            ThoughtMergeSourceTableCompanion.insert(
              mergedThoughtId: f.note.id,
              sourceThoughtId: d.Value(f.other),
              position: 0,
              sourceSnapshot: 'Other',
              mergedSnapshot: 'Linked thought',
            ),
          );
      final token = (await db.thoughtDao.deleteThoughtForUndo(f.note.id))!;
      expect((await db.taskDao.getTaskById(f.task))!.linkedThoughtId, isNull);
      expect(await db.select(db.thoughtReminderLinkTable).get(), isEmpty);
      expect(await db.thoughtDao.restoreThoughtDeletion(token), true);
      expect(await db.thoughtDao.getThoughtById(f.note.id), f.note);
      expect(
        (await db.taskDao.getTaskById(f.task))!.linkedThoughtId,
        f.note.id,
      );
      final links = await db.select(db.thoughtMergeSourceTable).get();
      expect(links, hasLength(2));
      expect(
        links.singleWhere((r) => r.id == outgoing).sourceThoughtId,
        f.other,
      );
      expect(
        links.singleWhere((r) => r.id == f.merge).sourceThoughtId,
        f.note.id,
      );
      expect(await db.select(db.thoughtReminderLinkTable).get(), hasLength(1));
      expect(await db.thoughtDao.restoreThoughtDeletion(token), false);
    },
  );

  test('newer task edits and changed merge snapshots are preserved', () async {
    final f = await fixture();
    final token = (await db.thoughtDao.deleteThoughtForUndo(f.note.id))!;
    await (db.update(db.taskTable)..where((r) => r.id.equals(f.task))).write(
      const TaskTableCompanion(title: d.Value('Newer title')),
    );
    await (db.update(
      db.thoughtMergeSourceTable,
    )..where((r) => r.id.equals(f.merge))).write(
      const ThoughtMergeSourceTableCompanion(
        sourceSnapshot: d.Value('Newer snapshot'),
      ),
    );
    expect(await db.thoughtDao.restoreThoughtDeletion(token), true);
    final task = (await db.taskDao.getTaskById(f.task))!;
    expect(task.title, 'Newer title');
    expect(task.linkedThoughtId, isNull);
    final merge = (await db.select(db.thoughtMergeSourceTable).get()).single;
    expect(merge.sourceSnapshot, 'Newer snapshot');
    expect(merge.sourceThoughtId, isNull);
  });

  test(
    'new associations and removed merge links are not overwritten',
    () async {
      final f = await fixture();
      final token = (await db.thoughtDao.deleteThoughtForUndo(f.note.id))!;
      await (db.update(db.taskTable)..where((r) => r.id.equals(f.task))).write(
        TaskTableCompanion(linkedThoughtId: d.Value(f.other)),
      );
      await (db.delete(
        db.thoughtMergeSourceTable,
      )..where((r) => r.id.equals(f.merge))).go();
      expect(await db.thoughtDao.restoreThoughtDeletion(token), true);
      expect((await db.taskDao.getTaskById(f.task))!.linkedThoughtId, f.other);
      expect(await db.select(db.thoughtMergeSourceTable).get(), isEmpty);
    },
  );

  test(
    'stale token cannot restore a later deletion or replaced workspace',
    () async {
      final f = await fixture();
      final first = (await db.thoughtDao.deleteThoughtForUndo(f.note.id))!;
      expect(await db.thoughtDao.restoreThoughtDeletion(first), true);
      final second = (await db.thoughtDao.deleteThoughtForUndo(f.note.id))!;
      expect(await db.thoughtDao.restoreThoughtDeletion(first), false);
      expect(await db.thoughtDao.getThoughtById(f.note.id), isNull);
      db.clearDeletionUndo();
      expect(await db.thoughtDao.restoreThoughtDeletion(second), false);
    },
  );

  test('failed restore rolls back relationships and can be retried', () async {
    final f = await fixture();
    final token = (await db.thoughtDao.deleteThoughtForUndo(f.note.id))!;
    await db.customStatement(
      "CREATE TRIGGER fail_restore BEFORE INSERT ON thought_reminder_links BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
    );
    await expectLater(
      db.thoughtDao.restoreThoughtDeletion(token),
      throwsA(anything),
    );
    expect(await db.thoughtDao.getThoughtById(f.note.id), isNull);
    expect((await db.taskDao.getTaskById(f.task))!.linkedThoughtId, isNull);
    await db.customStatement('DROP TRIGGER fail_restore');
    expect(await db.thoughtDao.restoreThoughtDeletion(token), true);
    await expectRestored(f.note.id, f.task, f.reminder, f.merge);
  });

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  for (final menu in [true, false]) {
    testWidgets(
      '${menu ? 'Menu' : 'Swipe'} Undo restores connected relationships',
      (tester) async {
        final f = await fixture();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: StreamBuilder<List<Thought>>(
                    stream: db.thoughtDao.watchActiveThoughts(),
                    builder: (context, state) =>
                        state.data?.any((n) => n.id == f.note.id) == true
                        ? ThoughtCardBubble(thought: f.note, index: 0)
                        : const SizedBox(),
                  ),
                ),
              ),
            ),
          ),
        );
        await flush(tester);
        if (menu) {
          // Dispatch the real menu selection; geometry is outside this Undo regression.
          tester
              .widget<PopupMenuButton<String>>(
                find.byType(PopupMenuButton<String>),
              )
              .onSelected!('delete');
        } else {
          await tester.drag(find.byType(Dismissible), const Offset(-700, 0));
        }
        await flush(tester);
        expect(
          await tester.runAsync(() => db.thoughtDao.getThoughtById(f.note.id)),
          isNull,
        );
        await tester.tap(find.text('Undo'));
        await flush(tester);
        await tester.runAsync(
          () => expectRestored(f.note.id, f.task, f.reminder, f.merge),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
  for (final failDelete in [true, false]) {
    testWidgets(
      failDelete
          ? 'Delete failure is visible and keeps the note'
          : 'Undo failure is visible and Retry restores relationships',
      (tester) async {
        final f = await fixture();
        if (failDelete) {
          await db.customStatement(
            "CREATE TRIGGER fail_delete BEFORE DELETE ON thoughts BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
          );
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: Scaffold(
                body: StreamBuilder<List<Thought>>(
                  stream: db.thoughtDao.watchActiveThoughts(),
                  builder: (context, state) =>
                      state.data?.any((n) => n.id == f.note.id) == true
                      ? ThoughtCardBubble(thought: f.note, index: 0)
                      : const SizedBox(),
                ),
              ),
            ),
          ),
        );
        await flush(tester);
        tester
            .widget<PopupMenuButton<String>>(
              find.byType(PopupMenuButton<String>),
            )
            .onSelected!('delete');
        await flush(tester);
        if (failDelete) {
          expect(
            find.text('Could not delete the thought. Please try again.'),
            findsOneWidget,
          );
          await tester.runAsync(
            () => expectRestored(f.note.id, f.task, f.reminder, f.merge),
          );
        } else {
          await tester.runAsync(
            () => db.customStatement(
              "CREATE TRIGGER fail_insert BEFORE INSERT ON thoughts BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
            ),
          );
          await tester.tap(find.text('Undo'));
          await flush(tester);
          expect(find.text('Could not restore the thought.'), findsOneWidget);
          expect(find.text('Retry'), findsOneWidget);
          await tester.runAsync(
            () => db.customStatement('DROP TRIGGER fail_insert'),
          );
          await tester.tap(find.text('Retry'));
          await flush(tester);
          await tester.runAsync(
            () => expectRestored(f.note.id, f.task, f.reminder, f.merge),
          );
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }
}
