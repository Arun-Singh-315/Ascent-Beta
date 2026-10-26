import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import '../models/promise_model.dart';

typedef PromiseNotificationScheduler =
    Future<bool> Function(int id, String title, String body, DateTime at);

/// One persistence boundary for commitments, dated progress and reminders.
class PromiseRepository {
  PromiseRepository(
    this._db, {
    DateTime Function()? clock,
    PromiseNotificationScheduler? scheduleNotification,
    Future<void> Function(int)? cancelNotification,
  }) : _clock = clock ?? DateTime.now,
       _schedule = scheduleNotification ?? _nativeSchedule,
       _cancel = cancelNotification ?? NotificationService.instance.cancel;
  final AppDatabase _db;
  final DateTime Function() _clock;
  final PromiseNotificationScheduler _schedule;
  final Future<void> Function(int) _cancel;
  final _reminderTails = <int, Future<void>>{};
  static final _initializations = Expando<Future<void>>();
  static Future<bool> _nativeSchedule(
    int id,
    String title,
    String body,
    DateTime at,
  ) => NotificationService.instance.schedulePromiseCheckIn(
    id: id,
    title: title,
    body: body,
    scheduledAt: at,
  );

  Future<void> initialize() => _initializations[_db] ??= _initialize();
  Future<void> _initialize() async {
    await _db.customStatement(
      '''CREATE TABLE IF NOT EXISTS promise_metadata (
      promise_id INTEGER PRIMARY KEY, tracking_type TEXT NOT NULL, target_value REAL NOT NULL DEFAULT 1,
      unit TEXT NOT NULL DEFAULT '', frequency_per_week INTEGER NOT NULL DEFAULT 0, target_date INTEGER,
      is_private INTEGER NOT NULL DEFAULT 0, reminder_time TEXT, reminder_days TEXT, reminder_enabled INTEGER NOT NULL DEFAULT 1,
      current_value REAL NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'active', completed_at INTEGER, next_action_prompt TEXT)''',
    );
    await _db.customStatement(
      '''CREATE TABLE IF NOT EXISTS promise_progress_events (
      id INTEGER PRIMARY KEY AUTOINCREMENT, promise_id INTEGER NOT NULL, event_type TEXT NOT NULL,
      amount REAL NOT NULL DEFAULT 1, occurred_at INTEGER NOT NULL, note TEXT)''',
    );
    final metadata = (await _rows(
      'PRAGMA table_info(promise_metadata)',
    )).map((r) => r['name']).toSet();
    for (final column in ['schedule_json TEXT', 'reminder_error TEXT']) {
      if (!metadata.contains(column.split(' ').first)) {
        await _db.customStatement(
          'ALTER TABLE promise_metadata ADD COLUMN $column',
        );
      }
    }
    final events = (await _rows(
      'PRAGMA table_info(promise_progress_events)',
    )).map((r) => r['name']).toSet();
    if (!events.contains('occurrence_date')) {
      await _db.customStatement(
        'ALTER TABLE promise_progress_events ADD COLUMN occurrence_date TEXT',
      );
    }
    await _db.customStatement(
      '''CREATE TABLE IF NOT EXISTS promise_occurrences (
      promise_id INTEGER NOT NULL, local_date TEXT NOT NULL, amount REAL NOT NULL DEFAULT 0,
      target REAL NOT NULL DEFAULT 1, state TEXT NOT NULL DEFAULT 'pending', note TEXT,
      PRIMARY KEY(promise_id, local_date))''',
    );
    await _db.customStatement(
      '''CREATE TABLE IF NOT EXISTS promise_schedule_versions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, promise_id INTEGER NOT NULL, effective_date TEXT NOT NULL,
      schedule_json TEXT, target REAL NOT NULL, UNIQUE(promise_id, effective_date))''',
    );
    await _db.customStatement(
      '''CREATE TABLE IF NOT EXISTS promise_pause_periods (
      id INTEGER PRIMARY KEY AUTOINCREMENT, promise_id INTEGER NOT NULL, started_at INTEGER NOT NULL, ended_at INTEGER)''',
    );
    await _db.customStatement(
      'CREATE INDEX IF NOT EXISTS promise_events_owner_date ON promise_progress_events(promise_id, occurrence_date)',
    );
  }

