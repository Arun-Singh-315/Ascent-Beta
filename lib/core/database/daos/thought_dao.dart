part of '../app_database.dart';

@DriftAccessor(tables: [ThoughtTable])
class ThoughtDao extends DatabaseAccessor<AppDatabase> with _$ThoughtDaoMixin {
  ThoughtDao(super.db);

  /// Watch active (non-archived) thoughts sorted by incomplete first, then pinned, then newest.
  Stream<List<Thought>> watchActiveThoughts() {
    return (select(thoughtTable)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  /// Watch archived thoughts sorted newest first.
  Stream<List<Thought>> watchArchivedThoughts() {
    return (select(thoughtTable)
          ..where((t) => t.isArchived.equals(true))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Watch count of thoughts created today (active non-archived).
  Stream<int> watchTodayThoughtsCount() {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final countExp = thoughtTable.id.count();
    final query = selectOnly(thoughtTable)
      ..addColumns([countExp])
      ..where(
        thoughtTable.isArchived.equals(false) &
            thoughtTable.createdAt.isBiggerOrEqualValue(dayStart) &
            thoughtTable.createdAt.isSmallerThanValue(dayEnd),
      );
    return query.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  /// Watch all thoughts (legacy helper).
  Stream<List<Thought>> watchAllThoughts() => watchActiveThoughts();

  /// Watch recent thoughts for Home screen preview.
  Stream<List<Thought>> watchRecentThoughts({int limit = 5}) {
    return (select(thoughtTable)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(limit))
        .watch();
  }

  /// Get a single thought by ID.
  Future<Thought?> getThoughtById(int id) {
    return (select(
      thoughtTable,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert a new thought.
  Future<int> insertThought(ThoughtTableCompanion entry) {
    return into(thoughtTable).insert(entry);
  }

  /// Toggle pinned state of a thought.
  Future<void> togglePin(int id) async {
    final thought = await getThoughtById(id);
    if (thought != null) {
      await update(
        thoughtTable,
      ).replace(thought.copyWith(isPinned: !thought.isPinned));
    }
  }

  /// Toggle completed state of a thought (double-tap action).
  Future<void> toggleCompleted(int id) async {
    final thought = await getThoughtById(id);
    if (thought != null) {
      await update(
        thoughtTable,
      ).replace(thought.copyWith(isCompleted: !thought.isCompleted));
    }
  }

  /// Explicitly set completed state of a thought.
  Future<void> setCompleted(int id, bool completed) async {
    final thought = await getThoughtById(id);
    if (thought != null && thought.isCompleted != completed) {
      await update(
        thoughtTable,
      ).replace(thought.copyWith(isCompleted: completed));
    }
  }

  /// Explicitly set completed state on any thoughts matching the given text content.
  Future<void> setCompletedByContent(String content, bool completed) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;
    final matches = await (select(
      thoughtTable,
    )..where((t) => t.content.equals(trimmed))).get();
    for (final t in matches) {
      if (t.isCompleted != completed) {
        await update(thoughtTable).replace(t.copyWith(isCompleted: completed));
      }
    }
  }

  /// Archive a thought.
  Future<void> archiveThought(int id) async {
    final thought = await getThoughtById(id);
    if (thought != null) {
      await update(thoughtTable).replace(thought.copyWith(isArchived: true));
    }
  }

  /// Unarchive a thought.
  Future<void> unarchiveThought(int id) async {
    final thought = await getThoughtById(id);
    if (thought != null) {
      await update(thoughtTable).replace(thought.copyWith(isArchived: false));
    }
  }

  /// Update an existing thought.
  Future<bool> updateThought(ThoughtTableCompanion entry) {
    return update(thoughtTable).replace(entry);
  }

  /// Delete a thought.
  Future<int> deleteThought(int id) {
    return (delete(thoughtTable)..where((t) => t.id.equals(id))).go();
  }
}
