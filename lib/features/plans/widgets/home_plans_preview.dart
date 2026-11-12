import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/home_design.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../core/services/plan_collection_service.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../planning_providers.dart';
import 'plan_collection_detail.dart';
import 'plan_collection_editor.dart';

enum _PlanFilter {
  all('All', Icons.auto_awesome_motion_rounded),
  study('Study', Icons.school_rounded),
  meal('Meal', Icons.restaurant_rounded),
  routine('Routines', Icons.event_repeat_rounded);

  const _PlanFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Compact, richly structured list of active plans shown inside the Dayboard.
///
/// Features dedicated styling and quick starters for Study & Meal planning,
/// clean category filters, progress indicators, and responsive glass cards.
class HomePlansPreview extends ConsumerStatefulWidget {
  const HomePlansPreview({super.key});

  @override
  ConsumerState<HomePlansPreview> createState() => _HomePlansPreviewState();
}

class _HomePlansPreviewState extends ConsumerState<HomePlansPreview> {
  static const _visibleLimit = 4;
  _PlanFilter _selectedFilter = _PlanFilter.all;

  static bool _isStudyPlan(PlanCollectionView p) {
    final desc = p.description.toLowerCase();
    final title = p.title.toLowerCase();
    return desc.contains('study') ||
        title.contains('study') ||
        title.contains('dsa') ||
        title.contains('course') ||
        title.contains('syllabus') ||
        title.contains('exam') ||
        title.contains('reading') ||
        title.contains('revision');
  }

  static bool _isMealPlan(PlanCollectionView p) {
    final desc = p.description.toLowerCase();
    final title = p.title.toLowerCase();
    return desc.contains('meal') ||
        desc.contains('diet') ||
        desc.contains('nutrition') ||
        title.contains('meal') ||
        title.contains('diet') ||
        title.contains('nutrition') ||
        title.contains('breakfast') ||
        title.contains('lunch') ||
        title.contains('dinner') ||
        title.contains('protein') ||
        title.contains('snack');
  }

  static _PlanFilter _classify(PlanCollectionView p) {
    if (_isStudyPlan(p)) return _PlanFilter.study;
    if (_isMealPlan(p)) return _PlanFilter.meal;
    return _PlanFilter.routine;
  }

  void _openStudyPlanner() {
    HapticFeedback.lightImpact();
    showPlanCollectionEditor(
      context,
      initialText:
          'DSA & Study Routine\n• Core Concepts & Notes\n• Practice Problems\n• Daily Review & Recall',
    );
  }

