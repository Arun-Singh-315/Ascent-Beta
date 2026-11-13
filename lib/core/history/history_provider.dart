import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../../features/promises/providers/promise_providers.dart';

const historyModules = {
  'tasks': 'Tasks',
  'focus': 'Focus',
  'thoughts': 'Thoughts',
  'promises': 'Commitments',
  'medicines': 'Care & medicines',
  'hydration': 'Hydration',
  'walks': 'Walks',
  'routines': 'Plans & routines',
  'money': 'Money',
  'pipeline': 'Applications',
  'dsa': 'DSA',
  'learning': 'Growth',
  'challenges': 'Momentum',
  'consistency': 'Consistency',
  'breaks': 'Chai breaks',
};
String historyModule(String value) => switch (value) {
  'medicine_doses' || 'care_plans' || 'care_records' => 'medicines',
  'routine_sessions' => 'routines',
  'plans' => 'routines',
  _ => value,
};
String historyAction(String value) => switch (value) {
  'saved' => 'Saved snapshot',
  'created' => 'Added',
  'completed' => 'Completed',
  'removed' => 'Removed',
  'archived' => 'Archived',
  'restored' => 'Restored',
  'status_changed' => 'Status changed',
  'rescheduled' => 'Rescheduled',
  'taken' => 'Dose taken',
  'corrected' => 'Corrected',
  'edited' => 'Edited',
  'durationSession' => 'Focus recorded',
  'frequencyCheckIn' => 'Checked in',
  'milestoneAdvance' => 'Progress recorded',
  'reflectionNote' => 'Reflection saved',
  'completion' => 'Completed',
  'not_confirmed' => 'Not confirmed',
  _ => value.replaceAll('_', ' '),
};

/// Listen to the source tables too: SQLite triggers don't emit Drift invalidations.
/// Privacy filtering happens before callers can search or count the results.
final historyEventsProvider = StreamProvider.autoDispose<List<HistoryEvent>>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  final unlocked = ref.watch(unlockedPromiseIdsProvider);
  final privateIds = ref.watch(privatePromiseIdsProvider);
  final privacyReady = ref.watch(allPromisesStreamProvider).hasValue;
  return db
      .customSelect(
        "SELECT * FROM history_events e WHERE NOT (e.module='tasks' AND EXISTS (SELECT 1 FROM medicine_logs m WHERE CAST(m.linked_task_id AS TEXT)=e.entity_id)) ORDER BY occurred_at DESC, rowid DESC",
        readsFrom: db.allTables.toSet(),
      )
      .watch()
      .map(
        (rows) => rows.map((row) => db.historyEventTable.map(row.data)).where((
          event,
        ) {
          final private =
              event.isPrivate ||
              (event.privacyThoughtId != null &&
                  (!privacyReady ||
                      privateIds.contains(event.privacyThoughtId)));
          return !private || unlocked.contains(event.privacyThoughtId);
        }).toList(),
      );
});
