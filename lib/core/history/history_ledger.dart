import '../database/app_database.dart';

/// SQLite triggers commit the snapshot with the source write, including writes
/// from AI, services and screens. Heartbeats never create history entries.
class HistoryLedger {
  static Future<void> capture(AppDatabase db, bool enabled) =>
      db.customStatement('UPDATE history_capture_control SET enabled = ?', [
        enabled ? 1 : 0,
      ]);

  static Future<void> install(AppDatabase db) async {
    await db.customStatement(
      'CREATE TABLE IF NOT EXISTS history_capture_control (enabled INTEGER NOT NULL)',
    );
    await db.customStatement(
      'INSERT INTO history_capture_control SELECT 1 WHERE NOT EXISTS (SELECT 1 FROM history_capture_control)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS history_chronology ON history_events(occurred_at DESC, id)',
    );
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS history_owner ON history_events(module, entity_id, occurred_at DESC)',
    );
    for (final spec in _specs) {
      await _installSpec(db, spec);
    }
  }

  static String _private(String ref) =>
      '''CASE WHEN $ref IS NULL THEN 0 ELSE
    COALESCE((SELECT MAX(is_private) FROM history_events WHERE privacy_thought_id=$ref),0)
    OR EXISTS(SELECT 1 FROM thoughts WHERE id=$ref AND category='private') END''';

  static Future<void> _installSpec(AppDatabase db, _Spec s) async {
    for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
      final r = operation == 'DELETE' ? 'OLD' : 'NEW';
      String sql(String value) => value.replaceAll('@', r);
      final changed = operation == 'UPDATE'
          ? ' AND (${s.fields.map((f) => 'OLD.$f IS NOT NEW.$f').join(' OR ')})'
          : '';
      final meaningful = s.table == 'medicine_logs' && operation != 'UPDATE'
          ? ' AND $r.is_taken=1'
          : '';
      final insertAction = s.table == 'time_sessions'
          ? "CASE WHEN NEW.status='completed' THEN 'completed' ELSE 'started' END"
          : s.table == 'medicine_logs'
          ? "'taken'"
          : "'created'";
      final action = operation == 'INSERT'
          ? insertAction
          : operation == 'DELETE'
          ? "'removed'"
          : s.action;
      final privacy = sql(s.privacy);
      await db.customStatement(
        '''CREATE TRIGGER IF NOT EXISTS history_${s.table}_${operation.toLowerCase()}
        AFTER $operation ON ${s.table}
        WHEN (SELECT enabled FROM history_capture_control)=1 $changed $meaningful
        BEGIN INSERT INTO history_events
        (id,module,entity_id,action,title,detail,occurred_at,privacy_thought_id,is_private,parent_entity_id,imported)
        VALUES(lower(hex(randomblob(16))), ${s.table == 'thoughts' ? "CASE WHEN $r.mood='promise' THEN 'promises' ELSE 'thoughts' END" : "'${s.module}'"},CAST($r.id AS TEXT), ${sql(action)},
        ${sql(s.title)}, ${sql(s.detail)}, CAST(strftime('%s','now') AS INTEGER),
        $privacy, ${_private(privacy)}, ${sql(s.parent)},0); END''',
      );
    }
    if (s.table == 'thoughts') {
      await db.customStatement(
        '''CREATE TRIGGER IF NOT EXISTS history_thought_privacy
        AFTER UPDATE OF category ON thoughts BEGIN
        UPDATE history_events SET is_private=(NEW.category='private') WHERE privacy_thought_id=NEW.id;
        END''',
      );
    }
  }

  /// Import only known facts. An imported snapshot is labelled explicitly;
  /// earlier edits and removed records cannot be reconstructed.
  static Future<void> backfill(AppDatabase db) async {
    for (final s in _specs) {
      String sql(String value) => value.replaceAll('@', 'source');
      final privacy = sql(s.privacy);
      await db.customStatement(
        '''INSERT OR IGNORE INTO history_events
        (id,module,entity_id,action,title,detail,occurred_at,privacy_thought_id,is_private,parent_entity_id,imported)
        SELECT 'import:${s.module}:'||source.id,${s.table == 'thoughts' ? "CASE WHEN source.mood='promise' THEN 'promises' ELSE 'thoughts' END" : "'${s.module}'"},CAST(source.id AS TEXT),'saved',
        ${sql(s.title)},${sql(s.detail)},${s.timestamp},$privacy,${_private(privacy)},${sql(s.parent)},1
        FROM ${s.table} source ${s.table == 'medicine_logs' ? 'WHERE source.is_taken=1' : ''}''',
      );
    }
    // We know when completed tasks finished, even when their planned day differs.
    await db.customStatement('''INSERT OR IGNORE INTO history_events
      (id,module,entity_id,action,title,detail,occurred_at,privacy_thought_id,is_private,imported)
      SELECT 'import:task-completion:'||id,'tasks',CAST(id AS TEXT),'completed',title,
      COALESCE(notes,''),actual_completed_date,linked_thought_id,${_private('linked_thought_id')},1
      FROM tasks WHERE actual_completed_date IS NOT NULL''');
    // Preserve the last known pre-upgrade goal; earlier goals remain unknown.
    await db.customStatement(
      "INSERT OR IGNORE INTO water_goal_versions SELECT date(updated_at,'unixepoch','localtime'),target_ml FROM water_goals",
    );
  }

  static Future<void> installPromises(AppDatabase db) async {
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS history_promise_progress
      AFTER INSERT ON promise_progress_events
      WHEN (SELECT enabled FROM history_capture_control)=1 BEGIN
      INSERT INTO history_events
      (id,module,entity_id,action,title,detail,occurred_at,privacy_thought_id,is_private,imported)
      SELECT 'promise-event:'||NEW.id,'promises',CAST(NEW.promise_id AS TEXT),NEW.event_type,t.content,
      CAST(NEW.amount AS TEXT)||' '||COALESCE(m.unit,'')||CASE WHEN NEW.note IS NULL THEN '' ELSE char(10)||NEW.note END,
      CAST(NEW.occurred_at/1000 AS INTEGER),NEW.promise_id,COALESCE(m.is_private,0),0
      FROM thoughts t LEFT JOIN promise_metadata m ON m.promise_id=t.id WHERE t.id=NEW.promise_id;
      END''',
    );
    await db.customStatement(
      '''CREATE TRIGGER IF NOT EXISTS history_promise_status
      AFTER UPDATE OF status ON promise_metadata
      WHEN OLD.status!=NEW.status AND (SELECT enabled FROM history_capture_control)=1 BEGIN
      INSERT INTO history_events(id,module,entity_id,action,title,detail,occurred_at,privacy_thought_id,is_private,imported)
      SELECT lower(hex(randomblob(16))),'promises',CAST(NEW.promise_id AS TEXT),NEW.status,content,'Promise '||NEW.status,
      CAST(strftime('%s','now') AS INTEGER),NEW.promise_id,NEW.is_private,0 FROM thoughts WHERE id=NEW.promise_id;
      END''',
    );
    for (final op in ['INSERT', 'UPDATE']) {
      await db.customStatement(
        '''CREATE TRIGGER IF NOT EXISTS history_promise_privacy_${op.toLowerCase()}
        AFTER $op ON promise_metadata BEGIN
        UPDATE history_events SET is_private=NEW.is_private WHERE privacy_thought_id=NEW.promise_id;
        END''',
      );
    }
    await db.customStatement(
      '''UPDATE history_events SET is_private=1
      WHERE privacy_thought_id IN (SELECT promise_id FROM promise_metadata WHERE is_private=1)''',
    );
    // Import real progress event timestamps, never inferred completion times.
    await db.customStatement('''INSERT OR IGNORE INTO history_events
      (id,module,entity_id,action,title,detail,occurred_at,privacy_thought_id,is_private,imported)
      SELECT 'promise-event:'||p.id,'promises',CAST(p.promise_id AS TEXT),p.event_type,t.content,
      CAST(p.amount AS TEXT)||' '||COALESCE(m.unit,'')||CASE WHEN p.note IS NULL THEN '' ELSE char(10)||p.note END,
      CAST(p.occurred_at/1000 AS INTEGER),p.promise_id,COALESCE(m.is_private,0),1
      FROM promise_progress_events p JOIN thoughts t ON t.id=p.promise_id
      LEFT JOIN promise_metadata m ON m.promise_id=p.promise_id''');
  }

  static final _specs = <_Spec>[
    _Spec(
      'plan_collections',
      'plans',
      '@.title',
      '@.description',
      ['title', 'description', 'status'],
      action:
          "CASE WHEN NEW.status!=OLD.status THEN NEW.status ELSE 'edited' END",
      privacy: '@.source_thought_id',
    ),

    _Spec(
      'consistency_logs',
      'consistency',
      "'Daily check-in'",
      "CASE WHEN @.present=1 THEN 'Showed up' ELSE 'Absent' END||char(10)||COALESCE(@.note,'')",
      ['present', 'hours_studied', 'note'],
      timestamp: 'source.date',
    ),

    _Spec(
      'tasks',
      'tasks',
      '@.title',
      "COALESCE(@.notes,'')||CASE WHEN @.estimated_minutes>0 THEN char(10)||'Focus target: '||@.estimated_minutes||' min' WHEN @.estimated_minutes=-1 THEN char(10)||'Flexible activity' ELSE '' END||CASE WHEN @.planned_date IS NOT NULL THEN char(10)||'Planned for '||date(@.planned_date,'unixepoch','localtime') ELSE '' END",
      [
        'title',
        'notes',
        'planned_date',
        'actual_completed_date',
        'is_archived',
        'priority',
        'estimated_minutes',
      ],
      action:
          "CASE WHEN NEW.is_archived!=OLD.is_archived THEN CASE WHEN NEW.is_archived=1 THEN 'archived' ELSE 'restored' END WHEN NEW.actual_completed_date IS NOT OLD.actual_completed_date THEN CASE WHEN NEW.actual_completed_date IS NULL THEN 'corrected' ELSE 'completed' END WHEN NEW.planned_date IS NOT OLD.planned_date THEN 'rescheduled' ELSE 'edited' END",
      privacy: '@.linked_thought_id',
      timestamp: 'COALESCE(source.updated_at,source.created_at)',
    ),
    _Spec(
      'time_sessions',
      'focus',
      '@.label',
      "CAST(@.duration_seconds AS TEXT)||' seconds · '||@.activity_type||' · '||@.status",
      ['status', 'label'],
      action:
          "CASE NEW.status WHEN 'completed' THEN 'completed' WHEN 'paused' THEN 'paused' WHEN 'running' THEN 'resumed' ELSE 'cancelled' END",
      privacy:
          '(SELECT linked_thought_id FROM tasks WHERE id=@.linked_task_id)',
      parent: 'CAST(@.linked_task_id AS TEXT)',
      timestamp: 'COALESCE(source.ended_at,source.started_at)',
    ),
    _Spec(
      'thoughts',
      'thoughts',
      '@.content',
      "'Space: '||@.category",
      ['content', 'category', 'is_archived', 'is_completed'],
      action:
          "CASE WHEN NEW.is_archived!=OLD.is_archived THEN CASE WHEN NEW.is_archived=1 THEN 'archived' ELSE 'restored' END WHEN NEW.is_completed!=OLD.is_completed THEN CASE WHEN NEW.is_completed=1 THEN 'completed' ELSE 'corrected' END ELSE 'edited' END",
      privacy: '@.id',
    ),
    _Spec(
      'medicine_logs',
      'medicine_doses',
      "COALESCE((SELECT name||' · '||dosage FROM medicines WHERE id=@.medicine_id),'Medicine dose')",
      "@.date_str||' · '||@.time_slot||CASE WHEN @.is_taken=1 THEN ' · Taken' ELSE ' · Scheduled' END",
      ['is_taken'],
      action: "CASE WHEN NEW.is_taken=1 THEN 'taken' ELSE 'corrected' END",
      timestamp: 'COALESCE(source.taken_at,source.created_at)',
    ),
    _Spec(
      'medicines',
      'medicines',
      '@.name',
      "@.dosage||' · '||@.instructions",
      ['name', 'dosage', 'scheduled_times', 'is_active'],
      action:
          "CASE WHEN NEW.is_active!=OLD.is_active THEN CASE WHEN NEW.is_active=0 THEN 'archived' ELSE 'restored' END ELSE 'edited' END",
    ),
    _Spec(
      'water_logs',
      'hydration',
      "CAST(@.amount_ml AS TEXT)||' ml water'",
      "'Recorded intake'",
      ['amount_ml', 'timestamp'],
      timestamp: 'source.timestamp',
    ),
    _Spec(
      'walk_sessions',
      'walks',
      "'Outdoor walk'",
      "CAST(@.distance_meters AS TEXT)||' m · '||CAST(@.duration_seconds AS TEXT)||' seconds'",
      ['is_completed'],
      action: "CASE WHEN NEW.is_completed=1 THEN 'completed' ELSE 'edited' END",
      timestamp: 'source.start_time',
    ),
    _Spec(
      'plan_definitions',
      'routines',
      '@.title',
      "@.recurrence_rule||' · '||@.local_time||' · '||@.start_date||' to '||@.end_date",
      ['title', 'status', 'local_time', 'recurrence_rule', 'end_date'],
      action:
          "CASE WHEN NEW.status!=OLD.status THEN NEW.status ELSE 'rescheduled' END",
      privacy: '@.source_thought_id',
    ),
    _Spec(
      'plan_occurrences',
      'routine_sessions',
      "COALESCE((SELECT title FROM plan_definitions WHERE id=@.plan_id),'Routine session')",
      "@.eligible_local_date||' · '||@.outcome",
      ['outcome'],
      action: 'NEW.outcome',
      timestamp:
          'COALESCE(source.completed_at,source.answered_at,source.scheduled_start_time)',
    ),
    _Spec(
      'finance_transactions',
      'money',
      '@.title',
      "@.type||' · '||CAST(@.amount AS TEXT)||' · '||@.category",
      ['title', 'amount', 'type', 'category'],
    ),
    _Spec(
      'applications',
      'pipeline',
      "@.company||' · '||@.role",
      "@.current_stage||char(10)||COALESCE(@.notes,'')",
      ['company', 'role', 'current_stage', 'notes'],
      action:
          "CASE WHEN NEW.current_stage!=OLD.current_stage THEN 'status_changed' ELSE 'edited' END",
    ),
    _Spec(
      'dsa_logs',
      'dsa',
      '@.problem_name',
      "@.topic||' · '||@.difficulty||char(10)||COALESCE(@.notes,'')",
      ['problem_name', 'notes', 'revisit_flag'],
      timestamp: 'source.date_solved',
    ),
    _Spec('courses', 'learning', '@.title', '@.description', [
      'title',
      'description',
    ]),
    _Spec(
      'challenge_challenges',
      'challenges',
      '@.title',
      "CAST(@.target_total AS TEXT)||' '||@.unit||' · '||@.start_day||' to '||@.end_day",
      ['title', 'status', 'target_total'],
      action:
          "CASE WHEN NEW.status!=OLD.status THEN NEW.status ELSE 'edited' END",
    ),
  ];
}

class _Spec {
  const _Spec(
    this.table,
    this.module,
    this.title,
    this.detail,
    this.fields, {
    this.action = "'edited'",
    this.privacy = 'NULL',
    this.parent = 'NULL',
    this.timestamp = 'source.created_at',
  });
  final String table, module, title, detail, action, privacy, parent, timestamp;
  final List<String> fields;
}
