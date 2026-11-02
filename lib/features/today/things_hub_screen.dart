import '../../core/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../home/widgets/activity_composer.dart';
import '../home/widgets/activity_row_item.dart';
import '../plans/widgets/home_plans_preview.dart';

class ThingsHubScreen extends ConsumerStatefulWidget {
  const ThingsHubScreen({super.key});
  @override
  ConsumerState<ThingsHubScreen> createState() => _ThingsHubScreenState();
}

class _ThingsHubScreenState extends ConsumerState<ThingsHubScreen> {
  String _query = '', _type = 'all', _tab = 'now';
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search your things',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Show'),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All activities'),
                      ),
                      DropdownMenuItem(value: 'task', child: Text('To-dos')),
                      DropdownMenuItem(value: 'timer', child: Text('Timers')),
                      DropdownMenuItem(
                        value: 'medicine',
                        child: Text('Medicines'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _type = v!),
                  ),
                ],
              ],
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
                                                  a.sourceType !=
                                                      'medicine')) &&
                                    (_query.isEmpty ||
                                        '${a.title} ${a.notes ?? ''}'
                                            .toLowerCase()
                                            .contains(_query)),
                              )
                              .toList();
                          final groups = <String, List<TodayActivityItem>>{};
                          for (final a in rows) {
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
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            children: [
                              if (rows.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    _query.isEmpty
                                        ? 'Nothing in this view. Your past activity is in History.'
                                        : 'No matching activities.',
                                    style: TextStyle(color: g.inkMuted),
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
                                      16,
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
                                TextButton.icon(
                                  onPressed: () => context.push('/history'),
                                  icon: const Icon(Icons.history_rounded),
                                  label: const Text('Browse all history'),
                                ),
                              if (_tab == 'now')
                                const Padding(
                                  padding: EdgeInsets.only(top: 16),
                                  child: ActivityComposer(),
                                ),
                            ],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
