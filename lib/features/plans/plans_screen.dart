import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/services/plan_collection_service.dart';
import '../../shared/widgets/app_surfaces.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/history_action.dart';
import '../../shared/widgets/skeleton_shimmer.dart';
import 'plan_templates.dart';
import 'planning_providers.dart';
import 'widgets/plan_collection_detail.dart';
import 'widgets/plan_detail_sheet.dart';
import 'widgets/plan_template_sheet.dart';

final allPlansStreamProvider = StreamProvider<List<PlanDefinition>>(
  (ref) => ref.watch(databaseProvider).planDao.watchAllPlans(),
);

/// Plans: start one from a template in a tap, then follow its progress.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key, this.initialPlanId});
  final String? initialPlanId;

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String _status = 'active';
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

  Future<void> _startTemplate(PlanTemplate template) async {
    HapticFeedback.selectionClick();
    final id = await showPlanTemplateSheet(context, template);
    if (id == null || !mounted) return;
    setState(() => _status = 'active');
    await showPlanCollectionDetail(context, id);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final collections = ref.watch(planCollectionsProvider);
    final legacy = ref.watch(allPlansStreamProvider);
    if (legacy.value != null) _checkInitialPlan(legacy.value!);
    final known = collections.value ?? const <PlanCollectionView>[];
    String label(String status, String name) {
      final n = known.where((c) => c.status == status).length;
      return n > 0 ? '$name $n' : name;
    }

    return AscentScaffold(
      title: 'Plans',
      actions: const [HistoryAction(module: 'routines')],
      body: CustomScrollView(
        key: const ValueKey('plans_scroll'),
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _templates(g)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s8,
                AppSpace.s16,
                AppSpace.s12,
              ),
              child: Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  AscentButton.tonal(
                    key: const ValueKey('plans_blank'),
                    label: 'Blank plan',
                    icon: Icons.add_rounded,
                    compact: true,
                    onPressed: () => context.push(AscentRoutes.createPlan),
                  ),
                  AscentButton.secondary(
                    key: const ValueKey('plans_study_hub'),
                    label: 'Study Hub',
                    icon: Icons.school_outlined,
                    onPressed: () => context.push(AscentRoutes.studyPlan),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s8,
                AppSpace.s16,
                AppSpace.s12,
              ),
              child: AscentSegmentedControl<String>(
                key: const ValueKey('plans_status'),
                selected: _status,
                onChanged: (s) => setState(() => _status = s),
                segments: [
                  AscentSegment(
                    value: 'active',
                    label: label('active', 'Active'),
                  ),
                  AscentSegment(
                    value: 'paused',
                    label: label('paused', 'Paused'),
                  ),
                  AscentSegment(
                    value: 'archived',
                    label: label('archived', 'Archived'),
                  ),
                ],
              ),
            ),
          ),
          ..._list(collections),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpace.s40)),
        ],
      ),
    );
  }

  Widget _templates(AscentGlass g) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s8,
          AppSpace.s16,
          AppSpace.s8,
        ),
        child: Text(
          'Start a plan',
          style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
        ),
      ),
      SizedBox(
        height: 176,
        child: ListView.separated(
          key: const ValueKey('plan_templates'),
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          itemCount: planTemplates.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpace.s12),
          itemBuilder: (context, i) => _TemplateCard(
            template: planTemplates[i],
            onTap: () => _startTemplate(planTemplates[i]),
          ),
        ),
      ),
    ],
  );

  List<Widget> _list(AsyncValue<List<PlanCollectionView>> collections) {
    if (collections.isLoading && !collections.hasValue) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          sliver: SliverList.list(
            children: [
              for (var i = 0; i < 3; i++) ...[
                SkeletonShimmer.card(height: 96),
                const SizedBox(height: AppSpace.s12),
              ],
            ],
          ),
        ),
      ];
    }
    if (collections.hasError && !collections.hasValue) {
      return [
        SliverToBoxAdapter(
          child: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load your plans',
            subtitle: 'Your plans have not been changed.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(planCollectionsProvider),
          ),
        ),
      ];
    }
    final list = (collections.value ?? const <PlanCollectionView>[])
        .where((c) => c.status == _status)
        .toList();
    if (list.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _status == 'active'
              ? EmptyState(
                  icon: Icons.event_repeat_rounded,
                  title: 'Plan anything, one tap to start',
                  subtitle:
                      'Pick a routine. Its steps show up in Things each day.',
                  starters: [
                    for (final t in planTemplates.take(3))
                      EmptyStarter(
                        label: t.title,
                        icon: t.icon,
                        onTap: () => _startTemplate(t),
                      ),
                  ],
                )
              : EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: _status == 'paused'
                      ? 'No paused plans'
                      : 'Nothing archived',
                  subtitle: 'Plans you pause or finish are kept here.',
                ),
        ),
      ];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
        sliver: SliverList.builder(
          itemCount: list.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s12),
            child: _PlanCard(plan: list[i]),
          ),
        ),
      ),
    ];
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.template, required this.onTap});
  final PlanTemplate template;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final t = template;
    final steps = t.steps.length;
    return SizedBox(
      width: 200,
      child: Semantics(
        button: true,
        label: 'Start ${t.title}',
        child: AppCard(
          key: ValueKey('plan_template_${t.id}'),
          padding: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: g.actionInk.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(t.icon, color: g.actionInk),
                  ),
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.homeHeadline.copyWith(color: g.ink),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Expanded(
                    child: Text(
                      t.blurb,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '${t.weeks} weeks · $steps ${steps == 1 ? 'step' : 'steps'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan});
  final PlanCollectionView plan;

  IconData get _icon {
    final text = '${plan.title} ${plan.description}'.toLowerCase();
    for (final t in planTemplates) {
      if (text.contains('${t.id} template')) return t.icon;
    }
    if (text.contains('study') || text.contains('dsa')) {
      return Icons.school_outlined;
    }
    if (text.contains('meal')) return Icons.restaurant_outlined;
    return plan.routines > 0
        ? Icons.event_repeat_rounded
        : Icons.checklist_rounded;
  }

  String _status(BuildContext context) {
    if (plan.total == 0) return 'No steps yet';
    final parts = <String>[
      '${plan.done} of ${plan.total} done',
      if (plan.overdue > 0) '${plan.overdue} overdue',
    ];
    final next = plan.nextAt;
    if (next != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(next.year, next.month, next.day);
      final when = day == today
          ? 'today'
          : day == today.add(const Duration(days: 1))
          ? 'tomorrow'
          : DateFormat('EEE').format(next);
      parts.add('next $when ${TimeOfDay.fromDateTime(next).format(context)}');
    }
    if (plan.pendingAlerts > 0) parts.add('alerts need attention');
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final progress = plan.total == 0 ? 0.0 : plan.done / plan.total;
    return AppCard(
      key: ValueKey('plan_card_${plan.id}'),
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showPlanCollectionDetail(context, plan.id),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: g.actionInk.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_icon, size: 18, color: g.actionInk),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Text(
                      plan.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.homeHeadline.copyWith(
                        color: g.ink,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: g.inkMuted),
                ],
              ),
              const SizedBox(height: AppSpace.s12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: g.actionInk,
                  backgroundColor: g.recessed,
                ),
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                _status(context),
                style: AscentTextStyles.caption.copyWith(
                  color: plan.pendingAlerts > 0 || plan.overdue > 0
                      ? g.coral
                      : g.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
