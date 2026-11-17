import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/plan_collection_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/section_card.dart';
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

class HomePlansPreview extends ConsumerStatefulWidget {
  const HomePlansPreview({super.key, this.standalone = true});

  final bool standalone;

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
    final c = context.c;

    final content = ref.watch(planCollectionsProvider).when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => TextButton.icon(
        onPressed: () => ref.invalidate(planCollectionsProvider),
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Retry plans'),
      ),
      data: (all) {
        final plans = all.where((p) => p.status == 'active').toList();
        if (plans.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Solid empty state container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(Rd.card),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 32,
                      color: c.textSecondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No Recurring Plans Yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Design routines, weekly rhythms, and habits that organize your days automatically.',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent, // primary clay
                        foregroundColor: c.onAccent,
                        elevation: 2,
                        shadowColor: const Color(0x0A5C4A3E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Rd.chip),
                        ),
                        minimumSize: const Size(140, 44),
                      ),
                      onPressed: () => showPlanCollectionEditor(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create a plan'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 2. Quick start row of two AppChips below
              _buildQuickStartChips(c),
            ],
          );
        }

        final filtered = _selectedFilter == _PlanFilter.all
            ? plans
            : plans.where((p) => _classify(p) == _selectedFilter).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter row if multiple plans
            if (plans.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    for (final filter in _PlanFilter.values) ...[
                      AppChip(
                        label: filter.label,
                        isSelected: _selectedFilter == filter,
                        onTap: () => setState(() => _selectedFilter = filter),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Plan rows
            for (final p in filtered.take(_visibleLimit))
              _PlanRow(
                plan: p,
                kind: _classify(p),
                onTap: () => showPlanCollectionDetail(context, p.id),
                onLongPress: () => showPlanActionMenu(context, p),
              ),

            const SizedBox(height: 14),
            _buildQuickStartChips(c),
          ],
        );
      },
    );

    if (!widget.standalone) return content;

    return SectionCard(
      key: const ValueKey('home_plans_big_card'),
      icon: Icons.event_repeat_outlined,
      title: 'Plans & Routines',
      onOpen: () => context.push('/plans'),
      child: content,
    );
  }

  Widget _buildQuickStartChips(AppColors c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          AppChip(
            icon: Icons.school_outlined,
            label: 'Plan study',
            onTap: _openStudyPlanner,
          ),
          const SizedBox(width: 8),
          AppChip(
            icon: Icons.restaurant_outlined,
            label: 'Plan meals',
            onTap: _openMealPlanner,
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
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
    final c = context.c;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Rd.field),
        border: Border.all(color: c.border),
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          onLongPress();
        },
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.accentTint,
                borderRadius: BorderRadius.circular(Rd.iconChip),
              ),
              child: Icon(kind.icon, size: 18, color: c.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    plan.description.isNotEmpty
                        ? plan.description
                        : '${plan.done}/${plan.total} completed',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}
