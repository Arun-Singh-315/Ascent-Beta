import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import '../../core/database/app_database.dart';

enum ThoughtConversionMode { todo, reminder, both }

class ThoughtConversionResult {
  const ThoughtConversionResult(this.taskIds, this.reminders);
  final List<int> taskIds;
  final List<Reminder> reminders;
}

class ThoughtActions {
  ThoughtActions(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final DateTime Function() clock;
  final AppDatabase db;

  static String extractTitle(String text) {
    final firstLine = text.trim().split(RegExp(r'\r?\n')).first.trim();
    final candidate = firstLine.isNotEmpty ? firstLine : text.trim();
    return candidate.length <= 300 ? candidate : '${candidate.substring(0, 297)}…';
  }

  static String? extractNotes(String title, String content) {
    final cleanTitle = title.trim();
    final cleanContent = content.trim();
    if (cleanTitle.toLowerCase() == cleanContent.toLowerCase()) {
      return null;
    }
    if (cleanContent.toLowerCase().startsWith(cleanTitle.toLowerCase())) {
      final remainder = cleanContent.substring(cleanTitle.length).trim();
      return remainder.isNotEmpty ? remainder : null;
    }
    return cleanContent.isNotEmpty ? cleanContent : null;
  }

  String _title(String text) => extractTitle(text);

  Future<List<Thought>> _sources(
    List<Thought> requested, {
    bool allowCompleted = false,
  }) async {
    final result = <Thought>[];
    final seen = <int>{};
    for (final source in requested) {
      if (!seen.add(source.id)) continue;
      final current = await db.thoughtDao.getThoughtById(source.id);
      if (current == null ||
          current.isArchived ||
          current.content != source.content) {
        throw StateError(
          'A selected note changed. Review your selection again.',
        );
      }
      if (allowCompleted || !current.isCompleted) result.add(current);
    }
    return result;
  }

  Future<List<int>> addToTodo(List<Thought> thoughts, {DateTime? now}) async =>
      (await convert(
        thoughts,
        mode: ThoughtConversionMode.todo,
        now: now,
      )).taskIds;

  Future<List<Reminder>> remind(
    List<Thought> thoughts,
    DateTime at, {
    bool asList = false,
  }) async => (await convert(
    thoughts,
    mode: ThoughtConversionMode.reminder,
    grouped: asList,
    at: at,
  )).reminders;

  Future<ThoughtConversionResult> convert(
    List<Thought> thoughts, {
    required ThoughtConversionMode mode,
    bool grouped = false,
    DateTime? at,
    DateTime? now,
    String groupTitle = 'Thought checklist',
  }) async {
    final makesReminder = mode != ThoughtConversionMode.todo;
    if (makesReminder && (at == null || !at.isAfter(clock()))) {
      throw ArgumentError('Choose a future date and time.');
    }
    if (groupTitle.trim().isEmpty || groupTitle.length > 300) {
      throw ArgumentError('Use a short checklist title.');
    }
    return db.transaction(() async {
      final sources = await _sources(thoughts);
      if (sources.isEmpty) return const ThoughtConversionResult([], []);
      final ids = <int>[];
      int? parentId;
      if (mode != ThoughtConversionMode.reminder) {
        final existing = <int, Task>{};
        for (final source in sources) {
          final task = await db.taskDao.getTaskLinkedToThought(source.id);
          if (task != null) existing[source.id] = task;
        }
        if (grouped && sources.length > 1) {
          final parents = existing.values
              .map((t) => t.parentTaskId)
              .whereType<int>()
              .toSet();
          if (parents.length > 1) {
            throw StateError(
              'These notes already belong to different checklists. Use Individual items.',
            );
          }
          parentId = parents.isEmpty ? null : parents.single;
          if (parentId != null) {
            if (existing.values.any((task) => task.id == parentId)) {
              throw StateError(
                'These actions include their own checklist parent. Choose its children or use Individual items.',
              );
            }
            final children = await (db.select(
              db.taskTable,
            )..where((t) => t.parentTaskId.equals(parentId!))).get();
            if (children.any(
              (t) =>
                  t.linkedThoughtId == null ||
                  !sources.any((n) => n.id == t.linkedThoughtId),
            )) {
              throw StateError(
                'This checklist includes other notes. Use Individual items.',
              );
            }
            final parent = await db.taskDao.getTaskById(parentId);
            if (parent == null || parent.actualCompletedDate != null) {
              throw StateError('The checklist is no longer active.');
            }
          }
          parentId ??= await db.taskDao.insertTask(
            TaskTableCompanion.insert(
              title: groupTitle.trim(),
              plannedDate: drift.Value(now ?? clock()),
            ),
          );
        }
        for (final source in sources) {
          final old = existing[source.id];
          if (old != null && old.actualCompletedDate != null) {
            throw StateError('A linked Todo is already complete.');
          }
          final cleanTitle = _title(source.content.trim());
          final cleanNotes = extractNotes(cleanTitle, source.content);
          final id =
              old?.id ??
              await db.taskDao.insertTask(
                TaskTableCompanion.insert(
                  title: cleanTitle,
                  notes: drift.Value(cleanNotes),
                  linkedThoughtId: drift.Value(source.id),
                  parentTaskId: drift.Value(parentId),
                  plannedDate: drift.Value(now ?? clock()),
                ),
              );
          if (old != null && parentId != null && old.parentTaskId != parentId) {
            await db.taskDao.updateTask(
              TaskTableCompanion(
                id: drift.Value(id),
                parentTaskId: drift.Value(parentId),
              ),
            );
          }
          ids.add(id);
        }
      }
      final reminders = <Reminder>[];
      if (makesReminder) {
        final groups = grouped
            ? [sources]
            : sources.map((source) => [source]).toList();
        for (final group in groups) {
          final sourceIds = group.map((t) => t.id).toSet();
          Reminder? saved;
          final candidates =
              await (db.select(db.reminderTable)..where(
                    (r) => r.scheduledAt.equals(at!) & r.isActive.equals(true),
                  ))
                  .get();
          for (final candidate in candidates) {
            final links = await (db.select(
              db.thoughtReminderLinkTable,
            )..where((l) => l.reminderId.equals(candidate.id))).get();
            final linked = links.map((l) => l.thoughtId).toSet();
            if (linked.length == sourceIds.length &&
                linked.containsAll(sourceIds)) {
              saved = candidate;
              break;
            }
          }
          if (saved == null) {
            final task = group.length == 1
                ? await db.taskDao.getTaskLinkedToThought(group.single.id)
                : null;
            final title = group.length == 1
                ? _title(group.single.content)
                : group
                      .asMap()
                      .entries
                      .map((e) => '${e.key + 1}. ${e.value.content}')
                      .join('\n');
            final finalTitle =
                title.length <= 300 ? title : '${title.substring(0, 297)}…';
            final id = await db.reminderDao.insertReminder(
              ReminderTableCompanion.insert(
                title: finalTitle,
                scheduledAt: at!,
                alertSyncPending: const drift.Value(true),
                linkedTaskId: drift.Value(parentId ?? task?.id),
              ),
            );
            for (final source in group) {
              await db
                  .into(db.thoughtReminderLinkTable)
                  .insert(
                    ThoughtReminderLinkTableCompanion.insert(
                      thoughtId: source.id,
                      reminderId: id,
                    ),
                  );
            }
            saved = (await db.reminderDao.getReminderById(id))!;
          }
          reminders.add(saved);
        }
      }
      return ThoughtConversionResult(
        parentId == null ? ids : [parentId],
        reminders,
      );
    });
  }

  Future<Thought> merge(
    List<Thought> sources, {
    String? content,
    bool archiveSources = false,
    bool pin = false,
  }) => db.transaction(() async {
    final notes = await _sources(sources, allowCompleted: true);
    if (notes.length < 2) throw ArgumentError('Select at least two notes.');
    // Compare complete snapshots, including pin/completion changes while previewing.
    for (final note in notes) {
      final original = sources.firstWhere((s) => s.id == note.id);
      if (jsonEncode(note.toJson()) != jsonEncode(original.toJson())) {
        throw StateError('A selected note changed. Review the preview again.');
      }
    }
    final text = (content ?? notes.map((n) => n.content).join('\n\n')).trim();
    if (text.isEmpty) throw ArgumentError('The merged note cannot be empty.');
    final id = await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(content: text, isPinned: drift.Value(pin)),
    );
    final merged = (await db.thoughtDao.getThoughtById(id))!;
    for (var i = 0; i < notes.length; i++) {
      final source = notes[i];
      await db
          .into(db.thoughtMergeSourceTable)
          .insert(
            ThoughtMergeSourceTableCompanion.insert(
              mergedThoughtId: id,
              sourceThoughtId: drift.Value(source.id),
              position: i,
              sourceSnapshot: jsonEncode(source.toJson()),
              mergedSnapshot: jsonEncode(merged.toJson()),
              archivedByMerge: drift.Value(
                archiveSources && !source.isArchived,
              ),
            ),
          );
      if (archiveSources) await db.thoughtDao.archiveThought(source.id);
    }
    return merged;
  });

