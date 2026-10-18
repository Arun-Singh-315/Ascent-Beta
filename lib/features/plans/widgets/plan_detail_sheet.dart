import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../planning_providers.dart';
import 'plan_collection_detail.dart';

/// Resolve existing definition deep links to their collection owner.
Future<void> showPlanDetailSheet(
  BuildContext context, [
  Object? planOrId,
]) async {
  final definitionId = planOrId is PlanDefinition
      ? planOrId.id
      : planOrId is String
      ? planOrId
      : null;
  if (definitionId == null) return;
  final container = ProviderScope.containerOf(context, listen: false);
  final service = container.read(planCollectionServiceProvider);
  await service.importLegacy();
  final item = await (service.db.select(
    service.db.planCollectionItemTable,
  )..where((i) => i.definitionId.equals(definitionId))).getSingleOrNull();
  if (item != null && context.mounted) {
    await showPlanCollectionDetail(context, item.collectionId);
  }
}
