import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/app_surfaces.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import 'widgets/plan_detail_sheet.dart';
import 'widgets/plan_collection_editor.dart';
import 'widgets/plan_collection_detail.dart';
import 'planning_providers.dart';

final allPlansStreamProvider = StreamProvider<List<PlanDefinition>>(
  (ref) => ref.watch(databaseProvider).planDao.watchAllPlans(),
);

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key, this.initialPlanId});
  final String? initialPlanId;

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  int _selectedTab = 0; // 0 = Active, 1 = Paused, 2 = Ended
  bool _handledInitialPlan = false;

  void _checkInitialPlan(List<PlanDefinition> plans) {
    if (_handledInitialPlan || widget.initialPlanId == null) return;
    _handledInitialPlan = true;
    final target = plans.where((p) => p.id == widget.initialPlanId).firstOrNull;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showPlanDetailSheet(context, target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final collections = ref.watch(planCollectionsProvider);
    final legacy = ref.watch(allPlansStreamProvider);
    if (legacy.value != null) _checkInitialPlan(legacy.value!);
    return AscentScaffold(
      title: 'Plans & Routines',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showPlanCollectionEditor(context),
                    icon: const Icon(Icons.add),
                    label: const Text('New plan'),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var n = 0; n < 3; n++)
                      ChoiceChip(
                        label: Text(['Active', 'Paused', 'Archived'][n]),
                        selected: _selectedTab == n,
                        onSelected: (_) => setState(() => _selectedTab = n),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: collections.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load plans.'),
                    TextButton(
                      onPressed: () => ref.invalidate(planCollectionsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (all) {
                final list = all
                    .where(
                      (c) =>
                          c.status ==
                          ['active', 'paused', 'archived'][_selectedTab],
                    )
                    .toList();
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.checklist_rounded,
                    title: 'Your plans belong here',
                    subtitle:
                        'Create a plan, add a few items, and schedule only what needs a time.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, n) {
                    final p = list[n];
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      child: InkWell(
                        onTap: () => showPlanCollectionDetail(context, p.id),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  p.routines > 0
                                      ? Icons.event_repeat
                                      : Icons.checklist,
                                  color: g.clay,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p.title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            const SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: p.total == 0 ? 0 : p.done / p.total,
                              color: g.clay,
                              backgroundColor: g.fill,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${p.done} of ${p.total} done · ${p.remaining} remaining',
                              style: TextStyle(color: g.inkSecondary),
                            ),
                            Text(
                              '${p.scheduled} scheduled · ${p.routines} repeating${p.pendingAlerts > 0 ? ' · alerts need attention' : ''}',
                              style: TextStyle(color: g.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
