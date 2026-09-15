part of '../app_database.dart';

@DriftAccessor(tables: [InsightDismissalTable])
class InsightDismissalDao extends DatabaseAccessor<AppDatabase>
    with _$InsightDismissalDaoMixin {
  InsightDismissalDao(super.db);

  /// Check if a specific insight is currently dismissed or snoozed.
  Future<bool> isDismissedOrSnoozed(String insightType) async {
    final now = DateTime.now();
    final row = await (select(insightDismissalTable)
          ..where((d) => d.insightType.equals(insightType)))
        .getSingleOrNull();

    if (row == null) return false;
    if (row.snoozedUntil == null) return true; // Dismissed indefinitely
    return row.snoozedUntil!.isAfter(now); // Still snoozed
  }

  /// Record or increment dismissal for an insight type.
  Future<void> recordDismissal(
    String insightType, {
    DateTime? snoozedUntil,
  }) async {
    final existing = await (select(insightDismissalTable)
          ..where((d) => d.insightType.equals(insightType)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(insightDismissalTable)
            ..where((d) => d.insightType.equals(insightType)))
          .write(
        InsightDismissalTableCompanion(
          dismissedAt: Value(DateTime.now()),
          snoozedUntil: Value(snoozedUntil),
          dismissalCount: Value(existing.dismissalCount + 1),
        ),
      );
    } else {
      await into(insightDismissalTable).insert(
        InsightDismissalTableCompanion.insert(
          insightType: insightType,
          snoozedUntil: Value(snoozedUntil),
        ),
      );
    }
  }

  /// Reset dismissal for testing or manual user reset.
  Future<int> clearDismissal(String insightType) => (delete(
        insightDismissalTable,
      )..where((d) => d.insightType.equals(insightType)))
          .go();
}
