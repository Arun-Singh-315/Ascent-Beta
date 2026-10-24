import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import '../models/promise_model.dart';

/// Repository managing Promise data persistence, progress tracking events,
/// and bidirectional synchronization with ThoughtTable and NotificationService.
class PromiseRepository {
  PromiseRepository(this._db);

  final AppDatabase _db;
  bool _initialized = false;

  /// Ensures SQLite tables for promise metadata and granular progress events exist.
  Future<void> initialize() async {
    if (_initialized) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS promise_metadata (
        promise_id INTEGER PRIMARY KEY,
        tracking_type TEXT NOT NULL,
        target_value REAL NOT NULL DEFAULT 1.0,
        unit TEXT NOT NULL DEFAULT '',
        frequency_per_week INTEGER NOT NULL DEFAULT 0,
        target_date INTEGER,
        is_private INTEGER NOT NULL DEFAULT 0,
        reminder_time TEXT,
        reminder_days TEXT,
        reminder_enabled INTEGER NOT NULL DEFAULT 1,
        current_value REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'active',
        completed_at INTEGER,
        next_action_prompt TEXT
      );
    ''');

    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS promise_progress_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        promise_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 1.0,
        occurred_at INTEGER NOT NULL,
        note TEXT
      );
    ''');
    _initialized = true;
  }

  /// Creates a new promise, stores its metadata and schedules respectful reminders.
  Future<PromiseModel> createPromise({
    required String title,
    required String intention,
    required String category,
    required PromiseTrackingType trackingType,
    double targetValue = 1.0,
    String unit = '',
    int frequencyPerWeek = 0,
    DateTime? targetDate,
    bool isPrivate = false,
    String? reminderTime,
    List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    bool reminderEnabled = true,
    double currentValue = 0.0,
    String? nextActionPrompt,
  }) async {
    await initialize();
    final now = DateTime.now();

    // 1. Insert into ThoughtTable for seamless sync with Mind Wall & backup
    final id = await _db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(
        content: title.trim(),
        mood: const drift.Value('promise'),
        category: drift.Value(category),
        promptQuestion: drift.Value(intention.trim()),
        isCompleted: const drift.Value(false),
        createdAt: drift.Value(now),
      ),
    );

    // 2. Insert metadata
    await _db.customStatement(
      '''
      INSERT OR REPLACE INTO promise_metadata (
        promise_id, tracking_type, target_value, unit, frequency_per_week,
        target_date, is_private, reminder_time, reminder_days, reminder_enabled,
        current_value, status, next_action_prompt
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      [
        id,
        trackingType.name,
        targetValue,
        unit,
        frequencyPerWeek,
        targetDate?.millisecondsSinceEpoch,
        isPrivate ? 1 : 0,
        reminderTime,
        jsonEncode(reminderDays),
        reminderEnabled ? 1 : 0,
        currentValue,
        PromiseStatus.active.name,
        nextActionPrompt,
      ],
    );

    final promise = PromiseModel(
      id: id,
      title: title.trim(),
      intention: intention.trim(),
      category: category,
      trackingType: trackingType,
      targetValue: targetValue,
      unit: unit,
      frequencyPerWeek: frequencyPerWeek,
      targetDate: targetDate,
      isPrivate: isPrivate,
      reminderTime: reminderTime,
      reminderDays: reminderDays,
      reminderEnabled: reminderEnabled,
      currentValue: currentValue,
      status: PromiseStatus.active,
      createdAt: now,
      nextActionPrompt: nextActionPrompt,
    );

    // 3. Schedule notification if configured
    if (reminderEnabled && reminderTime != null) {
      await _schedulePromiseNotification(promise);
    }

    return promise;
  }

  /// Retrieves a promise by ID.
  Future<PromiseModel?> getPromiseById(int id) async {
    await initialize();
    final thought = await _db.thoughtDao.getThoughtById(id);
    if (thought == null) return null;

    final metaRows = await _db.customSelect(
      'SELECT * FROM promise_metadata WHERE promise_id = ?',
      variables: [drift.Variable.withInt(id)],
    ).get();

    if (metaRows.isEmpty) {
      // Default fallback metadata if thought exists without metadata
      return PromiseModel(
        id: thought.id,
        title: thought.content,
        intention: thought.promptQuestion ?? '',
        category: thought.category ?? 'personal',
        trackingType: PromiseTrackingType.completion,
        status: thought.isCompleted ? PromiseStatus.completed : PromiseStatus.active,
        createdAt: thought.createdAt,
      );
    }

    final row = metaRows.first.data;
    return _mapRowToPromise(thought, row);
  }

  /// Records a granular progress event (e.g. workout session, duration study, check-in).
  Future<void> recordProgress({
    required int promiseId,
    required PromiseEventType eventType,
    double amount = 1.0,
    String? note,
  }) async {
    await initialize();
    final now = DateTime.now();

    // 1. Insert progress event
    await _db.customStatement(
      '''
      INSERT INTO promise_progress_events (promise_id, event_type, amount, occurred_at, note)
      VALUES (?, ?, ?, ?, ?);
      ''',
      [promiseId, eventType.name, amount, now.millisecondsSinceEpoch, note],
    );

    // 2. Fetch current metadata
    final promise = await getPromiseById(promiseId);
    if (promise == null) return;

    final newCurrentValue = promise.currentValue + amount;
    bool shouldComplete = false;

    if (promise.trackingType == PromiseTrackingType.completion) {
      shouldComplete = true;
    } else if (promise.trackingType == PromiseTrackingType.milestone && newCurrentValue >= promise.targetValue) {
      shouldComplete = true;
    }

    // 3. Update metadata
    await _db.customStatement(
      '''
      UPDATE promise_metadata
      SET current_value = ?,
          status = ?,
          completed_at = ?
      WHERE promise_id = ?;
      ''',
      [
        newCurrentValue,
        shouldComplete ? PromiseStatus.completed.name : promise.status.name,
        shouldComplete ? now.millisecondsSinceEpoch : promise.completedAt?.millisecondsSinceEpoch,
        promiseId,
      ],
    );

    // 4. Update ThoughtTable if completed
    if (shouldComplete) {
      await _db.thoughtDao.setCompleted(promiseId, true);
      await _cancelNotification(promiseId);
    }
  }

  /// Marks a promise as completed.
  Future<void> completePromise(int id) async {
    await initialize();
    final now = DateTime.now();

    await _db.customStatement(
      '''
      UPDATE promise_metadata
      SET status = ?,
          completed_at = ?
      WHERE promise_id = ?;
      ''',
      [PromiseStatus.completed.name, now.millisecondsSinceEpoch, id],
    );

    await _db.thoughtDao.setCompleted(id, true);
    await _cancelNotification(id);
  }

  /// Sets the lifecycle status of a promise (active, paused, archived, completed).
  Future<void> setPromiseStatus(int id, PromiseStatus status) async {
    await initialize();
    final now = DateTime.now();

    await _db.customStatement(
      '''
      UPDATE promise_metadata
      SET status = ?,
          completed_at = ?
      WHERE promise_id = ?;
      ''',
      [
        status.name,
        status == PromiseStatus.completed ? now.millisecondsSinceEpoch : null,
        id,
      ],
    );

    if (status == PromiseStatus.completed) {
      await _db.thoughtDao.setCompleted(id, true);
      await _cancelNotification(id);
    } else if (status == PromiseStatus.active) {
      await _db.thoughtDao.setCompleted(id, false);
      final p = await getPromiseById(id);
      if (p != null && p.reminderEnabled && p.reminderTime != null) {
        await _schedulePromiseNotification(p);
      }
    } else if (status == PromiseStatus.paused) {
      await _cancelNotification(id);
    }
  }

  /// Deletes a promise completely along with its history and notifications.
  Future<void> deletePromise(int id) async {
    await initialize();
    await _cancelNotification(id);
    await _db.customStatement('DELETE FROM promise_progress_events WHERE promise_id = ?', [id]);
    await _db.customStatement('DELETE FROM promise_metadata WHERE promise_id = ?', [id]);
    await _db.thoughtDao.deleteThought(id);
  }

  /// Retrieves progress history events for a given promise.
  Future<List<PromiseProgressEvent>> getProgressEvents(int promiseId) async {
    await initialize();
    final rows = await _db.customSelect(
      'SELECT * FROM promise_progress_events WHERE promise_id = ? ORDER BY occurred_at DESC',
      variables: [drift.Variable.withInt(promiseId)],
    ).get();

    return rows.map((r) {
      final d = r.data;
      return PromiseProgressEvent(
        id: d['id'] as int,
        promiseId: d['promise_id'] as int,
        eventType: PromiseEventType.values.firstWhere(
          (e) => e.name == (d['event_type'] as String),
          orElse: () => PromiseEventType.completion,
        ),
        amount: (d['amount'] as num).toDouble(),
        occurredAt: DateTime.fromMillisecondsSinceEpoch(d['occurred_at'] as int),
        note: d['note'] as String?,
      );
    }).toList();
  }

  /// Retrieves all active promises.
  Future<List<PromiseModel>> getActivePromises() async {
    await initialize();
    final thoughts = await (_db.select(_db.thoughtTable)
          ..where((t) => t.mood.equals('promise') & t.isArchived.equals(false)))
        .get();

    final results = <PromiseModel>[];
    for (final t in thoughts) {
      final p = await getPromiseById(t.id);
      if (p != null && p.isActive) {
        results.add(p);
      }
    }
    return results;
  }

  /// Retrieves all completed promises.
  Future<List<PromiseModel>> getCompletedPromises() async {
    await initialize();
    final thoughts = await (_db.select(_db.thoughtTable)
          ..where((t) => t.mood.equals('promise') & t.isArchived.equals(false)))
        .get();

    final results = <PromiseModel>[];
    for (final t in thoughts) {
      final p = await getPromiseById(t.id);
      if (p != null && p.isCompleted) {
        results.add(p);
      }
    }
    return results;
  }

  /// Retrieves all paused promises.
  Future<List<PromiseModel>> getPausedPromises() async {
    await initialize();
    final thoughts = await (_db.select(_db.thoughtTable)
          ..where((t) => t.mood.equals('promise') & t.isArchived.equals(false)))
        .get();

    final results = <PromiseModel>[];
    for (final t in thoughts) {
      final p = await getPromiseById(t.id);
      if (p != null && p.isPaused) {
        results.add(p);
      }
    }
    return results;
  }

  /// Watch active promises stream.
  Stream<List<PromiseModel>> watchActivePromises() {
    return (_db.select(_db.thoughtTable)
          ..where((t) => t.mood.equals('promise') & t.isArchived.equals(false)))
        .watch()
        .asyncMap((thoughts) async {
      final results = <PromiseModel>[];
      for (final t in thoughts) {
        final p = await getPromiseById(t.id);
        if (p != null && p.isActive) {
          results.add(p);
        }
      }
      return results;
    });
  }

  /// Watch completed promises stream.
  Stream<List<PromiseModel>> watchCompletedPromises() {
    return (_db.select(_db.thoughtTable)
          ..where((t) => t.mood.equals('promise') & t.isArchived.equals(false)))
        .watch()
        .asyncMap((thoughts) async {
      final results = <PromiseModel>[];
      for (final t in thoughts) {
        final p = await getPromiseById(t.id);
        if (p != null && p.isCompleted) {
          results.add(p);
        }
      }
      return results;
    });
  }

  /// Watch paused promises stream.
  Stream<List<PromiseModel>> watchPausedPromises() {
    return (_db.select(_db.thoughtTable)
          ..where((t) => t.mood.equals('promise') & t.isArchived.equals(false)))
        .watch()
        .asyncMap((thoughts) async {
      final results = <PromiseModel>[];
      for (final t in thoughts) {
        final p = await getPromiseById(t.id);
        if (p != null && p.isPaused) {
          results.add(p);
        }
      }
      return results;
    });
  }

  /// Watch all promises stream.
  Stream<List<PromiseModel>> watchAllPromises() {
    return (_db.select(_db.thoughtTable)
          ..where((t) => t.mood.equals('promise') & t.isArchived.equals(false)))
        .watch()
        .asyncMap((thoughts) async {
      final results = <PromiseModel>[];
      for (final t in thoughts) {
        final p = await getPromiseById(t.id);
        if (p != null) {
          results.add(p);
        }
      }
      return results;
    });
  }

  PromiseModel _mapRowToPromise(Thought thought, Map<String, dynamic> row) {
    final trackingTypeName = row['tracking_type'] as String? ?? 'completion';
    final statusName = row['status'] as String? ?? 'active';
    final targetDateMillis = row['target_date'] as int?;
    final completedAtMillis = row['completed_at'] as int?;

    List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7];
    if (row['reminder_days'] != null) {
      try {
        final decoded = jsonDecode(row['reminder_days'] as String);
        if (decoded is List) {
          reminderDays = decoded.map((e) => (e as num).toInt()).toList();
        }
      } catch (_) {}
    }

    return PromiseModel(
      id: thought.id,
      title: thought.content,
      intention: thought.promptQuestion ?? '',
      category: thought.category ?? 'personal',
      trackingType: PromiseTrackingType.values.firstWhere(
        (e) => e.name == trackingTypeName,
        orElse: () => PromiseTrackingType.completion,
      ),
      targetValue: (row['target_value'] as num?)?.toDouble() ?? 1.0,
      unit: row['unit'] as String? ?? '',
      frequencyPerWeek: (row['frequency_per_week'] as num?)?.toInt() ?? 0,
      targetDate: targetDateMillis != null ? DateTime.fromMillisecondsSinceEpoch(targetDateMillis) : null,
      isPrivate: (row['is_private'] as int?) == 1,
      reminderTime: row['reminder_time'] as String?,
      reminderDays: reminderDays,
      reminderEnabled: (row['reminder_enabled'] as int?) != 0,
      currentValue: (row['current_value'] as num?)?.toDouble() ?? 0.0,
      status: PromiseStatus.values.firstWhere(
        (e) => e.name == statusName,
        orElse: () => thought.isCompleted ? PromiseStatus.completed : PromiseStatus.active,
      ),
      createdAt: thought.createdAt,
      completedAt: completedAtMillis != null ? DateTime.fromMillisecondsSinceEpoch(completedAtMillis) : null,
      nextActionPrompt: row['next_action_prompt'] as String?,
    );
  }

  Future<void> _schedulePromiseNotification(PromiseModel promise) async {
    if (promise.reminderTime == null) return;
    final parts = promise.reminderTime!.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final title = promise.isPrivate ? 'A personal commitment awaits' : promise.title;
    final body = promise.isPrivate
        ? 'Take a quiet moment for the promise you made to yourself.'
        : (promise.intention.isNotEmpty ? promise.intention : 'One small step is enough to get started.');

    try {
      await NotificationService.instance.schedulePromiseCheckIn(
        id: 1900000000 + promise.id,
        title: title,
        body: body,
        scheduledAt: scheduled,
      );
    } catch (_) {}
  }

  Future<void> _cancelNotification(int promiseId) async {
    try {
      await NotificationService.instance.cancel(1900000000 + promiseId);
    } catch (_) {}
  }
}
