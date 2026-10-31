import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../promises/providers/promise_providers.dart';
import '../../vault/providers/vault_providers.dart';
import '../thought_category_action.dart';
import 'board_logic.dart';
import 'space_style.dart';

/// Result of the space picker: either an existing space [key], or the [newName]
/// of a space to create.
typedef SpacePick = ({String? key, String? newName});

String _spaceLabel(String key, String name) =>
    key == wallCategoryKey ? 'Wall' : name;

/// Asks where a thought should live. Offers the wall, every space and a way to
/// create a new space on the spot. Returns null when dismissed.
Future<SpacePick?> showSpacePicker(
  BuildContext context, {
  String? current,
  String title = 'Move to',
}) {
  return showModalBottomSheet<SpacePick>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => Consumer(
      builder: (context, ref, _) {
        final g = context.glass;
        final categories =
            ref.watch(thoughtCategoriesStreamProvider).value ??
            ThoughtDao.builtInCategories;
        final keys = [
          wallCategoryKey,
          ...categories.keys.where((k) => k != wallCategoryKey),
        ];
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AscentTextStyles.cardTitle.copyWith(color: g.ink),
                ),
                const SizedBox(height: AppSpace.s16),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final key in keys)
                      ChoicePill(
                        key: ValueKey('space_pick_$key'),
                        icon: key == wallCategoryKey
                            ? Icons.bubble_chart_rounded
                            : spaceStyleFor(categories[key] ?? '').icon,
                        label: _spaceLabel(key, categories[key] ?? ''),
                        selected: key == current,
                        onTap: () => Navigator.pop(sheetContext, (
                          key: key,
                          newName: null,
                        )),
                      ),
                    ChoicePill(
                      key: const ValueKey('space_pick_new'),
                      icon: Icons.add_rounded,
                      label: 'New space',
                      onTap: () async {
                        final name = await showDialog<String>(
                          context: sheetContext,
                          builder: (_) =>
                              const CreateThoughtCategoryDialog(move: true),
                        );
                        if (name != null && sheetContext.mounted) {
                          Navigator.pop(sheetContext, (
                            key: null,
                            newName: name,
                          ));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// A bordered pill with an icon and a label. Wraps its text instead of
/// overflowing, so it survives narrow screens and large text.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.selected = false,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;

  /// Overrides the text and icon colour (used for destructive actions).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final ink = color ?? g.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s14,
            vertical: AppSpace.s8,
          ),
          decoration: BoxDecoration(
            color: selected ? g.clay.withValues(alpha: .14) : Colors.transparent,
            borderRadius: AppGeometry.roundedr14,
            border: Border.all(
              color: selected ? g.clay : ink.withValues(alpha: .28),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: ink),
              const SizedBox(width: AppSpace.s8),
              Flexible(
                child: Text(
                  label,
                  style: AscentTextStyles.labelLarge.copyWith(color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Moves thoughts to the chosen space (creating it first when asked) and
/// offers Undo. Returns true when the move was saved.
Future<bool> moveThoughtsToSpace(
  BuildContext context,
  WidgetRef ref,
  List<Thought> thoughts,
  SpacePick pick,
) async {
  if (thoughts.isEmpty) return false;
  final db = ref.read(databaseProvider);
  try {
    final String key;
    if (pick.newName != null) {
      key = await db.thoughtDao.createCategoryAndMove(
        pick.newName!,
        thoughts.map((t) => t.id),
      );
    } else {
      key = pick.key!;
      await db.thoughtDao.moveToCategory(thoughts.map((t) => t.id), key);
    }
    if (!context.mounted) return true;
    final names =
        ref.read(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final label = _spaceLabel(key, names[key] ?? pick.newName ?? 'space');
    AscentSnackBar.show(
      context,
      message: thoughts.length == 1
          ? 'Moved to $label'
          : '${thoughts.length} moved to $label',
      icon: Icons.folder_outlined,
      actionLabel: 'Undo',
      onAction: () async {
        await db.transaction(() async {
          for (final thought in thoughts) {
            final current = await db.thoughtDao.getThoughtById(thought.id);
            if (current?.category == key) {
              await db.thoughtDao.moveToCategory([
                thought.id,
              ], thought.category);
            }
          }
        });
      },
    );
    return true;
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(context, message: 'Could not move. Try again.');
    }
    return false;
  }
}

/// Deletes thoughts and offers Undo. Returns how many were removed.
Future<int> deleteThoughtsWithUndo(
  BuildContext context,
  WidgetRef ref,
  List<Thought> thoughts,
) async {
  HapticFeedback.mediumImpact();
  final dao = ref.read(thoughtDaoProvider);
  try {
    final snapshots = <ThoughtDeletion>[];
    for (final thought in thoughts) {
      final snapshot = await dao.deleteThoughtForUndo(thought.id);
      if (snapshot != null) snapshots.add(snapshot);
    }
    if (snapshots.isEmpty) {
      if (context.mounted) {
        AscentSnackBar.error(
          context,
          message: 'This thought is no longer available.',
        );
      }
      return 0;
    }
    if (context.mounted) {
      AscentSnackBar.undo(
        context,
        message: snapshots.length == 1
            ? 'Thought removed'
            : '${snapshots.length} thoughts removed',
        onUndo: () async {
          for (final snapshot in snapshots) {
            try {
              await dao.restoreThoughtDeletion(snapshot);
            } catch (_) {
              // A newer change wins; the rest are still restored.
            }
          }
        },
      );
    }
    return snapshots.length;
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(
        context,
        message: 'Could not delete. Please try again.',
      );
    }
    return 0;
  }
}

/// Archives (or restores, if all are archived) and offers Undo.
Future<void> archiveThoughtsWithUndo(
  BuildContext context,
  WidgetRef ref,
  List<Thought> thoughts,
) async {
  if (thoughts.isEmpty) return;
  HapticFeedback.lightImpact();
  final dao = ref.read(thoughtDaoProvider);
  final archive = thoughts.any((t) => !t.isArchived);
  try {
    for (final thought in thoughts) {
      if (archive) {
        await dao.archiveThought(thought.id);
      } else {
        await dao.unarchiveThought(thought.id);
      }
    }
    if (!context.mounted) return;
    AscentSnackBar.show(
      context,
      message: archive
          ? (thoughts.length == 1
                ? 'Thought archived'
                : '${thoughts.length} thoughts archived')
          : (thoughts.length == 1
                ? 'Thought restored'
                : '${thoughts.length} thoughts restored'),
      icon: archive ? Icons.archive_outlined : Icons.unarchive_outlined,
      actionLabel: 'Undo',
      onAction: () async {
        for (final thought in thoughts) {
          if (archive) {
            await dao.unarchiveThought(thought.id);
          } else {
            await dao.archiveThought(thought.id);
          }
        }
      },
    );
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(context, message: 'Could not update. Try again.');
    }
  }
}

/// Flips the done state of one thought.
Future<void> toggleThoughtDone(
  BuildContext context,
  WidgetRef ref,
  Thought thought,
) async {
  HapticFeedback.selectionClick();
  try {
    await ref.read(thoughtDaoProvider).toggleCompleted(thought.id);
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(
        context,
        message: 'Could not update thought. Try again.',
      );
    }
  }
}

/// Asks for biometrics and, if confirmed, unlocks a private promise for this
/// session. Returns whether it is now unlocked.
Future<bool> unlockPrivateThought(
  WidgetRef ref,
  Thought thought, {
  String reason = 'Unlock private commitment',
}) async {
  final unlocked = await ref
      .read(vaultSecurityServiceProvider)
      .authenticateBiometrics(reason: reason);
  if (unlocked) {
    ref.read(unlockedPromiseIdsProvider.notifier).unlock(thought.id);
  }
  return unlocked;
}
