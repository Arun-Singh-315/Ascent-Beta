import '../../core/notifications/notification_service.dart';
import '../../core/notifications/reminder_alert_sync.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/plan_collection_service.dart';

final planCollectionServiceProvider = Provider<PlanCollectionService>(
  (ref) => PlanCollectionService(ref.watch(databaseProvider)),
);

final planCollectionsProvider =
    StreamProvider.autoDispose<List<PlanCollectionView>>((ref) async* {
      final service = ref.watch(planCollectionServiceProvider);
      await service.importLegacy();
      yield* service.watchCollections();
    });

final planItemsProvider = StreamProvider.autoDispose
    .family<List<PlanItemView>, String>((ref, id) {
      return ref.watch(planCollectionServiceProvider).watchItems(id);
    });

final planningAlertSyncProvider = Provider<ReminderAlertSync>(
  (ref) => ReminderAlertSync.device(ref.watch(databaseProvider)),
);

/// Every task's plan name in one query (task id -> plan title). Rows read
/// from this instead of each opening its own query as it scrolls in.
final allTaskPlanLabelsProvider = StreamProvider<Map<int, String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        '''
    SELECT i.task_id AS task_id, c.title AS title FROM plan_collections c
    JOIN plan_collection_items i ON i.collection_id=c.id
    WHERE i.task_id IS NOT NULL
    UNION ALL
    SELECT o.linked_task_id AS task_id, c.title AS title FROM plan_collections c
    JOIN plan_collection_items i ON i.collection_id=c.id
    JOIN plan_occurrences o ON o.plan_id=i.definition_id
    WHERE o.linked_task_id IS NOT NULL
  ''',
        readsFrom: {
          db.planCollectionTable,
          db.planCollectionItemTable,
          db.planOccurrenceTable,
        },
      )
      .watch()
      .map((rows) {
        final out = <int, String>{};
        for (final r in rows) {
          final id = r.data['task_id'] as int?;
          final title = r.data['title'] as String?;
          if (id != null && title != null) out.putIfAbsent(id, () => title);
        }
        return out;
      });
});

/// The plan a task belongs to, if any (read from [allTaskPlanLabelsProvider]).
final taskPlanLabelProvider = StreamProvider.autoDispose.family<String?, int>((
  ref,
  taskId,
) {
  final all = ref.watch(allTaskPlanLabelsProvider);
  return Stream.value(all.value?[taskId]);
});

final planningRequestPermissionsProvider = Provider<Future<bool> Function()>(
  (ref) => NotificationService.instance.requestPermissions,
);
