import '../../../shared/widgets/ascent_button.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../core/services/plan_collection_service.dart';
import '../planning_providers.dart';
import 'plan_collection_detail.dart';
import 'plan_collection_editor.dart';

/// Compact list of active plans shown inside the Dayboard.
///
/// Each plan is one tappable row with a title and a single status line.
/// Repeating routines live inside their plan, so they are not listed again.
class HomePlansPreview extends ConsumerWidget {
  const HomePlansPreview({super.key});

  static const _visibleLimit = 3;

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
            final plans = all.where((p) => p.status == 'active').toList();
            if (plans.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpace.s32,
                  horizontal: AppSpace.s16,
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
                          border: Border.all(color: g.line, width: 0.8),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.calendar_month_outlined,
                            size: 26,
                            color: g.inkMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpace.s16),
                      Text(
                        'No Recurring Plans Yet',
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpace.s6),
                      Text(
                        'Design routines, weekly rhythms, and habits that organize your days automatically.',
                        style: TextStyle(
                          color: g.inkMuted,
                          fontSize: 13,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpace.s16),
                      AscentButton.tonal(
                        compact: true,
                        label: 'Create a plan',
                        icon: Icons.add_rounded,
                        onPressed: () => showPlanCollectionEditor(context),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final p in plans.take(_visibleLimit))
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s12,
                          vertical: AppSpace.s10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr16,
                        ),
                        side: BorderSide(color: g.edge),
                      ),
                      onPressed: () => showPlanCollectionDetail(context, p.id),
                      onLongPress: () => showPlanActionMenu(context, p),
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  _statusLine(p),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.pendingAlerts > 0
                                        ? g.clay
                                        : g.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => showPlanCollectionEditor(context),
                      icon: const Icon(Icons.add),
                      label: const Text('New plan'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.push('/plans'),
                      child: const Text('View ›'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
  }

  /// One short line: alerts problem first, then next time, then progress.
  static String _statusLine(PlanCollectionView p) {
    if (p.pendingAlerts > 0) return 'Alerts need attention';
    if (p.total == 0) return 'No items yet';
    final progress = '${p.done} of ${p.total} done';
    final next = p.nextAt;
    if (next == null) return progress;
    return '$progress · Next ${DateFormat('EEE, h:mm a').format(next)}';
  }
}
