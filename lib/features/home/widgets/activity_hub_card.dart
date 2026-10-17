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

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final activitiesAsync = ref.watch(todayActivitiesProvider);
    final streak = ref.watch(currentStreakStreamProvider).value ?? 0;

    return activitiesAsync.when(
      loading: () => SkeletonShimmer.card(height: 140),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Text(
          'Error loading activities: $err',
          style: TextStyle(color: g.inkMuted),
        ),
      ),
      data: (allActivities) {
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
        final progressFraction = totalCount > 0
            ? (doneCount / totalCount).clamp(0.0, 1.0)
            : 0.0;

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
        final filteredList = sortedPending;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADING ROW: THINGS HUB + VIEW BOARD CTA (OUTSIDE CARD) ──────
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    'Things hub',
                    style: AscentTextStyles.homeTitle.copyWith(
                      color: g.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: g.inkMuted,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Plans & Options',
                        onSelected: (val) {
                          if (val == 'plans') {
                            context.push('/plans');
                          } else if (val == 'board') {
                            context.push('/today');
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'plans',
                            child: Row(
                              children: [
                                Icon(Icons.event_repeat_rounded, size: 18),
                                SizedBox(width: 8),
                                Text('Routines & Plans'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'board',
                            child: Row(
                              children: [
                                Icon(Icons.dashboard_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Open Board'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
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
                  // Keep the progress track full-width, with readable counts below.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      minHeight: 4,
                      color: g.clay,
                      backgroundColor: g.track,
                      semanticsLabel: 'Things hub activity progress',
                    ),
                  ),
                  const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      '$doneCount of $totalCount done',
                      style: AscentTextStyles.homeSecondary
                          .copyWith(color: g.inkSecondary)
                          .merge(AppTypeRoles.typeRole40),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 15,
                          color: g.inkMuted,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$streak',
                          style: AscentTextStyles.homeSecondary
                              .copyWith(color: g.inkMuted)
                              .merge(AppTypeRoles.typeRole63),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── ACTIVITIES LIST (CAPPED PREVIEW) ──────────────────────────
              if (filteredList.isEmpty)
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
                          totalCount > 0
                              ? Icons.task_alt_rounded
                              : Icons.wb_sunny_outlined,
                          size: 20,
                          color: g.clay,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            totalCount > 0
                                ? 'All caught up! All $doneCount activities finished.'
                                : 'No activities scheduled for today.',
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
                        ? filteredList
                        : filteredList.take(widget.previewLimit.clamp(1, 4))))
                  ActivityRowItem(activity: act),

                // Show more / Show less toggle when count exceeds 4
                if (filteredList.length > 4)
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
                                      : 'Show ${filteredList.length - 4} more',
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
              const ActivityComposer(),
            ],
          ),
        ),
      ],
    );
      },
    );
  }
}
