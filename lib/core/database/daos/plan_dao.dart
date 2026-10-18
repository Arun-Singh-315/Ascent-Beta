part of '../app_database.dart';

@DriftAccessor(tables: [
  PlanDefinitionTable,
  PlanOccurrenceTable,
  OccurrenceAlertLinkTable,
  TaskTable,
  ReminderTable,
])
class PlanDao extends DatabaseAccessor<AppDatabase> with _$PlanDaoMixin {
  PlanDao(super.db);

  // --- Plan Definitions ---

  Future<void> insertPlan(PlanDefinitionTableCompanion companion) {
    return into(planDefinitionTable).insert(companion);
  }

  Future<PlanDefinition?> getPlanById(String id) {
    return (select(planDefinitionTable)..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  Future<bool> updatePlan(PlanDefinitionTableCompanion companion) async {
    final rows = await (update(planDefinitionTable)
          ..where((p) => p.id.equals(companion.id.value)))
        .write(companion);
    return rows > 0;
  }

  Stream<List<PlanDefinition>> watchAllPlans() {
    return (select(planDefinitionTable)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Stream<List<PlanDefinition>> watchActivePlans() {
    return (select(planDefinitionTable)
          ..where((p) => p.status.equals('active'))
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .watch();
  }

  Future<List<PlanDefinition>> getAllPlans() {
    return (select(planDefinitionTable)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .get();
  }

  // --- Plan Occurrences ---

  Future<void> insertOccurrence(PlanOccurrenceTableCompanion companion) {
    return into(planOccurrenceTable).insert(companion);
  }

  Future<PlanOccurrence?> getOccurrenceById(String id) {
    return (select(planOccurrenceTable)..where((o) => o.id.equals(id)))
        .getSingleOrNull();
  }

  Future<PlanOccurrence?> getOccurrenceByTaskId(int taskId) {
    return (select(planOccurrenceTable)
          ..where((o) => o.linkedTaskId.equals(taskId)))
        .getSingleOrNull();
  }

  Future<List<PlanOccurrence>> getOccurrencesForPlan(String planId) {
    return (select(planOccurrenceTable)
          ..where((o) => o.planId.equals(planId))
          ..orderBy([(o) => OrderingTerm.asc(o.scheduledStartTime)]))
        .get();
  }

  Future<List<PlanOccurrence>> getOccurrencesForDate(String dateStr) {
    return (select(planOccurrenceTable)
          ..where((o) => o.eligibleLocalDate.equals(dateStr))
          ..orderBy([(o) => OrderingTerm.asc(o.scheduledStartTime)]))
        .get();
  }

  Stream<List<PlanOccurrence>> watchOccurrencesForDate(String dateStr) {
    return (select(planOccurrenceTable)
          ..where((o) => o.eligibleLocalDate.equals(dateStr))
          ..orderBy([(o) => OrderingTerm.asc(o.scheduledStartTime)]))
        .watch();
  }

  Future<List<PlanOccurrence>> getUpcomingOccurrences(
    DateTime now, {
    int limit = 10,
  }) {
    return (select(planOccurrenceTable)
          ..where(
            (o) =>
                o.outcome.equals('scheduled') &
                o.scheduledStartTime.isBiggerOrEqualValue(now),
          )
          ..orderBy([(o) => OrderingTerm.asc(o.scheduledStartTime)])
          ..limit(limit))
        .get();
  }

  Future<bool> updateOccurrence(PlanOccurrenceTableCompanion companion) async {
    final rows = await (update(planOccurrenceTable)
          ..where((o) => o.id.equals(companion.id.value)))
        .write(companion);
    return rows > 0;
  }

  Future<int> deleteOccurrencesAfterDate(String planId, String dateStr) {
    return (delete(planOccurrenceTable)
          ..where(
            (o) =>
                o.planId.equals(planId) &
                o.eligibleLocalDate.isBiggerThanValue(dateStr),
          ))
        .go();
  }

  // --- Occurrence Alert Links ---

  Future<int> insertAlertLink(OccurrenceAlertLinkTableCompanion companion) {
    return into(occurrenceAlertLinkTable).insert(companion);
  }

  Future<List<OccurrenceAlertLink>> getAlertLinksForOccurrence(
    String occurrenceId,
  ) {
    return (select(occurrenceAlertLinkTable)
          ..where((l) => l.occurrenceId.equals(occurrenceId))
          ..orderBy([(l) => OrderingTerm.asc(l.attemptIndex)]))
        .get();
  }

  Future<OccurrenceAlertLink?> getAlertLinkForReminder(int reminderId) {
    return (select(occurrenceAlertLinkTable)
          ..where((l) => l.reminderId.equals(reminderId)))
        .getSingleOrNull();
  }

  Future<PlanOccurrence?> getOccurrenceForReminder(int reminderId) async {
    final link = await getAlertLinkForReminder(reminderId);
    if (link == null) return null;
    return getOccurrenceById(link.occurrenceId);
  }

  Future<int> deleteAlertLinksForOccurrence(String occurrenceId) {
    return (delete(occurrenceAlertLinkTable)
          ..where((l) => l.occurrenceId.equals(occurrenceId)))
        .go();
  }
}
