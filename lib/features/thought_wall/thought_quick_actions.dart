import '../../shared/widgets/glass_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../home/widgets/home_schedule_sheet.dart';
import 'thought_action_ui.dart';
import 'thought_category_action.dart';

/// Permanent, compact actions shared by Home and Thought Wall cards.
class ThoughtQuickActions extends ConsumerStatefulWidget {
  const ThoughtQuickActions({
    super.key,
    required this.thought,
    required this.db,
    this.onMoveToCategory,
    this.onActionCompleted,
  });
  final Future<void> Function()? onMoveToCategory;
  final VoidCallback? onActionCompleted;
  final Thought thought;
  final AppDatabase db;

  @override
  ConsumerState<ThoughtQuickActions> createState() =>
      _ThoughtQuickActionsState();
}

class _ThoughtQuickActionsState extends ConsumerState<ThoughtQuickActions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        widget.onActionCompleted?.call();
      }
    }
  }

  Future<void> _category() async {
    if (widget.onMoveToCategory != null) {
      await widget.onMoveToCategory!();
    } else {
      await moveThoughtsToCategory(context, ref, [widget.thought]);
    }
  }

  Future<void> _act(String action) async {
    await applyThoughtAction(context, widget.db, [widget.thought], action);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final action in <(String, String, Future<void> Function())>[
          ('Category', 'Move to category', _category),
          if (widget.thought.mood != 'promise')
            ('Plan', 'Plan', () => showHomeSchedule(context, widget.thought)),
          if (widget.thought.mood != 'promise')
            ('Todo', 'Create Todo', () => _act('todo')),
          if (widget.thought.mood != 'promise')
            ('Reminder', 'Set reminder', () => _act('reminder')),
        ])
          GlassChip(
            label: action.$1,
            tooltip: action.$2,
            onTap: _busy ? null : () => _run(action.$3),
          ),
      ],
    ),
  );
}
