import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../home/widgets/activity_row_item.dart';
import '../../money/add_transaction_sheet.dart';
import '../models/things_intelligence.dart';

/// Intelligent card enclosure in Things Hub that pairs the canonical [ActivityRowItem]
/// with dynamic domain synthesis: 3 auto-generated micro-steps, smart category pips,
/// and contextual single-tap execution chips.
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: g.fill.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isExpanded
              ? enrichment.categoryColor.withValues(alpha: 0.4)
              : g.line.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. The Canonical Activity Item
          ActivityRowItem(
            key: ValueKey(activity.id),
            activity: activity,
            compact: widget.compact,
          ),

          // 2. Intelligent Sub-Bar (Category Badge + Unpack Trigger)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Smart Category Pill
                Container(
                  constraints: const BoxConstraints(maxWidth: 240),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: enrichment.categoryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: enrichment.categoryColor.withValues(alpha: 0.25),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        enrichment.categoryIcon,
                        size: 10,
                        color: enrichment.categoryColor,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          enrichment.categoryLabel,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: enrichment.categoryColor,
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
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.auto_awesome_rounded,
                          size: 12,
                          color: enrichment.categoryColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _isExpanded ? 'Hide' : 'Blueprint',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: enrichment.categoryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Fast Action Chips
                if (enrichment.actionChips.any((c) => c.type == ThingsActionType.moneyLog))
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      AddTransactionSheet.show(context);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.payments_outlined, size: 12, color: enrichment.categoryColor),
                          const SizedBox(width: 3),
                          Text(
                            'Log Money',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: enrichment.categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (enrichment.actionChips.any((c) => c.type == ThingsActionType.focusTimer) &&
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
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 12, color: enrichment.categoryColor),
                          const SizedBox(width: 3),
                          Text(
                            'Focus',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: enrichment.categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Expanded Blueprint Panel
          if (_isExpanded)
            Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: enrichment.categoryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: enrichment.categoryColor.withValues(alpha: 0.15),
                  width: 0.6,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < enrichment.microSteps.length; i++) ...[
                    if (i > 0) const SizedBox(height: 5),
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
                            size: 14,
                            color: _checkedSteps.contains(i)
                                ? enrichment.categoryColor
                                : g.inkMuted,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              enrichment.microSteps[i],
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.25,
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
                ],
              ),
            ),
        ],
      ),
    );
  }
}
