import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/locked_commitment_tile.dart';
import '../../home/widgets/home_schedule_sheet.dart';
import '../../promises/providers/promise_providers.dart';
import '../drop_thought_sheet.dart';
import '../thought_action_ui.dart';
import '../thought_wall_screen.dart' show shareThought;
import 'board_actions.dart';
import 'board_logic.dart';
import 'space_style.dart';

/// Everything you can do with one thought lives here, behind a tap, so the
/// wall itself stays calm. The sheet follows the live record: toggling Done or
/// Pin updates it immediately.
class ThoughtDetailSheet extends ConsumerWidget {
  const ThoughtDetailSheet({super.key, required this.initial});

  final Thought initial;

  static Future<void> show(BuildContext context, Thought thought) =>
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => ThoughtDetailSheet(initial: thought),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final active = ref.watch(allThoughtsStreamProvider).value ?? <Thought>[];
    final archived =
        ref.watch(archivedThoughtsStreamProvider).value ?? <Thought>[];
    final thought =
        [...active, ...archived].where((t) => t.id == initial.id).firstOrNull ??
        initial;
    final categories =
        ref.watch(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final locked = isPrivateLocked(
      thought,
      ref.watch(privatePromiseIdsProvider),
      ref.watch(unlockedPromiseIdsProvider),
    );
    final isPromise = thought.mood == 'promise';
    final inWall = thought.category == wallCategoryKey;
    final spaceName = inWall ? 'Wall' : (categories[thought.category] ?? 'Space');
    final style = spaceStyleFor(spaceName);
    final high = isHighPriorityContent(thought.content);
    final prompt = thought.promptQuestion?.trim();
    final showPrompt =
        !isPromise &&
        prompt != null &&
        prompt.isNotEmpty &&
        prompt.toLowerCase() != thought.content.trim().toLowerCase();
    final db = ref.read(databaseProvider);
    final dao = ref.read(thoughtDaoProvider);

    void close() {
      if (context.mounted) Navigator.of(context).pop();
    }

    Future<void> move() async {
      final pick = await showSpacePicker(context, current: thought.category);
      if (pick == null || !context.mounted) return;
      await moveThoughtsToSpace(context, ref, [thought], pick);
    }

    Future<void> convert(String action) async {
      final saved = await applyThoughtAction(context, db, [thought], action);
      if (saved) close();
    }

    Future<void> plan() async {
      await showHomeSchedule(context, thought);
      close();
    }

    Future<void> copy() async {
      HapticFeedback.lightImpact();
      await Clipboard.setData(ClipboardData(text: displayContent(thought.content)));
      if (context.mounted) {
        AscentSnackBar.success(context, message: 'Copied to clipboard');
      }
    }

    Future<void> togglePriority() async {
      HapticFeedback.lightImpact();
      try {
        await dao.setContent(
          thought.id,
          toggleHighPriorityContent(thought.content),
        );
      } catch (_) {
        if (context.mounted) {
          AscentSnackBar.error(context, message: 'Could not update. Try again.');
        }
      }
    }

    void openRoute(String location, {Object? extra}) {
      final router = GoRouter.of(context);
      close();
      router.push(location, extra: extra);
    }

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s20,
            AppSpace.s4,
            AppSpace.s20,
            AppSpace.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpace.s10,
                runSpacing: AppSpace.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoicePill(
                    key: const ValueKey('detail_space'),
                    icon: inWall
                        ? Icons.bubble_chart_rounded
                        : style.icon,
                    label: spaceName,
                    onTap: move,
                  ),
                  Text(
                    DateFormat('EEE, MMM d · h:mm a').format(thought.createdAt),
                    style: AscentTextStyles.labelMedium.copyWith(
                      color: g.inkMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.s16),
              if (locked)
                LockedCommitmentTile(
                  label: 'Private commitment',
                  onTap: () => unlockPrivateThought(ref, thought),
                )
              else
                SelectableText(
                  displayContent(thought.content).trim(),
                  style: AppTypography.thoughtContent(
                    color: g.ink,
                  ).copyWith(fontSize: 17),
                ),
              if (showPrompt && !locked) ...[
                const SizedBox(height: AppSpace.s12),
                Text(
                  prompt!,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s20),
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  ChoicePill(
                    key: const ValueKey('detail_done'),
                    icon: thought.isCompleted
                        ? Icons.replay_rounded
                        : Icons.check_circle_outline_rounded,
                    label: thought.isCompleted
                        ? 'Reopen'
                        : (inWall ? 'Done' : style.doneLabel),
                    onTap: () => toggleThoughtDone(context, ref, thought),
                  ),
                  ChoicePill(
                    key: const ValueKey('detail_pin'),
                    icon: thought.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    label: thought.isPinned ? 'Unpin' : 'Pin',
                    onTap: () => dao.togglePin(thought.id),
                  ),
                  if (!locked)
                    ChoicePill(
                      key: const ValueKey('detail_edit'),
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      onTap: () => DropThoughtSheet.show(
                        context,
                        existingThought: thought,
                      ),
                    ),
                  if (!locked && !isPromise) ...[
                    ChoicePill(
                      key: const ValueKey('detail_todo'),
                      icon: Icons.add_task_rounded,
                      label: 'Todo',
                      onTap: () => convert('todo'),
                    ),
                    ChoicePill(
                      key: const ValueKey('detail_reminder'),
                      icon: Icons.notifications_active_outlined,
                      label: 'Reminder',
                      onTap: () => convert('reminder'),
                    ),
                    ChoicePill(
                      key: const ValueKey('detail_plan'),
                      icon: Icons.event_outlined,
                      label: 'Plan',
                      onTap: plan,
                    ),
                  ],
                  if (isPromise) ...[
                    ChoicePill(
                      key: const ValueKey('detail_promises'),
                      icon: Icons.handshake_rounded,
                      label: 'Promises',
                      onTap: () => openRoute('/promises'),
                    ),
                    if (!locked)
                      ChoicePill(
                        key: const ValueKey('detail_challenge'),
                        icon: Icons.flag_outlined,
                        label: 'Track with Challenge',
                        onTap: () => openRoute('/momentum', extra: thought),
                      ),
                  ],
                  if (!locked) ...[
                    ChoicePill(
                      key: const ValueKey('detail_share'),
                      icon: Icons.share_outlined,
                      label: 'Share',
                      onTap: () => shareThought(thought),
                    ),
                    ChoicePill(
                      key: const ValueKey('detail_copy'),
                      icon: Icons.copy_rounded,
                      label: 'Copy',
                      onTap: copy,
                    ),
                    ChoicePill(
                      key: const ValueKey('detail_priority'),
                      icon: high ? Icons.flag_rounded : Icons.flag_outlined,
                      label: high ? 'Remove priority' : 'Priority',
                      color: high ? g.coral : null,
                      onTap: togglePriority,
                    ),
                  ],
                  ChoicePill(
                    key: const ValueKey('detail_archive'),
                    icon: thought.isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                    label: thought.isArchived ? 'Unarchive' : 'Archive',
                    onTap: () async {
                      await archiveThoughtsWithUndo(context, ref, [thought]);
                      close();
                    },
                  ),
                  ChoicePill(
                    key: const ValueKey('detail_delete'),
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete',
                    color: g.errorInk,
                    onTap: () async {
                      final removed = await deleteThoughtsWithUndo(
                        context,
                        ref,
                        [thought],
                      );
                      if (removed > 0) close();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
