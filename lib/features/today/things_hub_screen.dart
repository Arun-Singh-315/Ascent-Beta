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
import '../home/widgets/activity_row_item.dart';
import '../plans/widgets/home_plans_preview.dart';
import 'widgets/things_hero_card.dart';

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
      final exists = activities.any((a) => a.id == focusId || a.linkedTaskId.toString() == focusId);
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

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return AscentScaffold(
      title: 'Things hub',
      subtitle: 'Make room for your next step',
      actions: [
        IconButton(
          tooltip: 'History',
          icon: const Icon(Icons.history_rounded),
          onPressed: () => context.push('/history'),
        ),
        IconButton(
          tooltip: 'Task board',
          icon: const Icon(Icons.checklist_rounded),
          onPressed: () => context.push('/today'),
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (typeKey, label) in [
                          ('all', 'All activities'),
                          ('task', 'To-dos'),
                          ('timer', 'Timers'),
                          ('medicine', 'Medicines'),
                        ]) ...[
                          GlassChip(
                            label: label,
                            selected: _type == typeKey,
                            onTap: () => setState(() => _type = typeKey),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
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
                            final tomorrow = DateTime.now().add(const Duration(days: 1));
                            final items = await ref.read(todayActivitiesProvider.future);
                            final pendingTasks = items.where(
                              (a) => a.status != TodayActivityStatus.done && a.linkedTaskId != null,
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
                : ref.watch(todayActivitiesProvider).when(
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
                                style: TextStyle(color: g.inkMuted, fontSize: 13),
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
                                  (_type == 'all' ||
                                      (_type == 'medicine'
                                          ? a.sourceType == 'medicine'
                                          : _type == 'timer'
                                          ? a.kind != ActivityKind.todo &&
                                                a.sourceType != 'medicine'
                                          : a.kind == ActivityKind.todo &&
                                                a.sourceType != 'medicine')) &&
                                  (_query.isEmpty ||
                                      '${a.title} ${a.notes ?? ''}'
                                          .toLowerCase()
                                          .contains(_query)),
                            )
                            .toList();

                        // Identify hero item for "Now" tab
                        TodayActivityItem? heroItem;
                        List<TodayActivityItem> nonHeroRows = rows;
                        if (_tab == 'now' && _query.isEmpty && _type == 'all' && rows.isNotEmpty) {
                          heroItem = rows.first;
                          nonHeroRows = rows.skip(1).toList();
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
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        _query.isEmpty
                                            ? (_tab == 'done'
                                                ? 'No finished activities yet today.'
                                                : 'All clear! Add one small thing to begin.')
                                            : 'No matching activities.',
                                        style: TextStyle(color: g.inkMuted, fontSize: 13),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_tab == 'now' && _query.isEmpty) ...[
                                        const SizedBox(height: 8),
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
                            for (final name in [
                              'In progress',
                              'Needs attention',
                              'Next',
                              'Finished today',
                            ])
                              if (groups.containsKey(name)) ...[
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    4,
                                    14,
                                    4,
                                    8,
                                  ),
                                  child: Text(
                                    '$name · ${groups[name]!.length}',
                                    style: TextStyle(
                                      color: g.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                for (final activity in groups[name]!)
                                  ActivityRowItem(
                                    key: ValueKey(activity.id),
                                    activity: activity,
                                    compact: true,
                                  ),
                              ],
                            if (_tab == 'done')
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
                child: ActivityComposer(
                  focusNode: _composerFocusNode,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
