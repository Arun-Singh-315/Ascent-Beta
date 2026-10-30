import '../../../core/providers/time_tracking_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
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
  final Set<String> _seenActivityIds = <String>{};
  bool _listLoadedOnce = false;

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
            TextButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/today');
              },
              child: Text(
                'View ›',
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
                  skipLoadingOnReload: true,
                  skipError: true,
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

                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final rowIds = allEntries
                          .whereType<_ActivityRowEntry>()
                          .map((e) => e.activity.id);
                      if (!_listLoadedOnce) {
                        _listLoadedOnce = true;
                      }
                      _seenActivityIds.addAll(rowIds);
                    });

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
                            _ActivityEntrance(
                              key: ValueKey('entrance_${entry.activity.id}'),
                              animate:
                                  _listLoadedOnce &&
                                  !_seenActivityIds.contains(entry.activity.id),
                              child: ActivityRowItem(
                                key: ValueKey(entry.activity.id),
                                activity: entry.activity,
                                compact: true,
                                onViewCompleted: () {
                                  if (!mounted) return;
                                  setState(() {
                                    _showCompleted = true;
                                    _showPlans = false;
                                    _showAll = false;
                                  });
                                },
                              ),
                            ),
                        ],
                        if (allEntries.length > widget.previewLimit &&
                            !_showAll)
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
                const SizedBox(height: 10),
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
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: AscentSegmentedControl<int>(
        segments: [
          for (final (index, label) in labels.indexed)
            AscentSegment(value: index, label: label),
        ],
        selected: selected,
        onChanged: onSelected,
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

class _ActivityEntrance extends StatefulWidget {
  const _ActivityEntrance({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<_ActivityEntrance> createState() => _ActivityEntranceState();
}

class _ActivityEntranceState extends State<_ActivityEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    value: widget.animate ? 0 : 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final fade = Curves.easeOutCubic.transform(_controller.value);
          final slide = Curves.easeOutCubic.transform(_controller.value);
          final scale = Curves.easeOutBack.transform(_controller.value);
          return Opacity(
            opacity: fade.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -18 * (1 - slide)),
              child: Transform.scale(
                scale: 0.96 + 0.04 * scale,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
          );
        },
      );
}
