import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../planning_providers.dart';
import 'plan_collection_detail.dart';
import 'plan_collection_editor.dart';

class HomePlansPreview extends ConsumerWidget {
  const HomePlansPreview({super.key, this.routinesOnly = false});
  final bool routinesOnly;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    return ref
        .watch(planCollectionsProvider)
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(planCollectionsProvider),
            child: const Text('Retry plans'),
          ),
          data: (all) {
            final plans = all
                .where(
                  (p) =>
                      p.status == 'active' && (!routinesOnly || p.routines > 0),
                )
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (plans.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
                    child: Text(
                      routinesOnly
                          ? 'No repeating items yet. Add a schedule to a plan item.'
                          : 'Make room for your next goal. Create a plan with a few clear steps.',
                    ),
                  ),
                for (final p in plans.take(4))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(AppSpace.s12),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr16,
                        ),
                        side: BorderSide(color: g.edge),
                      ),
                      onPressed: () => showPlanCollectionDetail(context, p.id),
                      child: Row(
                        children: [
                          Icon(
                            p.routines > 0
                                ? Icons.event_repeat
                                : Icons.checklist,
                            color: g.clay,
                          ),
                          const SizedBox(width: AppSpace.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.title,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  '${p.done} of ${p.total} done · ${p.remaining} remaining',
                                  style: TextStyle(color: g.inkSecondary),
                                ),
                                if (p.nextAt != null)
                                  Text(
                                    'Next · ${DateFormat('EEE, h:mm a').format(p.nextAt!)}',
                                    style: TextStyle(color: g.clay),
                                  ),
                                Text(
                                  '${p.scheduled} scheduled · ${p.unscheduled} without times${p.pendingAlerts > 0 ? ' · alerts pending' : ''}',
                                  style: TextStyle(color: g.inkMuted),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                Wrap(
                  spacing: AppSpace.s8,
                  children: [
                    TextButton.icon(
                      onPressed: () => showPlanCollectionEditor(context),
                      icon: const Icon(Icons.add),
                      label: const Text('New plan'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/plans'),
                      child: Text('View all ${plans.length} plans'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
  }
}
