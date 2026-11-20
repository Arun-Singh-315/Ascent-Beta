import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../home/widgets/activity_composer.dart';
import 'board/board_logic.dart' show displayContent;
import 'thought_action_ui.dart';
import 'thought_actions.dart';

/// Turns one thought into a to-do through the Things quick add, pre-filled
/// with the thought's first line, so the user can add a day, time, duration
/// or reminder by typing ("tomorrow 7am 30m") before saving. The rest of the
/// thought becomes the to-do's notes and the two stay linked.
///
/// A thought that is already a to-do opens the conversion sheet instead,
/// which updates the existing to-do rather than creating a second one.
Future<bool> convertThoughtWithQuickAdd(
  BuildContext context,
  WidgetRef ref,
  Thought thought, {
  bool remind = false,
}) async {
  final db = ref.read(databaseProvider);
  final existing = await db.taskDao.getTaskLinkedToThought(thought.id);
  if (!context.mounted) return false;
  if (existing != null) {
    return applyThoughtAction(
      context,
      db,
      [thought],
      remind ? 'reminder' : 'todo',
    );
  }
  final text = displayContent(thought.content);
  final title = ThoughtActions.extractTitle(text);
  final notes = ThoughtActions.extractNotes(title, text);
  final saved = await showAscentSheet<bool>(
    context: context,
    builder: (sheet) =>
        _QuickAddFromThought(
          title: title,
          notes: notes,
          thoughtId: thought.id,
          remind: remind,
        ),
  );
  return saved ?? false;
}

class _QuickAddFromThought extends StatelessWidget {
  const _QuickAddFromThought({
    required this.title,
    required this.notes,
    required this.thoughtId,
    required this.remind,
  });

  final String title;
  final String? notes;
  final int thoughtId;
  final bool remind;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      key: const ValueKey('thought_quick_add'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AscentButton.ghost(
                label: 'Cancel',
                compact: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              Expanded(
                child: Text(
                  remind ? 'Remind me' : 'Make it a to-do',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.dialogTitle.copyWith(color: g.ink),
                ),
              ),
              // Balances Cancel so the title stays centred.
              const SizedBox(width: 72),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s4,
              AppSpace.s4,
              AppSpace.s4,
              AppSpace.s12,
            ),
            child: Text(
              remind
                  ? 'Say when by typing, e.g. “tomorrow 7am”.'
                  : 'Add a day, time or reminder by typing, e.g. “tomorrow 7am 30m”.',
              style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
            ),
          ),
          ActivityComposer(
            initialTitle: title,
            notes: notes,
            linkedThoughtId: thoughtId,
            remind: remind,
            onSaved: (_) => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}
