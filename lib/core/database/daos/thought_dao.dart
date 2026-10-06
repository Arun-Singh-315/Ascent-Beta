part of '../app_database.dart';

@DriftAccessor(tables: [
  ThoughtTable,
])
class ThoughtDao extends DatabaseAccessor<AppDatabase> with _$ThoughtDaoMixin {
  ThoughtDao(super.db);

  /// Watch all thoughts sorted by pinned first, then newest.
  Stream<List<Thought>> watchAllThoughts() {
    return (select(thoughtTable)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Watch recent thoughts for Home screen preview.
  Stream<List<Thought>> watchRecentThoughts({int limit = 5}) {
    return (select(thoughtTable)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
          ])
          ..limit(limit))
        .watch();
  }

  /// Insert a new thought.
  Future<int> insertThought(ThoughtTableCompanion entry) {
    return into(thoughtTable).insert(entry);
  }

  /// Toggle pinned state of a thought.
  Future<void> togglePin(int id) async {
    final thought = await (select(thoughtTable)..where((t) => t.id.equals(id))).getSingleOrNull();
    if (thought != null) {
      await update(thoughtTable).replace(
        thought.copyWith(isPinned: !thought.isPinned),
      );
    }
  }

  /// Delete a thought.
  Future<int> deleteThought(int id) {
    return (delete(thoughtTable)..where((t) => t.id.equals(id))).go();
  }
}
