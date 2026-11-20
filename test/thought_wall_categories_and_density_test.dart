import 'dart:io';

import 'package:ascent/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'schema 19 upgrade adds the custom category registry without changing thoughts',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'thought-category-upgrade-',
      );
      final file = File('${dir.path}/workspace.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Existing reflection'),
        );
        await db.customStatement('DROP TABLE thought_categories');
        await db.customStatement('PRAGMA user_version = 19');
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        expect(
          await db.thoughtDao.watchCategories().first,
          ThoughtDao.builtInCategories,
        );
        expect(
          (await db.thoughtDao.getThoughtById(id))!.content,
          'Existing reflection',
        );
        expect(await db.select(db.thoughtCategoryTable).get(), isEmpty);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'custom categories persist across restart and reuse normalized names',
    () async {
      final dir = await Directory.systemTemp.createTemp('thought-folders-');
      final file = File('${dir.path}/workspace.sqlite');
      var db = AppDatabase.forTesting(NativeDatabase(file));
      try {
        final first = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Learn'),
        );
        final second = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Practise'),
        );
        final category = await db.thoughtDao.createCategoryAndMove(
          '  Work   ideas  ',
          [first],
        );
        await db.close();
        db = AppDatabase.forTesting(NativeDatabase(file));
        expect(
          (await db.thoughtDao.watchCategories().first)[category],
          'Work ideas',
        );
        expect(
          await db.thoughtDao.createCategoryAndMove('work ideas', [second]),
          category,
        );
        expect(await db.select(db.thoughtCategoryTable).get(), hasLength(1));
        expect((await db.thoughtDao.getThoughtById(first))!.category, category);
        expect(
          (await db.thoughtDao.getThoughtById(second))!.category,
          category,
        );
        expect(
          await db.thoughtDao.createCategoryAndMove(' LIFE goals ', [second]),
          'life_goals',
        );
        await expectLater(
          db.thoughtDao.createCategoryAndMove('  ', [first]),
          throwsArgumentError,
        );
        await expectLater(
          db.thoughtDao.createCategoryAndMove('x' * 51, [first]),
          throwsArgumentError,
        );
        expect((await db.thoughtDao.getThoughtById(first))!.category, category);
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'creating a category and moving thoughts rolls back together on failure',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Keep me'),
        );
        await db.customStatement(
          "CREATE TRIGGER reject_category BEFORE UPDATE OF category ON thoughts BEGIN SELECT RAISE(ABORT, 'simulated failure'); END",
        );
        await expectLater(
          db.thoughtDao.createCategoryAndMove('Rejected', [id]),
          throwsA(anything),
        );
        expect(await db.select(db.thoughtCategoryTable).get(), isEmpty);
        expect((await db.thoughtDao.getThoughtById(id))!.category, 'general');
      } finally {
        await db.close();
      }
    },
  );
}
