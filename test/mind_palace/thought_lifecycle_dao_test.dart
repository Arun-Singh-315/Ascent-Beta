import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/board/thought_lifecycle.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lifecycle rules on a real (in-memory) database with an injected clock.
/// Run after `dart run build_runner build --delete-conflicting-outputs`.
void main() {
  late AppDatabase db;
  late ThoughtDao dao;
  final nov18 = DateTime(2026, 11, 18, 10);
  final nov20 = DateTime(2026, 11, 20, 9);
  final nov21 = DateTime(2026, 11, 21, 9);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dao = db.thoughtDao;
  });
  tearDown(() => db.close());

  Future<int> add(String text, DateTime at, {String category = 'general'}) =>
      dao.insertThought(
        ThoughtTableCompanion.insert(
          content: text,
          category: drift.Value(category),
          createdAt: drift.Value(at),
        ),
      );

  Future<Thought> get(int id) async => (await dao.getThoughtById(id))!;

  test('open thought from yesterday is Earlier, not Today', () async {
    final id = await add('old', nov18);
    expect(placeOf(await get(id), nov20), ThoughtPlace.earlier);
    expect(placeOf(await get(id), nov18), ThoughtPlace.today);
  });

  test('carrying keeps one row, keeps createdAt, moves it to Today', () async {
    final id = await add('carry me', nov18);
    expect(await dao.carryToToday([id], now: nov20), 1);
    final t = await get(id);
    expect(t.createdAt, nov18);
    expect(placeOf(t, nov20), ThoughtPlace.today);
    expect(originTag(t, nov20), 'from 18 Nov');
    expect((await dao.watchAllThoughts().first).length, 1);
  });

  test('carried then done: one record, shows on both days in History', () async {
    final id = await add('x', nov18);
    await dao.carryToToday([id], now: nov20);
    await dao.setCompleted(id, true, now: nov20);
    final t = await get(id);
    Set<HistoryKind> kinds(DateTime day) =>
        historyForDay([t], day).map((e) => e.kind).toSet();
    expect(kinds(dayOf(nov18)), {HistoryKind.written});
    expect(kinds(dayOf(nov20)), {HistoryKind.carriedIn, HistoryKind.finished});
    expect(placeOf(t, nov20), ThoughtPlace.today); // done today
    expect(placeOf(t, nov21), ThoughtPlace.done); // done earlier
  });

  test('archive today stays in Today tagged, then only in Archive', () async {
    final id = await add('a', nov20);
    await dao.archiveThought(id, now: nov20);
    final t = await get(id);
    expect(placeOf(t, nov20), ThoughtPlace.archivedToday);
    expect(placeOf(t, nov21), ThoughtPlace.archive);
    expect(isInToday(t, nov21), isFalse);
  });

  test('restore clears the archive state', () async {
    final id = await add('a', nov20);
    await dao.archiveThought(id, now: nov20);
    await dao.unarchiveThought(id);
    expect(placeOf(await get(id), nov20), ThoughtPlace.today);
  });

  test('carry all brings every open earlier thought, nothing else', () async {
    final a = await add('a', nov18);
    final b = await add('b', nov18);
    final done = await add('c', nov18);
    await dao.setCompleted(done, true, now: nov18);
    final previous = await dao.carryAllEarlierToToday(now: nov20);
    expect(previous.keys, unorderedEquals([a, b]));
    expect(placeOf(await get(a), nov20), ThoughtPlace.today);
    expect(placeOf(await get(b), nov20), ThoughtPlace.today);
    expect(placeOf(await get(done), nov20), ThoughtPlace.done);

    // Undo puts them back where they were.
    await dao.restoreCarriedOn(previous);
    expect(placeOf(await get(a), nov20), ThoughtPlace.earlier);
    expect(placeOf(await get(b), nov20), ThoughtPlace.earlier);
  });

  test('Today stream loads only today rows; Earlier only older open', () async {
    await add('today', nov20);
    await add('old', nov18);
    final today = await dao.watchToday(now: nov20).first;
    final earlier = await dao.watchEarlier(now: nov20).first;
    expect(today.map((t) => t.content), ['today']);
    expect(earlier.map((t) => t.content), ['old']);
  });

  test('Done and Archive are paged', () async {
    for (var i = 0; i < 12; i++) {
      final id = await add('t$i', nov18);
      await dao.setCompleted(id, true, now: nov18.add(Duration(minutes: i)));
    }
    expect((await dao.watchDone(limit: 5).first).length, 5);
    expect((await dao.watchDone(limit: 50).first).length, 12);
  });

  test('bullet style validates', () async {
    final id = await add('- a\n- b', nov20);
    await dao.setBulletStyle(id, 'bullet');
    expect((await get(id)).bulletStyle, 'bullet');
    await dao.setBulletStyle(id, null);
    expect((await get(id)).bulletStyle, isNull);
    expect(() => dao.setBulletStyle(id, 'grid'), throwsArgumentError);
    expect((await get(id)).content, '- a\n- b'); // text never rewritten
  });

  test('volume: 5,000 thoughts, first page stays small', () async {
    await db.batch((b) {
      b.insertAll(db.thoughtTable, [
        for (var i = 0; i < 5000; i++)
          ThoughtTableCompanion.insert(
            content: 't$i',
            createdAt: drift.Value(nov18.subtract(Duration(minutes: i))),
            isCompleted: const drift.Value(true),
            completedAt: drift.Value(nov18.subtract(Duration(minutes: i))),
          ),
      ]);
    });
    expect((await dao.watchDone(limit: 50).first).length, 50);
    expect((await dao.watchToday(now: nov20).first), isEmpty);
  });
}
