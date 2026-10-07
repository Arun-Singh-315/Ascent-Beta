import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/skeleton_shimmer.dart';
import '../../today/add_activity_sheet.dart';
import 'activity_row_item.dart';

/// Level 1 · Primary: Today
/// Redesigned according to Ascent Home Redesign spec:
/// - No heavy box container. Clean typography and hairlines carry structure.
/// - Single-line progress bar with done count and streak flame.
/// - Three text tabs with active underline indicator.
/// - 44dp hit-area task items.
/// - Inline "Add activity" action row.
class ActivityHubCard extends ConsumerStatefulWidget {
  const ActivityHubCard({super.key});

  @override
  ConsumerState<ActivityHubCard> createState() => _ActivityHubCardState();
}

class _ActivityHubCardState extends ConsumerState<ActivityHubCard> {
  int _selectedTabIndex = 0; // 0: Up Next, 1: Completed, 2: All
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final activitiesAsync = ref.watch(todayActivitiesProvider);
    final trackingState = ref.watch(timeTrackingProvider);
    final streak = ref.watch(currentStreakStreamProvider).value ?? 0;

    return activitiesAsync.when(
      loading: () => SkeletonShimmer.card(height: 140),
      error: (err, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Error loading activities: $err', style: TextStyle(color: g.inkMuted)),
      ),
      data: (activities) {
        final doneActivities = activities.where((a) => a.status == TodayActivityStatus.done).toList();
        final pendingActivities = activities.where((a) => a.status != TodayActivityStatus.done).toList();
        final doneCount = doneActivities.length;
        final totalCount = activities.length;
        final progressFraction = totalCount > 0 ? (doneCount / totalCount).clamp(0.0, 1.0) : 0.0;

        List<TodayActivityItem> filteredList;
        if (_selectedTabIndex == 0) {
          filteredList = pendingActivities;
        } else if (_selectedTabIndex == 1) {
          filteredList = doneActivities;
        } else {
          filteredList = activities;
        }

        final activeSession = trackingState.activeSession;
        final hasActiveSession = activeSession != null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADING ROW: TODAY + VIEW BOARD CTA ───────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Today',
                  style: AscentTextStyles.homeTitle.copyWith(
                    color: g.ink,
                  ),
                ),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/today');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View board',
                          style: AscentTextStyles.homeSecondary.copyWith(
                            color: g.clay,
                            fontWeight: FontWeight.w600,
                          ),
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

            const SizedBox(height: 10),

            // ── PROGRESS & STREAK ROW (SINGLE CLEAN LINE) ─────────────────
            Row(
              children: [
                // Progress Bar
                Expanded(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: g.track,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: progressFraction,
                      child: Container(
                        decoration: BoxDecoration(
                          color: g.clay,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$doneCount of $totalCount done',
                  style: AscentTextStyles.homeSecondary.copyWith(
                    color: g.inkSecondary,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(width: 8),
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
                      style: AscentTextStyles.homeSecondary.copyWith(
                        color: g.inkMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ── ACTIVE FOCUS BANNER (IF ACTIVE SESSION) ────────────────────
            if (hasActiveSession) ...[
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/focus');
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: g.claySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: g.clay.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: trackingState.isRunning ? g.clay : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activeSession.label,
                          style: AscentTextStyles.homeHeadline.copyWith(
                            fontSize: 14,
                            color: g.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        trackingState.formattedTime,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: g.clay,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          trackingState.isRunning
                              ? Icons.pause_circle_outline_rounded
                              : Icons.play_circle_outline_rounded,
                          size: 24,
                          color: g.clay,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          if (trackingState.isRunning) {
                            ref.read(timeTrackingProvider.notifier).pauseSession();
                          } else {
                            ref.read(timeTrackingProvider.notifier).resumeSession();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── TABS: UP NEXT / COMPLETED / ALL ───────────────────────────
            Container(
              height: 40,
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: g.line, width: 1.0)),
              ),
              child: Row(
                children: [
                  _HomeTabItem(
                    label: 'Up next',
                    count: pendingActivities.length,
                    isSelected: _selectedTabIndex == 0,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedTabIndex = 0;
                        _showAll = false;
                      });
                    },
                  ),
                  const SizedBox(width: 24),
                  _HomeTabItem(
                    label: 'Completed',
                    count: doneCount,
                    isSelected: _selectedTabIndex == 1,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedTabIndex = 1;
                        _showAll = false;
                      });
                    },
                  ),
                  const SizedBox(width: 24),
                  _HomeTabItem(
                    label: 'All',
                    count: totalCount,
                    isSelected: _selectedTabIndex == 2,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedTabIndex = 2;
                        _showAll = false;
                      });
                    },
                  ),
                ],
              ),
            ),

            // ── ACTIVITIES LIST (CAPPED PREVIEW) ──────────────────────────
            if (filteredList.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No activities in this view',
                    style: AscentTextStyles.homeSecondary.copyWith(
                      color: g.inkMuted,
                    ),
                  ),
                ),
              )
            else ...[
              // Render either capped items (max 4) or all if expanded
              for (final act in (_showAll ? filteredList : filteredList.take(4)))
                ActivityRowItem(activity: act),

              // Show more / Show less toggle when count exceeds 4
              if (filteredList.length > 4)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showAll = !_showAll);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showAll ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                size: 18,
                                color: g.clay,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showAll ? 'Show less' : 'Show ${filteredList.length - 4} more',
                                style: AscentTextStyles.homeSecondary.copyWith(
                                  color: g.clay,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          context.push('/today');
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Text(
                            'Open Board ›',
                            style: AscentTextStyles.homeSecondary.copyWith(
                              color: g.inkMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            // ── ADD ACTIVITY ROW ──────────────────────────────────────────
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                AddActivitySheet.show(context);
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: g.claySoft,
                          ),
                          child: Icon(Icons.add_rounded, size: 16, color: g.clay),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add activity',
                      style: AscentTextStyles.homeHeadline.copyWith(
                        color: g.clay,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomeTabItem extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _HomeTabItem({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return InkWell(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AscentTextStyles.homeSecondary.copyWith(
                    color: isSelected ? g.ink : g.inkMuted,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: AscentTextStyles.homeCaption.copyWith(
                    color: g.inkMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Container(
              height: 2,
              width: 40,
              decoration: BoxDecoration(
                color: g.clay,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}
