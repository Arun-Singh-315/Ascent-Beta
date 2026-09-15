import 'package:drift/drift.dart';

/// Categories for time tracking (e.g. Study, Entertainment, or user-defined).
@DataClassName('SessionCategory')
class SessionCategoryTable extends Table {
  @override
  String get tableName => 'session_categories';

  IntColumn get id => integer().autoIncrement()();

  /// Display name of the category (e.g. "Study", "Entertainment", "Freelance").
  TextColumn get name => text()();

  /// Hex color string for badges and live-timer bar (e.g. "#5FA070").
  TextColumn get colorHex => text()();

  /// Built-in categories (Study, Entertainment) cannot be deleted.
  BoolColumn get isBuiltIn => boolean().withDefault(const Constant(false))();
}
