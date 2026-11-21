import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/theme/app_colors.dart';
import 'package:ascent/core/theme/app_tokens.dart';
import 'package:ascent/features/thought_wall/board/board_logic.dart';
import 'package:ascent/features/thought_wall/utils/thought_checklist_helper.dart';
import 'package:ascent/shared/widgets/thought_excerpt.dart';
import 'package:ascent/shared/widgets/undo_snackbar.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeThoughtBubble extends ConsumerWidget {
  const HomeThoughtBubble({
    super.key,
    required this.thought,
    required this.locked,
    required this.timeAgo,
    required this.onTap,
    required this.onAction,
    this.maxLines = 4,
  });

  final Thought thought;
  final bool locked;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final int maxLines;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isHighPriority = isHighPriorityContent(thought.content);
    final display = locked
        ? 'Private thought'
        : ThoughtExcerpt.displayContent(thought.content);

    final heroBg = isHighPriority
        ? c.accent.withValues(alpha: dark ? 0.12 : 0.05)
        : (dark ? Colors.transparent : c.surface);
    final heroBorderColor = isHighPriority
        ? c.accent.withValues(alpha: 0.6)
        : (dark
              ? c.border.withValues(alpha: 0.95)
              : c.border.withValues(alpha: 0.85));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.bubble),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        onLongPress: onAction,
        child: Container(
          decoration: BoxDecoration(
            color: heroBg,
            borderRadius: BorderRadius.circular(AppRadius.bubble),
            border: AppBorder.all(
              heroBorderColor,
              width: isHighPriority ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (isHighPriority)
                BoxShadow(
                  color: c.accent.withValues(alpha: dark ? 0.15 : 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                )
              else if (!dark)
                ...AppElevation.soft(c.border, dark: dark),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: category pill + timestamp + full thought star + full thought done + more menu
              Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (locked) ...[
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: c.accentTint,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.lock_rounded,
                                      size: 12,
                                      color: c.accent,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PRIVATE COMMITMENT',
                                      style: AscentTextStyles.homeCaption
                                          .copyWith(
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                            color: c.accent,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            timeAgo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.homeCaption.copyWith(
                              color: c.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    key: ValueKey('thought_${thought.id}_star_thought_btn'),
                    tooltip: isHighPriority
                        ? 'Unstar thought'
                        : 'Star thought (important)',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      isHighPriority
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 20,
                      color: isHighPriority ? c.accent : c.textSecondary,
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final newContent = toggleHighPriorityContent(
                        thought.content,
                      );
                      await ref
                          .read(thoughtDaoProvider)
                          .setContent(thought.id, newContent);
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    key: ValueKey('thought_${thought.id}_full_done_btn'),
                    tooltip: thought.isCompleted
                        ? 'Mark uncompleted'
                        : 'Mark thought done',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      thought.isCompleted
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 20,
                      color: thought.isCompleted ? c.accent : c.textSecondary,
                    ),
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final newStatus = !thought.isCompleted;
                      await ref
                          .read(thoughtDaoProvider)
                          .setCompleted(thought.id, newStatus);
                      if (ThoughtChecklistHelper.hasChecklistItems(
                        thought.content,
                      )) {
                        final newContent = ThoughtChecklistHelper.setAllDone(
                          thought.content,
                          newStatus,
                        );
                        await ref
                            .read(thoughtDaoProvider)
                            .setContent(thought.id, newContent);
                      }
                    },
                  ),
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: 'Thought actions',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: c.textSecondary,
                    ),
                    onPressed: onAction,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (!locked &&
                  ThoughtChecklistHelper.hasChecklistItems(
                    thought.content,
                  )) ...[
                _buildChecklist(context, ref, c),
              ] else ...[
                ThoughtExcerpt(
                  content: display,
                  style: AscentTextStyles.bodyMedium.copyWith(
                    height: 1.45,
                    fontStyle: locked ? FontStyle.italic : FontStyle.normal,
                    color: locked ? c.textSecondary : c.textPrimary,
                    fontWeight: FontWeight.w500,
                    decoration: thought.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: maxLines,
                  thoughtId: thought.id,
                  textKey: const ValueKey('home_latest_thought_text'),
                  toggleKey: const ValueKey('home_thought_expand_toggle'),
                  arrowColor: c.accent,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklist(BuildContext context, WidgetRef ref, dynamic c) {
    final items = ThoughtChecklistHelper.parseItems(thought.content);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: 3,
                horizontal: item.isHighlighted ? 6 : 0,
              ),
              decoration: item.isHighlighted
                  ? BoxDecoration(
                      color: c.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    )
                  : null,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    key: ValueKey('thought_${thought.id}_check_${item.index}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final newText = ThoughtChecklistHelper.toggleItemDone(
                        thought.content,
                        item.index,
                      );
                      await ref
                          .read(thoughtDaoProvider)
                          .setContent(thought.id, newText);
                      final updatedItems = ThoughtChecklistHelper.parseItems(
                        newText,
                      );
                      final allDone = ThoughtChecklistHelper.areAllDone(
                        updatedItems,
                      );
                      if (allDone != thought.isCompleted) {
                        await ref
                            .read(thoughtDaoProvider)
                            .setCompleted(thought.id, allDone);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: 8,
                        top: 2,
                        bottom: 2,
                      ),
                      child: Icon(
                        item.isDone
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 18,
                        color: item.isDone ? c.accent : c.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.text,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        height: 1.35,
                        color: item.isDone
                            ? c.textSecondary
                            : (item.isHighlighted ? c.accent : c.textPrimary),
                        decoration: item.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        fontWeight: item.isHighlighted
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    key: ValueKey('thought_${thought.id}_star_${item.index}'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      final newText =
                          ThoughtChecklistHelper.toggleItemHighlight(
                            thought.content,
                            item.index,
                          );
                      await ref
                          .read(thoughtDaoProvider)
                          .setContent(thought.id, newText);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 8,
                        top: 2,
                        bottom: 2,
                      ),
                      child: Icon(
                        item.isHighlighted
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 18,
                        color: item.isHighlighted
                            ? c.accent
                            : c.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('thought_${thought.id}_convert_to_activities'),
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                HapticFeedback.mediumImpact();
                final now = DateTime.now();
                final isFullHigh = isHighPriorityContent(thought.content);
                final created = <int>[];
                for (final it in items) {
                  final isHigh = it.isHighlighted || isFullHigh;
                  created.add(
                    await ref
                        .read(taskDaoProvider)
                        .insertTask(
                          TaskTableCompanion.insert(
                            title: it.text,
                            priority: drift.Value(isHigh ? 'high' : 'medium'),
                            plannedDate: drift.Value(now),
                            actualCompletedDate: drift.Value(
                              it.isDone ? now : null,
                            ),
                          ),
                        ),
                  );
                }
                if (context.mounted) {
                  final dao = ref.read(taskDaoProvider);
                  showUndoSnackbar(
                    context,
                    message: created.length == 1
                        ? '1 item added to today'
                        : '${created.length} items added to today',
                    onUndo: () async {
                      for (final id in created) {
                        await dao.deleteTask(id);
                      }
                    },
                  );
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.accent.withValues(alpha: 0.25)),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.playlist_add_check_rounded,
                        size: 15,
                        color: c.accent,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Convert to activities',
                        style: AscentTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
