import '../../../app/theme/home_design.dart';
import '../../../shared/widgets/ascent_sheet.dart';
import 'activity_starter_actions.dart';
import 'home_section_heading.dart';
import 'home_content_transition.dart';
import 'home_outline_surface.dart';
import 'home_capture_entrance.dart';
import '../../../core/providers/time_tracking_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/skeleton_shimmer.dart';
import '../../plans/widgets/home_plans_preview.dart';
import '../../today/widgets/things_hero_card.dart';
import 'activity_composer.dart';
import 'activity_row_item.dart';
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
    this.showHero = false,
  });
  final int previewLimit;
  final Set<int> excludedTaskIds;
  final bool showHero;
  @override
  ConsumerState<ActivityHubCard> createState() => _ActivityHubCardState();
}

class _ActivityHubCardState extends ConsumerState<ActivityHubCard> {
  final _composerFocus = FocusNode();

  @override
  void dispose() {
    _composerFocus.dispose();
    super.dispose();
  }

  Widget _starterCard(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Start with something small.',
            style: AscentTextStyles.interfaceTitle.copyWith(
              color: g.ink,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const ActivityStarterActions(),
        ],
      ),
    );
  }

  bool _showAll = false;
  bool _showCompleted = false;
  bool _showPlans = false;
  final Set<String> _seenActivityIds = <String>{};
  bool _listLoadedOnce = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final activities = ref.watch(todayActivitiesProvider);

    final (totalCount, doneCount) = activities.maybeWhen(
      data: (items) => (
        items.length,
        items.where((a) => a.status == TodayActivityStatus.done).length,
      ),
      orElse: () => (0, 0),
    );

    return HomeBorderSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SECTION HEADING ──────────────────────────────────────────
          HomeSectionHeading(
            title: 'Things',
            cutout: false,
            dotColor: SharedControlColors.actionBlue,
          ),
          const SizedBox(height: 4),
          HomeContentTransition(
            child: Container(
              key: const ValueKey('home_activity_card'),
              decoration: null,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 340 ||
                          MediaQuery.textScalerOf(context).scale(14) > 20;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                key: const ValueKey('view_all_things_btn'),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  context.push('/things');
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(
                                  'View all ›',
                                  style: TextStyle(
                                    color: g.inkSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            _HubTabs(
                              key: const ValueKey('activity_hub_tabs'),
                              labels: const ['Today', 'Done', 'Plans'],
                              selected: _showPlans ? 2 : (_showCompleted ? 1 : 0),
                              onSelected: (i) => setState(() {
                                _showCompleted = i == 1;
                                _showPlans = i == 2;
                                _showAll = false;
                              }),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _HubTabs(
                              key: const ValueKey('activity_hub_tabs'),
                              labels: const ['Today', 'Done', 'Plans'],
                              selected: _showPlans ? 2 : (_showCompleted ? 1 : 0),
                              onSelected: (i) => setState(() {
                                _showCompleted = i == 1;
                                _showPlans = i == 2;
                                _showAll = false;
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            key: const ValueKey('view_all_things_btn'),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              context.push('/things');
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View all',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: g.inkSecondary,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 16,
                                  color: g.inkSecondary,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  if (!_showPlans && totalCount > 0 && doneCount > 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                      child: Text(
                        '$doneCount of $totalCount completed',
                        style: TextStyle(color: g.inkMuted, fontSize: 12),
                      ),
                    ),
                  AnimatedSwitcher(
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 220,
                    ),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _showPlans
                        ? const HomePlansPreview(key: ValueKey('tab_plans'))
                        : activities.when(
                            skipLoadingOnReload: true,
                            skipError: true,
                            loading: () => Padding(
                              key: const ValueKey('hub_loading'),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                children: [
                                  SkeletonShimmer(height: 48),
                                  const SizedBox(height: 8),
                                  SkeletonShimmer(height: 48),
                                ],
                              ),
                            ),
                            error: (_, _) => Padding(
                              key: const ValueKey('hub_error'),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Unable to refresh activities. Your tasks are safely preserved.',
                                      style: TextStyle(
                                        color: g.inkMuted,
                                        fontSize: 13,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    AscentButton.tonal(
                                      compact: true,
                                      label: 'Retry',
                                      icon: Icons.refresh_rounded,
                                      onPressed: () => ref.invalidate(
                                        todayActivitiesProvider,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            data: (items) {
                              final animateNew = _listLoadedOnce;
                              final knownIds = Set<String>.of(_seenActivityIds);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _listLoadedOnce = true;
                                _seenActivityIds.addAll(
                                  items.map((item) => item.id),
                                );
                              });
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

                              final medGroups =
                                  <String, List<TodayActivityItem>>{};
                              for (final med in medicineItems) {
                                final match = RegExp(
                                  r'^(.*?)\s*\(medicine\)(?:\s*\((.*?)\))?',
                                ).firstMatch(med.title);
                                final name =
                                    match?.group(1)?.trim() ?? med.title;
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

                              final hasHero =
                                  widget.showHero &&
                                  !_showCompleted &&
                                  standardRows.isNotEmpty;
                              final heroActivity = hasHero
                                  ? standardRows.first
                                  : null;
                              final displayStandardRows = hasHero
                                  ? standardRows.skip(1).toList()
                                  : standardRows;

                              final allEntries = <_HubEntry>[
                                ...displayStandardRows.map(
                                  (r) => _ActivityRowEntry(r),
                                ),
                                ...medGroupEntries,
                              ];

                              final limit = _showAll
                                  ? 20
                                  : widget.previewLimit.clamp(1, 6);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (allEntries.isEmpty &&
                                      !hasHero &&
                                      items.isEmpty &&
                                      !_showCompleted)
                                    _starterCard(context),
                                  if (allEntries.isEmpty &&
                                      !hasHero &&
                                      (items.isNotEmpty || _showCompleted))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 24,
                                        horizontal: 16,
                                      ),
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Icon(
                                              _showCompleted
                                                  ? Icons
                                                        .check_circle_outline_rounded
                                                  : Icons.spa_outlined,
                                              size: 32,
                                              color: g.inkSecondary,
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              _showCompleted
                                                  ? 'No completed activities yet.'
                                                  : (items.any(
                                                          (a) =>
                                                              a.status ==
                                                              TodayActivityStatus
                                                                  .done,
                                                        )
                                                        ? 'All caught up! All ${items.where((a) => a.status == TodayActivityStatus.done).length} activities finished.'
                                                        : 'A little space to begin.\nAdd one thing you want to do today.'),
                                              style: TextStyle(
                                                color: g.inkMuted,
                                                fontSize: 13,
                                                height: 1.4,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (hasHero && heroActivity != null)
                                    ThingsHeroCard(
                                      activity: heroActivity,
                                      onTap: () => context.push(
                                        '/things?focus=${heroActivity.id}',
                                      ),
                                    ),
                                  for (final (index, entry)
                                      in allEntries.take(limit).indexed) ...[
                                    if (index > 0 &&
                                        entry is _ActivityRowEntry &&
                                        entry.activity.kind ==
                                            ActivityKind.todo &&
                                        (entry.activity.targetMinutes ?? 0) <=
                                            0 &&
                                        allEntries[index - 1]
                                            is _ActivityRowEntry &&
                                        (allEntries[index - 1]
                                                    as _ActivityRowEntry)
                                                .activity
                                                .kind ==
                                            ActivityKind.todo)
                                      Divider(
                                        height: 1,
                                        thickness: .6,
                                        indent: 42,
                                        color: g.line.withValues(alpha: .65),
                                      ),
                                    if (entry is _MedicineGroupEntry)
                                      MedicineActivityGroupCard(
                                        key: ValueKey(
                                          'med_group_${entry.medicineName}',
                                        ),
                                        medicineName: entry.medicineName,
                                        dosage: entry.dosage,
                                        activities: entry.activities,
                                        compact: true,
                                      )
                                    else if (entry is _ActivityRowEntry)
                                      HomeCaptureEntrance(
                                        key: ValueKey(
                                          'entrance_${entry.activity.id}',
                                        ),
                                        animate:
                                            animateNew &&
                                            !knownIds.contains(
                                              entry.activity.id,
                                            ),
                                        child: ActivityRowItem(
                                          key: ValueKey(entry.activity.id),
                                          activity: entry.activity,
                                          compact: true,
                                          ground: true,
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
                                    AscentButton.outlined(
                                      key: const ValueKey('hub_show_more'),
                                      compact: true,
                                      strongOutline: true,
                                      label:
                                          '+${allEntries.length - widget.previewLimit} more',
                                      icon: Icons.expand_more_rounded,
                                      onPressed: () =>
                                          setState(() => _showAll = true),
                                    ),
                                  if (_showAll && allEntries.length > 20)
                                    AscentButton.outlined(
                                      key: const ValueKey('hub_full_list'),
                                      compact: true,
                                      strongOutline: true,
                                      label:
                                          'Browse all ${allEntries.length} activities',
                                      icon: Icons.arrow_forward_rounded,
                                      iconAtEnd: true,
                                      onPressed: () => showAscentSheet<void>(
                                        context: context,
                                        builder: (_) => _FullActivityList(
                                          completed: _showCompleted,
                                          filter: 'all',
                                          excludedTaskIds:
                                              widget.excludedTaskIds,
                                        ),
                                      ),
                                    ),
                                  if (_showCompleted)
                                    AscentButton.outlined(
                                      compact: true,
                                      strongOutline: true,
                                      label: 'Browse all history',
                                      icon: Icons.history_rounded,
                                      onPressed: () => context.push('/history'),
                                    ),
                                  if (_showAll)
                                    AscentButton.outlined(
                                      compact: true,
                                      strongOutline: true,
                                      label: 'Show less',
                                      icon: Icons.expand_less_rounded,
                                      onPressed: () =>
                                          setState(() => _showAll = false),
                                    ),
                                ],
                              );
                            },
                          ),
                  ),
                  if (!_showPlans && !_showCompleted) ...[
                    const SizedBox(height: 10),
                    ActivityComposer(
                      key: const ValueKey('home_composer'),
                      focusNode: _composerFocus,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
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
        accented: true,
        inline: true,
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
  final inProgress = <TodayActivityItem>[];
  final needsAttention = <TodayActivityItem>[];
  final next = <TodayActivityItem>[];
  final now = DateTime.now();

  for (final item in items) {
    if (item.status == TodayActivityStatus.inProgress ||
        item.status == TodayActivityStatus.paused) {
      inProgress.add(item);
    } else if (item.isOverdue ||
        item.priority == 'high' ||
        (item.scheduledTime != null &&
            item.scheduledTime!.difference(now) <= const Duration(hours: 1))) {
      needsAttention.add(item);
    } else {
      next.add(item);
    }
  }

  int rank(TodayActivityItem item) => switch (item.priority) {
    'high' => 0,
    'medium' => 1,
    _ => 2,
  };

  needsAttention.sort((a, b) {
    if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
    final priority = rank(a).compareTo(rank(b));
    if (priority != 0) return priority;
    if (a.scheduledTime != null && b.scheduledTime != null) {
      return a.scheduledTime!.compareTo(b.scheduledTime!);
    }
    return a.scheduledTime != null ? -1 : 1;
  });

  next.sort((a, b) {
    final priority = rank(a).compareTo(rank(b));
    if (priority != 0) return priority;
    if (a.scheduledTime != null && b.scheduledTime != null) {
      return a.scheduledTime!.compareTo(b.scheduledTime!);
    }
    return 0;
  });

  return [
    ...inProgress.where((a) => a.status == TodayActivityStatus.inProgress),
    ...inProgress.where((a) => a.status == TodayActivityStatus.paused),
    ...needsAttention,
    ...next,
  ];
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
                      style: AscentTextStyles.interfaceSection.copyWith(
                        color: g.ink,
                      ),
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
                          ground: true,
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