  Future<List<Map<String, dynamic>>> _rows(
    String sql, [
    List<Object?> values = const [],
  ]) async =>
      (await _db
              .customSelect(
                sql,
                variables: values
                    .map(
                      (v) => switch (v) {
                        int n => drift.Variable.withInt(n),
                        double n => drift.Variable.withReal(n),
                        String s => drift.Variable.withString(s),
                        null => const drift.Variable<String>(null),
                        _ => throw ArgumentError('Unsupported SQL value'),
                      },
                    )
                    .toList(),
              )
              .get())
          .map((r) => r.data)
          .toList();
  void _notify() =>
      _db.notifyUpdates({drift.TableUpdate(_db.thoughtTable.actualTableName)});

  Future<PromiseModel> createPromise({
    required String title,
    required String intention,
    required String category,
    required PromiseTrackingType trackingType,
    double targetValue = 1,
    String unit = '',
    int frequencyPerWeek = 0,
    DateTime? targetDate,
    PromiseSchedule? schedule,
    bool isPrivate = false,
    String? reminderTime,
    List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7],
    bool reminderEnabled = true,
    double currentValue = 0,
    String? nextActionPrompt,
  }) async {
    await initialize();
    _validate(
      title,
      targetValue,
      reminderTime,
      schedule,
      frequencyPerWeek,
      trackingType,
    );
    final now = _clock();
    final id = await _db.transaction(() async {
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
      await _db.customStatement(
        '''INSERT INTO promise_metadata
        (promise_id, tracking_type, target_value, unit, frequency_per_week, target_date, is_private, reminder_time,
         reminder_days, reminder_enabled, current_value, status, next_action_prompt, schedule_json)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
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
          reminderEnabled && reminderTime != null ? 1 : 0,
          currentValue,
          'active',
          nextActionPrompt,
          schedule?.encode(),
        ],
      );
      await _db.customStatement(
        'INSERT INTO promise_schedule_versions(promise_id,effective_date,schedule_json,target) VALUES(?,?,?,?)',
        [id, promiseDateKey(now), schedule?.encode(), targetValue],
      );
      return id;
    });
    _notify();
    final created = (await getPromiseById(id))!;
    if (created.reminderEnabled) await syncReminders(created);
    return (await getPromiseById(id))!;
  }

  void _validate(
    String title,
    double target,
    String? reminder,
    PromiseSchedule? schedule,
    int weekly,
    PromiseTrackingType type,
  ) {
    if (title.trim().isEmpty || title.trim().length > 1000) {
      throw ArgumentError('Write a promise of 1 to 1,000 characters.');
    }
    if (!target.isFinite || target <= 0) {
      throw ArgumentError('Choose a target greater than zero.');
    }
    if (reminder != null && !validPromiseTime(reminder)) {
      throw ArgumentError('Choose a valid reminder time.');
    }
    if (type == PromiseTrackingType.frequency && (weekly < 1 || weekly > 21)) {
      throw ArgumentError('Choose a weekly target from 1 to 21.');
    }
    schedule?.validate();
  }

  Future<PromiseModel?> getPromiseById(int id) async {
    await initialize();
    final thought = await _db.thoughtDao.getThoughtById(id);
    if (thought == null || thought.mood != 'promise' || thought.isArchived) {
      return null;
    }
    final rows = await _rows(
      'SELECT * FROM promise_metadata WHERE promise_id = ?',
      [id],
    );
    if (rows.isEmpty) {
      return PromiseModel(
        id: id,
        title: thought.content,
        intention: thought.promptQuestion ?? '',
        category: thought.category,
        trackingType: PromiseTrackingType.completion,
        status: thought.isCompleted
            ? PromiseStatus.completed
            : PromiseStatus.active,
        createdAt: thought.createdAt,
      );
    }
    final r = rows.first;
    final schedule = PromiseSchedule.decode(r['schedule_json'] as String?);
    final type = PromiseTrackingType.values.firstWhere(
      (e) => e.name == r['tracking_type'],
      orElse: () => PromiseTrackingType.completion,
    );
    var value = (r['current_value'] as num).toDouble();
    if (schedule != null &&
        schedule.repeats &&
        type != PromiseTrackingType.milestone) {
      final today = promiseDay(_clock());
      final since = type == PromiseTrackingType.frequency
          ? promiseWeek(today)
          : today;
      final until = type == PromiseTrackingType.frequency
          ? DateTime(since.year, since.month, since.day + 7)
          : DateTime(today.year, today.month, today.day + 1);
      final all = await getProgressEvents(id);
      value = all
          .where((event) {
            final date = event.dateKey == null
                ? promiseDay(event.occurredAt)
                : DateTime.parse(event.dateKey!);
            return !date.isBefore(since) && date.isBefore(until);
          })
          .fold(0.0, (sum, e) => sum + e.amount);
    }
    final dayRows = await _rows(
      'SELECT * FROM promise_occurrences WHERE promise_id = ? AND local_date = ?',
      [id, promiseDateKey(_clock())],
    );
    List<int> days = const [1, 2, 3, 4, 5, 6, 7];
    try {
      days = (jsonDecode(r['reminder_days'] as String? ?? '[]') as List)
          .cast<int>();
    } catch (_) {
      /* Invalid legacy preference uses safe defaults. */
    }
    return PromiseModel(
      id: id,
      title: thought.content,
      intention: thought.promptQuestion ?? '',
      category: thought.category,
      trackingType: type,
      targetValue: (r['target_value'] as num).toDouble(),
      unit: r['unit'] as String,
      frequencyPerWeek: r['frequency_per_week'] as int,
      targetDate: r['target_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r['target_date'] as int),
      schedule: schedule,
      isPrivate: r['is_private'] == 1,
      reminderTime: r['reminder_time'] as String?,
      reminderDays: days,
      reminderEnabled: r['reminder_enabled'] == 1,
      currentValue: value.clamp(0, double.infinity),
      status: thought.isCompleted
          ? PromiseStatus.completed
          : PromiseStatus.values.firstWhere(
              (e) => e.name == r['status'],
              orElse: () => PromiseStatus.active,
            ),
      createdAt: thought.createdAt,
      completedAt: r['completed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r['completed_at'] as int),
      nextActionPrompt: r['next_action_prompt'] as String?,
      isDoneToday: dayRows.isNotEmpty && dayRows.first['state'] == 'done',
      reminderIssue: r['reminder_error'] as String?,
    );
  }

  Future<void> updatePromise(PromiseModel edited) async {
    await initialize();
    _validate(
      edited.title,
      edited.targetValue,
      edited.reminderEnabled ? edited.reminderTime : null,
      edited.schedule,
      edited.frequencyPerWeek,
      edited.trackingType,
    );
    final thought = await _db.thoughtDao.getThoughtById(edited.id);
    if (thought == null) throw StateError('This promise no longer exists.');
    final original = await getPromiseById(edited.id);
    await _db.transaction(() async {
      final versions = await _rows(
        'SELECT id FROM promise_schedule_versions WHERE promise_id=?',
        [edited.id],
      );
      if (versions.isEmpty && original != null) {
        await _db.customStatement(
          'INSERT OR IGNORE INTO promise_schedule_versions(promise_id,effective_date,schedule_json,target) VALUES(?,?,?,?)',
          [
            edited.id,
            promiseDateKey(original.createdAt),
            original.schedule?.encode(),
            original.targetValue,
          ],
        );
      }
      await _db.customStatement(
        "INSERT OR IGNORE INTO promise_metadata(promise_id,tracking_type,target_value,unit) VALUES(?,?,?,?)",
        [edited.id, edited.trackingType.name, edited.targetValue, edited.unit],
      );
      await _db.thoughtDao.updateThought(
        thought
            .toCompanion(true)
            .copyWith(
              content: drift.Value(edited.title.trim()),
              promptQuestion: drift.Value(edited.intention),
              category: drift.Value(edited.category),
            ),
      );
      await _db.customStatement(
        '''UPDATE promise_metadata SET tracking_type=?,unit=?,target_value=?,frequency_per_week=?,target_date=?,is_private=?,reminder_time=?,reminder_enabled=?,reminder_days=?,schedule_json=? WHERE promise_id=?''',
        [
          edited.trackingType.name,
          edited.unit,
          edited.targetValue,
          edited.frequencyPerWeek,
          edited.targetDate?.millisecondsSinceEpoch,
          edited.isPrivate ? 1 : 0,
          edited.reminderEnabled ? edited.reminderTime : null,
          edited.reminderEnabled && edited.reminderTime != null ? 1 : 0,
          jsonEncode(edited.reminderDays),
          edited.schedule?.encode(),
          edited.id,
        ],
      );
      await _db.customStatement(
        'INSERT OR REPLACE INTO promise_schedule_versions(promise_id,effective_date,schedule_json,target) VALUES(?,?,?,?)',
        [
          edited.id,
          promiseDateKey(_clock()),
          edited.schedule?.encode(),
          edited.targetValue,
        ],
      );
    });
    _notify();
    await syncReminders((await getPromiseById(edited.id))!);
  }

  Future<void> recordProgress({
    required int promiseId,
    required PromiseEventType eventType,
    double amount = 1,
    String? note,
    DateTime? occurrenceDate,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Progress must be greater than zero.');
    }
    await initialize();
    await _db.transaction(() async {
      final p = await getPromiseById(promiseId);
      if (p == null || !p.isActive) {
        throw StateError('This promise is not active.');
      }
      final date = promiseDay(occurrenceDate ?? _clock());
      await _validateLogDate(p, date);
      await _record(p, date, eventType, amount, note);
    });
    _notify();
    final updated = await getPromiseById(promiseId);
    if (updated != null && updated.reminderEnabled) {
      await syncReminders(updated);
    }
  }

  Future<void> _validateLogDate(PromiseModel p, DateTime date) async {
    if (date.isAfter(promiseDay(_clock())) ||
        date.isBefore(promiseDay(p.createdAt))) {
      throw ArgumentError(
        'Choose a day since this promise began, up to today.',
      );
    }
    final versions = await _rows(
      'SELECT * FROM promise_schedule_versions WHERE promise_id=? AND effective_date<=? ORDER BY effective_date DESC,id DESC LIMIT 1',
      [p.id, promiseDateKey(date)],
    );
    final s = versions.isEmpty
        ? p.schedule
        : PromiseSchedule.decode(versions.first['schedule_json'] as String?);
    final pauses = await _rows(
      'SELECT * FROM promise_pause_periods WHERE promise_id=?',
      [p.id],
    );
    if (pauses.any(
      (r) =>
          !date.isBefore(
            promiseDay(
              DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
            ),
          ) &&
          (r['ended_at'] == null ||
              date.isBefore(
                promiseDay(
                  DateTime.fromMillisecondsSinceEpoch(r['ended_at'] as int),
                ),
              )),
    )) {
      throw ArgumentError('This promise was paused on that day.');
    }
    if (s != null &&
        !s.includes(date) &&
        !(s.repeat == PromiseRepeat.once &&
            !date.isBefore(promiseDay(s.startDate)) &&
            (s.endDate == null || !date.isAfter(promiseDay(s.endDate!))))) {
      throw ArgumentError('This day is not scheduled.');
    }
  }

  Future<double> _legacyDayAmount(int id, DateTime day) async {
    final key = promiseDateKey(day);
    final events = await getProgressEvents(id);
    return events
        .where((e) => (e.dateKey ?? promiseDateKey(e.occurredAt)) == key)
        .fold<double>(0, (sum, e) => sum + e.amount)
        .clamp(0, double.infinity);
  }

  Future<void> _record(
    PromiseModel p,
    DateTime date,
    PromiseEventType type,
    double amount,
    String? note,
  ) async {
    final key = promiseDateKey(date);
    final rows = await _rows(
      'SELECT * FROM promise_occurrences WHERE promise_id=? AND local_date=?',
      [p.id, key],
    );
    final previous = rows.isEmpty
        ? await _legacyDayAmount(p.id, date)
        : (rows.first['amount'] as num).toDouble();
    final versions = await _rows(
      'SELECT target FROM promise_schedule_versions WHERE promise_id=? AND effective_date<=? ORDER BY effective_date DESC,id DESC LIMIT 1',
      [p.id, key],
    );
    final historicalTarget =
        (p.trackingType == PromiseTrackingType.duration ||
                p.trackingType == PromiseTrackingType.milestone) &&
            versions.isNotEmpty
        ? (versions.first['target'] as num).toDouble()
        : _dailyTarget(p);
    final target = rows.isEmpty
        ? historicalTarget
        : (rows.first['target'] as num).toDouble();
    final total = (previous + amount).clamp(0.0, double.infinity);
    await _db.customStatement(
      'INSERT INTO promise_progress_events(promise_id,event_type,amount,occurred_at,note,occurrence_date) VALUES(?,?,?,?,?,?)',
      [p.id, type.name, amount, _clock().millisecondsSinceEpoch, note, key],
    );
    await _db.customStatement(
      'INSERT OR REPLACE INTO promise_occurrences(promise_id,local_date,amount,target,state,note) VALUES(?,?,?,?,?,?)',
      [p.id, key, total, target, total >= target ? 'done' : 'partial', note],
    );
    final complete =
        (p.trackingType == PromiseTrackingType.milestone &&
            p.currentValue + amount >= p.targetValue) ||
        ((p.schedule == null || !p.schedule!.repeats) &&
            p.trackingType == PromiseTrackingType.completion);
    await _db.customStatement(
      'UPDATE promise_metadata SET current_value=current_value+?,status=?,completed_at=? WHERE promise_id=?',
      [
        amount,
        complete ? 'completed' : p.status.name,
        complete
            ? _clock().millisecondsSinceEpoch
            : p.completedAt?.millisecondsSinceEpoch,
        p.id,
      ],
    );
    if (complete) await _db.thoughtDao.setCompleted(p.id, true);
  }

  double _dailyTarget(PromiseModel p) =>
      p.trackingType == PromiseTrackingType.duration ||
          p.trackingType == PromiseTrackingType.milestone
      ? p.targetValue
      : 1;

  /// Idempotent command used by Home, list and calendar. One tap logs one day.
  Future<void> markDayDone(int id, {DateTime? date, String? note}) async {
    await initialize();
    await _db.transaction(() async {
      final p = await getPromiseById(id);
      if (p == null) throw StateError('This promise no longer exists.');
      final day = promiseDay(date ?? _clock());
      await _validateLogDate(p, day);
      final rows = await _rows(
        'SELECT * FROM promise_occurrences WHERE promise_id=? AND local_date=?',
        [id, promiseDateKey(day)],
      );
      if (rows.isNotEmpty && rows.first['state'] == 'done') return;
      if (!p.isActive) {
        throw StateError('Resume this promise before logging progress.');
      }
      final previous = rows.isEmpty
          ? await _legacyDayAmount(id, day)
          : (rows.first['amount'] as num).toDouble();
      final oldTarget = rows.isNotEmpty
          ? (rows.first['target'] as num).toDouble()
          : (await _rows(
              'SELECT target FROM promise_schedule_versions WHERE promise_id=? AND effective_date<=? ORDER BY effective_date DESC,id DESC LIMIT 1',
              [id, promiseDateKey(day)],
            )).firstOrNull?['target'];
      final target =
          p.trackingType == PromiseTrackingType.duration ||
              p.trackingType == PromiseTrackingType.milestone
          ? (oldTarget as num?)?.toDouble() ?? _dailyTarget(p)
          : 1.0;
      await _record(
        p,
        day,
        switch (p.trackingType) {
          PromiseTrackingType.frequency => PromiseEventType.frequencyCheckIn,
          PromiseTrackingType.duration => PromiseEventType.durationSession,
          PromiseTrackingType.milestone => PromiseEventType.milestoneAdvance,
          _ => PromiseEventType.completion,
        },
        (target - previous).clamp(0.0, double.infinity),
        note ?? 'Marked done',
      );
    });
    _notify();
    final p = await getPromiseById(id);
    if (p != null) await syncReminders(p);
  }

  Future<void> undoDay(int id, DateTime date) async {
    await initialize();
    await _db.transaction(() async {
      final original = await getPromiseById(id);
      if (original == null) throw StateError('Promise not found.');
      if (promiseDay(date).isAfter(promiseDay(_clock()))) {
        throw ArgumentError('Choose today or an earlier day.');
      }
      final rows = await _rows(
        'SELECT * FROM promise_occurrences WHERE promise_id=? AND local_date=?',
        [id, promiseDateKey(date)],
      );
      if (rows.isEmpty) return;
      final amount = (rows.first['amount'] as num).toDouble();
      await _db.customStatement(
        'INSERT INTO promise_progress_events(promise_id,event_type,amount,occurred_at,note,occurrence_date) VALUES(?,?,?,?,?,?)',
        [
          id,
          'completion',
          -amount,
          _clock().millisecondsSinceEpoch,
          'Undid entry',
          promiseDateKey(date),
        ],
      );
      await _db.customStatement(
        'DELETE FROM promise_occurrences WHERE promise_id=? AND local_date=?',
        [id, promiseDateKey(date)],
      );
      await _db.customStatement(
        "UPDATE promise_metadata SET current_value=MAX(0,current_value-?),status=?,completed_at=? WHERE promise_id=?",
        [
          amount,
          original.isCompleted ? 'active' : original.status.name,
          original.isCompleted
              ? null
              : original.completedAt?.millisecondsSinceEpoch,
          id,
        ],
      );
      await _db.thoughtDao.setCompleted(id, false);
    });
    _notify();
    final p = await getPromiseById(id);
    if (p != null) await syncReminders(p);
  }

  Future<void> completePromise(int id) async {
    await initialize();
    await _db.transaction(() async {
      await _db.customStatement(
        "UPDATE promise_metadata SET status='completed',completed_at=? WHERE promise_id=?",
        [_clock().millisecondsSinceEpoch, id],
      );
      await _db.thoughtDao.setCompleted(id, true);
    });
    _notify();
    final updated = await getPromiseById(id);
    if (updated != null) await syncReminders(updated);
  }

  Future<void> setPromiseStatus(int id, PromiseStatus status) async {
    await initialize();
    await _db.transaction(() async {
      final p = await getPromiseById(id);
      if (p == null) throw StateError('Promise not found.');
      if (status == PromiseStatus.paused && !p.isPaused) {
        await _db.customStatement(
          'INSERT INTO promise_pause_periods(promise_id,started_at) VALUES(?,?)',
          [id, _clock().millisecondsSinceEpoch],
        );
      } else if (status == PromiseStatus.active) {
        await _db.customStatement(
          'UPDATE promise_pause_periods SET ended_at=? WHERE promise_id=? AND ended_at IS NULL',
          [_clock().millisecondsSinceEpoch, id],
        );
      }
      await _db.customStatement(
        'UPDATE promise_metadata SET status=?,completed_at=? WHERE promise_id=?',
        [
          status.name,
          status == PromiseStatus.completed
              ? _clock().millisecondsSinceEpoch
              : null,
          id,
        ],
      );
      await _db.thoughtDao.setCompleted(id, status == PromiseStatus.completed);
    });
    _notify();
    final p = await getPromiseById(id);
    if (p != null) await syncReminders(p);
  }

  Future<void> deletePromise(int id) async {
    await initialize();
    await _db.transaction(() async {
      for (final table in [
        'promise_occurrences',
        'promise_schedule_versions',
        'promise_pause_periods',
        'promise_progress_events',
        'promise_metadata',
      ]) {
        await _db.customStatement('DELETE FROM $table WHERE promise_id=?', [
          id,
        ]);
      }
      await _db.thoughtDao.deleteThought(id);
    });
    await (_reminderTails[id] ?? Future<void>.value());
    await _cancelReminders(id);
    _notify();
  }

  Future<List<PromiseProgressEvent>> getProgressEvents(int id) async {
    await initialize();
    return (await _rows(
          'SELECT * FROM promise_progress_events WHERE promise_id=? ORDER BY occurred_at DESC,id DESC',
          [id],
        ))
        .map(
          (r) => PromiseProgressEvent(
            id: r['id'] as int,
            promiseId: id,
            eventType: PromiseEventType.values.firstWhere(
              (e) => e.name == r['event_type'],
              orElse: () => PromiseEventType.completion,
            ),
            amount: (r['amount'] as num).toDouble(),
            occurredAt: DateTime.fromMillisecondsSinceEpoch(
              r['occurred_at'] as int,
            ),
            note: r['note'] as String?,
            dateKey: r['occurrence_date'] as String?,
          ),
        )
        .toList();
  }

  Future<List<PromiseDayRecord>> calendar(int id, DateTime month) async {
    final p = await getPromiseById(id);
    if (p == null) return [];
    final entries = {
      for (final row in await _rows(
        'SELECT * FROM promise_occurrences WHERE promise_id=?',
        [id],
      ))
        row['local_date'] as String: row,
    };
    final events = await getProgressEvents(id);
    final legacy = <String, double>{};
    for (final e in events) {
      final key = e.dateKey ?? promiseDateKey(e.occurredAt);
      legacy[key] = (legacy[key] ?? 0) + e.amount;
    }
    final versions = await _rows(
      'SELECT * FROM promise_schedule_versions WHERE promise_id=? ORDER BY effective_date,id',
      [id],
    );
    final pauses = await _rows(
      'SELECT * FROM promise_pause_periods WHERE promise_id=?',
      [id],
    );
    final today = promiseDay(_clock());
    return List.generate(DateTime(month.year, month.month + 1, 0).day, (index) {
      final day = DateTime(month.year, month.month, index + 1);
      final key = promiseDateKey(day);
      final applicable = versions
          .where((r) => (r['effective_date'] as String).compareTo(key) <= 0)
          .lastOrNull;
      final s = applicable == null
          ? p.schedule
          : PromiseSchedule.decode(applicable['schedule_json'] as String?);
      final row = entries[key];
      final amount = (row?['amount'] as num?)?.toDouble() ?? legacy[key] ?? 0;
      final target =
          (row?['target'] as num?)?.toDouble() ??
          (p.trackingType == PromiseTrackingType.duration ||
                  p.trackingType == PromiseTrackingType.milestone
              ? (applicable?['target'] as num?)?.toDouble() ?? p.targetValue
              : 1.0);
      if (amount > 0) {
        return PromiseDayRecord(
          date: day,
          state: amount >= target
              ? PromiseDayState.done
              : PromiseDayState.partial,
          amount: amount,
          target: target,
          note: row?['note'] as String?,
        );
      }
      if (day.isBefore(promiseDay(p.createdAt)) ||
          (p.completedAt != null && day.isAfter(promiseDay(p.completedAt!))) ||
          s == null ||
          !s.includes(day)) {
        return PromiseDayRecord(date: day, state: PromiseDayState.off);
      }
      final paused = pauses.any(
        (r) =>
            !day.isBefore(
              promiseDay(
                DateTime.fromMillisecondsSinceEpoch(r['started_at'] as int),
              ),
            ) &&
            (r['ended_at'] == null ||
                day.isBefore(
                  promiseDay(
                    DateTime.fromMillisecondsSinceEpoch(r['ended_at'] as int),
                  ),
                )),
      );
      if (paused || (p.isPaused && day == today)) {
        return PromiseDayRecord(date: day, state: PromiseDayState.paused);
      }
      return PromiseDayRecord(
        date: day,
        state: day.isAfter(today)
            ? PromiseDayState.upcoming
            : day == today
            ? PromiseDayState.pending
            : s.repeat == PromiseRepeat.weekly
            ? PromiseDayState.off
            : PromiseDayState.missed,
        target: target,
      );
    });
  }

  Future<List<PromiseModel>> _getAll() async {
    await initialize();
    final thoughts =
        await (_db.select(_db.thoughtTable)..where(
              (t) => t.mood.equals('promise') & t.isArchived.equals(false),
            ))
            .get();
    final result = <PromiseModel>[];
    for (final t in thoughts) {
      final p = await getPromiseById(t.id);
      if (p != null) result.add(p);
    }
    return result;
  }

  Future<List<PromiseModel>> getActivePromises() async =>
      (await _getAll()).where((p) => p.isActive).toList();
  Future<List<PromiseModel>> getCompletedPromises() async =>
      (await _getAll()).where((p) => p.isCompleted).toList();
  Future<List<PromiseModel>> getPausedPromises() async =>
      (await _getAll()).where((p) => p.isPaused).toList();
  Stream<List<PromiseModel>> watchAllPromises() =>
      (_db.select(_db.thoughtTable)..where(
            (t) => t.mood.equals('promise') & t.isArchived.equals(false),
          ))
          .watch()
          .asyncMap((_) => _getAll());
  Stream<List<PromiseModel>> watchActivePromises() =>
      watchAllPromises().map((all) => all.where((p) => p.isActive).toList());
  Stream<List<PromiseModel>> watchCompletedPromises() =>
      watchAllPromises().map((all) => all.where((p) => p.isCompleted).toList());
  Stream<List<PromiseModel>> watchPausedPromises() =>
      watchAllPromises().map((all) => all.where((p) => p.isPaused).toList());

  /// Keep a rolling fortnight of exact dates; refreshed on launch, resume and midnight.
  Future<void> syncAllReminders() async {
    _notify();
    for (final p in await _getAll()) {
      await syncReminders(p);
    }
  }

  /// Synchronize a committed chat operation, including a deleted Promise.
  Future<bool> syncChatEffects(int id) async {
    final promise = await getPromiseById(id);
    if (promise == null) {
      await _cancelReminders(id);
      return true;
    }
    await syncReminders(promise);
    return (await getPromiseById(id))?.reminderIssue == null;
  }

  int _notificationId(int id, int slot) => 1400000000 + id * 16 + slot;
  Future<void> _cancelReminders(int id) async {
    for (final notification in [
      1900000000 + id,
      for (var i = 0; i < 14; i++) _notificationId(id, i),
    ]) {
      await _cancel(notification);
    }
  }

  Future<void> syncReminders(PromiseModel p) {
    final result = (_reminderTails[p.id] ?? Future<void>.value()).then((
      _,
    ) async {
      final latest = await getPromiseById(p.id);
      if (latest != null) await _syncReminders(latest);
    });
    final tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _reminderTails[p.id] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_reminderTails[p.id], tail)) _reminderTails.remove(p.id);
      }),
    );
    return result;
  }

  Future<void> _syncReminders(PromiseModel p) async {
    var success = true;
    try {
      await _cancelReminders(p.id);
      if (p.isActive && p.reminderEnabled && p.reminderTime != null) {
        final now = _clock();
        final parts = p.reminderTime!.split(':').map(int.parse).toList();
        final schedule = p.schedule;
        var slot = 0;
        for (var offset = 0; offset < 366 && slot < 14; offset++) {
          final date = DateTime(now.year, now.month, now.day + offset);
          if (schedule != null
              ? !schedule.includes(date)
              : !p.reminderDays.contains(date.weekday)) {
            continue;
          }
          if (schedule?.endDate != null &&
              date.isAfter(promiseDay(schedule!.endDate!))) {
            break;
          }
          final at = DateTime(
            date.year,
            date.month,
            date.day,
            parts[0],
            parts[1],
          );
          if (!at.isAfter(now) || (offset == 0 && p.isDoneToday)) continue;
          success =
              await _schedule(
                _notificationId(p.id, slot++),
                p.isPrivate ? 'A personal commitment awaits' : p.title,
                p.isPrivate
                    ? 'A quiet reminder for your personal promise.'
                    : 'A small step for the promise you made to yourself.',
                at,
              ) &&
              success;
          if (schedule?.repeat == PromiseRepeat.once || schedule == null) break;
        }
      }
    } catch (_) {
      success = false;
    }
    final issue = success
        ? null
        : 'Your promise is saved. Reminders are unavailable; check notification permissions.';
    await _db.customStatement(
      'UPDATE promise_metadata SET reminder_error=? WHERE promise_id=?',
      [issue, p.id],
    );
    if (issue != p.reminderIssue) _notify();
  }
}
