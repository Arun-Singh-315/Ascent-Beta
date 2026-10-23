import '../../../core/providers/time_tracking_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../app/theme/text_styles.dart';
import '../../plans/widgets/home_plans_preview.dart';
import 'activity_row_item.dart';
import 'activity_composer.dart';

class ActivityHubCard extends ConsumerStatefulWidget {
  const ActivityHubCard({
    super.key,
    this.previewLimit = 4,
    this.excludedTaskIds = const {},
  });
  final int previewLimit;
  final Set<int> excludedTaskIds;
  @override
  ConsumerState<ActivityHubCard> createState() => _ActivityHubCardState();
}

class _ActivityHubCardState extends ConsumerState<ActivityHubCard> {
  bool _showAll = false;
  bool _showCompleted = false;
  bool _showPlans = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final activities = ref.watch(todayActivitiesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Things hub',
                style: TextStyle(
                  color: g.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Things hub options',
              onSelected: (_) => context.push('/today'),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'board', child: Text('View board')),
              ],
              icon: Icon(Icons.more_horiz, color: g.inkMuted),
            ),
          ],
        ),
        GlassSurface(
          key: const ValueKey('home_activity_card'),
          borderRadius: BorderRadius.circular(18),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          enableBlur: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HubTabs(
                key: const ValueKey('activity_hub_tabs'),
                labels: const ['Active', 'Completed', 'Plans'],
                selected: _showPlans ? 2 : (_showCompleted ? 1 : 0),
                onSelected: (i) => setState(() {
                  _showCompleted = i == 1;
                  _showPlans = i == 2;
                  _showAll = false;
                }),
              ),
              if (_showPlans)
                const HomePlansPreview()
              else
                activities.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(todayActivitiesProvider),
                    child: const Text('Retry activities'),
                  ),
                  data: (items) {
                    final rows = _prioritizeActivities(
                      items.where(
                        (a) =>
                            (a.status == TodayActivityStatus.done) ==
                                _showCompleted &&
                            (_showCompleted ||
                                !widget.excludedTaskIds.contains(
                                  a.linkedTaskId,
                                )),
                      ),
                    );
                    final limit = _showAll
                        ? 20
                        : widget.previewLimit.clamp(1, 4);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rows.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              _showCompleted
                                  ? 'No completed activities yet.'
                                  : 'Nothing pending. Add something below.',
                              style: TextStyle(color: g.inkMuted, fontSize: 13),
                            ),
                          ),
                        for (final (i, row) in rows.take(limit).indexed) ...[
                          if (i > 0)
                            Divider(
                              key: ValueKey('activity_row_separator_$i'),
                              color: g.line.withValues(alpha: .45),
                              height: 1,
                              thickness: .5,
                              indent: 26,
                              endIndent: 4,
                            ),
                          ActivityRowItem(
                            key: ValueKey(row.id),
                            activity: row,
                            compact: true,
                          ),
                        ],
                        if (rows.length > widget.previewLimit && !_showAll)
                          TextButton(
                            onPressed: () => setState(() => _showAll = true),
                            child: const Text('Show more'),
                          ),
                        if (_showAll && rows.length > 20)
                          TextButton(
                            key: const ValueKey('hub_full_list'),
                            onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => _FullActivityList(
                                completed: _showCompleted,
                                filter: 'all',
                                excludedTaskIds: widget.excludedTaskIds,
                              ),
                            ),
                            child: Text('Browse all ${rows.length} activities'),
                          ),
                        if (_showAll)
                          TextButton(
                            onPressed: () => setState(() => _showAll = false),
                            child: const Text('Show less'),
                          ),
                      ],
                    );
                  },
                ),
              if (!_showPlans && !_showCompleted) ...[
                // Full-width, stronger rule: sets the composer apart from the
                // lighter, inset hairlines between activity rows.
                Divider(
                  key: const ValueKey('activity_hub_controls_separator'),
                  color: g.line,
                  height: 20,
                  thickness: 1,
                ),
                const ActivityComposer(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Slim text tabs (Active · Completed · Plans) shown at the top of the card.
class _HubTabs extends StatelessWidget {
  const _HubTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Row(
        children: [
          for (final (i, label) in labels.indexed)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onSelected(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: i == selected ? g.ink : g.inkMuted,
                        fontSize: 13,
                        fontWeight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      height: 2,
                      width: 16,
                      decoration: BoxDecoration(
                        color: i == selected ? g.clay : Colors.transparent,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<TodayActivityItem> _prioritizeActivities(
  Iterable<TodayActivityItem> items,
) {
  final running = <TodayActivityItem>[];
  final paused = <TodayActivityItem>[];
  final upcoming = <TodayActivityItem>[];
  for (final item in items) {
    switch (item.status) {
      case TodayActivityStatus.inProgress:
        running.add(item);
      case TodayActivityStatus.paused:
        paused.add(item);
      default:
        upcoming.add(item);
    }
  }
  int rank(TodayActivityItem item) => switch (item.priority) {
    'high' => 0,
    'medium' => 1,
    _ => 2,
  };
  final order = {for (var i = 0; i < upcoming.length; i++) upcoming[i].id: i};
  upcoming.sort((a, b) {
    final priority = rank(a).compareTo(rank(b));
    return priority != 0 ? priority : order[a.id]!.compareTo(order[b.id]!);
  });
  return [...running, ...paused, ...upcoming];
}

String _activityType(TodayActivityItem item) =>
    item.sourceType == 'medicine' || item.categoryTag == 'Medicine'
    ? 'medicine'
    : item.sourceType == 'lecture'
    ? 'lectures'
    : item.kind != ActivityKind.todo || (item.targetMinutes ?? 0) > 0
    ? 'timers'
    : 'todos';

bool _matchesActivityType(TodayActivityItem item, String filter) =>
    filter == 'all' || _activityType(item) == filter;

class _FullActivityList extends ConsumerStatefulWidget {
  const _FullActivityList({
    required this.completed,
    required this.filter,
    required this.excludedTaskIds,
  });
  final bool completed;
  final String filter;
  final Set<int> excludedTaskIds;

  @override
  ConsumerState<_FullActivityList> createState() => _FullActivityListState();
}

class _FullActivityListState extends ConsumerState<_FullActivityList> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return FractionallySizedBox(
      heightFactor: .9,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.completed
                          ? 'Completed activities'
                          : 'Today’s activities',
                      style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close activities',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                key: const ValueKey('hub_full_list_search'),
                decoration: const InputDecoration(
                  hintText: 'Search activities',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: ref
                  .watch(todayActivitiesProvider)
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Center(
                      child: TextButton(
                        onPressed: () =>
                            ref.invalidate(todayActivitiesProvider),
                        child: const Text('Retry activities'),
                      ),
                    ),
                    data: (items) {
                      final rows = _prioritizeActivities(
                        items.where(
                          (item) =>
                              (item.status == TodayActivityStatus.done) ==
                                  widget.completed &&
                              (widget.completed ||
                                  !widget.excludedTaskIds.contains(
                                    item.linkedTaskId,
                                  )) &&
                              _matchesActivityType(item, widget.filter) &&
                              (_query.isEmpty ||
                                  item.title.toLowerCase().contains(_query) ||
                                  (item.notes ?? '').toLowerCase().contains(
                                    _query,
                                  )),
                        ),
                      );
                      if (rows.isEmpty) {
                        return const Center(
                          child: Text('No activities in this view.'),
                        );
                      }
                      return ListView.builder(
                        key: const ValueKey('hub_full_activity_list'),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: rows.length,
                        itemBuilder: (context, index) => ActivityRowItem(
                          key: ValueKey(rows[index].id),
                          activity: rows[index],
                          compact: true,
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
