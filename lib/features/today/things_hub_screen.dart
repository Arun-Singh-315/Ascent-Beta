import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import '../../shared/widgets/scroll_edge_fade.dart';
import '../../app/theme/home_design.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/brand_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_composer.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass_surface.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../../shared/widgets/undo_snackbar.dart';
import '../home/widgets/activity_composer.dart';
import '../home/widgets/activity_row_item.dart';
import '../plans/widgets/home_plans_preview.dart';
import 'add_activity_sheet.dart';
import 'models/things_sections.dart';
import 'screens/add_activity_screen.dart';
import 'things_providers.dart';
import '../../shared/widgets/group_header.dart';
import '../capture/capture_button.dart';

/// The planning hero (CLAUDE.md §5.2): Today · Upcoming · Anytime · Routines.
class ThingsHubScreen extends ConsumerStatefulWidget {
  const ThingsHubScreen({
    super.key,
    this.initialTab,
    this.initialFocusId,
    this.initialMode,
  });

  /// `today` (or legacy `now` / `done`), `upcoming`, `anytime`, `routines`
  /// (or legacy `plans`).
  final String? initialTab;
  final String? initialFocusId;
  final String? initialMode;

  @override
  ConsumerState<ThingsHubScreen> createState() => _ThingsHubScreenState();
}

class _ThingsHubScreenState extends ConsumerState<ThingsHubScreen> {
  late ThingsSegment _segment = thingsSegmentForTab(widget.initialTab);
  late bool _showCompleted = widget.initialTab == 'done';
  late bool _wrapupMode = widget.initialMode == 'wrapup';
  String _query = '';
  bool _showSearch = false;
  bool _moving = false;
  final FocusNode _composerFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _anytimeController = TextEditingController();
  bool _savingAnytime = false;

  static const _starters = [
    'Drink a glass of water',
    'Read for 20 minutes',
    'Plan tomorrow',
  ];

