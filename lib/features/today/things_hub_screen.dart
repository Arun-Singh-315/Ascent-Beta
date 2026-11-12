import '../home/widgets/activity_starter_actions.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/glass_surface.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../home/widgets/activity_composer.dart';
import '../plans/widgets/home_plans_preview.dart';
import '../home/widgets/activity_row_item.dart';

class ThingsHubScreen extends ConsumerStatefulWidget {
  const ThingsHubScreen({
    super.key,
    this.initialTab,
    this.initialFocusId,
    this.initialMode,
  });

  final String? initialTab;
  final String? initialFocusId;
  final String? initialMode;

  @override
  ConsumerState<ThingsHubScreen> createState() => _ThingsHubScreenState();
}

class _ThingsHubScreenState extends ConsumerState<ThingsHubScreen>
    with SingleTickerProviderStateMixin {
  String _query = '';
  String _section = 'all';
  String _tab = 'now';
  bool _expanded = true;
  bool _wrapupMode = false;
  bool _showSearch = false;
  final FocusNode _composerFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _reveal;

  static const _sections = {
    'overdue': 'Overdue',
    'scheduled': 'Scheduled',
    'anytime': 'Anytime',
  };

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    if ({'now', 'done', 'plans'}.contains(widget.initialTab)) {
      _tab = widget.initialTab!;
    }
    _wrapupMode = widget.initialMode == 'wrapup';
    _checkInitialFocus();
  }

  @override
  void dispose() {
    _reveal.dispose();
    _searchController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _checkInitialFocus() {
    final focusId = widget.initialFocusId;
    if (focusId == null || focusId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final activities = await ref.read(todayActivitiesProvider.future);
      if (!mounted) return;
      if (!activities.any(
        (a) => a.id == focusId || a.linkedTaskId.toString() == focusId,
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This activity is no longer pending. Here are your Things.',
            ),
          ),
        );
      }
    });
  }

  String _sectionFor(TodayActivityItem item) => item.isOverdue
      ? 'overdue'
      : item.scheduledTime != null
      ? 'scheduled'
      : 'anytime';

  Color _sectionColor(BuildContext context, String section) =>
      switch (section) {
        'overdue' => SharedControlColors.dueRed,
        'scheduled' =>
          context.glass.isDark
              ? SharedControlColors.actionBlueDark
              : SharedControlColors.actionBlue,
        _ => context.glass.inkMuted,
      };

  void _selectSection(String section) {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = _section == section ? !_expanded : true;
      _section = section;
    });
    if (MediaQuery.disableAnimationsOf(context) || !_expanded) {
      _reveal.value = 1;
    } else {
      _reveal.forward(from: 0);
    }
  }

  Future<void> _showViews() async {
    final view = await showAscentActionMenu<String>(
      context: context,
      title: 'Your things',
      actions: const [
        AscentAction('now', 'Today', Icons.today_outlined),
        AscentAction('done', 'Completed', Icons.check_circle_outline_rounded),
        AscentAction('plans', 'Plans', Icons.event_note_outlined),
        AscentAction('history', 'All history', Icons.history_rounded),
      ],
    );
    if (!mounted || view == null) return;
    if (view == 'history') {
      context.push('/history');
      return;
    }
    setState(() {
      _tab = view;
      _section = 'all';
      _expanded = true;
    });
  }

  int _compareSchedule(TodayActivityItem a, TodayActivityItem b) {
    final first = a.scheduledTime ?? a.plannedDate;
    final second = b.scheduledTime ?? b.plannedDate;
    if (first == null) return second == null ? 0 : 1;
    return second == null ? -1 : first.compareTo(second);
  }

  Widget _buildBoardHeader(BuildContext context, List<TodayActivityItem> rows) {
    final g = context.glass;
    final disabledMotion = MediaQuery.disableAnimationsOf(context);
    final allOpen = _section == 'all' && _expanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const ValueKey('things_show_all'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectSection('all'),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: _section == 'all' && _expanded
                  ? g.line.withValues(alpha: g.isDark ? 0.12 : 0.06)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _section == 'all' && _expanded
                    ? g.line.withValues(alpha: g.isDark ? 0.30 : 0.18)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_tab == 'done' ? 'Completed today' : 'All things'} · ${rows.length.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: g.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: allOpen ? .5 : 0,
                  duration: disabledMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: g.inkMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_tab == 'now')
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final large = MediaQuery.textScalerOf(context).scale(1) >= 1.45;
                final headings = [
                  for (final entry in _sections.entries)
                    _buildSectionHeading(
                      context,
                      entry.key,
                      entry.value,
                      rows.where((a) => _sectionFor(a) == entry.key).length,
                      large,
                    ),
                ];
                // Keep the full labels readable at accessibility text sizes.
                return large
                    ? Column(children: headings)
                    : Row(
                        children: [
                          for (final heading in headings)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2.5,
                                ),
                                child: heading,
                              ),
                            ),
                        ],
                      );
              },
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Divider(
            height: 1,
            thickness: 0.6,
            color: g.line.withValues(alpha: g.isDark ? 0.35 : 0.20),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(
    BuildContext context,
    String section,
    String label,
    int count,
    bool large,
  ) {
    final g = context.glass;
    final color = _sectionColor(context, section);
    final active = _section == section && _expanded;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    return Semantics(
      button: true,
      excludeSemantics: true,
      expanded: _expanded && (_section == section || _section == 'all'),
      label: '$label, $count ${count == 1 ? 'thing' : 'things'}',
      child: InkWell(
        key: ValueKey('things_heading_$section'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectSection(section),
        child: AnimatedContainer(
          duration: duration,
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: g.isDark ? .14 : .08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? color.withValues(alpha: g.isDark ? 0.35 : 0.22)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: large ? 16 : 4,
            vertical: 8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$label - ${count.toString().padLeft(2, '0')}',
                textAlign: large ? TextAlign.start : TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: duration,
                child: Center(
                  child: Container(
                    width: 14,
                    height: 2,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivities(BuildContext context, List<TodayActivityItem> items) {
    final g = context.glass;
    final rows = items
        .where(
          (a) =>
              (a.status == TodayActivityStatus.done) == (_tab == 'done') &&
              (_query.isEmpty ||
                  '${a.title} ${a.notes ?? ''}'.toLowerCase().contains(_query)),
        )
        .toList();
    final groups = <String, List<TodayActivityItem>>{};
    for (final item in rows) {
      final section = _sectionFor(item);
      if (_section != 'all' && _section != section) continue;
      groups.putIfAbsent(section, () => []).add(item);
    }
    final originalOrder = {
      for (final (index, item) in rows.indexed) item.id: index,
    };
    for (final entry in groups.entries) {
      entry.value.sort((a, b) {
        final order = entry.key == 'anytime' ? 0 : _compareSchedule(a, b);
        return order != 0
            ? order
            : originalOrder[a.id]!.compareTo(originalOrder[b.id]!);
      });
    }
    final entries = <Widget Function()>[];
    if (_expanded) {
      if (groups.isEmpty) entries.add(() => _buildEmpty(context, items));
      for (final section in _sections.keys) {
        final group = groups[section];
        if (group == null) continue;
        if (_section == 'all' && _tab == 'now') {
          entries.add(
            () => Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _sectionColor(context, section),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      section == 'scheduled'
                          ? 'Scheduled today'
                          : _sections[section]!,
                      style: TextStyle(
                        color: _sectionColor(context, section),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        for (final (index, item) in group.indexed) {
          if (index > 0) {
            entries.add(
              () => Divider(
                height: 1,
                thickness: .5,
                indent: 46,
                color: g.line.withValues(alpha: .6),
              ),
            );
          }
          entries.add(
            () => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ActivityRowItem(
                key: ValueKey('things_row_${item.id}'),
                activity: item,
                compact: true,
                ground: true,
                hubStyle: true,
              ),
            ),
          );
        }
      }
      entries.add(() => const SizedBox(height: 14));
    }
    return CustomScrollView(
      key: ValueKey('things_list_$_tab'),
      slivers: [
        if (_showSearch)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _buildSearch(),
            ),
          ),
        SliverToBoxAdapter(child: _buildSummary(context, items)),
        if (_wrapupMode && _tab == 'now')
          SliverToBoxAdapter(child: _buildWrapup(context)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: DecoratedSliver(
            key: const ValueKey('things_connected_card'),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: g.line.withValues(alpha: g.isDark ? .30 : .20),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: g.shadow.withValues(alpha: g.isDark ? .14 : .05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            sliver: SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: Material(
                      type: MaterialType.transparency,
                      child: _buildBoardHeader(context, rows),
                    ),
                  ),
                  SliverFadeTransition(
                    opacity: _reveal.drive(
                      CurveTween(curve: Curves.easeOutCubic),
                    ),
                    sliver: SliverList.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) => entries[index](),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_tab == 'done')
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AscentButton.outlined(
                label: 'Browse all history',
                icon: Icons.history_rounded,
                onPressed: () => context.push('/history'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, List<TodayActivityItem> items) {
    final g = context.glass;
    final done = items
        .where((a) => a.status == TodayActivityStatus.done)
        .length;
    final total = items.length;
    final progress = total > 0 ? (done / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _tab == 'done' ? 'Completed' : 'Today',
            style: TextStyle(
              color: g.ink,
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '${items.length - done} remaining · $done completed',
            style: TextStyle(color: g.inkMuted, fontSize: 13, height: 1.4),
          ),
          if (total > 0 && _tab == 'now') ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Container(
                height: 3.5,
                decoration: BoxDecoration(
                  color: g.line.withValues(alpha: g.isDark ? 0.35 : 0.20),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: progress == 1.0
                          ? context.doneInk
                          : (g.isDark
                                ? SharedControlColors.actionBlueDark
                                : SharedControlColors.actionBlue),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearch() => TextField(
    controller: _searchController,
    autofocus: true,
    decoration: InputDecoration(
      hintText: 'Search your things',
      prefixIcon: const Icon(Icons.search_rounded, size: 20),
      suffixIcon: _query.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear_rounded, size: 18),
              tooltip: 'Clear search',
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.glass.line, width: 0.8),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: context.glass.line, width: 0.8),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: context.glass.isDark
              ? SharedControlColors.actionBlueDark
              : SharedControlColors.actionBlue,
          width: 1.4,
        ),
      ),
    ),
    onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
  );

  Widget _buildEmpty(BuildContext context, List<TodayActivityItem> items) {
    final g = context.glass;
    final filtered = _query.isNotEmpty || _section != 'all';
    final IconData emptyIcon = _query.isNotEmpty
        ? Icons.search_off_rounded
        : _tab == 'done'
        ? Icons.check_circle_outline_rounded
        : _section == 'overdue'
        ? Icons.alarm_off_rounded
        : _section == 'scheduled'
        ? Icons.schedule_rounded
        : _section == 'anytime'
        ? Icons.spa_outlined
        : items.isEmpty
        ? Icons.lightbulb_outline_rounded
        : Icons.done_all_rounded;

    final Color iconColor = _section == 'overdue' && _query.isEmpty
        ? SharedControlColors.dueRed
        : (_tab == 'done' || (!filtered && items.isNotEmpty)
              ? context.doneInk
              : g.inkMuted);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withValues(alpha: g.isDark ? 0.12 : 0.08),
              ),
              child: Icon(emptyIcon, size: 22, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              _query.isNotEmpty
                  ? 'No matching things'
                  : _tab == 'done'
                  ? 'Nothing completed yet'
                  : _section == 'overdue'
                  ? 'Nothing overdue'
                  : _section == 'scheduled'
                  ? 'Nothing scheduled'
                  : _section == 'anytime'
                  ? 'No anytime things'
                  : items.isEmpty
                  ? 'What’s one thing for today?'
                  : 'You’re all caught up',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: g.ink,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _query.isNotEmpty
                  ? 'Try another search.'
                  : _section == 'overdue'
                  ? 'Your deadlines are up to date.'
                  : _section == 'scheduled'
                  ? 'Things with a time will appear here.'
                  : _tab == 'done'
                  ? 'Things you finish today will appear here.'
                  : 'Add a thing whenever you’re ready.',
              textAlign: TextAlign.center,
              style: TextStyle(color: g.inkMuted, fontSize: 12.5, height: 1.4),
            ),
            if (filtered) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _query = '';
                    _section = 'all';
                    _expanded = true;
                  });
                },
                child: const Text('Show all things'),
              ),
            ] else if (_tab == 'now' && items.isEmpty) ...[
              const SizedBox(height: 16),
              const Center(child: ActivityStarterActions()),
            ],
          ],
        ),
      ),
    );
  }

  bool _usesScrollingControls(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) >= 1.45 ||
      MediaQuery.sizeOf(context).height < 600;

  Widget _buildWrapup(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(12),
        customBorder: Border.all(
          color: SharedControlColors.actionBlue.withValues(alpha: 0.35),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.nightlight_round,
                  size: 16,
                  color: SharedControlColors.actionBlue,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Evening Wrap-up',
                    style: TextStyle(
                      color: g.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  tooltip: 'Dismiss wrap-up',
                  onPressed: () => setState(() => _wrapupMode = false),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Ready to close out today? Carry unfinished items over to tomorrow with one tap.',
              style: TextStyle(color: g.inkMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            AscentButton.primary(
              compact: true,
              expanded: true,
              label: 'Carry over to tomorrow',
              icon: Icons.next_plan_outlined,
              onPressed: () async {
                HapticFeedback.lightImpact();
                final messenger = ScaffoldMessenger.of(context);
                final db = ref.read(databaseProvider);
                final tomorrow = DateTime.now().add(const Duration(days: 1));
                final items = await ref.read(todayActivitiesProvider.future);
                final pendingTasks = items.where(
                  (a) =>
                      a.status != TodayActivityStatus.done &&
                      a.linkedTaskId != null,
                );
                for (final a in pendingTasks) {
                  await db.taskDao.updateTask(
                    TaskTableCompanion(
                      id: Value(a.linkedTaskId!),
                      plannedDate: Value(tomorrow),
                    ),
                  );
                }
                if (mounted) {
                  setState(() => _wrapupMode = false);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Unfinished items moved to tomorrow.'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    if (!_usesScrollingControls(context)) {
      return ActivityComposer(focusNode: _composerFocusNode);
    }
    return AscentButton.primary(
      label: 'Add a thing',
      icon: Icons.add_rounded,
      onPressed: () => showAscentSheet<void>(
        context: context,
        builder: (context) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ActivityComposer(focusNode: _composerFocusNode),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AscentScaffold(
    title: 'Things',
    backgroundColor: Theme.of(context).colorScheme.surface,
    actions: [
      IconButton(
        tooltip: _showSearch ? 'Close search' : 'Search things',
        icon: Icon(
          _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
        ),
        onPressed: () => setState(() {
          _showSearch = !_showSearch;
          if (!_showSearch) {
            _query = '';
            _searchController.clear();
          }
        }),
      ),
      IconButton(
        key: const ValueKey('things_calendar_button'),
        tooltip: 'Things calendar',
        icon: const Icon(Icons.calendar_month_rounded),
        onPressed: () => context.push('/calendar?scope=things'),
      ),
      IconButton(
        tooltip: 'Things views',
        icon: const Icon(Icons.more_horiz_rounded),
        onPressed: _showViews,
      ),
    ],
    body: Column(
      children: [
        Expanded(
          child: _tab == 'plans'
              ? const SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: HomePlansPreview(),
                )
              : ref
                    .watch(todayActivitiesProvider)
                    .when(
                      skipLoadingOnReload: true,
                      skipError: true,
                      loading: () => ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          SkeletonShimmer(height: 160),
                          const SizedBox(height: 12),
                          SkeletonShimmer(height: 120),
                        ],
                      ),
                      error: (_, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Unable to load your things. Your tasks and history are preserved.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.glass.inkMuted),
                              ),
                              const SizedBox(height: 12),
                              AscentButton.tonal(
                                label: 'Retry',
                                icon: Icons.refresh_rounded,
                                onPressed: () =>
                                    ref.invalidate(todayActivitiesProvider),
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: (items) => _buildActivities(context, items),
                    ),
        ),
        if (_tab == 'now')
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: context.glass.line.withValues(
                      alpha: context.glass.isDark ? 0.25 : 0.15,
                    ),
                    width: 0.8,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.glass.shadow.withValues(
                      alpha: context.glass.isDark ? 0.12 : 0.04,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: _buildComposer(context),
            ),
          ),
      ],
    ),
  );
}
