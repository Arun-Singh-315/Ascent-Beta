import '../capture/quick_capture_sheet.dart';
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
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/glass_chip.dart';
import '../../shared/widgets/glass_surface.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import '../home/widgets/activity_composer.dart';
import '../plans/widgets/home_plans_preview.dart';
import 'models/things_intelligence.dart';
import 'widgets/things_hero_card.dart';
import 'widgets/things_interactive_card.dart';

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

class _ThingsHubScreenState extends ConsumerState<ThingsHubScreen> {
  String _query = '';
  String _type = 'all';
  String _tab = 'now';
  bool _wrapupMode = false;
  bool _showLenses = false;
  final Set<String> _collapsedSections = <String>{};
  final FocusNode _composerFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null &&
        {'now', 'done', 'plans'}.contains(widget.initialTab)) {
      _tab = widget.initialTab!;
    }
    if (widget.initialMode == 'wrapup') {
      _wrapupMode = true;
    }
    _checkInitialFocus();
  }

  @override
  void dispose() {
    _composerFocusNode.dispose();
    super.dispose();
  }

  void _checkInitialFocus() {
    final focusId = widget.initialFocusId;
    if (focusId == null || focusId.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final activities = await ref.read(todayActivitiesProvider.future);
      final exists = activities.any(
        (a) => a.id == focusId || a.linkedTaskId.toString() == focusId,
      );
      if (!exists && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This activity is no longer pending. Here is your Things hub.',
            ),
          ),
        );
      }
    });
  }

  bool _matchesFilter(TodayActivityItem a, String type) {
    switch (type) {
      case 'all':
        return true;
      case 'medicine':
        return a.sourceType == 'medicine';
      case 'timer':
        return a.kind != ActivityKind.todo && a.sourceType != 'medicine';
      case 'task':
        return a.kind == ActivityKind.todo && a.sourceType != 'medicine';
      case 'quick_wins':
        return ThingsEnrichmentEngine.analyze(a).smartLens ==
            ThingsSmartLens.quickWins;
      case 'deep_focus':
        return ThingsEnrichmentEngine.analyze(a).smartLens ==
            ThingsSmartLens.deepFocus;
      case 'life_errands':
        return ThingsEnrichmentEngine.analyze(a).smartLens ==
            ThingsSmartLens.lifeErrands;
      case 'wind_down':
        return ThingsEnrichmentEngine.analyze(a).smartLens ==
            ThingsSmartLens.windDown;
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return AscentScaffold(
      title: 'Things hub',
      subtitle: 'Make room for your next step',
      actions: [
        IconButton(
          tooltip: 'Quick capture',
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () => showQuickCapture(context),
        ),
        IconButton(
          tooltip: 'History',
          icon: const Icon(Icons.history_rounded),
          onPressed: () => context.push('/history'),
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search your things',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 10),
                AscentSegmentedControl<String>(
                  segments: const [
                    AscentSegment(value: 'now', label: 'Now'),
                    AscentSegment(value: 'done', label: 'Finished today'),
                    AscentSegment(value: 'plans', label: 'Plans'),
                  ],
                  selected: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                ),
                if (_tab != 'plans') ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (typeKey, label) in [
                        ('all', 'All activities'),
                        ('task', 'To-dos'),
                        ('timer', 'Timers'),
                        ('medicine', 'Medicines'),
                      ])
                        GlassChip(
                          label: label,
                          selected: _type == typeKey,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _type = typeKey);
                          },
                        ),
                      GlassChip(
                        key: const ValueKey('things_hub_toggle_lenses'),
                        icon: _showLenses
                            ? Icons.expand_less_rounded
                            : Icons.tune_rounded,
                        label: _showLenses ? 'Less' : 'More lenses',
                        selected: _type != 'all' &&
                            _type != 'task' &&
                            _type != 'timer' &&
                            _type != 'medicine',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showLenses = !_showLenses);
                        },
                      ),
                      if (_showLenses) ...[
                        for (final (typeKey, label) in [
                          ('quick_wins', '⚡ Quick Wins'),
                          ('deep_focus', '🎯 Deep Focus'),
                          ('life_errands', '🏃 Life & Errands'),
                          ('wind_down', '🌙 Wind-down'),
                        ])
                          GlassChip(
                            label: label,
                            selected: _type == typeKey,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _type = typeKey);
                            },
                          ),
                      ],
                    ],
                  ),
                  ref.watch(todayActivitiesProvider).maybeWhen(
                    data: (items) {
                      final total = items.length;
                      final done = items
                          .where((a) => a.status == TodayActivityStatus.done)
                          .length;
                      if (total == 0 || done == 0) {
                        return const SizedBox.shrink();
                      }
                      final percent = ((done / total) * 100).round();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Text(
                              '$done of $total finished · $percent%',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: g.inkMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: (done / total).clamp(0.0, 1.0),
                                  minHeight: 3,
                                  backgroundColor: g.line,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                    SharedControlColors.actionBlue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
          if (_wrapupMode && _tab == 'now')
            Padding(
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
                        Text(
                          'Evening Wrap-up',
                          style: TextStyle(
                            color: g.ink,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
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
                    Row(
                      children: [
                        AscentButton.primary(
                          compact: true,
                          expanded: false,
                          label: 'Carry over to tomorrow',
                          icon: Icons.next_plan_outlined,
                          onPressed: () async {
                            HapticFeedback.lightImpact();
                            final messenger = ScaffoldMessenger.of(context);
                            final db = ref.read(databaseProvider);
                            final tomorrow = DateTime.now().add(
                              const Duration(days: 1),
                            );
                            final items = await ref.read(
                              todayActivitiesProvider.future,
                            );
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
                                  content: Text(
                                    'Unfinished items moved to tomorrow.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
                            SkeletonShimmer(height: 52),
                            const SizedBox(height: 8),
                            SkeletonShimmer(height: 52),
                            const SizedBox(height: 8),
                            SkeletonShimmer(height: 52),
                          ],
                        ),
                        error: (_, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Unable to load activities. Your tasks and history are preserved.',
                                  style: TextStyle(
                                    color: g.inkMuted,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                AscentButton.tonal(
                                  label: 'Retry activities',
                                  icon: Icons.refresh_rounded,
                                  onPressed: () =>
                                      ref.invalidate(todayActivitiesProvider),
                                ),
                              ],
                            ),
                          ),
                        ),
                        data: (items) {
                          final rows = items
                              .where(
                                (a) =>
                                    (a.status == TodayActivityStatus.done) ==
                                        (_tab == 'done') &&
                                    _matchesFilter(a, _type) &&
                                    (_query.isEmpty ||
                                        '${a.title} ${a.notes ?? ''}'
                                            .toLowerCase()
                                            .contains(_query)),
                              )
                              .toList();

                          // For single item on "Now" tab, render focused hero compass;
                          // for multiple items, arrange cleanly into ground sections.
                          TodayActivityItem? heroItem;
                          List<TodayActivityItem> nonHeroRows = rows;
                          if (_tab == 'now' &&
                              _query.isEmpty &&
                              _type == 'all' &&
                              rows.length == 1) {
                            heroItem = rows.first;
                            nonHeroRows = const [];
                          }

                          final groups = <String, List<TodayActivityItem>>{};
                          for (final a in nonHeroRows) {
                            final group = _tab == 'done'
                                ? 'Finished today'
                                : a.status == TodayActivityStatus.inProgress ||
                                      a.status == TodayActivityStatus.paused
                                ? 'In progress'
                                : a.isOverdue ||
                                      a.priority == 'high' ||
                                      (a.scheduledTime != null &&
                                          a.scheduledTime!.difference(
                                                DateTime.now(),
                                              ) <=
                                              const Duration(hours: 1))
                                ? 'Needs attention'
                                : 'Next';
                            groups.putIfAbsent(group, () => []).add(a);
                          }

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                            children: [
                              if (heroItem != null)
                                ThingsHeroCard(
                                  key: ValueKey('things_hero_${heroItem.id}'),
                                  activity: heroItem,
                                  onTap: () {},
                                ),
                              if (rows.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 48,
                                    horizontal: 24,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 52,
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: g.fill,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: g.line,
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              _query.isNotEmpty
                                                  ? Icons.search_off_rounded
                                                  : (_tab == 'done'
                                                      ? Icons.celebration_outlined
                                                      : Icons.spa_outlined),
                                              size: 26,
                                              color: g.inkMuted,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          _query.isEmpty
                                              ? (_tab == 'done'
                                                  ? 'No Finished Tasks Yet'
                                                  : 'Your Space is Clear')
                                              : 'No Matching Things',
                                          style: TextStyle(
                                            color: g.ink,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _query.isEmpty
                                              ? (_tab == 'done'
                                                  ? 'Complete an activity today and review your achievements here.'
                                                  : 'Nothing pending on your plate. Add one small task below to begin.')
                                              : 'Try adjusting your search keywords.',
                                          style: TextStyle(
                                            color: g.inkMuted,
                                            fontSize: 13,
                                            height: 1.4,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        if (_tab == 'now' && _query.isEmpty) ...[
                                          const SizedBox(height: 16),
                                          AscentButton.tonal(
                                            compact: true,
                                            label: 'Add one small thing',
                                            icon: Icons.add_rounded,
                                            onPressed: () =>
                                                _composerFocusNode.requestFocus(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              for (final (name, icon, color) in [
                                ('In progress', Icons.play_circle_outline_rounded, SharedControlColors.actionBlue),
                                ('Needs attention', Icons.error_outline_rounded, SharedControlColors.dueRed),
                                ('Next', Icons.playlist_play_rounded, g.ink),
                                ('Finished today', Icons.check_circle_outline_rounded, SharedControlColors.actionBlue),
                              ])
                                if (groups.containsKey(name)) ...[
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (_collapsedSections.contains(name)) {
                                          _collapsedSections.remove(name);
                                        } else {
                                          _collapsedSections.add(name);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        16,
                                        4,
                                        8,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(icon, size: 16, color: color),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '$name · ${groups[name]!.length}',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: g.ink,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(
                                            _collapsedSections.contains(name)
                                                ? Icons.keyboard_arrow_down_rounded
                                                : Icons.keyboard_arrow_up_rounded,
                                            size: 18,
                                            color: g.inkMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (!_collapsedSections.contains(name))
                                    for (final activity in groups[name]!)
                                      ThingsInteractiveCard(
                                        key: ValueKey(
                                          'things_interactive_${activity.id}',
                                        ),
                                        activity: activity,
                                        compact: true,
                                      ),
                                ],
                              if (_tab == 'done')
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Center(
                                    child: TextButton.icon(
                                      onPressed: () => context.push('/history'),
                                      icon: const Icon(Icons.history_rounded),
                                      label: const Text('Browse all history'),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
          ),
          if (_tab == 'now')
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                decoration: BoxDecoration(
                  color: g.surface,
                  border: Border(top: BorderSide(color: g.line, width: 0.8)),
                ),
                child: ActivityComposer(focusNode: _composerFocusNode),
              ),
            ),
        ],
      ),
    );
  }
}
