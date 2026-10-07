import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_card.dart';
import '../../../shared/widgets/skeleton_shimmer.dart';
import '../../today/add_activity_sheet.dart';
import 'activity_row_item.dart';

class ActivityHubCard extends ConsumerStatefulWidget {
  const ActivityHubCard({super.key});

  @override
  ConsumerState<ActivityHubCard> createState() => _ActivityHubCardState();
}

class _ActivityHubCardState extends ConsumerState<ActivityHubCard> {
  int _selectedTabIndex = 0; // 0: Up Next, 1: Completed, 2: All

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(todayActivitiesProvider);
    final trackingState = ref.watch(timeTrackingProvider);
    final trackingNotifier = ref.read(timeTrackingProvider.notifier);

    return activitiesAsync.when(
      loading: () => SkeletonShimmer.card(height: 180),
      error: (err, _) => AscentCard(child: Text('Error loading activities: $err')),
      data: (activities) {
        final doneActivities = activities.where((a) => a.status == TodayActivityStatus.done).toList();
        final pendingActivities = activities.where((a) => a.status != TodayActivityStatus.done).toList();
        final doneCount = doneActivities.length;

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

        return AscentCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Activity Hub',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.bgBase,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.divider, width: 0.8),
                        ),
                        child: Text(
                          '$doneCount/${activities.length} Done',
                          style: GoogleFonts.jetBrainsMono(
                            color: context.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/today');
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Text(
                        'View board ›',
                        style: TextStyle(
                          color: context.accentSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Active Focus Banner (if active session)
              if (hasActiveSession) ...[
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/focus');
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: trackingState.isRunning
                          ? context.accentSecondary.withValues(alpha: 0.08)
                          : context.bgBase,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: trackingState.isRunning
                            ? context.accentSecondary.withValues(alpha: 0.3)
                            : context.divider,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: trackingState.isRunning
                                          ? context.accentSecondary
                                          : Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    trackingState.isRunning ? 'FOCUSING NOW' : 'FOCUS PAUSED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: trackingState.isRunning
                                          ? context.accentSecondary
                                          : Colors.orange,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activeSession.label,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          trackingState.formattedTime,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: trackingState.isRunning
                                ? context.accentSecondary
                                : context.textMuted,
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
                            size: 26,
                            color: context.accentSecondary,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (trackingState.isRunning) {
                              trackingNotifier.pauseSession();
                            } else {
                              trackingNotifier.resumeSession();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Filter Tabs with Count Badges (Up Next / Completed / All)
              Row(
                children: [
                  _ActivityTabChip(
                    label: 'Up Next',
                    count: pendingActivities.length,
                    isSelected: _selectedTabIndex == 0,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTabIndex = 0);
                    },
                  ),
                  const SizedBox(width: 6),
                  _ActivityTabChip(
                    label: 'Completed',
                    count: doneCount,
                    isSelected: _selectedTabIndex == 1,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTabIndex = 1);
                    },
                  ),
                  const SizedBox(width: 6),
                  _ActivityTabChip(
                    label: 'All',
                    count: activities.length,
                    isSelected: _selectedTabIndex == 2,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTabIndex = 2);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Filtered activities list
              if (filteredList.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.checklist_rounded, size: 24, color: context.textMuted),
                        const SizedBox(height: 6),
                        Text(
                          'No activities in this view',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap "+ Add activity" below to queue your next task.',
                          style: TextStyle(fontSize: 11, color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...filteredList.map((act) => ActivityRowItem(activity: act)),

              Divider(height: 1, color: context.divider, thickness: 0.8),

              // Add activity button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  AddActivitySheet.show(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: context.accentSecondary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.add, size: 13, color: context.accentSecondary),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Add activity',
                        style: TextStyle(
                          color: context.accentSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Swipe left to delete',
                        style: TextStyle(fontSize: 10, color: context.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityTabChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityTabChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? context.accentSecondary.withValues(alpha: 0.12)
              : context.bgBase,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.accentSecondary.withValues(alpha: 0.35)
                : context.divider,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? context.accentSecondary : context.textMuted,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? context.accentSecondary : context.divider,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : context.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
