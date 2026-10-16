import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../../features/thought_wall/thought_actions.dart';
import '../services/promise_service.dart';
import 'riya_capabilities.dart';
import 'riya_money_actions.dart';

const riyaWorkspaceCapabilities = <RiyaCapability>[
  RiyaCapability(
    'thoughts.list',
    'Read recent or pinned thoughts',
    '/thought-wall',
    {'scope': RiyaValue.text, 'offset': RiyaValue.offset},
  ),
  RiyaCapability(
    'thoughts.read',
    'Read a selected thought',
    '/thought-wall',
    {'id': RiyaValue.integer},
    required: ['id'],
  ),
  RiyaCapability(
    'thoughts.create',
    'Save a thought',
    '/thought-wall',
    {'content': RiyaValue.longText},
    required: ['content'],
    write: true,
  ),
  RiyaCapability(
    'thoughts.edit',
    'Edit a selected thought',
    '/thought-wall',
    {'id': RiyaValue.integer, 'content': RiyaValue.longText},
    required: ['id', 'content'],
    write: true,
  ),
  RiyaCapability(
    'thoughts.pin',
    'Change a selected thought pin',
    '/thought-wall',
    {'id': RiyaValue.integer, 'pinned': RiyaValue.boolean},
    required: ['id', 'pinned'],
    write: true,
  ),
  RiyaCapability(
    'thoughts.archive',
    'Archive or restore selected thoughts',
    '/thought-wall',
    {'noteIds': RiyaValue.integerList, 'archived': RiyaValue.boolean},
    required: ['noteIds', 'archived'],
    write: true,
  ),
  RiyaCapability(
    'thoughts.delete',
    'Delete selected thoughts',
    '/thought-wall',
    {'noteIds': RiyaValue.integerList},
    required: ['noteIds'],
    write: true,
  ),
  RiyaCapability(
    'thoughts.merge',
    'Merge selected thoughts',
    '/thought-wall',
    {'noteIds': RiyaValue.integerList, 'archiveSources': RiyaValue.boolean},
    required: ['noteIds'],
    write: true,
  ),
  RiyaCapability(
    'thoughts.convert',
    'Turn thoughts into actions',
    '/thought-wall',
    {
      'noteIds': RiyaValue.integerList,
      'mode': RiyaValue.text,
      'grouped': RiyaValue.boolean,
      'at': RiyaValue.date,
    },
    required: ['noteIds', 'mode'],
    write: true,
  ),
  RiyaCapability('tasks.list', 'Read tasks for a selected day', '/today', {
    'scope': RiyaValue.text,
    'day': RiyaValue.date,
    'offset': RiyaValue.offset,
  }),
  RiyaCapability(
    'tasks.edit',
    'Edit a selected task',
    '/today',
    {'id': RiyaValue.integer, 'title': RiyaValue.text},
    required: ['id', 'title'],
    write: true,
  ),
  RiyaCapability(
    'tasks.complete',
    'Complete an eligible task',
    '/today',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'tasks.delete',
    'Delete a task and its dependent records',
    '/today',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'reminders.done',
    'Complete a selected reminder',
    '/reminders',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'reminders.delete',
    'Delete a selected reminder',
    '/reminders',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'reminders.snooze',
    'Snooze a selected reminder',
    '/reminders',
    {'id': RiyaValue.integer, 'minutes': RiyaValue.integer},
    required: ['id', 'minutes'],
    write: true,
  ),
  RiyaCapability(
    'reminders.mode',
    'Change reminder alert mode',
    '/reminders',
    {'id': RiyaValue.integer, 'alarm': RiyaValue.boolean},
    required: ['id', 'alarm'],
    write: true,
  ),
  RiyaCapability('expenses.list', 'Read scoped expenses', '/money', {
    'scope': RiyaValue.text,
    'day': RiyaValue.date,
    'offset': RiyaValue.offset,
  }),
  RiyaCapability(
    'expenses.edit',
    'Edit a selected expense',
    '/money',
    {
      'id': RiyaValue.integer,
      'amount': RiyaValue.number,
      'title': RiyaValue.text,
    },
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'expenses.delete',
    'Delete a selected expense',
    '/money',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'hydration.read',
    'Read today’s water intake',
    '/hydration',
    {},
  ),
  RiyaCapability(
    'focus.stop',
    'Finish the selected Focus session',
    '/focus',
    {'id': RiyaValue.integer},
    required: ['id'],
    write: true,
  ),
  RiyaCapability(
    'learning.list',
    'Read courses and learning progress',
    '/learning',
    {},
  ),
  RiyaCapability(
    'learning.complete',
    'Complete an eligible lecture',
    '/learning',
    {'courseId': RiyaValue.text, 'lectureId': RiyaValue.integer},
    required: ['courseId', 'lectureId'],
    write: true,
  ),
  RiyaCapability(
    'learning.pause',
    'Pause Learning',
    '/learning',
    {},
    write: true,
  ),
  RiyaCapability(
    'learning.resume',
    'Resume Learning',
    '/learning',
    {},
    write: true,
  ),
  RiyaCapability('home.layout', 'Read Home layout', '/home', {}),
  RiyaCapability(
    'home.visibility',
    'Show or hide a Home card',
    '/home',
    {'section': RiyaValue.text, 'visible': RiyaValue.boolean},
    required: ['section', 'visible'],
    write: true,
  ),
];

