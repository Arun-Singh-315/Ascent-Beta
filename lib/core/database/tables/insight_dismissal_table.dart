import 'package:drift/drift.dart';

/// Stores user dismissals of Insight Engine nudges so the engine can
/// tune the frequency of future nudges of the same type.
@DataClassName('InsightDismissal')
class InsightDismissalTable extends Table {
  @override
  String get tableName => 'insight_dismissals';

  IntColumn get id => integer().autoIncrement()();

  /// Type of insight nudge that was dismissed.
  /// Known values: 'stale_note', 'pipeline_stale', 'skill_imbalance',
  /// 'consistency_dip', 'series_lagging', 'revisit_due'.
  TextColumn get insightType => text()();

  DateTimeColumn get dismissedAt =>
      dateTime().withDefault(currentDateAndTime)();

  /// When null = dismissed indefinitely for now.
  /// When set = temporarily snoozed until this timestamp.
  DateTimeColumn get snoozedUntil => dateTime().nullable()();

  /// Cumulative dismissal count for this type.
  /// The engine uses this to back off frequency exponentially.
  IntColumn get dismissalCount =>
      integer().withDefault(const Constant(1))();
}
