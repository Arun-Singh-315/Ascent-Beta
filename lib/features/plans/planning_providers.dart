import '../../core/notifications/notification_service.dart';
import 'package:drift/drift.dart' show Variable;
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

final planItemsProvider =
    StreamProvider.autoDispose.family<List<PlanItemView>, String>((ref, id) {
  return ref.watch(planCollectionServiceProvider).watchItems(id);
});

final planningAlertSyncProvider = Provider<ReminderAlertSync>(
  (ref) => ReminderAlertSync.device(ref.watch(databaseProvider)),
);

final taskPlanLabelProvider = StreamProvider.autoDispose.family<String?, int>((
  ref,
  taskId,
) {
  final db = ref.watch(databaseProvider);
  return db
      .customSelect(
        '''
    SELECT c.title FROM plan_collections c
    JOIN plan_collection_items i ON i.collection_id=c.id
    LEFT JOIN plan_occurrences o ON o.plan_id=i.definition_id
    WHERE i.task_id=? OR o.linked_task_id=? LIMIT 1
  ''',
        variables: [Variable(taskId), Variable(taskId)],
        readsFrom: {
          db.planCollectionTable,
          db.planCollectionItemTable,
          db.planOccurrenceTable,
        },
      )
      .watch()
      .map((rows) => rows.isEmpty ? null : rows.single.data['title'] as String);
});

final planningRequestPermissionsProvider = Provider<Future<bool> Function()>(
  (ref) => NotificationService.instance.requestPermissions,
);
