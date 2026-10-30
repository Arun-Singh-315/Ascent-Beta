part of '../app_database.dart';

/// An in-memory, single-use Undo token for one exact deletion.
class ThoughtDeletion {
  const ThoughtDeletion._(
    this.thought,
    this._tasks,
    this._reminders,
    this._reminderRecords,
    this._merges,
  );
  final Thought thought;
  final List<Task> _tasks;
  final List<ThoughtReminderLink> _reminders;
  final Map<int, Reminder> _reminderRecords;
  final List<ThoughtMergeSource> _merges;
}

@DriftAccessor(tables: [ThoughtTable])
class ThoughtDao extends DatabaseAccessor<AppDatabase> with _$ThoughtDaoMixin {
  ThoughtDao(super.db);
  final _recentlyDeleted = <int, ThoughtDeletion>{};
  void clearDeletionUndo() => _recentlyDeleted.clear();

  /// Watch active (non-archived) thoughts sorted by open first, then pinned and newest.
  Stream<List<Thought>> watchActiveThoughts() {
    return (select(thoughtTable)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
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

  /// Watch recent thoughts for Home preview (open first, then pinned and newest before limiting).
  Stream<List<Thought>> watchRecentThoughts({int limit = 10}) {
    return (select(thoughtTable)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(limit))
        .watch();
  }

  /// Home shows the newest non-archived message, independent of wall pinning.
  Stream<Thought?> watchLatestThought() {
    return (select(thoughtTable)
          ..where((t) => t.isArchived.equals(false))
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(1))
        .watchSingleOrNull();
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

  static const builtInCategories = {
    'general': 'General',
    'suggestions': 'Suggestions',
    'bugs': 'Bugs',
    'life_goals': 'Life Goals',
  };

  Stream<Map<String, String>> watchCategories() =>
      (db.select(
        db.thoughtCategoryTable,
      )..orderBy([(t) => OrderingTerm.asc(t.normalizedName)])).watch().map(
        (rows) => {
          ...builtInCategories,
          for (final row in rows) 'custom_${row.id}': row.name,
        },
      );

  /// Creation and assignment commit together; repeated names reuse their folder.
  Future<String> createCategoryAndMove(
    String name,
    Iterable<int> ids,
  ) => db.transaction(() async {
    final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty || clean.length > 50) {
      throw ArgumentError('Use a category name between 1 and 50 characters.');
    }
    final normalized = clean.toLowerCase();
    String? category;
    for (final entry in builtInCategories.entries) {
      if (entry.value.toLowerCase() == normalized) category = entry.key;
    }
    if (category == null) {
      final existing = await (db.select(
        db.thoughtCategoryTable,
      )..where((t) => t.normalizedName.equals(normalized))).getSingleOrNull();
      final id =
          existing?.id ??
          await db
              .into(db.thoughtCategoryTable)
              .insert(
                ThoughtCategoryTableCompanion.insert(
                  name: clean,
                  normalizedName: normalized,
                ),
              );
      category = 'custom_$id';
    }
    await moveToCategory(ids, category);
    return category;
  });

  /// Categories are independent of note type, age and archive state.
  Future<void> moveToCategory(Iterable<int> ids, String category) async {
    if (!builtInCategories.containsKey(category)) {
      final id = category.startsWith('custom_')
          ? int.tryParse(category.substring(7))
          : null;
      if (id == null ||
          await (db.select(
                db.thoughtCategoryTable,
              )..where((t) => t.id.equals(id))).getSingleOrNull() ==
              null) {
        throw ArgumentError.value(category, 'category');
      }
    }
    final selected = ids.toSet();
    if (selected.isEmpty) return;
    await db.transaction(() async {
      await (update(thoughtTable)..where((t) => t.id.isIn(selected))).write(
        ThoughtTableCompanion(category: Value(category)),
      );
    });
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
  Future<int> deleteThought(int id) async =>
      await deleteThoughtForUndo(id) == null ? 0 : 1;

  Future<ThoughtDeletion?> deleteThoughtForUndo(int id) => db.transaction(
    () async {
      final original = await getThoughtById(id);
      if (original == null) return null;
      final tasks = await (db.select(
        db.taskTable,
      )..where((t) => t.linkedThoughtId.equals(id))).get();
      final reminders = await (db.select(
        db.thoughtReminderLinkTable,
      )..where((l) => l.thoughtId.equals(id))).get();
      final reminderRecords = <int, Reminder>{};
      for (final link in reminders) {
        final reminder = await db.reminderDao.getReminderById(link.reminderId);
        if (reminder != null) reminderRecords[reminder.id] = reminder;
      }
      final merges =
          await (db.select(db.thoughtMergeSourceTable)..where(
                (l) =>
                    l.mergedThoughtId.equals(id) | l.sourceThoughtId.equals(id),
              ))
              .get();
      await (db.update(db.taskTable)
            ..where((t) => t.linkedThoughtId.equals(id)))
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
      await (db.update(
        db.planCollectionTable,
      )..where((c) => c.sourceThoughtId.equals(id))).write(
        const PlanCollectionTableCompanion(sourceThoughtId: Value(null)),
      );
      await (db.update(
        db.planDefinitionTable,
      )..where((p) => p.sourceThoughtId.equals(id))).write(
        const PlanDefinitionTableCompanion(sourceThoughtId: Value(null)),
      );
      final count = await (delete(
        thoughtTable,
      )..where((t) => t.id.equals(id))).go();
      if (count == 1) {
        final snapshot = ThoughtDeletion._(
          original,
          tasks,
          reminders,
          reminderRecords,
          merges,
        );
        _recentlyDeleted[id] = snapshot;
        if (_recentlyDeleted.length > 20) {
          _recentlyDeleted.remove(_recentlyDeleted.keys.first);
        }
      }
      return _recentlyDeleted[id];
    },
  );

  /// Compatibility entry point; new UI callers retain the exact deletion token.
  Future<bool> restoreDeletedThought(Thought thought) async {
    final snapshot = _recentlyDeleted[thought.id];
    if (snapshot == null || snapshot.thought != thought) return false;
    return restoreThoughtDeletion(snapshot);
  }

  Future<bool> restoreThoughtDeletion(
    ThoughtDeletion snapshot,
  ) => db.transaction(() async {
    final thought = snapshot.thought;
    if (!identical(_recentlyDeleted[thought.id], snapshot) ||
        await getThoughtById(thought.id) != null) {
      return false;
    }
    await into(thoughtTable).insert(thought.toCompanion(true));
    for (final task in snapshot._tasks) {
      final current = await db.taskDao.getTaskById(task.id);
      // Only restore the link if the detached record has not changed since
      // deletion. Never replace a newer task or undo a newer association.
      if (current == task.copyWith(linkedThoughtId: const Value(null))) {
        await (db.update(db.taskTable)..where((t) => t.id.equals(task.id)))
            .write(TaskTableCompanion(linkedThoughtId: Value(thought.id)));
      }
    }
    for (final link in snapshot._reminders) {
      final current = await db.reminderDao.getReminderById(link.reminderId);
      final original = snapshot._reminderRecords[link.reminderId];
      if (current != null && original != null && current == original) {
        await db
            .into(db.thoughtReminderLinkTable)
            .insert(link.toCompanion(true), mode: InsertMode.insertOrIgnore);
      }
    }
    for (final link in snapshot._merges) {
      if (await getThoughtById(link.mergedThoughtId) == null) continue;
      if (link.sourceThoughtId != null &&
          await getThoughtById(link.sourceThoughtId!) == null) {
        continue;
      }
      final current = await (db.select(
        db.thoughtMergeSourceTable,
      )..where((l) => l.id.equals(link.id))).getSingleOrNull();
      if (link.mergedThoughtId == thought.id) {
        if (current == null) {
          await db
              .into(db.thoughtMergeSourceTable)
              .insert(link.toCompanion(true), mode: InsertMode.insertOrIgnore);
        }
      } else if (current == link.copyWith(sourceThoughtId: const Value(null))) {
        // A retained source tombstone must still match every field. If it
        // was edited or removed since deletion, leave that newer work alone.
        await (db.update(
          db.thoughtMergeSourceTable,
        )..where((l) => l.id.equals(link.id))).write(
          ThoughtMergeSourceTableCompanion(
            sourceThoughtId: Value(link.sourceThoughtId),
          ),
        );
      }
    }
    _recentlyDeleted.remove(thought.id);
    return true;
  });
}
