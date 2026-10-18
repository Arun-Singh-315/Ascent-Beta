import 'dart:convert';
import 'dart:math';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'home_capture_service.dart';
import 'plan_recurrence_engine.dart';
import 'plan_service.dart';

String planningId() => List.generate(
  16,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();

class PlanItemDraft {
  const PlanItemDraft({
    required this.title,
    this.notes = '',
    this.at,
    this.alert = 'reminder',
    this.minutes,
    this.recurrence = 'once',
    this.endDate,
    this.checkIn = false,
    this.dateOnly = false,
  });
  final String title, notes, alert, recurrence;
  final DateTime? at, endDate;
  final int? minutes;
  final bool checkIn, dateOnly;

  factory PlanItemDraft.fromText(String text, DateTime now) {
    final proposal = HomeCaptureProposal.parse(text, now);
    var valid =
        !proposal.needsTimeClarification &&
        proposal.at != null &&
        proposal.at!.isAfter(now);
    final clocks = RegExp(
      r'\b\d{1,2}(?::\d{2})?\s*(?:am|pm)\b',
      caseSensitive: false,
    ).allMatches(text);
    if (clocks.length > 1) valid = false;
    for (final date in RegExp(r'\b\d{4}-\d{2}-\d{2}\b').allMatches(text)) {
      try {
        PlanRecurrenceEngine.parseDate(date.group(0)!);
      } catch (_) {
        valid = false;
      }
    }
    return PlanItemDraft(
      title: valid ? proposal.title : text,
      at: valid ? proposal.at : null,
      recurrence: proposal.isRecurring ? proposal.recurrenceRule : 'once',
      endDate: proposal.endDate == null
          ? null
          : DateTime.tryParse(proposal.endDate!),
      checkIn: valid && proposal.followUp,
    );
  }

  static List<String> parseList(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    return lines
        .where(
          (l) => !RegExp(
            r'^(list|todo|to-do|plan)\s*:$',
            caseSensitive: false,
          ).hasMatch(l),
        )
        .map(
          (l) => l
              .replaceFirst(
                RegExp(r'^(?:-->|→|--|[-•*]|\d+[.)]|\[[ xX]\])\s+'),
                '',
              )
              .trim(),
        )
        .where((l) => l.isNotEmpty)
        .toList();
  }
}

class PlanItemView {
  PlanItemView(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get collectionId => data['collection_id'] as String;
  String get title => (data['display_title'] ?? data['title']) as String;
  String get notes => data['notes'] as String;
  String? get definitionId => data['definition_id'] as String?;
  String? get occurrenceId => data['occurrence_id'] as String?;
  int? get taskId => data['resolved_task_id'] as int?;
  bool get dateOnly => data['date_only'] == 1;
  bool get done => data['completed_at'] != null || data['outcome'] == 'done';
  bool get skipped => data['outcome'] == 'skipped';
  bool get recurring => (data['recurrence_rule'] ?? 'once') != 'once';
  DateTime? get at => data['scheduled_start_time'] == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(
          (data['scheduled_start_time'] as int) * 1000,
        );
  DateTime? get endDate => data['end_date'] == null
      ? null
      : DateTime.tryParse(data['end_date'] as String);
  String get recurrence => data['recurrence_rule'] as String? ?? 'once';
  int? get minutes => data['target_minutes'] as int?;
  String get alert => data['alarm'] == 1
      ? 'alarm'
      : data['reminder_policy'] == 'at_start'
      ? 'reminder'
      : 'none';
  bool get checkIn => (data['check_in_policy'] ?? 'off') != 'off';
  bool get alertPending => data['alert_pending'] == 1;
}

class PlanCollectionView {
  PlanCollectionView(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  String get title => data['title'] as String;
  String get description => data['description'] as String;
  String get status => data['status'] as String;
  int get total => data['total'] as int;
  int get done => data['done'] as int;
  int get scheduled => data['scheduled'] as int;
  int get remaining => total - done - skipped;
  int get skipped => data['skipped'] as int;
  int get routines => data['routines'] as int;
  int get unscheduled => data['unscheduled'] as int;
  int get overdue => data['overdue'] as int;
  DateTime? get nextAt => data['next_at'] == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch((data['next_at'] as int) * 1000);
  int get pendingAlerts => data['pending_alerts'] as int;
}

/// Collections own items; the existing engine owns dated executions and alerts.
/// Inactive reminders are durable cancellation records and are never hard-deleted
/// while device reconciliation is pending.
class PlanCollectionService {
  PlanCollectionService(this.db, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final DateTime Function() clock;
  String? _resolvedZoneSignature;

  String get _itemsSql => '''
    SELECT i.*, coalesce(t.title, i.title) AS display_title,
      coalesce(o.linked_task_id, i.task_id) AS resolved_task_id,
      t.actual_completed_date AS completed_at, o.id AS occurrence_id,
      o.outcome, coalesce(o.scheduled_start_time,t.planned_date) AS scheduled_start_time, d.recurrence_rule, d.end_date,
      d.target_minutes, d.reminder_policy, d.check_in_policy,
      EXISTS(SELECT 1 FROM occurrence_alert_links l JOIN reminders r ON r.id=l.reminder_id
        WHERE l.occurrence_id=o.id AND l.role='start' AND r.is_active=1 AND r.alarm_enabled=1) AS alarm,
      EXISTS(SELECT 1 FROM occurrence_alert_links l JOIN reminders r ON r.id=l.reminder_id
        WHERE l.occurrence_id=o.id AND r.alert_sync_pending=1) AS alert_pending
    FROM plan_collection_items i
    LEFT JOIN plan_definitions d ON d.id=i.definition_id
    LEFT JOIN plan_occurrences o ON o.id=(SELECT x.id FROM plan_occurrences x
      WHERE x.plan_id=d.id ORDER BY
      CASE WHEN x.eligible_local_date=? THEN 0 WHEN x.scheduled_start_time>=? THEN 1 ELSE 2 END,
      CASE WHEN x.scheduled_start_time>=? THEN x.scheduled_start_time ELSE -x.scheduled_start_time END LIMIT 1)
    LEFT JOIN tasks t ON t.id=coalesce(o.linked_task_id,i.task_id)
  ''';
  List<Variable> get _timeVars => [
    Variable(PlanRecurrenceEngine.formatDate(clock())),
    Variable(clock().millisecondsSinceEpoch ~/ 1000),
    Variable(clock().millisecondsSinceEpoch ~/ 1000),
  ];
  Set<TableInfo> get _reads => {
    db.planCollectionTable,
    db.planCollectionItemTable,
    db.planDefinitionTable,
    db.planOccurrenceTable,
    db.taskTable,
    db.reminderTable,
    db.occurrenceAlertLinkTable,
  };

  Stream<List<PlanItemView>> watchItems(String collectionId) => db
      .customSelect(
        '$_itemsSql WHERE i.collection_id=? ORDER BY i.position,i.id',
        variables: [..._timeVars, Variable(collectionId)],
        readsFrom: _reads,
      )
      .watch()
      .map((rows) => rows.map((r) => PlanItemView(r.data)).toList());

  Stream<List<PlanCollectionView>> watchCollections() => db
      .customSelect(
        '''
    WITH items AS ($_itemsSql)
    SELECT c.*, count(i.id) AS total,
      coalesce(sum(CASE WHEN i.completed_at IS NOT NULL OR i.outcome='done' THEN 1 ELSE 0 END),0) AS done,
      coalesce(sum(CASE WHEN i.outcome='skipped' THEN 1 ELSE 0 END),0) AS skipped,
      coalesce(sum(CASE WHEN i.scheduled_start_time IS NOT NULL AND i.completed_at IS NULL AND (i.outcome='scheduled' OR i.outcome IS NULL) THEN 1 ELSE 0 END),0) AS scheduled,
      coalesce(sum(CASE WHEN i.recurrence_rule IS NOT NULL AND i.recurrence_rule!='once' THEN 1 ELSE 0 END),0) AS routines,
      coalesce(sum(i.alert_pending),0) AS pending_alerts,
      coalesce(sum(CASE WHEN i.id IS NOT NULL AND i.scheduled_start_time IS NULL AND i.completed_at IS NULL THEN 1 ELSE 0 END),0) AS unscheduled,
      coalesce(sum(CASE WHEN i.scheduled_start_time < ${DateTime(clock().year, clock().month, clock().day).millisecondsSinceEpoch ~/ 1000} AND i.completed_at IS NULL AND (i.outcome='scheduled' OR i.outcome IS NULL) THEN 1 ELSE 0 END),0) AS overdue,
      min(CASE WHEN i.scheduled_start_time >= ${clock().millisecondsSinceEpoch ~/ 1000} AND i.completed_at IS NULL THEN i.scheduled_start_time ELSE NULL END) AS next_at
    FROM plan_collections c LEFT JOIN items i ON i.collection_id=c.id
    GROUP BY c.id ORDER BY c.created_at DESC,c.id
    ''',
        variables: _timeVars,
        readsFrom: _reads,
      )
      .watch()
      .map((rows) => rows.map((r) => PlanCollectionView(r.data)).toList());

  void _validate(PlanItemDraft item) {
    if (item.title.trim().isEmpty ||
        item.title.trim().length > 300 ||
        item.notes.length > 20000) {
      throw ArgumentError(
        'Each item needs a title of 1–300 characters and notes under 20,000 characters.',
      );
    }
    if (!['none', 'reminder', 'alarm'].contains(item.alert) ||
        !['once', 'daily', 'weekdays'].contains(item.recurrence) ||
        (item.minutes != null && (item.minutes! < 1 || item.minutes! > 1440))) {
      throw ArgumentError('Choose valid alert, repeat and duration settings.');
    }
    if (item.at != null && !item.dateOnly && !item.at!.isAfter(clock())) {
      throw ArgumentError('Choose a future time or save without a schedule.');
    }
    if (item.dateOnly && item.recurrence != 'once') {
      throw ArgumentError(
        'Date-only items cannot repeat; choose a time for a routine.',
      );
    }
    if (item.recurrence != 'once' &&
        (item.at == null ||
            item.endDate == null ||
            item.endDate!.isBefore(
              DateTime(item.at!.year, item.at!.month, item.at!.day),
            ) ||
            item.endDate!.difference(item.at!).inDays > 90)) {
      throw ArgumentError(
        'Repeating items need a start time and an end date within 90 days.',
      );
    }
  }

  Future<String> save({
    required String title,
    required List<PlanItemDraft> items,
    required String requestId,
    int? sourceThoughtId,
    String description = '',
    String? collectionId,
  }) => db.transaction(() async {
    final receipt =
        await (db.select(db.aiCommandTable)
              ..where((r) => r.requestId.equals('planning:$requestId')))
            .getSingleOrNull();
    if (receipt != null) {
      final id =
          (jsonDecode(receipt.resultJson) as Map)['collectionId'] as String;
      if (await (db.select(
            db.planCollectionTable,
          )..where((c) => c.id.equals(id))).getSingleOrNull() ==
          null) {
        throw StateError('This saved plan was deleted. Start a new draft.');
      }
      return id;
    }
    final existing = await (db.select(
      db.planCollectionTable,
    )..where((c) => c.requestId.equals(requestId))).getSingleOrNull();
    if (existing != null && collectionId == null) return existing.id;
    if (title.trim().isEmpty ||
        title.trim().length > 300 ||
        description.length > 20000 ||
        items.isEmpty ||
        items.length > 200) {
      throw ArgumentError('Name your plan and add 1–200 items.');
    }
    for (final item in items) {
      _validate(item);
    }
    final id = collectionId ?? 'collection_${planningId()}';
    if (collectionId == null) {
      await db
          .into(db.planCollectionTable)
          .insert(
            PlanCollectionTableCompanion.insert(
              id: id,
              requestId: requestId,
              title: title.trim(),
              description: Value(description),
              sourceThoughtId: Value(
                sourceThoughtId != null &&
                        await db.thoughtDao.getThoughtById(sourceThoughtId) !=
                            null
                    ? sourceThoughtId
                    : null,
              ),
            ),
          );
    } else {
      final parent = await (db.select(
        db.planCollectionTable,
      )..where((c) => c.id.equals(id))).getSingleOrNull();
      if (parent == null || parent.status != 'active') {
        throw StateError('Open an active plan to add items.');
      }
    }
    final current = await (db.select(
      db.planCollectionItemTable,
    )..where((i) => i.collectionId.equals(id))).get();
    if (current.length + items.length > 200) {
      throw ArgumentError('A plan can hold up to 200 items.');
    }
    final offset = current.fold<int>(-1, (v, i) => max(v, i.position)) + 1;
    for (var n = 0; n < items.length; n++) {
      await _insert(id, items[n], offset + n);
    }
    await db
        .into(db.aiCommandTable)
        .insert(
          AiCommandTableCompanion.insert(
            requestId: 'planning:$requestId',
            capability: 'planning.collection',
            argumentsJson: '{}',
            resultJson: jsonEncode({'collectionId': id}),
          ),
        );
    return id;
  });

  Future<void> _insert(
    String collection,
    PlanItemDraft item,
    int position,
  ) async {
    int? taskId;
    String? definition;
    if (item.at == null || item.dateOnly) {
      taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: item.title.trim(),
          notes: Value(item.notes),
          plannedDate: Value(item.dateOnly ? item.at : null),
          estimatedMinutes: Value(item.minutes),
        ),
      );
    } else {
      final p = await PlanService(db, clock: clock).createPlan(
        title: item.title.trim(),
        startDate: PlanRecurrenceEngine.formatDate(item.at!),
        endDate: PlanRecurrenceEngine.formatDate(item.endDate ?? item.at!),
        localTime:
            '${item.at!.hour.toString().padLeft(2, '0')}:${item.at!.minute.toString().padLeft(2, '0')}',
        recurrenceRule: item.recurrence,
        activityType: item.minutes == null ? 'todo' : 'timer',
        targetMinutes: item.minutes,
        reminderPolicy: item.alert == 'none' ? 'none' : 'at_start',
        checkInPolicy: item.checkIn ? 'once' : 'off',
      );
      definition = p.id;
      final occurrences = await db.planDao.getOccurrencesForPlan(p.id);
      for (final o in occurrences) {
        if (o.linkedTaskId != null) {
          await (db.update(db.taskTable)
                ..where((t) => t.id.equals(o.linkedTaskId!)))
              .write(TaskTableCompanion(notes: Value(item.notes)));
        }
        if (item.alert == 'alarm') {
          for (final l in await db.planDao.getAlertLinksForOccurrence(o.id)) {
            if (l.role == 'start') {
              await (db.update(
                db.reminderTable,
              )..where((r) => r.id.equals(l.reminderId))).write(
                const ReminderTableCompanion(alarmEnabled: Value(true)),
              );
            }
          }
        }
      }
    }
    await db
        .into(db.planCollectionItemTable)
        .insert(
          PlanCollectionItemTableCompanion.insert(
            id: 'item_${planningId()}',
            collectionId: collection,
            position: position,
            title: item.title.trim(),
            notes: Value(item.notes),
            dateOnly: Value(item.dateOnly),
            taskId: Value(taskId),
            definitionId: Value(definition),
          ),
        );
  }

  Future<void> complete(
    PlanItemView item,
    bool completed,
  ) => db.transaction(() async {
    final current = (await watchItems(
      item.collectionId,
    ).first).where((v) => v.id == item.id).firstOrNull;
    if (current == null ||
        current.taskId == null ||
        !completed ||
        current.done) {
      return;
    }
    if (!await db.taskDao.markComplete(current.taskId!)) {
      throw StateError(
        'Finish the required focus session before completing this timed item.',
      );
    }
  });

  Future<void> rename(String id, String title, String description) async {
    if (title.trim().isEmpty ||
        title.trim().length > 300 ||
        description.length > 20000) {
      throw ArgumentError('Enter a valid plan name and description.');
    }
    await (db.update(
      db.planCollectionTable,
    )..where((c) => c.id.equals(id))).write(
      PlanCollectionTableCompanion(
        title: Value(title.trim()),
        description: Value(description),
      ),
    );
  }

  Future<void> setStatus(String id, String status) => db.transaction(() async {
    if (!['active', 'paused', 'archived'].contains(status)) {
      throw ArgumentError('Invalid status');
    }
    await (db.update(db.planCollectionTable)..where((c) => c.id.equals(id)))
        .write(PlanCollectionTableCompanion(status: Value(status)));
    for (final item in await (db.select(
      db.planCollectionItemTable,
    )..where((i) => i.collectionId.equals(id))).get()) {
      if (item.definitionId != null) {
        final service = PlanService(db, clock: clock);
        if (status == 'active') {
          await service.resumePlan(item.definitionId!);
        } else {
          await service.pausePlan(item.definitionId!);
        }
      }
    }
  });

  Future<void> deleteCollection(String id) => db.transaction(() async {
    for (final item in await watchItems(id).first) {
      await deleteItem(item);
    }
    await (db.delete(
      db.planCollectionTable,
    )..where((c) => c.id.equals(id))).go();
  });

  Future<void> _removeExecution(PlanOccurrence occurrence) async {
    final links = await db.planDao.getAlertLinksForOccurrence(occurrence.id);
    for (final link in links) {
      await (db.update(
        db.reminderTable,
      )..where((r) => r.id.equals(link.reminderId))).write(
        const ReminderTableCompanion(
          isActive: Value(false),
          alertSyncPending: Value(true),
          linkedTaskId: Value(null),
        ),
      );
    }
    await db.planDao.deleteAlertLinksForOccurrence(occurrence.id);
    await (db.delete(
      db.planOccurrenceTable,
    )..where((o) => o.id.equals(occurrence.id))).go();
    if (occurrence.linkedTaskId != null) {
      await _removeTask(occurrence.linkedTaskId!);
    }
  }

  Future<void> _removeTask(int id) async {
    final running =
        await (db.select(db.timeSessionTable)..where(
              (s) =>
                  s.linkedTaskId.equals(id) &
                  s.status.isIn(['running', 'paused']),
            ))
            .get();
    if (running.isNotEmpty) {
      throw StateError('Finish or cancel the active focus session first.');
    }
    final children = await (db.select(
      db.taskTable,
    )..where((t) => t.parentTaskId.equals(id))).get();
    if (children.isNotEmpty) {
      throw StateError(
        'Manage this activity’s subtasks before removing it from the plan.',
      );
    }
    // Historical focus sessions remain, without a dangling task reference.
    await (db.update(db.timeSessionTable)
          ..where((s) => s.linkedTaskId.equals(id)))
        .write(const TimeSessionTableCompanion(linkedTaskId: Value(null)));
    await (db.update(
      db.reminderTable,
    )..where((r) => r.linkedTaskId.equals(id))).write(
      const ReminderTableCompanion(
        linkedTaskId: Value(null),
        isActive: Value(false),
        alertSyncPending: Value(true),
      ),
    );
    await (db.delete(db.taskTable)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteItem(PlanItemView item) => db.transaction(() async {
    final current = await (db.select(
      db.planCollectionItemTable,
    )..where((i) => i.id.equals(item.id))).getSingleOrNull();
    if (current == null) return;
    final tasks = <int>{if (current.taskId != null) current.taskId!};
    if (current.definitionId != null) {
      for (final o in await db.planDao.getOccurrencesForPlan(
        current.definitionId!,
      )) {
        final running =
            await (db.select(db.timeSessionTable)..where(
                  (s) =>
                      s.linkedTaskId.equals(o.linkedTaskId ?? -1) &
                      s.status.isIn(['running', 'paused']),
                ))
                .get();
        if (running.isNotEmpty) {
          throw StateError(
            'Finish or cancel the active focus session before deleting this item.',
          );
        }
      }
      for (final o in await db.planDao.getOccurrencesForPlan(
        current.definitionId!,
      )) {
        await _removeExecution(o);
      }
    }
    await (db.delete(
      db.planCollectionItemTable,
    )..where((i) => i.id.equals(item.id))).go();
    if (current.definitionId != null) {
      await (db.delete(
        db.planDefinitionTable,
      )..where((p) => p.id.equals(current.definitionId!))).go();
    }
    for (final id in tasks) {
      await _removeTask(id);
    }
  });

  Future<void> updateItem(
    PlanItemView item,
    PlanItemDraft draft,
  ) => db.transaction(() async {
    final parent = await (db.select(
      db.planCollectionTable,
    )..where((c) => c.id.equals(item.collectionId))).getSingleOrNull();
    if (parent == null || parent.status != 'active') {
      throw StateError('Resume this plan before editing its items.');
    }
    _validate(draft);
    final current = (await watchItems(
      item.collectionId,
    ).first).where((i) => i.id == item.id).firstOrNull;
    if (current == null ||
        current.definitionId != item.definitionId ||
        current.at != item.at ||
        current.title != item.title ||
        current.notes != item.notes ||
        current.recurrence != item.recurrence ||
        current.minutes != item.minutes) {
      throw StateError(
        'This item changed. Close the editor and review it again.',
      );
    }
    if (current.done && !current.recurring) {
      throw StateError(
        'Completed items are kept as history. Add a new item instead.',
      );
    }
    final original = await (db.select(
      db.planCollectionItemTable,
    )..where((i) => i.id.equals(item.id))).getSingle();
    if (item.definitionId == null) {
      await deleteItem(item);
      await _insert(item.collectionId, draft, original.position);
      final fresh =
          await (db.select(db.planCollectionItemTable)..where(
                (i) =>
                    i.collectionId.equals(item.collectionId) &
                    i.position.equals(original.position),
              ))
              .getSingle();
      await (db.update(db.planCollectionItemTable)
            ..where((i) => i.id.equals(fresh.id)))
          .write(PlanCollectionItemTableCompanion(id: Value(original.id)));
      return;
    }
    final old = item.definitionId!;
    final executions = await db.planDao.getOccurrencesForPlan(old);
    final history = executions.where((o) => o.outcome != 'scheduled').toList();
    if (history.isNotEmpty && draft.at == null) {
      throw ArgumentError(
        'Keep a schedule for a routine with history, or add a separate unscheduled item.',
      );
    }
    for (final o in executions.where((o) => o.outcome == 'scheduled')) {
      await _removeExecution(o);
    }
    await (db.delete(
      db.planCollectionItemTable,
    )..where((i) => i.id.equals(item.id))).go();
    await _insert(item.collectionId, draft, original.position);
    final fresh =
        await (db.select(db.planCollectionItemTable)..where(
              (i) =>
                  i.collectionId.equals(item.collectionId) &
                  i.position.equals(original.position),
            ))
            .getSingle();
    if (fresh.definitionId != null) {
      final generated = await db.planDao.getOccurrencesForPlan(
        fresh.definitionId!,
      );
      for (final h in history) {
        for (final o in generated.where(
          (o) =>
              o.eligibleLocalDate == h.eligibleLocalDate &&
              o.slotIndex == h.slotIndex,
        )) {
          await _removeExecution(o);
        }
        await (db.update(
          db.planOccurrenceTable,
        )..where((o) => o.id.equals(h.id))).write(
          PlanOccurrenceTableCompanion(planId: Value(fresh.definitionId!)),
        );
      }
    }
    await (db.delete(
      db.planDefinitionTable,
    )..where((p) => p.id.equals(old))).go();
    await (db.update(db.planCollectionItemTable)
          ..where((i) => i.id.equals(fresh.id)))
        .write(PlanCollectionItemTableCompanion(id: Value(original.id)));
  });

  Future<void> updateItems(
    List<PlanItemView> items,
    List<PlanItemDraft> drafts,
  ) => db.transaction(() async {
    if (items.length != drafts.length || items.isEmpty) {
      throw ArgumentError('Review the remaining items again.');
    }
    for (var n = 0; n < items.length; n++) {
      await updateItem(items[n], drafts[n]);
    }
  });

  Future<void> move(String itemId, String destination) => db.transaction(
    () async {
      final parent = await (db.select(
        db.planCollectionTable,
      )..where((c) => c.id.equals(destination))).getSingleOrNull();
      if (parent == null || parent.status != 'active') {
        throw StateError('Choose an active destination plan.');
      }
      final rows = await (db.select(
        db.planCollectionItemTable,
      )..where((i) => i.collectionId.equals(destination))).get();
      if (rows.length >= 200) throw StateError('The destination plan is full.');
      await (db.update(
        db.planCollectionItemTable,
      )..where((i) => i.id.equals(itemId))).write(
        PlanCollectionItemTableCompanion(
          collectionId: Value(destination),
          position: Value(rows.length),
        ),
      );
    },
  );

  Future<void> reorder(String collectionId, List<String> ids) =>
      db.transaction(() async {
        final rows = await (db.select(
          db.planCollectionItemTable,
        )..where((i) => i.collectionId.equals(collectionId))).get();
        if (ids.toSet().length != rows.length ||
            !ids.toSet().containsAll(rows.map((r) => r.id))) {
          throw ArgumentError('The plan changed; reload before reordering.');
        }
        for (var n = 0; n < ids.length; n++) {
          await (db.update(db.planCollectionItemTable)
                ..where((i) => i.id.equals(ids[n])))
              .write(PlanCollectionItemTableCompanion(position: Value(n)));
        }
      });

  /// Re-resolve future wall-clock intent after a device timezone change.
  Future<void> reconcileLocalSchedules() async {
    final now = clock();
    final signature = '${now.timeZoneName}:${now.timeZoneOffset.inMinutes}';
    if (_resolvedZoneSignature == signature) {
      return;
    }
    await db.transaction(() async {
      final today = PlanRecurrenceEngine.formatDate(clock());
      for (final definition in await db.planDao.getAllPlans()) {
        if (definition.status != 'active' ||
            definition.timezonePolicy != 'device_local') {
          continue;
        }
        for (final occurrence in await db.planDao.getOccurrencesForPlan(
          definition.id,
        )) {
          if (occurrence.outcome != 'scheduled' ||
              occurrence.eligibleLocalDate.compareTo(today) < 0) {
            continue;
          }
          final resolved = PlanRecurrenceEngine.calculateStartTime(
            dateStr: occurrence.eligibleLocalDate,
            localTime: definition.localTime,
          );
          if (resolved == occurrence.scheduledStartTime ||
              !resolved.isAfter(clock())) {
            continue;
          }
          final delta = resolved.difference(occurrence.scheduledStartTime);
          await db.planDao.updateOccurrence(
            PlanOccurrenceTableCompanion(
              id: Value(occurrence.id),
              scheduledStartTime: Value(resolved),
              scheduledEndTime: Value(occurrence.scheduledEndTime?.add(delta)),
              closeTime: Value(occurrence.closeTime.add(delta)),
              updatedAt: Value(clock()),
            ),
          );
          if (occurrence.linkedTaskId != null) {
            await (db.update(db.taskTable)
                  ..where((t) => t.id.equals(occurrence.linkedTaskId!)))
                .write(TaskTableCompanion(plannedDate: Value(resolved)));
          }
          for (final link in await db.planDao.getAlertLinksForOccurrence(
            occurrence.id,
          )) {
            final reminder = await db.reminderDao.getReminderById(
              link.reminderId,
            );
            if (reminder != null && reminder.isActive) {
              await (db.update(
                db.reminderTable,
              )..where((r) => r.id.equals(reminder.id))).write(
                ReminderTableCompanion(
                  scheduledAt: Value(reminder.scheduledAt.add(delta)),
                  alertSyncPending: const Value(true),
                ),
              );
            }
          }
        }
      }
    });
    _resolvedZoneSignature = signature;
  }

  /// Stable import identities make startup/restore retries harmless.
  Future<void> importLegacy() => db.transaction(() async {
    for (final plan in await db.planDao.getAllPlans()) {
      final owned = await (db.select(
        db.planCollectionItemTable,
      )..where((i) => i.definitionId.equals(plan.id))).getSingleOrNull();
      if (owned != null) continue;
      final id = 'legacy_${plan.id}';
      await db
          .into(db.planCollectionTable)
          .insert(
            PlanCollectionTableCompanion.insert(
              id: id,
              requestId: id,
              title: plan.title,
              sourceThoughtId: Value(plan.sourceThoughtId),
              status: Value(plan.status == 'ended' ? 'archived' : plan.status),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await db
          .into(db.planCollectionItemTable)
          .insert(
            PlanCollectionItemTableCompanion.insert(
              id: 'legacy_item_${plan.id}',
              collectionId: id,
              position: 0,
              title: plan.title,
              definitionId: Value(plan.id),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
    final receipts = await (db.select(
      db.aiCommandTable,
    )..where((c) => c.capability.equals(HomeCaptureService.capability))).get();
    for (final receipt in receipts) {
      Map args;
      try {
        final raw = jsonDecode(receipt.argumentsJson);
        if (raw is! Map) continue;
        args = raw;
      } catch (_) {
        continue;
      }
      if (args['reminderId'] is! int ||
          (args['taskId'] != null && args['taskId'] is! int) ||
          (args['checkInId'] != null && args['checkInId'] is! int) ||
          (args['thoughtId'] != null && args['thoughtId'] is! int)) {
        continue;
      }
      if (args['planId'] != null) continue;
      final reminderId = args['reminderId'] as int?;
      final reminder = reminderId == null
          ? null
          : await db.reminderDao.getReminderById(reminderId);
      if (reminder == null) continue;
      final id = 'legacy_capture_${receipt.requestId}';
      if (await (db.select(
            db.planCollectionTable,
          )..where((c) => c.id.equals(id))).getSingleOrNull() !=
          null) {
        continue;
      }
      if (args['title'] != null && args['title'] is! String) {
        continue;
      }
      final title = (args['title'] as String? ?? reminder.title).trim();
      final at = reminder.scheduledAt;
      final definition = '${id}_definition';
      final date = PlanRecurrenceEngine.formatDate(at);
      final taskId = args['taskId'] as int?;
      final task = taskId == null ? null : await db.taskDao.getTaskById(taskId);
      await db.planDao.insertPlan(
        PlanDefinitionTableCompanion.insert(
          id: definition,
          title: title,
          startDate: date,
          endDate: date,
          localTime:
              '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}',
        ),
      );
      final occurrence = '${id}_occurrence';
      await db.planDao.insertOccurrence(
        PlanOccurrenceTableCompanion.insert(
          id: occurrence,
          planId: definition,
          eligibleLocalDate: date,
          scheduledStartTime: at,
          closeTime: at.add(const Duration(days: 1)),
          linkedTaskId: Value(task?.id),
          outcome: Value(
            task?.actualCompletedDate != null ? 'done' : 'scheduled',
          ),
          completedAt: Value(task?.actualCompletedDate),
        ),
      );
      for (final role in ['start', 'check_in']) {
        final rid = role == 'start' ? reminderId : args['checkInId'] as int?;
        if (rid != null && await db.reminderDao.getReminderById(rid) != null) {
          await db.planDao.insertAlertLink(
            OccurrenceAlertLinkTableCompanion.insert(
              occurrenceId: occurrence,
              reminderId: rid,
              role: role,
            ),
          );
        }
      }
      await db
          .into(db.planCollectionTable)
          .insert(
            PlanCollectionTableCompanion.insert(
              id: id,
              requestId: id,
              title: title,
              sourceThoughtId: Value(
                args['thoughtId'] is int &&
                        await db.thoughtDao.getThoughtById(
                              args['thoughtId'] as int,
                            ) !=
                            null
                    ? args['thoughtId'] as int
                    : null,
              ),
            ),
          );
      await db
          .into(db.planCollectionItemTable)
          .insert(
            PlanCollectionItemTableCompanion.insert(
              id: '${id}_item',
              collectionId: id,
              position: 0,
              title: title,
              definitionId: Value(definition),
            ),
          );
      await (db.update(
        db.aiCommandTable,
      )..where((r) => r.requestId.equals(receipt.requestId))).write(
        const AiCommandTableCompanion(
          capability: Value('home.schedule.imported'),
        ),
      );
    }
  });
}
