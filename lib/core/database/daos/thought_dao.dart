part of '../app_database.dart';

class _DeletedThoughtLinks {
  const _DeletedThoughtLinks(this.tasks, this.reminders, this.merges);
  final List<Task> tasks;
  final List<ThoughtReminderLink> reminders;
  final List<ThoughtMergeSource> merges;
}

@DriftAccessor(tables: [ThoughtTable])
class ThoughtDao extends DatabaseAccessor<AppDatabase> with _$ThoughtDaoMixin {
  ThoughtDao(super.db);
  final _recentlyDeleted = <int, _DeletedThoughtLinks>{};

  /// Watch active (non-archived) thoughts sorted by pinned first, then newest with stable ID ties.
  Stream<List<Thought>> watchActiveThoughts() {
    return (select(thoughtTable)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
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

  /// Partial, serialized updates preserve concurrent content edits.
  Future<void> togglePin(int id) => db.transaction(() async {
    final thought = await getThoughtById(id);
    if (thought != null) {
      await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
        ThoughtTableCompanion(isPinned: Value(!thought.isPinned)),
      );
    }
  });

  Future<void> toggleCompleted(int id) => db.transaction(() async {
    final thought = await getThoughtById(id);
    if (thought != null) await setCompleted(id, !thought.isCompleted);
  });

  Future<void> setCompleted(int id, bool completed) async {
    await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
      ThoughtTableCompanion(isCompleted: Value(completed)),
    );
  }

  Future<void> archiveThought(int id) async {
    await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
      const ThoughtTableCompanion(isArchived: Value(true)),
    );
  }

  Future<void> unarchiveThought(int id) async {
    await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
      const ThoughtTableCompanion(isArchived: Value(false)),
    );
  }

  /// Update an existing thought.
  Future<bool> updateThought(ThoughtTableCompanion entry) {
    return update(thoughtTable).replace(entry);
  }

  /// Delete a thought.
  Future<int> deleteThought(int id) => db.transaction(() async {
    final tasks = await (db.select(
      db.taskTable,
    )..where((t) => t.linkedThoughtId.equals(id))).get();
    final reminders = await (db.select(
      db.thoughtReminderLinkTable,
    )..where((l) => l.thoughtId.equals(id))).get();
    final merges =
        await (db.select(db.thoughtMergeSourceTable)..where(
              (l) =>
                  l.mergedThoughtId.equals(id) | l.sourceThoughtId.equals(id),
            ))
            .get();
    await (db.update(db.taskTable)..where((t) => t.linkedThoughtId.equals(id)))
        .write(const TaskTableCompanion(linkedThoughtId: Value(null)));
    await (db.delete(
      db.thoughtReminderLinkTable,
    )..where((l) => l.thoughtId.equals(id))).go();
    await (db.delete(
      db.thoughtMergeSourceTable,
    )..where((l) => l.mergedThoughtId.equals(id))).go();
    await (db.update(
      db.thoughtMergeSourceTable,
    )..where((l) => l.sourceThoughtId.equals(id))).write(
      const ThoughtMergeSourceTableCompanion(sourceThoughtId: Value(null)),
    );
    final count = await (delete(
      thoughtTable,
    )..where((t) => t.id.equals(id))).go();
    if (count == 1) {
      _recentlyDeleted[id] = _DeletedThoughtLinks(tasks, reminders, merges);
      if (_recentlyDeleted.length > 20) {
        _recentlyDeleted.remove(_recentlyDeleted.keys.first);
      }
    }
    return count;
  });

  Future<void> restoreDeletedThought(Thought thought) => db.transaction(
    () async {
      if (await getThoughtById(thought.id) != null) return;
      await into(thoughtTable).insert(thought.toCompanion(true));
      final links = _recentlyDeleted[thought.id];
      if (links == null) return;
      for (final task in links.tasks) {
        final current = await db.taskDao.getTaskById(task.id);
        if (current != null && current.linkedThoughtId == null) {
          await (db.update(db.taskTable)..where((t) => t.id.equals(task.id)))
              .write(TaskTableCompanion(linkedThoughtId: Value(thought.id)));
        }
      }
      for (final link in links.reminders) {
        if (await db.reminderDao.getReminderById(link.reminderId) != null) {
          await db
              .into(db.thoughtReminderLinkTable)
              .insertOnConflictUpdate(link.toCompanion(true));
        }
      }
      for (final link in links.merges) {
        final otherId = link.mergedThoughtId == thought.id
            ? link.sourceThoughtId
            : link.mergedThoughtId;
        if (otherId != null && await getThoughtById(otherId) == null) continue;
        final current = await (db.select(
          db.thoughtMergeSourceTable,
        )..where((l) => l.id.equals(link.id))).getSingleOrNull();
        if (current == null || current.sourceThoughtId == null) {
          await db
              .into(db.thoughtMergeSourceTable)
              .insertOnConflictUpdate(link.toCompanion(true));
        }
      }
      _recentlyDeleted.remove(thought.id);
    },
  );
}
