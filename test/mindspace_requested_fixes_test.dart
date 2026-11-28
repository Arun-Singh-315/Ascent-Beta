import 'dart:async';
import 'dart:io';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/shared/utils/action_text.dart';
import 'package:ascent/shared/widgets/note_list_button.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class DelayedDeleteDao extends TaskDao {
  DelayedDeleteDao(super.db);
  final gate = Completer<void>();
  @override
  Future<void> archiveTask(int id) async {
    await gate.future;
    return super.archiveTask(id);
  }

  @override
  Future<int> deleteTask(int id, {bool bypassProtection = false}) async {
    await gate.future;
    return super.deleteTask(id, bypassProtection: bypassProtection);
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'supporting text hides duplicates while preserving distinct words and notes',
    () {
      expect(actionSupportingText('Read Java', '  read  Java\n'), isNull);
      expect(
        actionSupportingText('Read Java', 'Read Java\n\nChapter 2'),
        'Chapter 2',
      );
      expect(
        actionSupportingText('Run', 'Running tomorrow'),
        'Running tomorrow',
      );
      expect(
        actionSupportingText('New title', 'Original thought'),
        'Original thought',
      );
    },
  );

  test(
    'bullet insertion respects existing spacing and cursor selection without long gaps',
    () {
      for (final text in ['First', 'First\n']) {
        final controller = TextEditingController(text: text);
        NoteListButton.insertNextItem(controller);
        expect(controller.text, 'First\n• ');
        NoteListButton.insertNextItem(controller);
        expect(controller.text, 'First\n• ');
        controller.dispose();
      }
      final controller = TextEditingController(text: 'FirstreplaceLast')
        ..selection = const TextSelection(baseOffset: 5, extentOffset: 12);
      NoteListButton.insertNextItem(controller);
      expect(controller.text, 'First\n• Last');
      controller.dispose();
    },
  );

  test(
    'schema 18 migration preserves thought type, history and task link',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'ascent-thought-category-',
      );
      final file = File('${directory.path}/workspace.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'My life goal',
            mood: const d.Value('promise'),
            isArchived: const d.Value(true),
          ),
        );
        final task = await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Act on goal',
            linkedThoughtId: d.Value(id),
          ),
        );
        final triggers = await db
            .customSelect("SELECT name FROM sqlite_master WHERE type='trigger'")
            .get();
        for (final row in triggers) {
          await db.customStatement(
            'DROP TRIGGER IF EXISTS ${row.read<String>('name')}',
          );
        }
        await db.customStatement('ALTER TABLE thoughts DROP COLUMN category');
        await db.customStatement('PRAGMA user_version = 18');
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        final migrated = (await db.thoughtDao.getThoughtById(id))!;
        expect(migrated.category, 'general');
        expect(migrated.mood, 'promise');
        expect(migrated.isArchived, true);
        await db.thoughtDao.moveToCategory([id], 'life_goals');
        expect(
          (await db.thoughtDao.getThoughtById(id))!.category,
          'life_goals',
        );
        expect((await db.taskDao.getTaskById(task))!.linkedThoughtId, id);
        await expectLater(
          db.thoughtDao.moveToCategory([id], 'invalid'),
          throwsArgumentError,
        );
        expect(
          (await db.thoughtDao.getThoughtById(id))!.category,
          'life_goals',
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );

}
