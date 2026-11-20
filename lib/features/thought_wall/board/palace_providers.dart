import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/local_day_provider.dart';

/// Space filter and search text shared by every Mindspace tab.
@immutable
class PalaceFilter {
  const PalaceFilter({this.space, this.query = ''});

  /// Category key to show, or null for every space.
  final String? space;
  final String query;

  bool get isActive => space != null || query.trim().isNotEmpty;

  PalaceFilter copyWith({
    String? space,
    bool clearSpace = false,
    String? query,
  }) => PalaceFilter(
    space: clearSpace ? null : (space ?? this.space),
    query: query ?? this.query,
  );

  @override
  bool operator ==(Object other) =>
      other is PalaceFilter && other.space == space && other.query == query;

  @override
  int get hashCode => Object.hash(space, query);
}

class PalaceFilterNotifier extends Notifier<PalaceFilter> {
  @override
  PalaceFilter build() => const PalaceFilter();

  void setSpace(String? space) =>
      state = state.copyWith(space: space, clearSpace: space == null);
  void setQuery(String query) => state = state.copyWith(query: query);
  void clear() => state = const PalaceFilter();
}

final palaceFilterProvider =
    NotifierProvider<PalaceFilterNotifier, PalaceFilter>(
      PalaceFilterNotifier.new,
    );

/// Page size for Done and Archive. The list grows by one page at a time.
const palacePageSize = 50;

/// Today tab data: only today's rows come from the database.
final palaceTodayProvider = StreamProvider<List<Thought>>((ref) {
  ref.watch(localDayProvider); // new stream after midnight
  final filter = ref.watch(palaceFilterProvider);
  return ref
      .watch(thoughtDaoProvider)
      .watchToday(category: filter.space, query: filter.query);
});

/// The "Earlier" row: open thoughts from before today.
final palaceEarlierProvider = StreamProvider<List<Thought>>((ref) {
  ref.watch(localDayProvider);
  final filter = ref.watch(palaceFilterProvider);
  return ref
      .watch(thoughtDaoProvider)
      .watchEarlier(category: filter.space, query: filter.query);
});

/// Done tab, [limit] rows.
final palaceDoneProvider = StreamProvider.family<List<Thought>, int>((
  ref,
  limit,
) {
  final filter = ref.watch(palaceFilterProvider);
  return ref
      .watch(thoughtDaoProvider)
      .watchDone(limit: limit, category: filter.space, query: filter.query);
});

/// Archive tab, [limit] rows.
final palaceArchiveProvider = StreamProvider.family<List<Thought>, int>((
  ref,
  limit,
) {
  final filter = ref.watch(palaceFilterProvider);
  return ref
      .watch(thoughtDaoProvider)
      .watchArchive(limit: limit, category: filter.space, query: filter.query);
});

/// Search results across every tab, honouring the space filter.
final palaceSearchProvider = StreamProvider<List<Thought>>((ref) {
  final filter = ref.watch(palaceFilterProvider);
  return ref
      .watch(thoughtDaoProvider)
      .watchSearch(query: filter.query, category: filter.space);
});

/// History: the events of one day.
final palaceHistoryDayProvider = StreamProvider.family<List<Thought>, DateTime>(
  (ref, day) => ref.watch(thoughtDaoProvider).watchHistoryForDay(day),
);

/// History day strip: activity of the last 14 days.
final palaceActivityProvider = StreamProvider<List<Thought>>((ref) {
  final today = ref.watch(localDayProvider);
  return ref
      .watch(thoughtDaoProvider)
      .watchActivitySince(today.subtract(const Duration(days: 14)));
});