class RiyaWorkspaceActions {
  RiyaWorkspaceActions(this.db, this.clock, {this.external});
  final AppDatabase db;
  final DateTime Function() clock;
  final Future<RiyaResult> Function(RiyaCommand)? external;
  bool handles(String id) => riyaWorkspaceCapabilities.any((c) => c.id == id);
  String _excerpt(String text) =>
      text.length <= 180 ? text : '${text.substring(0, 177)}…';
  Future<List<Thought>> _notes(List<dynamic> ids) async {
    final result = <Thought>[];
    for (final id in ids.cast<int>().toSet()) {
      final note = await db.thoughtDao.getThoughtById(id);
      if (note == null) throw StateError('A selected note no longer exists');
      result.add(note);
    }
    return result;
  }

  Future<RiyaResult> run(RiyaCommand cmd) async {
    final a = cmd.arguments, route = cmd.capability.route;
    if (cmd.id.startsWith('learning.') || cmd.id.startsWith('home.')) {
      if (external == null) {
        throw StateError('This action needs the active workspace');
      }
      return external!(cmd);
    }
    switch (cmd.id) {
      case 'thoughts.list':
        final scope = a['scope'] as String? ?? 'recent';
        if (!{'recent', 'pinned', 'archived'}.contains(scope)) {
          throw ArgumentError('Choose recent, pinned or archived');
        }
        final rows =
            await (db.select(db.thoughtTable)
                  ..where(
                    (t) =>
                        t.isArchived.equals(scope == 'archived') &
                        (scope == 'pinned'
                            ? t.isPinned.equals(true)
                            : const Constant(true)),
                  )
                  ..orderBy([
                    (t) => OrderingTerm.desc(t.createdAt),
                    (t) => OrderingTerm.desc(t.id),
                  ])
                  ..limit(4, offset: a['offset'] as int? ?? 0))
                .get();
        return RiyaResult(
          rows.isEmpty
              ? 'No $scope thoughts.'
              : '$scope thoughts:\n${rows.take(3).map((n) => '#${n.id} ${_excerpt(n.content)}').join('\n')}${rows.length > 3 ? '\nMore notes are available.' : ''}',
          route,
          options: [
            'Recent thoughts',
            'Pinned thoughts',
            if (rows.length > 3) 'More thoughts',
          ],
        );
      case 'thoughts.read':
        final note = (await _notes([a['id']])).single;
        return RiyaResult(
          '#${note.id}\n${note.content}',
          route,
          entityType: 'thoughts',
          entityId: note.id,
        );
      case 'thoughts.create':
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: (a['content'] as String).trim(),
          ),
        );
        if (await db.thoughtDao.getThoughtById(id) == null) {
          throw StateError('Thought save could not be verified');
        }
        return RiyaResult(
          'Saved thought #$id.',
          route,
          entityType: 'thoughts',
          entityId: id,
        );
      case 'thoughts.edit':
        final note = (await _notes([a['id']])).single;
        if (note.mood == 'promise') {
          await PromiseService(
            db,
            scheduleNotification: (_, _, _) async {},
          ).update(thoughtId: note.id, content: a['content']);
        } else {
          await db.thoughtDao.updateThought(
            note
                .toCompanion(true)
                .copyWith(content: Value((a['content'] as String).trim())),
          );
        }
        final saved = await db.thoughtDao.getThoughtById(note.id);
        if (saved?.content != (a['content'] as String).trim()) {
          throw StateError('Thought edit could not be verified');
        }
        final task = await db.taskDao.getTaskLinkedToThought(note.id);
        final reminders = task == null
            ? <Reminder>[]
            : (await db.reminderDao.getRemindersByTaskId(task.id))
                  .where((r) => r.isActive && r.scheduledAt.isAfter(clock()))
                  .toList();
        for (final reminder in reminders) {
          await db.reminderDao.updateReminder(
            reminder
                .toCompanion(true)
                .copyWith(alertSyncPending: const Value(true)),
          );
        }
        return RiyaResult(
          'Updated thought #${note.id}.',
          route,
          cancelReminderIds: reminders.map((r) => r.id).toList(),
          reminderIds: reminders.map((r) => r.id).toList(),
        );
      case 'thoughts.pin':
        final note = (await _notes([a['id']])).single;
        await db.thoughtDao.updateThought(
          note.toCompanion(true).copyWith(isPinned: Value(a['pinned'] as bool)),
        );
        return RiyaResult(
          '${a['pinned'] == true ? 'Pinned' : 'Unpinned'} thought #${note.id}.',
          route,
        );
      case 'thoughts.archive':
      case 'thoughts.delete':
        final notes = await _notes(a['noteIds']);
        for (final note in notes) {
          if (cmd.id == 'thoughts.delete') {
            await db.thoughtDao.deleteThought(note.id);
          } else if (a['archived'] == true) {
            await db.thoughtDao.archiveThought(note.id);
          } else {
            await db.thoughtDao.unarchiveThought(note.id);
          }
        }
        return RiyaResult(
          '${cmd.id == 'thoughts.delete'
              ? 'Deleted'
              : a['archived'] == true
              ? 'Archived'
              : 'Restored'} ${notes.length} selected notes.',
          route,
        );
      case 'thoughts.merge':
        final notes = await _notes(a['noteIds']);
        final merged = await ThoughtActions(
          db,
          clock: clock,
        ).merge(notes, archiveSources: a['archiveSources'] == true);
        return RiyaResult(
          'Saved merged thought #${merged.id}. Original links are preserved.',
          route,
        );
      case 'thoughts.convert':
        final notes = await _notes(a['noteIds']);
        final mode = switch (a['mode']) {
          'todo' => ThoughtConversionMode.todo,
          'reminder' => ThoughtConversionMode.reminder,
          'both' => ThoughtConversionMode.both,
          _ => throw ArgumentError('Choose todo, reminder or both'),
        };
        final result = await ThoughtActions(db, clock: clock).convert(
          notes,
          mode: mode,
          grouped: a['grouped'] == true,
          at: a['at'] == null ? null : DateTime.parse(a['at']).toLocal(),
        );
        if (result.taskIds.isEmpty && result.reminders.isEmpty) {
          throw StateError('Select active notes');
        }
        return RiyaResult(
          'Saved ${result.taskIds.length} Todos and ${result.reminders.length} reminders.',
          route,
          reminderIds: result.reminders.map((r) => r.id).toList(),
        );
      case 'tasks.list':
        final scope = a['scope'] as String? ?? 'today';
        if (!{'today', 'tomorrow', 'all', 'date'}.contains(scope)) {
          throw ArgumentError('Choose a task date');
        }
        final now = clock();
        final day = a['day'] == null
            ? DateTime(
                now.year,
                now.month,
                now.day + (scope == 'tomorrow' ? 1 : 0),
              )
            : DateTime.parse(a['day']).toLocal();
        final from = DateTime(day.year, day.month, day.day),
            to = DateTime(day.year, day.month, day.day + 1);
        final rows =
            await (db.select(db.taskTable)
                  ..where(
                    (t) => scope == 'all'
                        ? const Constant(true)
                        : t.plannedDate.isBiggerOrEqualValue(from) &
                              t.plannedDate.isSmallerThanValue(to),
                  )
                  ..orderBy([
                    (t) => OrderingTerm.desc(t.createdAt),
                    (t) => OrderingTerm.desc(t.id),
                  ])
                  ..limit(4, offset: a['offset'] as int? ?? 0))
                .get();
        return RiyaResult(
          rows.isEmpty
              ? 'No tasks for $scope.'
              : 'Tasks · $scope:\n${rows.take(3).map((t) => '#${t.id} ${t.actualCompletedDate == null ? '•' : '✓'} ${_excerpt(t.title)}').join('\n')}',
          route,
          options: [
            'Tasks today',
            'Tasks tomorrow',
            'All tasks',
            if (rows.length > 3) 'More tasks',
          ],
        );
      case 'tasks.edit':
        final task = await db.taskDao.getTaskById(a['id']);
        if (task == null) throw StateError('The task no longer exists');
        if (!await db.taskDao.updateTask(
          TaskTableCompanion(
            id: Value(task.id),
            title: Value(a['title']),
            updatedAt: Value(clock()),
          ),
        )) {
          throw StateError('Task edit failed');
        }
        return RiyaResult('Updated task #${task.id}.', route);
      case 'tasks.complete':
        final task = await db.taskDao.getTaskById(a['id']);
        if (task == null) throw StateError('The task no longer exists');
        final reminders = await db.reminderDao.getRemindersByTaskId(task.id);
        final completed =
            task.actualCompletedDate != null ||
            await db.taskDao.markComplete(task.id);
        if (!completed) {
          throw StateError(
            task.learningCourseId != null
                ? 'This activity belongs to Learning. Complete its lecture study target there.'
                : 'Complete the required Focus time or unfinished checklist items first',
          );
        }
        return RiyaResult(
          'Completed task #${task.id}.',
          route,
          cancelReminderIds: reminders.map((r) => r.id).toList(),
        );
      case 'tasks.delete':
        final task = await db.taskDao.getTaskById(a['id']);
        if (task == null) throw StateError('The task no longer exists');
        final cancel = await db.taskDao.deleteTaskWithDependents(task.id);
        return RiyaResult(
          'Deleted task #${task.id} and its linked records.',
          route,
          cancelReminderIds: cancel,
        );
      case 'reminders.done':
      case 'reminders.delete':
      case 'reminders.snooze':
      case 'reminders.mode':
        final old = await db.reminderDao.getReminderById(a['id']);
        if (old == null) throw StateError('The reminder no longer exists');
        if (cmd.id == 'reminders.delete') {
          await db.reminderDao.deleteReminder(old.id);
        } else {
          final minutes = a['minutes'] as int? ?? 10;
          if (minutes > 1440) throw ArgumentError('Snooze up to one day');
          await db.reminderDao.updateReminder(
            old
                .toCompanion(true)
                .copyWith(
                  isActive: Value(cmd.id != 'reminders.done'),
                  scheduledAt: Value(
                    cmd.id == 'reminders.snooze'
                        ? clock().add(Duration(minutes: minutes))
                        : old.scheduledAt,
                  ),
                  alarmEnabled: Value(a['alarm'] as bool? ?? old.alarmEnabled),
                  alertSyncPending: Value(cmd.id != 'reminders.done'),
                ),
          );
        }
        final reschedule =
            cmd.id == 'reminders.snooze' || cmd.id == 'reminders.mode';
        return RiyaResult(
          '${cmd.id == 'reminders.delete'
              ? 'Deleted'
              : cmd.id == 'reminders.done'
              ? 'Completed'
              : 'Updated'} reminder #${old.id}.',
          route,
          cancelReminderIds: [old.id],
          reminderIds: reschedule ? [old.id] : [],
        );
      case 'expenses.list':
        final result = await RiyaMoneyActions(db, clock).run(
          RiyaCommand('transactions.list', {
            ...a,
            'type': 'expense',
            if (a['scope'] == 'recent') 'scope': 'all',
          }),
        );
        return RiyaResult(
          result.message,
          route,
          options: [
            'Expenses today',
            'Expenses all',
            if (result.options.contains('More transactions')) 'More expenses',
          ],
        );
      case 'expenses.edit':
      case 'expenses.delete':
        final old = await (db.select(
          db.financeTransactionTable,
        )..where((r) => r.id.equals(a['id'] as int))).getSingleOrNull();
        if (old == null || old.type != 'expense') {
          throw StateError('The expense no longer exists');
        }
        if (cmd.id == 'expenses.delete') {
          await (db.delete(
            db.financeTransactionTable,
          )..where((r) => r.id.equals(old.id))).go();
        } else {
          if (!a.containsKey('amount') && !a.containsKey('title')) {
            throw ArgumentError('Choose an amount or description to change');
          }
          await (db.update(
            db.financeTransactionTable,
          )..where((r) => r.id.equals(old.id))).write(
            FinanceTransactionTableCompanion(
              amount: Value((a['amount'] as num?)?.toDouble() ?? old.amount),
              title: Value(a['title'] as String? ?? old.title),
            ),
          );
        }
        return RiyaResult(
          '${cmd.id == 'expenses.delete' ? 'Deleted' : 'Updated'} expense #${old.id}.',
          route,
        );
      case 'hydration.read':
        final amount = await db.waterDao.watchTodayWaterMl().first;
        return RiyaResult('Water logged today: $amount ml.', route);
      case 'focus.stop':
        final session = await db.timeSessionDao.getActiveFocusSession();
        if (session == null || session.id != a['id']) {
          throw StateError('The selected Focus session is no longer active');
        }
        await db.timeSessionDao.completeSession(session.id);
        if (session.linkedTaskId != null) {
          await db.taskDao.completeTimedTaskAfterFocus(session.linkedTaskId!);
        }
        return RiyaResult(
          'Finished Focus “${session.label}”. Task completion still follows its time requirement.',
          route,
        );
      default:
        throw UnsupportedError('Unsupported workspace action');
    }
  }
}
