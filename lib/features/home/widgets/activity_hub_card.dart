import '../../../core/providers/time_tracking_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../app/theme/text_styles.dart';
import '../../plans/widgets/home_plans_preview.dart';
import 'activity_row_item.dart';
import 'activity_composer.dart';
import 'medicine_activity_group_card.dart';

sealed class _HubEntry {
  const _HubEntry();
}

class _ActivityRowEntry extends _HubEntry {
  final TodayActivityItem activity;
  const _ActivityRowEntry(this.activity);
}

class _MedicineGroupEntry extends _HubEntry {
  final String medicineName;
  final String dosage;
  final List<TodayActivityItem> activities;
  const _MedicineGroupEntry({
    required this.medicineName,
    required this.dosage,
    required this.activities,
  });
}

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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Things hub',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/today');
              },
              icon: Icon(Icons.dashboard_outlined, size: 16, color: g.clay),
              label: Text(
                'View board',
                style: TextStyle(
                  color: g.clay,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
                    final medicineItems = items
                        .where((a) => a.sourceType == 'medicine')
                        .toList();
                    final nonMedicineItems = items
                        .where(
                          (a) =>
                              a.sourceType != 'medicine' &&
                              (_showCompleted ||
                                  !widget.excludedTaskIds.contains(
                                    a.linkedTaskId,
                                  )),
                        )
                        .toList();

                    final standardRows = _prioritizeActivities(
                      nonMedicineItems.where(
                        (a) =>
                            (a.status == TodayActivityStatus.done) ==
                            _showCompleted,
                      ),
                    );

                    final medGroups = <String, List<TodayActivityItem>>{};
                    for (final med in medicineItems) {
                      final match = RegExp(
                        r'^(.*?)\s*\(medicine\)(?:\s*\((.*?)\))?',
                      ).firstMatch(med.title);
                      final name = match?.group(1)?.trim() ?? med.title;
                      medGroups.putIfAbsent(name, () => []).add(med);
                    }

                    final medGroupEntries = <_MedicineGroupEntry>[];
                    for (final entry in medGroups.entries) {
                      final doses = entry.value;
                      final isAllDone = doses.every(
                        (d) => d.status == TodayActivityStatus.done,
                      );
                      if (isAllDone == _showCompleted) {
                        final match = RegExp(
                          r'^(.*?)\s*\(medicine\)(?:\s*\((.*?)\))?',
                        ).firstMatch(doses.first.title);
                        final dosage = match?.group(2)?.trim() ?? '';
                        medGroupEntries.add(
                          _MedicineGroupEntry(
                            medicineName: entry.key,
                            dosage: dosage,
                            activities: doses,
                          ),
                        );
                      }
                    }

                    final allEntries = <_HubEntry>[
                      ...medGroupEntries,
                      ...standardRows.map((r) => _ActivityRowEntry(r)),
                    ];

                    final limit = _showAll
                        ? 20
                        : widget.previewLimit.clamp(1, 4);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (allEntries.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              _showCompleted
                                  ? 'No completed activities yet.'
                                  : (items.any(
                                          (a) =>
                                              a.status ==
                                              TodayActivityStatus.done,
                                        )
                                        ? 'All caught up! All ${items.where((a) => a.status == TodayActivityStatus.done).length} activities finished.'
                                        : 'Nothing pending. Add something below.'),
                              style: TextStyle(color: g.inkMuted, fontSize: 13),
                            ),
                          ),
                        for (final entry in allEntries.take(limit)) ...[
                          if (entry is _MedicineGroupEntry)
                            MedicineActivityGroupCard(
                              key: ValueKey('med_group_${entry.medicineName}'),
                              medicineName: entry.medicineName,
                              dosage: entry.dosage,
                              activities: entry.activities,
                              compact: true,
                            )
                          else if (entry is _ActivityRowEntry)
                            ActivityRowItem(
                              key: ValueKey(entry.activity.id),
                              activity: entry.activity,
                              compact: true,
                            ),
                        ],
                        if (allEntries.length > widget.previewLimit && !_showAll)
                          TextButton(
                            key: const ValueKey('hub_show_more'),
                            onPressed: () => setState(() => _showAll = true),
                            child: Text(
                              '+${allEntries.length - widget.previewLimit} more',
                              style: TextStyle(
                                color: g.clay,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (_showAll && allEntries.length > 20)
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
                            child: Text(
                              'Browse all ${allEntries.length} activities',
                            ),
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final (i, label) in labels.indexed)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onSelected(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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
