import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';
import '../notifications/notification_service.dart';

/// Promises are reflections with shared daily check-ins, never implicit tasks.
/// All commitments live in Thought Wall so editing, backup and archive work normally.
class PromiseService {
  PromiseService(
    this._db, {
    Future<void> Function(int, String, DateTime)? scheduleNotification,
    Future<void> Function(int)? cancelNotification,
    DateTime Function()? clock,
  }) : _schedule = scheduleNotification ?? _scheduleCheckIn,
       _cancel = cancelNotification ?? NotificationService.instance.cancel,
       _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final Future<void> Function(int, String, DateTime) _schedule;
  final Future<void> Function(int) _cancel;
  final DateTime Function() _clock;
  static const checkInHours = [10, 14, 18, 21];
  // Separate from persisted reminder, medicine and focus notification IDs.
  static const notificationBase = 1800000000;
  Future<void> _syncTail = Future.value();

  static Future<void> _scheduleCheckIn(int id, String copy, DateTime at) async {
    final lines = copy.split('\n');
    final success = await NotificationService.instance.schedulePromiseCheckIn(
      id: id,
      title: lines.first,
      body: lines.skip(1).join('\n'),
      scheduledAt: at,
    );
    if (!success) throw StateError('Promise check-ins are unavailable.');
  }

  Future<int> create({required String content, String? promptQuestion}) async =>
      (await createBatch([content], promptQuestion: promptQuestion)).single;

  Future<List<int>> createBatch(
    List<String> contents, {
    String? promptQuestion,
  }) async {
    final texts = contents.map((text) => text.trim()).toList();
    if (texts.isEmpty ||
        texts.any((text) => text.isEmpty || text.length > 300)) {
      throw ArgumentError('Use 1 to 300 characters for each promise.');
    }
    final ids = <int>[];
    await _db.transaction(() async {
      for (final text in texts) {
        ids.add(
          await _db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(
              content: text,
              mood: const drift.Value('promise'),
              promptQuestion: drift.Value(promptQuestion),
              createdAt: drift.Value(_clock()),
            ),
          ),
        );
      }
    });
    // The committed reflections survive denied permissions; retry on changes/resume.
    await syncCheckIns();
    return ids;
  }

  Future<bool> syncCheckIns() {
    final result = _syncTail.then((_) => _sync());
    _syncTail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<bool> _sync() async {
    try {
      final now = _clock();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = DateTime(now.year, now.month, now.day + 1);
      final thoughts =
          await (_db.select(_db.thoughtTable)..where(
                (t) =>
                    t.mood.equals('promise') &
                    t.isArchived.equals(false) &
                    t.isCompleted.equals(false) &
                    t.createdAt.isBiggerOrEqualValue(today) &
                    t.createdAt.isSmallerThanValue(tomorrow),
              ))
              .get();
      final profile = await _db.userProfileDao.getProfile();
      final name = profile?.name.trim().split(RegExp(r'\s+')).first ?? '';
      final greeting = name.isEmpty
          ? 'Hey, let’s keep your promises'
          : 'Hey $name, let’s keep your promises';
      final content = [
        greeting,
        'We’re in this together. Take one small step:',
        for (var i = 0; i < thoughts.length; i++)
          '${i + 1}. ${thoughts[i].content}',
      ].join('\n');
      var complete = true;
      for (var i = 0; i < checkInHours.length; i++) {
        final id = notificationBase + i;
        final at = DateTime(now.year, now.month, now.day, checkInHours[i]);
        try {
          await _cancel(id);
          if (thoughts.isNotEmpty && at.isAfter(now)) {
            await _schedule(id, content, at);
          }
        } catch (_) {
          complete = false;
        }
      }
      return complete;
    } catch (_) {
      return false;
    }
  }

  /// New promises only update their reflection. Legacy links remain editable.
  Future<void> update({required int thoughtId, required String content}) async {
    final text = content.trim();
    if (text.isEmpty || text.length > 300) {
      throw ArgumentError('Use 1 to 300 characters.');
    }
    await _db.transaction(() async {
      final thought = await _db.thoughtDao.getThoughtById(thoughtId);
      if (thought == null || thought.mood != 'promise') {
        throw StateError('Promise not found.');
      }
      await _db.thoughtDao.updateThought(
        thought.toCompanion(true).copyWith(content: drift.Value(text)),
      );
      final task = await _db.taskDao.getTaskLinkedToThought(thoughtId);
      if (task != null) {
        await (_db.update(_db.taskTable)..where((t) => t.id.equals(task.id)))
            .write(TaskTableCompanion(title: drift.Value(text)));
        await (_db.update(
          _db.reminderTable,
        )..where((r) => r.linkedTaskId.equals(task.id))).write(
          ReminderTableCompanion(
            title: drift.Value('Promise: $text'),
            alertSyncPending: const drift.Value(true),
          ),
        );
      }
    });
    await syncCheckIns();
  }
}
