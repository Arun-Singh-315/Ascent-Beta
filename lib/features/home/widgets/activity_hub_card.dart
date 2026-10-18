import '../../plans/planning_providers.dart';
import '../../plans/widgets/home_plans_preview.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/skeleton_shimmer.dart';
import '../../../shared/widgets/glass_surface.dart';
import 'activity_row_item.dart';
import 'activity_composer.dart';

/// Level 1 · Primary: Today
/// Redesigned according to Ascent Home Redesign spec:
/// - A soft surface groups today’s progress, activities and add action.
/// - Single-line progress bar with done count and streak flame.
/// - Three text tabs with active underline indicator.
/// - 44dp hit-area task items.
/// - Inline "Add activity" action row.
class ActivityHubCard extends ConsumerStatefulWidget {
  const ActivityHubCard({
    super.key,
    this.previewLimit = 4,
    this.excludedTaskIds = const {},
  });
  final Set<int> excludedTaskIds;
  final int previewLimit;

  @override
  ConsumerState<ActivityHubCard> createState() => _ActivityHubCardState();
}

class _ActivityHubCardState extends ConsumerState<ActivityHubCard> {
  bool _showAll = false;
  bool _showCompleted = false;
  bool _showPlans = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final plans = ref.watch(planCollectionsProvider).value ?? [];
    final planCount = plans.where((p) => p.status == 'active').length;
    final activitiesAsync = ref.watch(todayActivitiesProvider);

    final allActivities =
        activitiesAsync.asData?.value ?? activitiesAsync.value;

    if (allActivities == null) {
      if (activitiesAsync.hasError) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          child: Text(
            'Error loading activities: ${activitiesAsync.error}',
            style: TextStyle(color: g.inkMuted),
          ),
        );
      }
      return SkeletonShimmer.card(height: 140);
    }
    final activities = allActivities
        .where(
          (a) =>
              a.status == TodayActivityStatus.done ||
              !widget.excludedTaskIds.contains(a.linkedTaskId),
        )
        .toList();
    final doneActivities = activities
        .where((a) => a.status == TodayActivityStatus.done)
        .toList();
    final pendingActivities = activities
        .where((a) => a.status != TodayActivityStatus.done)
        .toList();
    final doneCount = doneActivities.length;
    final totalCount = allActivities.length;

    // Sort so that any currently active running activity is prioritised at the top
    final sortedPending = <TodayActivityItem>[...pendingActivities]
      ..sort((a, b) {
        if (a.status == TodayActivityStatus.inProgress &&
            b.status != TodayActivityStatus.inProgress) {
          return -1;
        }
        if (b.status == TodayActivityStatus.inProgress &&
            a.status != TodayActivityStatus.inProgress) {
          return 1;
        }
        return 0;
      });
    final currentList = _showCompleted ? doneActivities : sortedPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── HEADING ROW: THINGS HUB + VIEW BOARD CTA (OUTSIDE CARD) ──────
        SizedBox(
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Things hub',
                  style: AscentTextStyles.homeTitle.copyWith(
                    color: g.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppTapArea(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/today');
                },
                borderRadius: AppGeometry.roundedr6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View board',
                        style: AscentTextStyles.homeSecondary
                            .copyWith(color: g.clay)
                            .merge(AppTypeRoles.typeRole8),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: g.clay,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        GlassSurface(
          key: const ValueKey('home_activity_card'),
          radius: 22,
          enableBlur: false,
          fillColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : null,
          customBorder: Theme.of(context).brightness == Brightness.light
              ? Border.all(color: g.edge.withValues(alpha: .45), width: 1)
              : null,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── ONE SEGMENTED CONTROL: TODAY · COMPLETED · PLANS ──────
              // Plans already contain their repeating routines, so there is no
              // separate Routines control. Counts appear only when above zero.
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: g.fill,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: g.edge),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _HubTabPill(
                            label: 'Today',
                            count: pendingActivities.length,
                            isSelected: !_showCompleted && !_showPlans,
                            activeColor: g.clay,
                            activeTextColor: Colors.white,
                            inactiveTextColor: g.inkSecondary,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _showPlans = false;
                                _showCompleted = false;
                                _showAll = false;
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          _HubTabPill(
                            label: 'Completed',
                            count: doneCount,
                            isSelected: _showCompleted && !_showPlans,
                            activeColor: g.clay,
                            activeTextColor: Colors.white,
                            inactiveTextColor: g.inkSecondary,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _showPlans = false;
                                _showCompleted = true;
                                _showAll = false;
                              });
                            },
                          ),
                          const SizedBox(width: 4),
                          _HubTabPill(
                            label: 'Plans',
                            count: planCount,
                            isSelected: _showPlans,
                            activeColor: g.clay,
                            activeTextColor: Colors.white,
                            inactiveTextColor: g.inkSecondary,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _showPlans = true;
                                _showAll = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── ACTIVITIES LIST (CAPPED PREVIEW) ──────────────────────────
              if (_showPlans)
                const HomePlansPreview()
              else if (currentList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s14,
                      vertical: AppSpace.s12,
                    ),
                    decoration: BoxDecoration(
                      color: g.fill,
                      borderRadius: AppGeometry.roundedr16,
                      border: Border.all(color: g.edge),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _showCompleted
                              ? Icons.task_alt_rounded
                              : (totalCount > 0
                                    ? Icons.task_alt_rounded
                                    : Icons.wb_sunny_outlined),
                          size: 20,
                          color: g.clay,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _showCompleted
                                ? 'No completed activities yet today.'
                                : (totalCount > 0
                                      ? 'All caught up! All $doneCount activities finished.'
                                      : 'No activities scheduled for today.'),
                            style: AscentTextStyles.homeSecondary.copyWith(
                              color: g.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Render either capped items (max 4) or all if expanded
                for (final act
                    in (_showAll
                        ? currentList
                        : currentList.take(widget.previewLimit.clamp(1, 4))))
                  ActivityRowItem(activity: act),

                // Show more / Show less toggle when count exceeds 4
                if (currentList.length > 4)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppTapArea(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _showAll = !_showAll);
                          },
                          borderRadius: AppGeometry.roundedr8,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s6,
                              vertical: AppSpace.s4,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showAll
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: g.clay,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showAll
                                      ? 'Show less'
                                      : 'Show ${currentList.length - 4} more',
                                  style: AscentTextStyles.homeSecondary
                                      .copyWith(color: g.clay)
                                      .merge(AppTypeRoles.typeRole8),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AppTapArea(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/today');
                          },
                          borderRadius: AppGeometry.roundedr8,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s6,
                              vertical: AppSpace.s4,
                            ),
                            child: Text(
                              'Open Board ›',
                              style: AscentTextStyles.homeSecondary
                                  .copyWith(color: g.inkMuted)
                                  .merge(AppTypeRoles.typeRole15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              // Quick entry defaults to a To-do today, without a reminder.
              if (!_showPlans) const ActivityComposer(),
            ],
          ),
        ),
      ],
    );
  }
}

class _HubTabPill extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color activeColor;
  final Color activeTextColor;
  final Color inactiveTextColor;
  final VoidCallback onTap;

  const _HubTabPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.activeColor,
    required this.activeTextColor,
    required this.inactiveTextColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppTapArea(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AscentTextStyles.homeSecondary.copyWith(
                color: isSelected ? activeTextColor : inactiveTextColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : inactiveTextColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? activeTextColor : inactiveTextColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
