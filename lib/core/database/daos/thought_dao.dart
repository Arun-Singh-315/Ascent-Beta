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
          ..where((t) => t.isArchived.equals(false) & t.mood.equals('promise').not())
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
          ..where((t) => t.isArchived.equals(false) & t.mood.equals('promise').not())
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

  int? _customCategoryId(String key) =>
      key.startsWith('custom_') ? int.tryParse(key.substring(7)) : null;

  Future<void> _requireCategory(String key) async {
    if (builtInCategories.containsKey(key)) return;
    final id = _customCategoryId(key);
    if (id == null ||
        await (db.select(
              db.thoughtCategoryTable,
            )..where((t) => t.id.equals(id))).getSingleOrNull() ==
            null) {
      throw ArgumentError.value(key, 'category');
    }
  }

  /// Renames a space the user created. Built-in spaces keep their names.
  Future<void> renameCategory(String key, String name) => db.transaction(
    () async {
      final id = _customCategoryId(key);
      if (id == null) throw ArgumentError.value(key, 'category');
      await _requireCategory(key);
      final clean = name.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (clean.isEmpty || clean.length > 50) {
        throw ArgumentError('Use a category name between 1 and 50 characters.');
      }
      final normalized = clean.toLowerCase();
      final usedByBuiltIn = builtInCategories.values.any(
        (v) => v.toLowerCase() == normalized,
      );
      final clash =
          await (db.select(db.thoughtCategoryTable)..where(
                (t) =>
                    t.normalizedName.equals(normalized) & t.id.equals(id).not(),
              ))
              .getSingleOrNull();
      if (usedByBuiltIn || clash != null) {
        throw ArgumentError('That name is already used.');
      }
      await (db.update(
        db.thoughtCategoryTable,
      )..where((t) => t.id.equals(id))).write(
        ThoughtCategoryTableCompanion(
          name: Value(clean),
          normalizedName: Value(normalized),
        ),
      );
    },
  );

  /// Removes a space the user created. Its entries are kept and move back to
  /// the wall. Returns how many entries moved.
  Future<int> deleteCategory(String key) => db.transaction(() async {
    final id = _customCategoryId(key);
    if (id == null) throw ArgumentError.value(key, 'category');
    await _requireCategory(key);
    final moved =
        await (update(thoughtTable)..where((t) => t.category.equals(key)))
            .write(const ThoughtTableCompanion(category: Value('general')));
    await (db.delete(
      db.thoughtCategoryTable,
    )..where((t) => t.id.equals(id))).go();
    return moved;
  });

  /// Adds several entries to a space in one transaction. They are inserted
  /// last-to-first so the first line ends up first when entries are listed
  /// newest-first. Returns the new ids in the order given.
  Future<List<int>> insertEntries(List<String> contents, String category) =>
      db.transaction(() async {
        await _requireCategory(category);
        if (contents.length > 100 ||
            contents.any((text) => text.trim().isEmpty)) {
          throw ArgumentError('Use up to 100 non-empty entries.');
        }
        final ids = List<int>.filled(contents.length, 0);
        for (var i = contents.length - 1; i >= 0; i--) {
          ids[i] = await insertThought(
            ThoughtTableCompanion.insert(
              content: contents[i],
              category: Value(category),
            ),
          );
        }
        return ids;
      });

  /// Replaces only the text of a thought.
  Future<void> setContent(int id, String content) async {
    await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
      ThoughtTableCompanion(content: Value(content)),
    );
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

  /// Ticks or unticks a thought and keeps [Thought.completedAt] in step.
  /// [now] exists so tests can move the clock.
  Future<void> setCompleted(int id, bool completed, {DateTime? now}) async {
    await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
      ThoughtTableCompanion(
        isCompleted: Value(completed),
        completedAt: Value(completed ? (now ?? DateTime.now()) : null),
      ),
    );
  }

  Future<void> archiveThought(int id, {DateTime? now}) async {
    await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
      ThoughtTableCompanion(
        isArchived: const Value(true),
        archivedAt: Value(now ?? DateTime.now()),
      ),
    );
  }

  Future<void> unarchiveThought(int id) async {
    await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
      const ThoughtTableCompanion(
        isArchived: Value(false),
        archivedAt: Value(null),
      ),
    );
  }

  // Lifecycle views --------------------------------------------------------
  //
  // One record, one state. Today, Earlier, Done, Archive and History are
  // queries over createdAt / carriedOn / completedAt / archivedAt: nothing is
  // ever copied. Promise thoughts stay in, exactly as on the old wall.

  static DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  Expression<bool> _inDay(
    GeneratedColumn<DateTime> column,
    DateTime start,
    DateTime end,
  ) => column.isBiggerOrEqualValue(start) & column.isSmallerThanValue(end);

  Expression<bool> _matches(
    $ThoughtTableTable t, {
    String? category,
    String? query,
  }) {
    Expression<bool> out = const Constant(true);
    if (category != null) out = out & t.category.equals(category);
    final text = query?.trim() ?? '';
    if (text.isNotEmpty) out = out & t.content.like('%$text%');
    return out;
  }

  /// Today: open thoughts written or carried today, thoughts finished today,
  /// and thoughts archived today (shown with an "Archived" tag until midnight).
  Stream<List<Thought>> watchToday({
    DateTime? now,
    String? category,
    String? query,
  }) {
    final n = now ?? DateTime.now();
    final start = _dayStart(n);
    final end = DateTime(n.year, n.month, n.day + 1);
    return (select(thoughtTable)
          ..where(
            (t) =>
                _matches(t, category: category, query: query) &
                ((t.isArchived.equals(false) &
                        (_inDay(t.createdAt, start, end) |
                            _inDay(t.carriedOn, start, end) |
                            (t.isCompleted.equals(true) &
                                _inDay(t.completedAt, start, end)))) |
                    (t.isArchived.equals(true) &
                        _inDay(t.archivedAt, start, end))),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.isCompleted),
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  Expression<bool> _earlier($ThoughtTableTable t, DateTime start) =>
      t.isArchived.equals(false) &
      t.isCompleted.equals(false) &
      t.createdAt.isSmallerThanValue(start) &
      (t.carriedOn.isNull() | t.carriedOn.isSmallerThanValue(start));

  /// Open thoughts from before today that were not brought to Today.
  Stream<List<Thought>> watchEarlier({
    DateTime? now,
    String? category,
    String? query,
  }) {
    final start = _dayStart(now ?? DateTime.now());
    return (select(thoughtTable)
          ..where(
            (t) =>
                _matches(t, category: category, query: query) &
                _earlier(t, start),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// Ticked thoughts that are not archived, newest completion first. Grows by
  /// raising [limit]; the stream keeps updating.
  Stream<List<Thought>> watchDone({
    required int limit,
    String? category,
    String? query,
  }) {
    return (select(thoughtTable)
          ..where(
            (t) =>
                _matches(t, category: category, query: query) &
                t.isCompleted.equals(true) &
                t.isArchived.equals(false),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.completedAt),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(limit))
        .watch();
  }

  /// Every archived thought, newest archive first.
  Stream<List<Thought>> watchArchive({
    required int limit,
    String? category,
    String? query,
  }) {
    return (select(thoughtTable)
          ..where(
            (t) =>
                _matches(t, category: category, query: query) &
                t.isArchived.equals(true),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.archivedAt),
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ])
          ..limit(limit))
        .watch();
  }

  /// Thoughts with any lifecycle event on [day]: written, finished, archived
  /// or carried in.
  Stream<List<Thought>> watchHistoryForDay(DateTime day) {
    final start = _dayStart(day);
    final end = DateTime(day.year, day.month, day.day + 1);
    return (select(thoughtTable)
          ..where(
            (t) =>
                (_inDay(t.createdAt, start, end) |
                    _inDay(t.completedAt, start, end) |
                    _inDay(t.archivedAt, start, end) |
                    _inDay(t.carriedOn, start, end)),
          )
          ..orderBy([
            (t) => OrderingTerm.desc(t.createdAt),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// Thoughts with any lifecycle event on or after [since]; used for the
  /// History day strip dots.
  Stream<List<Thought>> watchActivitySince(DateTime since) {
    final start = _dayStart(since);
    return (select(thoughtTable)
          ..where(
            (t) =>
                (t.createdAt.isBiggerOrEqualValue(start) |
                    t.completedAt.isBiggerOrEqualValue(start) |
                    t.archivedAt.isBiggerOrEqualValue(start) |
                    t.carriedOn.isBiggerOrEqualValue(start)),
          )
          ..limit(5000))
        .watch();
  }

  /// Brings open thoughts to Today. Only [Thought.carriedOn] changes, so the
  /// original date stays and no second record exists. Returns how many moved.
  Future<int> carryToToday(Iterable<int> ids, {DateTime? now}) async {
    final selected = ids.toSet();
    if (selected.isEmpty) return 0;
    final at = now ?? DateTime.now();
    return (update(thoughtTable)..where(
          (t) =>
              t.id.isIn(selected) &
              t.isArchived.equals(false) &
              t.isCompleted.equals(false),
        ))
        .write(ThoughtTableCompanion(carriedOn: Value(at)));
  }

  /// Brings every Earlier thought to Today. Returns how many moved.
  Future<int> carryAllEarlierToToday({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final start = _dayStart(at);
    return (update(thoughtTable)..where((t) => _earlier(t, start)))
        .write(ThoughtTableCompanion(carriedOn: Value(at)));
  }

  /// 'todo', 'bullet' or null (follow the user's default).
  Future<void> setBulletStyle(int id, String? style) async {
    if (style != null && style != 'todo' && style != 'bullet') {
      throw ArgumentError.value(style, 'style');
    }
    await (update(thoughtTable)..where((t) => t.id.equals(id))).write(
      ThoughtTableCompanion(bulletStyle: Value(style)),
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
