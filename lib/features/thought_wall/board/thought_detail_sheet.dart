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

final boardThoughtRecordProvider = StreamProvider.autoDispose
    .family<Thought?, int>((ref, id) {
      final db = ref.watch(databaseProvider);
      return (db.select(
        db.thoughtTable,
      )..where((t) => t.id.equals(id))).watchSingleOrNull();
    });

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
    final record = ref.watch(boardThoughtRecordProvider(initial.id));
    if (record.hasValue && record.value == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('This thought is no longer available.'),
      );
    }
    final thought = record.value ?? initial;
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
    final spaceName = inWall
        ? 'Wall'
        : (categories[thought.category] ?? 'Space');
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
      await Clipboard.setData(
        ClipboardData(text: displayContent(thought.content)),
      );
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
          AscentSnackBar.error(
            context,
            message: 'Could not update. Try again.',
          );
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
                    icon: inWall ? Icons.bubble_chart_rounded : style.icon,
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
                  prompt,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: AppSpace.s20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final actions = <Widget>[
                    _PrimaryAction(
                      key: const ValueKey('detail_done'),
                      icon: thought.isCompleted
                          ? Icons.replay_rounded
                          : Icons.check_rounded,
                      label: thought.isCompleted
                          ? 'Reopen'
                          : (inWall ? 'Done' : style.doneLabel),
                      onTap: () => toggleThoughtDone(context, ref, thought),
                    ),
                    if (!locked)
                      _PrimaryAction(
                        key: const ValueKey('detail_edit'),
                        icon: Icons.edit_outlined,
                        label: 'Edit',
                        onTap: () => DropThoughtSheet.show(
                          context,
                          existingThought: thought,
                        ),
                      ),
                    if (!locked)
                      _PrimaryAction(
                        key: const ValueKey('detail_priority'),
                        icon: high
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        label: high ? 'Unstar' : 'Star',
                        onTap: togglePriority,
                      ),
                  ];
                  if (MediaQuery.textScalerOf(context).scale(1) >= 1.45) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: actions,
                    );
                  }
                  return Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: actions[i]),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(
                  context,
                ).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: const ValueKey('detail_more'),
                  tilePadding: EdgeInsets.zero,
                  title: const Text('More actions'),
                  children: [
                    _DetailAction(
                      key: const ValueKey('detail_pin'),
                      icon: Icons.push_pin_outlined,
                      label: thought.isPinned ? 'Unpin' : 'Pin',
                      onTap: () => dao.togglePin(thought.id),
                    ),
                    _DetailAction(
                      icon: Icons.drive_file_move_outlined,
                      label: 'Move to space',
                      onTap: move,
                    ),
                    if (!locked && !isPromise) ...[
                      _DetailAction(
                        key: const ValueKey('detail_todo'),
                        icon: Icons.add_task_rounded,
                        label: 'Create todo',
                        onTap: () => convert('todo'),
                      ),
                      _DetailAction(
                        key: const ValueKey('detail_reminder'),
                        icon: Icons.notifications_none_rounded,
                        label: 'Set reminder',
                        onTap: () => convert('reminder'),
                      ),
                      _DetailAction(
                        key: const ValueKey('detail_plan'),
                        icon: Icons.event_outlined,
                        label: 'Add to plan',
                        onTap: plan,
                      ),
                    ],
                    if (isPromise) ...[
                      _DetailAction(
                        key: const ValueKey('detail_promises'),
                        icon: Icons.handshake_outlined,
                        label: 'Commitments',
                        onTap: () => openRoute('/promises'),
                      ),
                      if (!locked)
                        _DetailAction(
                          key: const ValueKey('detail_challenge'),
                          icon: Icons.flag_outlined,
                          label: 'Track with Challenge',
                          onTap: () => openRoute('/momentum', extra: thought),
                        ),
                    ],
                    if (!locked) ...[
                      _DetailAction(
                        key: const ValueKey('detail_share'),
                        icon: Icons.ios_share_rounded,
                        label: 'Share',
                        onTap: () => shareThought(thought),
                      ),
                      _DetailAction(
                        key: const ValueKey('detail_copy'),
                        icon: Icons.copy_outlined,
                        label: 'Copy text',
                        onTap: copy,
                      ),
                    ],
                    const Divider(height: 24),
                    _DetailAction(
                      key: const ValueKey('detail_archive'),
                      icon: Icons.archive_outlined,
                      label: thought.isArchived ? 'Unarchive' : 'Archive',
                      onTap: () async {
                        await archiveThoughtsWithUndo(context, ref, [thought]);
                        close();
                      },
                    ),
                    _DetailAction(
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: g.ink.withValues(alpha: .05),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 23),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailAction extends StatelessWidget {
  const _DetailAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color ?? context.glass.inkSecondary, size: 22),
    title: Text(label, style: TextStyle(color: color)),
    onTap: onTap,
  );
}
