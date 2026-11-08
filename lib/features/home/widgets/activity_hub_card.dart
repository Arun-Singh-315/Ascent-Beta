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
import '../../../shared/widgets/glass_surface.dart';
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
  String? _starterTitle;

  @override
  void dispose() {
    _composerFocus.dispose();
    super.dispose();
  }

  void _tryStarter(String title) {
    setState(() => _starterTitle = title);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  Widget _starterCard(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SharedControlColors.actionBlue.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.wb_twilight_outlined,
                  size: 24,
                  color: SharedControlColors.actionBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start with something small.',
                      style: AscentTextStyles.cardTitle.copyWith(
                        color: g.ink,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Choose an idea to make your own, or write one below.',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: g.inkSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final idea in ['Read a few pages', 'Make time for a walk'])
                ActionChip(
                  label: Text(idea),
                  onPressed: () => _tryStarter(idea),
                  labelStyle: AscentTextStyles.labelSmall.copyWith(
                    color: SharedControlColors.actionBlue,
                  ),
                  backgroundColor: SharedControlColors.actionBlue.withValues(
                    alpha: .06,
                  ),
                  side: BorderSide.none,
                ),
            ],
          ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION HEADING ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Dayboard',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Open Dayboard',
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/things');
              },
              icon: Icon(Icons.arrow_forward_rounded, size: 22, color: g.ink),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GlassSurface(
          key: const ValueKey('home_activity_card'),
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          enableBlur: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              if (totalCount > 0 && doneCount > 0 && !_showPlans)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                  child: Row(
                    children: [
                      Text(
                        '$doneCount of $totalCount done',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: g.inkMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: (doneCount / totalCount).clamp(0.0, 1.0),
                            minHeight: 3,
                            backgroundColor: g.line,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              SharedControlColors.actionBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
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
                                  onPressed: () =>
                                      ref.invalidate(todayActivitiesProvider),
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
                              : widget.previewLimit.clamp(1, 4);
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
                              for (final entry in allEntries.take(limit)) ...[
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
                                        !knownIds.contains(entry.activity.id),
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
                                TextButton(
                                  key: const ValueKey('hub_show_more'),
                                  onPressed: () =>
                                      setState(() => _showAll = true),
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
                              if (_showCompleted)
                                TextButton.icon(
                                  onPressed: () => context.push('/history'),
                                  icon: const Icon(
                                    Icons.history_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Browse all history'),
                                ),
                              if (_showAll)
                                TextButton(
                                  onPressed: () =>
                                      setState(() => _showAll = false),
                                  child: const Text('Show less'),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              if (!_showPlans && !_showCompleted) ...[
                const SizedBox(height: 10),
                ActivityComposer(
                  key: ValueKey('home_composer_$_starterTitle'),
                  initialTitle: _starterTitle,
                  focusNode: _composerFocus,
                ),
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

  return [...inProgress, ...needsAttention, ...next];
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