  @override
  void initState() {
    super.initState();
    _checkInitialFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _anytimeController.dispose();
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
        AscentSnackBar.show(
          context,
          message: 'This activity is no longer pending. Here are your Things.',
        );
      }
    });
  }

  Color get _dueColor => context.glass.isDark
      ? SharedControlColors.dueRedDark
      : SharedControlColors.dueRed;

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _selectSegment(ThingsSegment segment) {
    setState(() => _segment = segment);
  }

  void _toggleSearch() => setState(() {
    _showSearch = !_showSearch;
    if (!_showSearch) {
      _query = '';
      _searchController.clear();
    }
  });

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  /// Moves dated tasks to [day] and offers Undo. Reminders move with them.
  Future<void> _moveTasks(
    Iterable<int> taskIds,
    DateTime day, {
    required String Function(int count) message,
  }) async {
    if (_moving) return;
    setState(() => _moving = true);
    HapticFeedback.lightImpact();
    final dao = ref.read(taskDaoProvider);
    try {
      final moved = await dao.moveManyToDay(taskIds, day);
      if (!mounted) return;
      if (moved.isEmpty) {
        AscentSnackBar.show(context, message: 'Nothing could be moved.');
        return;
      }
      showUndoSnackbar(
        context,
        message: message(moved.length),
        onUndo: () => dao.restorePlannedDays(moved),
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not move your things. Nothing changed.',
        );
      }
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _moveOverdueToToday(ThingsTodayView view) => _moveTasks(
    view.movableOverdueTaskIds,
    _today,
    message: (n) => 'Moved $n ${n == 1 ? 'thing' : 'things'} to today',
  );

  Future<void> _carryOverToTomorrow(ThingsTodayView view) async {
    final ids = [
      for (final a in [...view.overdue, ...view.today])
        if (a.linkedTaskId != null && !a.isDailyStanding) a.linkedTaskId!,
    ];
    await _moveTasks(
      ids,
      _today.add(const Duration(days: 1)),
      message: (n) => 'Moved $n ${n == 1 ? 'thing' : 'things'} to tomorrow',
    );
    if (mounted) setState(() => _wrapupMode = false);
  }

  /// Empty-state starter: creates a real to-do for today, with Undo.
  Future<void> _addStarter(String title) async {
    final dao = ref.read(taskDaoProvider);
    final id = await dao.insertTask(
      TaskTableCompanion.insert(title: title, plannedDate: Value(_today)),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    showUndoSnackbar(
      context,
      message: 'Added “$title” to today',
      onUndo: () => dao.deleteTask(id),
    );
  }

  /// Saves an undated thing for the Anytime list, with Undo.
  Future<void> _addAnytime() async {
    final title = _anytimeController.text.trim();
    if (title.isEmpty || _savingAnytime) return;
    if (title.length > 300) {
      AscentSnackBar.error(context, message: 'Keep it under 300 characters.');
      return;
    }
    setState(() => _savingAnytime = true);
    final dao = ref.read(taskDaoProvider);
    try {
      final id = await dao.insertTask(TaskTableCompanion.insert(title: title));
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _anytimeController.clear();
      showUndoSnackbar(
        context,
        message: 'Added “$title” to Anytime',
        onUndo: () => dao.deleteTask(id),
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not save. Your text is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _savingAnytime = false);
    }
  }

  void _focusComposer() {
    if (_usesScrollingControls(context)) {
      _openAddScreen();
    } else {
      _composerFocusNode.requestFocus();
    }
  }

  void _openAddScreen() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const AddActivityScreen()));

  bool _usesScrollingControls(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1) >= 1.45 ||
      MediaQuery.sizeOf(context).height < 600;

  // ---------------------------------------------------------------------------
  // Building blocks
  // ---------------------------------------------------------------------------

  Widget _row(TodayActivityItem item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: ActivityRowItem(
      key: ValueKey('things_row_${item.id}'),
      activity: item,
      compact: true,
      ground: true,
      hubStyle: true,
    ),
  );

  Widget _sectionHeader(
    String title, {
    Color? color,
    int? count,
    Widget? trailing,
    Key? key,
  }) {
    final g = context.glass;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                count == null ? title : '$title · $count',
                style: AscentTextStyles.sectionHeading.copyWith(
                  color: color ?? g.ink,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  /// A grouped, rounded list of rows (CLAUDE.md §3.3).
  Widget _group(List<TodayActivityItem> items, {Key? key}) {
    final g = context.glass;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: DecoratedSliver(
        key: key,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          // Light cards: shadow, no outline; dark cards: a hairline (§3.3).
          border: g.isDark
              ? Border.all(color: g.line.withValues(alpha: .30))
              : null,
          boxShadow: [
            BoxShadow(
              color: g.shadow.withValues(alpha: g.isDark ? 0 : .08),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        sliver: SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          sliver: SliverList.separated(
            itemCount: items.length,
            itemBuilder: (_, i) => _row(items[i]),
            separatorBuilder: (_, _) => Divider(
              height: 1,
              thickness: .5,
              indent: 46,
              color: g.line.withValues(alpha: .6),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _section(
    String title,
    List<TodayActivityItem> items, {
    required String id,
    Color? color,
    Widget? trailing,
  }) {
    if (items.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: _sectionHeader(
          title,
          color: color,
          count: items.length,
          trailing: trailing,
          key: ValueKey('things_section_$id'),
        ),
      ),
      _group(items, key: ValueKey('things_group_$id')),
    ];
  }

  /// Today as one big card: sections by part of the day (and medicine
  /// together), each with a tinted icon header and hairlines between, so
  /// long lists stay readable and you can see at a glance what is where.
  Widget _dayBoard(List<TodayActivityItem> items) {
    final g = context.glass;
    final parts = groupByDayPart(items);
    Color tint(DayPart p) => switch (p) {
      DayPart.morning => g.amber,
      DayPart.afternoon => g.actionInk,
      DayPart.evening => BrandPalette.pillarTint('mind', dark: g.isDark),
      DayPart.anytime => g.inkMuted,
      DayPart.medicine => BrandPalette.pillarTint('medicine', dark: g.isDark),
    };
    IconData icon(DayPart p) => switch (p) {
      DayPart.morning => Icons.wb_twilight_rounded,
      DayPart.afternoon => Icons.wb_sunny_outlined,
      DayPart.evening => Icons.nightlight_outlined,
      DayPart.anytime => Icons.all_inclusive_rounded,
      DayPart.medicine => Icons.medication_outlined,
    };
    // Flattened so the list builds lazily (1000 things stay smooth): each
    // entry is a header, a row or a hairline, painted as one card.
    final entries = <Widget>[];
    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        entries.add(
          Divider(
            height: 16,
            indent: 16,
            endIndent: 16,
            color: g.line.withValues(alpha: .5),
          ),
        );
      }
      entries.add(
        Padding(
          key: ValueKey('things_part_${parts[i].$1.name}'),
          padding: const EdgeInsets.fromLTRB(20, 8, 16, 4),
          child: GroupHeader(
            icon: icon(parts[i].$1),
            tint: tint(parts[i].$1),
            title: parts[i].$1.label,
            count: parts[i].$2.length,
          ),
        ),
      );
      for (final item in parts[i].$2) {
        entries.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _row(item),
          ),
        );
      }
    }
    final surface = Theme.of(context).colorScheme.surface;
    const radius = Radius.circular(22);
    return SliverPadding(
      key: const ValueKey('things_day_board'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      sliver: SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final first = i == 0, last = i == entries.length - 1;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.vertical(
                top: first ? radius : Radius.zero,
                bottom: last ? radius : Radius.zero,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(
                top: first ? 8 : 0,
                bottom: last ? 8 : 0,
              ),
              child: entries[i],
            ),
          );
        },
      ),
    );
  }

  Widget _box(Widget child) => SliverToBoxAdapter(
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );

  Widget _fill(Widget child) =>
      SliverFillRemaining(hasScrollBody: false, child: child);

  Widget _noMatches() => _box(
    EmptyState.inline(
      icon: Icons.search_off_rounded,
      title: 'No things match “$_query”',
      actionLabel: 'Clear search',
      onAction: _clearSearch,
    ),
  );

  Widget _summary(List<TodayActivityItem> items) {
    final g = context.glass;
    final done = items.where((a) => a.status == TodayActivityStatus.done);
    final total = items.length;
    if (total == 0) return const SizedBox.shrink();
    final progress = (done.length / total).clamp(0.0, 1.0);
    final left = total - done.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            left == 0
                ? 'All done · ${done.length} completed'
                : '$left left · ${done.length} done',
            style: AscentTextStyles.supportingText.copyWith(color: g.inkMuted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: g.line.withValues(alpha: g.isDark ? .35 : .20),
              color: progress == 1 ? context.doneInk : g.actionInk,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Segments
  // ---------------------------------------------------------------------------

  List<Widget> _todaySlivers(List<TodayActivityItem> items) {
    final all = groupToday(items);
    final view = ThingsTodayView(
      overdue: all.overdue.where((a) => matchesThingsQuery(a, _query)).toList(),
      today: all.today.where((a) => matchesThingsQuery(a, _query)).toList(),
      completed: all.completed
          .where((a) => matchesThingsQuery(a, _query))
          .toList(),
    );
    final hasPending = all.overdue.isNotEmpty || all.today.isNotEmpty;

    if (all.isEmpty && !items.any(isAnytimeThing)) {
      return [
        _fill(
          EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Your day is wide open',
            subtitle:
                'Add one thing you want to get done today. You can add a time or reminder whenever you like.',
            actionLabel: 'Add your first thing',
            onAction: _focusComposer,
            starters: [
              for (final title in _starters)
                EmptyStarter(label: title, onTap: () => _addStarter(title)),
            ],
          ),
        ),
      ];
    }
    if (_query.isNotEmpty && view.isEmpty) return [_noMatches()];

    return [
      // Progress counts only what belongs to today, not Anytime things.
      if (_query.isEmpty)
        SliverToBoxAdapter(
          child: _summary([...all.overdue, ...all.today, ...all.completed]),
        ),
      if (_wrapupMode && hasPending)
        SliverToBoxAdapter(child: _buildWrapup(all)),
      ..._section(
        'Overdue',
        view.overdue,
        id: 'overdue',
        color: _dueColor,
        trailing: view.movableOverdueTaskIds.isEmpty
            ? null
            : AscentButton.ghost(
                key: const ValueKey('things_move_overdue'),
                label: 'Move all to today',
                compact: true,
                loading: _moving,
                onPressed: () => _moveOverdueToToday(view),
              ),
      ),
      if (view.today.isNotEmpty)
        _dayBoard(view.today)
      else if (_query.isEmpty && view.overdue.isEmpty)
        _box(
          EmptyState.inline(
            icon: Icons.done_all_rounded,
            title: all.completed.isEmpty
                ? 'Nothing planned for today yet'
                : 'All done for today',
            actionLabel: 'Add a thing',
            onAction: _focusComposer,
          ),
        ),
      if (view.completed.isNotEmpty) ...[
        SliverToBoxAdapter(child: _completedHeader(view.completed.length)),
        if (_showCompleted || _query.isNotEmpty) ...[
          _group(view.completed, key: const ValueKey('things_group_completed')),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AscentButton.ghost(
                label: 'Browse all history',
                icon: Icons.history_rounded,
                compact: true,
                onPressed: () => context.push('/history'),
              ),
            ),
          ),
        ],
      ],
    ];
  }

  Widget _completedHeader(int count) {
    final g = context.glass;
    final open = _showCompleted || _query.isNotEmpty;
    return Semantics(
      button: true,
      expanded: open,
      excludeSemantics: true,
      label: 'Completed, $count ${count == 1 ? 'thing' : 'things'}',
      child: InkWell(
        key: const ValueKey('things_completed_toggle'),
        onTap: _query.isNotEmpty
            ? null
            : () {
                HapticFeedback.selectionClick();
                setState(() => _showCompleted = !_showCompleted);
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Completed · $count',
                    style: AscentTextStyles.sectionHeading.copyWith(
                      color: g.inkMuted,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? .5 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: g.inkMuted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _upcomingSlivers() {
    final async = ref.watch(upcomingThingsProvider);
    final items = async.value;
    if (items == null) return [_loadingSliver()];
    final now = DateTime.now();
    final days = groupUpcoming(
      items.where((a) => matchesThingsQuery(a, _query)),
      now,
    );
    if (days.isEmpty) {
      if (_query.isNotEmpty) return [_noMatches()];
      return [
        _fill(
          EmptyState(
            icon: Icons.event_outlined,
            title: 'Nothing coming up',
            subtitle:
                'Things you plan for later days show up here, grouped by day.',
            actionLabel: 'Plan something',
            onAction: () => AddActivitySheet.show(
              context,
              initialDate: _today.add(const Duration(days: 1)),
            ),
          ),
        ),
      ];
    }
    return [
      for (final day in days)
        ..._section(
          upcomingDayLabel(day.day, now),
          day.items,
          id: 'day_${day.day.toIso8601String().substring(0, 10)}',
        ),
    ];
  }

  List<Widget> _anytimeSlivers(List<TodayActivityItem> items) {
    final anytime = anytimeThings(
      items,
    ).where((a) => matchesThingsQuery(a, _query)).toList();
    if (anytime.isEmpty) {
      if (_query.isNotEmpty) return [_noMatches()];
      return [
        _fill(
          EmptyState(
            icon: Icons.inbox_outlined,
            title: 'Nothing waiting for anytime',
            subtitle:
                'Keep things without a date here and pick them up when you have a moment.',
            actionLabel: 'Add an anytime thing',
            onAction: _composerFocusNode.requestFocus,
          ),
        ),
      ];
    }
    return _section('No date', anytime, id: 'anytime');
  }

  List<Widget> _routineSlivers(List<TodayActivityItem> items) {
    final daily = dailyRoutines(
      items,
    ).where((a) => matchesThingsQuery(a, _query)).toList();
    return [
      ..._section('Every day', daily, id: 'daily'),
      SliverToBoxAdapter(child: _sectionHeader('Plans and routines')),
      const SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(child: HomePlansPreview()),
      ),
    ];
  }

  Widget _loadingSliver() => SliverPadding(
    padding: const EdgeInsets.all(16),
    sliver: SliverList.list(
      children: [
        SkeletonShimmer(height: 160),
        const SizedBox(height: 12),
        SkeletonShimmer(height: 120),
      ],
    ),
  );

  Widget _errorSliver() => _fill(
    Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Unable to load your things. Your tasks and history are preserved.',
              textAlign: TextAlign.center,
              style: AscentTextStyles.supportingText.copyWith(
                color: context.glass.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
            AscentButton.tonal(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(todayActivitiesProvider),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildWrapup(ThingsTodayView view) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(16),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.nightlight_round, size: 16, color: g.actionInk),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Evening wrap-up',
                    style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
                  ),
                ),
                AscentButton.icon(
                  icon: Icons.close_rounded,
                  tooltip: 'Dismiss wrap-up',
                  semanticLabel: 'Dismiss wrap-up',
                  onPressed: () => setState(() => _wrapupMode = false),
                ),
              ],
            ),
            Text(
              'Ready to close out today? Move what’s left to tomorrow in one tap.',
              style: AscentTextStyles.supportingText.copyWith(
                color: g.inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            AscentButton.primary(
              key: const ValueKey('things_carry_over'),
              compact: true,
              expanded: true,
              label: 'Move to tomorrow',
              icon: Icons.next_plan_outlined,
              loading: _moving,
              onPressed: () => _carryOverToTomorrow(view),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() => AppTextField(
    controller: _searchController,
    autofocus: true,
    hintText: 'Search your things',
    prefixIcon: const Icon(Icons.search_rounded, size: 20),
    suffixIcon: _query.isNotEmpty
        ? AscentButton.icon(
            icon: Icons.clear_rounded,
            tooltip: 'Clear search',
            semanticLabel: 'Clear search',
            onPressed: _clearSearch,
          )
        : null,
    onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
  );

  Widget _buildComposer(BuildContext context) {
    // Anytime things have no date, so that segment gets a one-field capture
    // that saves without one.
    if (_segment == ThingsSegment.anytime) {
      return AscentComposer(
        key: const ValueKey('things_anytime_composer'),
        controller: _anytimeController,
        focusNode: _composerFocusNode,
        hint: 'e.g. Read that article',
        maxLines: 1,
        submitOnEnter: true,
        busy: _savingAnytime,
        fieldKey: const ValueKey('things_anytime_field'),
        sendKey: const ValueKey('things_anytime_send'),
        sendTooltip: 'Add to Anytime',
        onSend: (_) => _addAnytime(),
      );
    }
    if (!_usesScrollingControls(context)) {
      return ActivityComposer(
        key: ValueKey('things_composer_${_segment.name}'),
        focusNode: _composerFocusNode,
        defaultDay: _segment == ThingsSegment.upcoming
            ? _today.add(const Duration(days: 1))
            : null,
      );
    }
    return AscentButton.primary(
      label: 'Add a thing',
      icon: Icons.add_rounded,
      onPressed: _openAddScreen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(todayActivitiesProvider);
    final items = activities.value;
    final List<Widget> content;
    if (_segment == ThingsSegment.upcoming) {
      content = _upcomingSlivers();
    } else if (items == null) {
      content = [activities.hasError ? _errorSliver() : _loadingSliver()];
    } else {
      content = switch (_segment) {
        ThingsSegment.today => _todaySlivers(items),
        ThingsSegment.anytime => _anytimeSlivers(items),
        ThingsSegment.routines => _routineSlivers(items),
        ThingsSegment.upcoming => const [],
      };
    }

    return AscentScaffold(
      title: 'Things',
      largeTitle: true,
      showBackButton: false,
      // Grouped canvas behind white cards, like Home (CLAUDE.md §3.1).
      backgroundColor: HomeDesign.of(context).canvas,
      actions: [
        const CaptureButton.nav(),
        AscentButton.icon(
          icon: _showSearch ? Icons.search_off_rounded : Icons.search_rounded,
          tooltip: _showSearch ? 'Close search' : 'Search things',
          semanticLabel: _showSearch ? 'Close search' : 'Search things',
          onPressed: _toggleSearch,
        ),
        AscentButton.icon(
          key: const ValueKey('things_calendar_button'),
          icon: Icons.calendar_month_rounded,
          tooltip: 'Things calendar',
          semanticLabel: 'Things calendar',
          onPressed: () => context.push('/calendar?scope=things'),
        ),
        AscentButton.icon(
          key: const ValueKey('things_reminders_button'),
          icon: Icons.notifications_none_rounded,
          tooltip: 'Reminders',
          semanticLabel: 'Reminders',
          onPressed: () => context.push('/reminders'),
        ),
        AscentButton.icon(
          icon: Icons.history_rounded,
          tooltip: 'All history',
          semanticLabel: 'All history',
          onPressed: () => context.push('/history'),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            // Rows fade out above the quick add instead of a hard cut.
            child: ScrollEdgeFade(
              child: CustomScrollView(
                key: ValueKey('things_list_${_segment.name}'),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: AscentSegmentedControl<ThingsSegment>(
                        key: const ValueKey('things_segments'),
                        segments: [
                          for (final s in ThingsSegment.values)
                            AscentSegment(
                              key: ValueKey('things_segment_${s.name}'),
                              value: s,
                              label: s.label,
                            ),
                        ],
                        selected: _segment,
                        onChanged: _selectSegment,
                      ),
                    ),
                  ),
                  if (_showSearch)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: _buildSearch(),
                      ),
                    ),
                  ...content,
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
          // Quick add on every list segment; Routines has its own plan
          // controls.
          if (_segment != ThingsSegment.routines)
            SafeArea(
              top: false,
              // No strip of its own: the field sits straight on the page,
              // like Mindspace's composer.
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: _buildComposer(context),
              ),
            ),
        ],
      ),
    );
  }
}
