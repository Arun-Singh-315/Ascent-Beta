import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../home/widgets/activity_row_item.dart';
import '../../money/add_transaction_sheet.dart';
import '../models/things_intelligence.dart';

/// Ground-border style interactive story item for Dayboard.
/// Sits directly on the background canvas with transparent fill and
/// category-tinted border contour (zero nested card boxes).
/// Pairs full-width Apple-style typography with dynamic domain synthesis,
/// interactive micro-steps blueprint, and contextual fast-action triggers.
class ThingsInteractiveCard extends ConsumerStatefulWidget {
  const ThingsInteractiveCard({
    super.key,
    required this.activity,
    this.compact = true,
  });

  final TodayActivityItem activity;
  final bool compact;

  @override
  ConsumerState<ThingsInteractiveCard> createState() =>
      _ThingsInteractiveCardState();
}

class _ThingsInteractiveCardState extends ConsumerState<ThingsInteractiveCard> {
  bool _isExpanded = false;
  final Set<int> _checkedSteps = {};

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final g = context.glass;
    final enrichment = ThingsEnrichmentEngine.analyze(activity);
    final isDone = activity.status == TodayActivityStatus.done;

    final borderColor = isDone
        ? g.line.withValues(alpha: 0.3)
        : (_isExpanded
              ? enrichment.categoryColor.withValues(alpha: 0.60)
              : enrichment.categoryColor.withValues(alpha: 0.25));

    final surfaceColor = isDone
        ? (g.isDark ? g.fill.withValues(alpha: 0.04) : Colors.transparent)
        : (g.isDark
              ? g.fill.withValues(alpha: _isExpanded ? 0.12 : 0.06)
              : g.fill.withValues(alpha: _isExpanded ? 0.08 : 0.03));

    return GestureDetector(
      onLongPress: () => showActivityActions(context, ref, activity),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: _isExpanded ? 1.2 : 0.9,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Canonical Activity Row in Ground Style (NO NESTED CARDS!)
            ActivityRowItem(
              key: ValueKey(activity.id),
              activity: activity,
              compact: widget.compact,
              ground: true,
            ),

            // 2. Intelligent Ground Sub-Bar (Category Badge + Blueprint Trigger + Fast Actions)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Smart Category 3D Matte Squircle Badge
                  Container(
                    constraints: const BoxConstraints(maxWidth: 240),
                    padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
                    decoration: BoxDecoration(
                      color: enrichment.categoryColor.withValues(
                        alpha: g.isDark ? 0.10 : 0.05,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: enrichment.categoryColor.withValues(
                          alpha: g.isDark ? 0.32 : 0.20,
                        ),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 3D Matte Squircle Icon Tile
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                enrichment.categoryColor.withValues(
                                  alpha: g.isDark ? 0.38 : 0.28,
                                ),
                                enrichment.categoryColor.withValues(
                                  alpha: g.isDark ? 0.18 : 0.10,
                                ),
                              ],
                            ),
                            border: Border.all(
                              color: enrichment.categoryColor.withValues(
                                alpha: g.isDark ? 0.50 : 0.38,
                              ),
                              width: 0.75,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: enrichment.categoryColor.withValues(
                                  alpha: g.isDark ? 0.25 : 0.12,
                                ),
                                blurRadius: 4,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              enrichment.categoryIcon,
                              size: 11,
                              color: enrichment.categoryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            enrichment.categoryLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: g.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unpack Blueprint Toggle
                  InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _isExpanded = !_isExpanded);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: enrichment.categoryColor.withValues(
                          alpha: _isExpanded ? 0.16 : 0.07,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: enrichment.categoryColor.withValues(
                            alpha: _isExpanded ? 0.38 : 0.20,
                          ),
                          width: 0.75,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.auto_awesome_rounded,
                            size: 13,
                            color: enrichment.categoryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isExpanded ? 'Hide' : 'Blueprint',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: g.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Fast Action: Log Money
                  if (enrichment.actionChips.any(
                    (c) => c.type == ThingsActionType.moneyLog,
                  ))
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        AddTransactionSheet.show(context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: enrichment.categoryColor.withValues(
                            alpha: 0.07,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: enrichment.categoryColor.withValues(
                              alpha: 0.20,
                            ),
                            width: 0.75,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 13,
                              color: enrichment.categoryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Log Money',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Fast Action: Focus Timer
                  if (enrichment.actionChips.any(
                        (c) => c.type == ThingsActionType.focusTimer,
                      ) &&
                      activity.status != TodayActivityStatus.done)
                    InkWell(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final tracker = ref.read(timeTrackingProvider.notifier);
                        await tracker.switchToTask(
                          title: activity.title,
                          taskId: activity.linkedTaskId,
                          sourceType: activity.sourceType,
                          autoStart: true,
                        );
                        if (context.mounted) {
                          context.push('/focus');
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: enrichment.categoryColor.withValues(
                            alpha: 0.07,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: enrichment.categoryColor.withValues(
                              alpha: 0.20,
                            ),
                            width: 0.75,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.play_circle_outline_rounded,
                              size: 13,
                              color: enrichment.categoryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Focus',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: g.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 3. Full-Width Expanded Blueprint Story Panel
            if (_isExpanded)
              Container(
                margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: enrichment.categoryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: enrichment.categoryColor.withValues(alpha: 0.20),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 14,
                          color: enrichment.categoryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Story Micro-Steps · ${_checkedSteps.length}/${enrichment.microSteps.length}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: g.ink,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < enrichment.microSteps.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            if (_checkedSteps.contains(i)) {
                              _checkedSteps.remove(i);
                            } else {
                              _checkedSteps.add(i);
                            }
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              _checkedSteps.contains(i)
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 16,
                              color: _checkedSteps.contains(i)
                                  ? enrichment.categoryColor
                                  : g.inkMuted,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                enrichment.microSteps[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.3,
                                  color: _checkedSteps.contains(i)
                                      ? g.inkMuted
                                      : g.ink,
                                  decoration: _checkedSteps.contains(i)
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (activity.notes != null &&
                        activity.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.sticky_note_2_outlined,
                            size: 13,
                            color: g.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              activity.notes!.trim(),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: g.inkMuted,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