  void _openMealPlanner() {
    HapticFeedback.lightImpact();
    showPlanCollectionEditor(
      context,
      dailyTimes: true,
      initialText:
          'Daily Meal & Nutrition Plan\n• Breakfast: Protein & Whole Grains (8:30 AM)\n• Lunch: Balanced Greens & Protein (1:30 PM)\n• Evening Snack: Energy Fuel (5:00 PM)\n• Dinner: Light Greens & Protein (8:00 PM)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return ref.watch(planCollectionsProvider).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => AscentButton.ghost(
            compact: true,
            label: 'Retry plans',
            icon: Icons.refresh_rounded,
            onPressed: () => ref.invalidate(planCollectionsProvider),
          ),
          data: (all) {
            final plans = all.where((p) => p.status == 'active').toList();
            if (plans.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpace.s24,
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
                      const SizedBox(height: AppSpace.s16),
                      _buildQuickStarters(compact: true),
                    ],
                  ),
                ),
              );
            }

            final studyCount = plans.where(_isStudyPlan).length;
            final mealCount = plans.where(_isMealPlan).length;
            final routineCount =
                plans.where((p) => !_isStudyPlan(p) && !_isMealPlan(p)).length;

            final filtered = _selectedFilter == _PlanFilter.all
                ? plans
                : plans.where((p) => _classify(p) == _selectedFilter).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (plans.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All (${plans.length})',
                          isSelected: _selectedFilter == _PlanFilter.all,
                          onTap: () => setState(
                            () => _selectedFilter = _PlanFilter.all,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '📚 Study ($studyCount)',
                          isSelected: _selectedFilter == _PlanFilter.study,
                          onTap: () => setState(
                            () => _selectedFilter = _PlanFilter.study,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _FilterChip(
                          label: '🥗 Meal ($mealCount)',
                          isSelected: _selectedFilter == _PlanFilter.meal,
                          onTap: () => setState(
                            () => _selectedFilter = _PlanFilter.meal,
                          ),
                        ),
                        if (routineCount > 0) ...[
                          const SizedBox(width: 6),
                          _FilterChip(
                            label: '⚡ Routines ($routineCount)',
                            isSelected: _selectedFilter == _PlanFilter.routine,
                            onTap: () => setState(
                              () => _selectedFilter = _PlanFilter.routine,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.s10),
                ],
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
                    child: Center(
                      child: Text(
                        'No ${_selectedFilter.label.toLowerCase()} plans active.',
                        style: TextStyle(color: g.inkMuted, fontSize: 13),
                      ),
                    ),
                  )
                else
                  for (final p in filtered.take(_visibleLimit))
                    _PlanCard(
                      plan: p,
                      kind: _classify(p),
                      onTap: () => showPlanCollectionDetail(context, p.id),
                      onLongPress: () => showPlanActionMenu(context, p),
                    ),
                const SizedBox(height: AppSpace.s6),
                _buildQuickStarters(compact: false),
                const SizedBox(height: AppSpace.s10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    AscentButton.tonal(
                      compact: true,
                      onPressed: () => showPlanCollectionEditor(context),
                      icon: Icons.add_rounded,
                      label: 'New plan',
                    ),
                    AscentButton.ghost(
                      compact: true,
                      onPressed: () => context.push('/plans'),
                      label: 'View all plans ›',
                    ),
                  ],
                ),
              ],
            );
          },
        );
  }

  Widget _buildQuickStarters({required bool compact}) {
    final g = context.glass;

    final studyCard = _QuickPlannerCard(
      title: 'Plan Study',
      subtitle: 'Syllabus, DSA & Targets',
      icon: Icons.school_rounded,
      accentColor: g.clay,
      onTap: _openStudyPlanner,
    );

    final mealCard = _QuickPlannerCard(
      title: 'Plan Meals',
      subtitle: 'Macros, Diet & Timings',
      icon: Icons.restaurant_rounded,
      accentColor: g.sage,
      onTap: _openMealPlanner,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        if (isNarrow) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              studyCard,
              const SizedBox(height: 8),
              mealCard,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: studyCard),
            const SizedBox(width: 8),
            Expanded(child: mealCard),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? g.elevated : g.fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? g.clay : g.line,
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? g.ink : g.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.kind,
    required this.onTap,
    required this.onLongPress,
  });

  final PlanCollectionView plan;
  final _PlanFilter kind;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    final Color accentColor = switch (kind) {
      _PlanFilter.study => g.clay,
      _PlanFilter.meal => g.sage,
      _ => HomeDesign.of(context).action,
    };

    final String tagLabel = switch (kind) {
      _PlanFilter.study => 'STUDY',
      _PlanFilter.meal => 'MEAL & DIET',
      _ => 'ROUTINE',
    };

    final progressFraction = plan.total > 0
        ? (plan.done / plan.total).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.s8),
      decoration: BoxDecoration(
        color: g.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
            onLongPress();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s12,
              vertical: AppSpace.s10,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      kind.icon,
                      size: 20,
                      color: accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tagLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: accentColor,
                              ),
                            ),
                          ),
                          if (plan.pendingAlerts > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: g.clay.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Alerts',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: g.clay,
                                ),
                              ),
                            ),
                          if (plan.nextAt != null)
                            Text(
                              'Next: ${DateFormat('EEE, h:mm a').format(plan.nextAt!)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: g.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: g.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: progressFraction,
                                minHeight: 4,
                                color: accentColor,
                                backgroundColor: g.track,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            plan.total == 0
                                ? 'No items'
                                : '${plan.done}/${plan.total} done',
                            style: TextStyle(
                              fontSize: 11,
                              color: plan.pendingAlerts > 0
                                  ? g.clay
                                  : g.inkMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: g.inkMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickPlannerCard extends StatelessWidget {
  const _QuickPlannerCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12,
            vertical: AppSpace.s10,
          ),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.24),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: g.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: g.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_rounded, size: 18, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}
