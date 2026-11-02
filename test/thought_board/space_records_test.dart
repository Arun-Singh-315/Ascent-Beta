import 'package:ascent/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());
  test(
    'Rename and delete a space preserve active and archived entries and IDs',
    () async {
      final key = await db.thoughtDao.createCategoryAndMove('Movies', []);
      final ids = await db.thoughtDao.insertEntries(['Arrival', 'Dune'], key);
      await db.thoughtDao.toggleCompleted(ids.first);
      await db.thoughtDao.archiveThought(ids.last);
      final before = await db.select(db.thoughtTable).get();
      await db.thoughtDao.renameCategory(key, 'Films');
      expect((await db.thoughtDao.watchCategories().first)[key], 'Films');
      await expectLater(
        db.thoughtDao.renameCategory(key, 'General'),
        throwsArgumentError,
      );
      expect(await db.thoughtDao.deleteCategory(key), 2);
      final after = await db.select(db.thoughtTable).get();
      for (final item in before) {
        expect(
          after.singleWhere((n) => n.id == item.id),
          item.copyWith(category: 'general'),
        );
      }
    },
  );
  test(
    'Bulk insertion keeps list order and rejects invalid input without partial writes',
    () async {
      final key = await db.thoughtDao.createCategoryAndMove('Books', []);
      final ids = await db.thoughtDao.insertEntries([
        'First',
        'Second',
        'Third',
      ], key);
      expect(
        (await db.thoughtDao.watchAllThoughts().first).map((n) => n.id),
        ids,
      );
      await expectLater(
        db.thoughtDao.insertEntries(['Valid', '  '], key),
        throwsArgumentError,
      );
      await expectLater(
        db.thoughtDao.insertEntries(List.filled(101, 'Too many'), key),
        throwsArgumentError,
      );
      await expectLater(
        db.thoughtDao.insertEntries(['Entry'], 'custom_999'),
        throwsArgumentError,
      );
      expect((await db.select(db.thoughtTable).get()).length, 3);
    },
  );
  test('Built-in and stale spaces cannot be renamed or deleted', () async {
    await expectLater(
      db.thoughtDao.deleteCategory('general'),
      throwsArgumentError,
    );
    await expectLater(
      db.thoughtDao.renameCategory('custom_999', 'Lost'),
      throwsArgumentError,
    );
    await expectLater(
      db.thoughtDao.deleteCategory('custom_999'),
      throwsArgumentError,
    );
  });
}
