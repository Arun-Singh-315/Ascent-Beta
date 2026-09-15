part of '../app_database.dart';

@DriftAccessor(tables: [NoteTable, NoteTagTable])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.db);

  // ---------------------------------------------------------------------------
  // Watch helpers
  // ---------------------------------------------------------------------------

  /// Stream of all notes, most recently updated first.
  Stream<List<Note>> watchAllNotes() =>
      (select(noteTable)
            ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
          .watch();

  /// Stream of notes whose [title] or [content] contains [query]
  /// (case-insensitive).
  Stream<List<Note>> searchNotes(String query) {
    final pattern = '%$query%';
    return (select(noteTable)
          ..where(
            (n) =>
                n.content.like(pattern) |
                n.title.like(pattern),
          )
          ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
        .watch();
  }

  /// Stream of notes that have the given [tag] via [NoteTagTable] join.
  Stream<List<Note>> watchNotesByTag(String tag) {
    final query = select(noteTable).join([
      innerJoin(
        noteTagTable,
        noteTagTable.noteId.equalsExp(noteTable.id),
      ),
    ])
      ..where(noteTagTable.tag.equals(tag))
      ..orderBy([OrderingTerm.desc(noteTable.updatedAt)]);
    return query.watch().map(
          (rows) => rows.map((r) => r.readTable(noteTable)).toList(),
        );
  }

  /// Stream of notes linked to [company] (case-insensitive).
  Stream<List<Note>> watchNotesByCompany(String company) =>
      (select(noteTable)
            ..where((n) => n.linkedCompany.equals(company))
            ..orderBy([(n) => OrderingTerm.desc(n.updatedAt)]))
          .watch();

  /// Stream of notes where [lastInteractedAt] is older than [daysThreshold]
  /// days ago (or null — never interacted).
  Stream<List<Note>> watchStaleNotes(int daysThreshold) {
    final cutoff = DateTime.now().subtract(Duration(days: daysThreshold));
    return (select(noteTable)
          ..where(
            (n) =>
                n.lastInteractedAt.isNull() |
                n.lastInteractedAt.isSmallerThanValue(cutoff),
          )
          ..orderBy([(n) => OrderingTerm.asc(n.lastInteractedAt)]))
        .watch();
  }

  // ---------------------------------------------------------------------------
  // Single-fetch queries
  // ---------------------------------------------------------------------------

  /// Returns the list of tag strings for the note with [id].
  Future<List<String>> getTagsForNote(int id) async {
    final rows = await (select(noteTagTable)
          ..where((t) => t.noteId.equals(id)))
        .get();
    return rows.map((r) => r.tag).toList();
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  /// Adds a single tag to the note with [noteId].
  Future<void> addTag(int noteId, String tag) =>
      into(noteTagTable).insert(
        NoteTagTableCompanion.insert(noteId: noteId, tag: tag),
      );

  /// Inserts a new note and returns the generated id.
  Future<int> insertNote(NoteTableCompanion companion) =>
      into(noteTable).insert(companion);

  /// Updates note [companion.id] and optionally replaces its tags atomically.
  ///
  /// When [tags] is non-null, the existing tag rows for that note are deleted
  /// and replaced with the new list.
  Future<void> updateNote(
    NoteTableCompanion companion, {
    List<String>? tags,
  }) async {
    await transaction(() async {
      await (update(noteTable)
            ..where((n) => n.id.equals(companion.id.value)))
          .write(companion);
      if (tags != null) {
        await (delete(noteTagTable)
              ..where((t) => t.noteId.equals(companion.id.value)))
            .go();
        for (final tag in tags) {
          await into(noteTagTable).insert(
            NoteTagTableCompanion.insert(
              noteId: companion.id.value,
              tag: tag,
            ),
          );
        }
      }
    });
  }

  /// Deletes the note with [id] and all its associated [NoteTagTable] rows.
  Future<int> deleteNote(int id) async {
    return transaction(() async {
      await (delete(noteTagTable)..where((t) => t.noteId.equals(id))).go();
      return (delete(noteTable)..where((n) => n.id.equals(id))).go();
    });
  }

  /// Updates [lastInteractedAt] to now for the note with [id].
  Future<void> touchNote(int id) async {
    await (update(noteTable)..where((n) => n.id.equals(id))).write(
      NoteTableCompanion(lastInteractedAt: Value(DateTime.now())),
    );
  }
}
