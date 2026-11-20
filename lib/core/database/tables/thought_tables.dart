import 'package:drift/drift.dart';

@DataClassName('Thought')
class ThoughtTable extends Table {
  @override
  String get tableName => 'thoughts';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  // 'thought', 'idea', 'me_to_me', 'win', 'future'
  TextColumn get mood => text().withDefault(const Constant('thought'))();
  TextColumn get category => text().withDefault(const Constant('general'))();
  TextColumn get colorHex => text().withDefault(const Constant('#2D2D3A'))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get promptQuestion => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  /// Set when [isCompleted] flips to true, cleared when it flips back.
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Set when [isArchived] flips to true, cleared when it flips back.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// Last day the thought was brought to Today. [createdAt] never changes, so
  /// the original date is always known and no duplicate record is needed.
  DateTimeColumn get carriedOn => dateTime().nullable()();

  /// 'todo' (circle before each bullet), 'bullet' (plain), or null (use the
  /// user's default). A view choice only: content is never rewritten.
  TextColumn get bulletStyle => text().nullable()();
}

@DataClassName('ThoughtCategory')
class ThoughtCategoryTable extends Table {
  @override
  String get tableName => 'thought_categories';
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get normalizedName => text().unique()();
}