  Future<bool> undoMerge(int id) => db.transaction(() async {
    final merged = await db.thoughtDao.getThoughtById(id);
    final links = await (db.select(
      db.thoughtMergeSourceTable,
    )..where((l) => l.mergedThoughtId.equals(id))).get();
    if (merged == null ||
        links.isEmpty ||
        jsonEncode(merged.toJson()) != links.first.mergedSnapshot ||
        await db.taskDao.getTaskLinkedToThought(id) != null) {
      return false;
    }
    final reminders = await (db.select(
      db.thoughtReminderLinkTable,
    )..where((l) => l.thoughtId.equals(id))).get();
    if (reminders.isNotEmpty) return false;
    for (final link in links.where(
      (l) => l.archivedByMerge && l.sourceThoughtId != null,
    )) {
      final source = await db.thoughtDao.getThoughtById(link.sourceThoughtId!);
      final before = Thought.fromJson(
        jsonDecode(link.sourceSnapshot) as Map<String, dynamic>,
      );
      if (source == null ||
          jsonEncode(source.toJson()) !=
              jsonEncode(before.copyWith(isArchived: true).toJson())) {
        return false;
      }
    }
    for (final link in links.where(
      (l) => l.archivedByMerge && l.sourceThoughtId != null,
    )) {
      await db.thoughtDao.unarchiveThought(link.sourceThoughtId!);
    }
    await (db.delete(
      db.thoughtMergeSourceTable,
    )..where((l) => l.mergedThoughtId.equals(id))).go();
    await db.thoughtDao.deleteThought(id);
    return true;
  });
}

Future<void> scheduleThoughtReminders(
  List<Reminder> reminders,
  Future<void> Function(Reminder) schedule,
) async {
  for (final reminder in reminders) {
    await schedule(reminder);
  }
}
