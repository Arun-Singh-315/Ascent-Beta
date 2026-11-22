import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_star_button.dart';
import 'package:drift/drift.dart' show Value;
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../home/widgets/activity_actions.dart';
import '../../home/widgets/activity_detail_sheet.dart';

final _time = DateFormat('h:mm a');

/// A light Things list row (CLAUDE.md §5.2): circle · title · one meta line
/// · star · play for timed items · more.
///
/// Stateless and cheap to build, so lists of thousands scroll smoothly.
/// Every action reuses the shared ones: complete with Undo, the action menu
/// (reschedule, edit, delete) and the details sheet. Swipe right completes,
/// swipe left opens the action menu.
class ThingsRow extends ConsumerWidget {
  const ThingsRow({super.key, required this.item});
  final TodayActivityItem item;

  bool get _timed =>
      item.kind != ActivityKind.todo || (item.targetMinutes ?? 0) > 0;

  String _meta() {
    final done = item.status == TodayActivityStatus.done;
    final running = item.status == TodayActivityStatus.inProgress;
    final paused = item.status == TodayActivityStatus.paused;
    final at =
        item.scheduledTime ??
        (item.sourceType == 'medicine' ? item.plannedDate : null);
    return [
      if (done) 'Completed',
      if (running) 'Running',
      if (paused) 'Paused',
      if (item.sourceType == 'medicine') 'Medicine',
      if (at != null) _time.format(at).toLowerCase(),
      if ((item.targetMinutes ?? 0) > 0) '${item.targetMinutes} min',
    ].join(' · ');
  }

  Future<void> _toggleTimer(BuildContext context, WidgetRef ref) async {
    HapticFeedback.selectionClick();
    try {
      final tracker = ref.read(timeTrackingProvider.notifier);
      if (item.status == TodayActivityStatus.inProgress) {
        await tracker.pauseSession();
      } else {
        await tracker.switchToTask(
          title: item.title,
          taskId: item.linkedTaskId,
          sourceType: item.sourceType,
          autoStart: true,
        );
      }
    } catch (_) {
      if (context.mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not update this timer. Please retry.',
        );
      }
    }
  }

  Future<void> _setStar(BuildContext context, WidgetRef ref, bool on) async {
    final id = item.linkedTaskId;
    if (id == null) return;
    final saved = await ref
        .read(taskDaoProvider)
        .updateTask(
          TaskTableCompanion(
            id: Value(id),
            priority: Value(on ? 'high' : 'low'),
            updatedAt: Value(DateTime.now()),
          ),
        );
    if (!context.mounted) return;
    if (saved) {
      AscentSnackBar.show(
        context,
        message: on
            ? 'Marked important · Pinned to top of Today'
            : 'Removed from important',
      );
    } else {
      AscentSnackBar.error(context, message: 'Could not save. Try again.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final done = item.status == TodayActivityStatus.done;
    final locked = item.isLockedUntilScheduled;
    final running = item.status == TodayActivityStatus.inProgress;
    final starred = item.priority == 'high';
    final meta = _meta();

    final circle = Semantics(
      button: true,
      label: done ? 'Completed' : 'Mark complete',
      excludeSemantics: true,
      child: InkResponse(
        key: ValueKey('activity_action_${item.id}'),
        radius: 22,
        onTap: done || locked || item.linkedTaskId == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                completeActivityWithUndo(context, ref, item);
              },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: locked && !done
                ? Icon(Icons.schedule_rounded, size: 20, color: g.inkMuted)
                : Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? g.actionInk : null,
                      border: Border.all(
                        color: done ? g.actionInk : g.inkMuted,
                        width: 1.5,
                      ),
                    ),
                    child: done
                        ? Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: g.primaryButtonFg,
                          )
                        : null,
                  ),
          ),
        ),
      ),
    );

    final row = Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('things_row_${item.id}'),
        onTap: () => showActivityDetailDialog(context, ref, item),
        onLongPress: () => showActivityActions(context, ref, item),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Row(
            children: [
              circle,
              const SizedBox(width: AppSpace.s4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AscentTextStyles.body.copyWith(
                          color: done ? g.inkSecondary : g.ink,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: g.inkSecondary,
                        ),
                      ),
                      if (meta.isNotEmpty)
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AscentTextStyles.caption.copyWith(
                            color: running ? g.actionInk : g.inkMuted,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!done && item.linkedTaskId != null)
                AscentStarButton(
                  key: ValueKey('activity_priority_${item.id}'),
                  selected: starred,
                  onChanged: (v) => _setStar(context, ref, v),
                )
              else if (starred)
                Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: g.amber,
                  semanticLabel: 'Important',
                ),
              if (_timed && !done)
                IconButton(
                  tooltip: running ? 'Pause' : 'Start',
                  icon: Icon(
                    running
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    color: g.actionInk,
                  ),
                  onPressed: () => _toggleTimer(context, ref),
                ),
              IconButton(
                tooltip: 'More',
                icon: Icon(Icons.more_horiz_rounded, color: g.inkMuted),
                onPressed: () => showActivityActions(context, ref, item),
              ),
            ],
          ),
        ),
      ),
    );

    if (done) return row;
    return Dismissible(
      key: ValueKey('activity_dismiss_${item.id}'),
      direction: item.linkedTaskId == null || locked
          ? DismissDirection.endToStart
          : DismissDirection.horizontal,
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.35,
        DismissDirection.endToStart: 0.35,
      },
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          HapticFeedback.lightImpact();
          await completeActivityWithUndo(context, ref, item);
        } else {
          await showActivityActions(context, ref, item);
        }
        return false; // The row updates from the data stream.
      },
      background: _SwipeHint(
        alignment: Alignment.centerLeft,
        color: g.successInk,
        icon: Icons.check_circle_outline_rounded,
        label: 'Complete',
      ),
      secondaryBackground: _SwipeHint(
        alignment: Alignment.centerRight,
        color: g.actionInk,
        icon: Icons.more_horiz_rounded,
        label: 'More',
      ),
      child: row,
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });
  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    color: color.withValues(alpha: .12),
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpace.s6),
        Text(label, style: AscentTextStyles.caption.copyWith(color: color)),
      ],
    ),
  );
}
