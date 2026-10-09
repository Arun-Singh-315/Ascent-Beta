import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import 'drop_thought_sheet.dart';

/// Formats thought content cleanly for WhatsApp, messages, and external sharing.
String formatThoughtForShare(Thought thought) {
  final buffer = StringBuffer();
  if (thought.promptQuestion != null && thought.promptQuestion!.trim().isNotEmpty) {
    buffer.writeln('💭 Prompt: ${thought.promptQuestion!.trim()}\n');
  }
  buffer.writeln('"${thought.content.trim()}"');
  buffer.writeln('\n— Mind Space · Ascent');
  return buffer.toString();
}

/// Triggers system share sheet to share thought directly to WhatsApp or any installed app.
Future<void> shareThought(Thought thought) async {
  HapticFeedback.lightImpact();
  final text = formatThoughtForShare(thought);
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: 'Mind Space Reflection',
    ),
  );
}

/// Thought Wall / Mind Space Screen ("Me to Me")
/// An aesthetic spatial wall for unfiltered self-talk, sparks of inspiration,
/// daily wins, and letters to your future self.
class ThoughtWallScreen extends ConsumerStatefulWidget {
  const ThoughtWallScreen({super.key});

  @override
  ConsumerState<ThoughtWallScreen> createState() => _ThoughtWallScreenState();
}

class _ThoughtWallScreenState extends ConsumerState<ThoughtWallScreen> {
  String _activeFilter = 'all';

  final Map<String, (String, IconData)> _filterMeta = const {
    'all': ('All Thoughts', Icons.bubble_chart_rounded),
    'me_to_me': ('Me to Me', Icons.psychology_alt_rounded),
    'thought': ('Raw Thoughts', Icons.insights_rounded),
    'idea': ('Sparks', Icons.lightbulb_rounded),
    'win': ('Wins', Icons.emoji_events_rounded),
    'future': ('Future Me', Icons.schedule_send_rounded),
    'pinned': ('Pinned', Icons.push_pin_rounded),
    'archived': ('Archived', Icons.archive_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final thoughtsAsync = _activeFilter == 'archived'
        ? ref.watch(archivedThoughtsStreamProvider)
        : ref.watch(allThoughtsStreamProvider);

    final g = context.glass;

    return AscentScaffold(
      title: 'Thought Wall',
      subtitle: 'Mind space • Me to Me talk',
      glow2: g.slate,
      actions: [
        IconButton(
          icon: Icon(Icons.add_comment_rounded, color: g.clay),
          tooltip: 'Drop a thought',
          onPressed: () {
            HapticFeedback.lightImpact();
            DropThoughtSheet.show(context);
          },
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: g.clay,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.edit_note_rounded, size: 20),
        label: Text(
          'Drop a Thought',
          style: AscentTextStyles.labelMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () {
          HapticFeedback.lightImpact();
          DropThoughtSheet.show(context);
        },
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _filterMeta.entries.map((entry) {
                final isSelected = _activeFilter == entry.key;
                final label = entry.value.$1;
                final icon = entry.value.$2;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 14, color: isSelected ? context.accentPrimary : context.textMuted),
                        const SizedBox(width: 5),
                        Text(label),
                      ],
                    ),
                    backgroundColor: context.bgSurface,
                    selectedColor: context.accentPrimary.withValues(alpha: 0.15),
                    labelStyle: AscentTextStyles.labelSmall.copyWith(
                      color: isSelected ? context.accentPrimary : context.textMuted,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected ? context.accentPrimary : context.divider,
                    ),
                    onSelected: (_) {
                      HapticFeedback.lightImpact();
                      setState(() => _activeFilter = entry.key);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),

          // Main Wall Content
          Expanded(
            child: thoughtsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading wall: $err')),
              data: (thoughts) {
                // Apply filter
                final filtered = thoughts.where((t) {
                  if (_activeFilter == 'archived') return true;
                  if (_activeFilter == 'all') return true;
                  if (_activeFilter == 'pinned') return t.isPinned;
                  return t.mood == _activeFilter;
                }).toList();

                if (filtered.isEmpty) {
                  return EmptyState(
                    title: _activeFilter == 'all'
                        ? 'Your Thought Wall is Empty'
                        : 'No thoughts found for this filter',
                    subtitle: 'Pin your first thought, raw idea, or honest self-talk.',
                    icon: Icons.bubble_chart_rounded,
                    actionLabel: 'Drop a Thought',
                    onAction: () => DropThoughtSheet.show(context),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final thought = filtered[index];
                    return _ThoughtCard(
                      thought: thought,
                      index: index,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ThoughtCard extends ConsumerWidget {
  final Thought thought;
  final int index;

  const _ThoughtCard({
    required this.thought,
    required this.index,
  });

  IconData _moodIcon(String mood) {
    switch (mood) {
      case 'me_to_me':
        return Icons.psychology_alt_rounded;
      case 'idea':
        return Icons.lightbulb_rounded;
      case 'win':
        return Icons.emoji_events_rounded;
      case 'future':
        return Icons.schedule_send_rounded;
      case 'thought':
      default:
        return Icons.insights_rounded;
    }
  }

  String _moodLabel(String mood) {
    switch (mood) {
      case 'me_to_me':
        return 'Me to Me';
      case 'idea':
        return 'Idea';
      case 'win':
        return 'Daily Win';
      case 'future':
        return 'Future Self';
      case 'thought':
      default:
        return 'Raw Thought';
    }
  }

  Color _moodColor(String mood) {
    switch (mood) {
      case 'me_to_me':
        return const Color(0xFF6366F1); // Refined Indigo
      case 'idea':
        return const Color(0xFFD97706); // Warm Amber
      case 'win':
        return const Color(0xFF16A34A); // Sage Green
      case 'future':
        return const Color(0xFFEA580C); // Terracotta
      case 'thought':
      default:
        return const Color(0xFF0284C7); // Sky Deep
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodColor = _moodColor(thought.mood);
    final icon = _moodIcon(thought.mood);
    final label = _moodLabel(thought.mood);
    final timeStr = DateFormat('MMM d • h:mm a').format(thought.createdAt);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Dismissible(
          key: ValueKey('thought_${thought.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            final thoughtDao = ref.read(thoughtDaoProvider);
            if (direction == DismissDirection.startToEnd) {
              // Archive / Unarchive
              HapticFeedback.mediumImpact();
              if (thought.isArchived) {
                await thoughtDao.unarchiveThought(thought.id);
              } else {
                await thoughtDao.archiveThought(thought.id);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(thought.isArchived ? 'Thought unarchived' : 'Thought archived'),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: context.accentPrimary,
                      onPressed: () async {
                        if (thought.isArchived) {
                          await thoughtDao.archiveThought(thought.id);
                        } else {
                          await thoughtDao.unarchiveThought(thought.id);
                        }
                      },
                    ),
                  ),
                );
              }
              return true;
            } else {
              // Delete
              HapticFeedback.mediumImpact();
              final backup = thought;
              await thoughtDao.deleteThought(thought.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Thought removed'),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: context.accentPrimary,
                      onPressed: () async {
                        await thoughtDao.insertThought(backup.toCompanion(true));
                      },
                    ),
                  ),
                );
              }
              return true;
            }
          },
          background: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(
                  thought.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined,
                  color: Colors.amber,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  thought.isArchived ? 'Unarchive' : 'Archive',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 8),
                Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
              ],
            ),
          ),
          child: GestureDetector(
            onDoubleTap: () async {
              HapticFeedback.mediumImpact();
              await ref.read(thoughtDaoProvider).toggleCompleted(thought.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(thought.isCompleted ? 'Thought marked active' : 'Thought marked done ✓'),
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: thought.isPinned
                      ? context.accentPrimary.withValues(alpha: 0.5)
                      : (thought.isCompleted
                          ? context.divider
                          : moodColor.withValues(alpha: 0.25)),
                  width: thought.isPinned ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (thought.isPinned ? context.accentPrimary : moodColor).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top meta row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: moodColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 12, color: moodColor),
                            const SizedBox(width: 5),
                            Text(
                              label,
                              style: AscentTextStyles.labelSmall.copyWith(
                                color: moodColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (thought.isCompleted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.accentPrimary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '✓ Done',
                            style: TextStyle(
                              color: context.accentPrimary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (thought.isPinned) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.accentPrimary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.push_pin_rounded, size: 10, color: context.accentPrimary),
                              const SizedBox(width: 3),
                              Text(
                                'PINNED',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: context.accentPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(
                        timeStr,
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: context.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: Icon(Icons.share_outlined, size: 16, color: context.textMuted),
                        tooltip: 'Share via WhatsApp & apps',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        onPressed: () => shareThought(thought),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz_rounded, size: 18, color: context.textMuted),
                        color: context.bgSurface,
                        padding: EdgeInsets.zero,
                        onSelected: (action) async {
                          if (action == 'share') {
                            await shareThought(thought);
                          } else if (action == 'toggle_done') {
                            HapticFeedback.lightImpact();
                            await ref.read(thoughtDaoProvider).toggleCompleted(thought.id);
                          } else if (action == 'convert_task') {
                            HapticFeedback.mediumImpact();
                            final taskDao = ref.read(taskDaoProvider);
                            await taskDao.insertTask(
                              TaskTableCompanion.insert(
                                title: thought.content.trim(),
                                plannedDate: drift.Value(DateTime.now()),
                                notes: drift.Value(thought.promptQuestion != null ? 'From Thought Wall: ${thought.promptQuestion}' : null),
                              ),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Added to Today tasks!'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else if (action == 'archive') {
                            HapticFeedback.lightImpact();
                            final dao = ref.read(thoughtDaoProvider);
                            if (thought.isArchived) {
                              await dao.unarchiveThought(thought.id);
                            } else {
                              await dao.archiveThought(thought.id);
                            }
                          } else if (action == 'pin') {
                            HapticFeedback.lightImpact();
                            await ref.read(thoughtDaoProvider).togglePin(thought.id);
                          } else if (action == 'copy') {
                            HapticFeedback.lightImpact();
                            await Clipboard.setData(ClipboardData(text: thought.content));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copied to clipboard!')),
                              );
                            }
                          } else if (action == 'delete') {
                            HapticFeedback.mediumImpact();
                            await ref.read(thoughtDaoProvider).deleteThought(thought.id);
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'toggle_done',
                            child: Row(
                              children: [
                                Icon(thought.isCompleted ? Icons.check_circle_outline_rounded : Icons.check_circle_rounded, size: 16),
                                const SizedBox(width: 8),
                                Text(thought.isCompleted ? 'Mark as undone' : 'Mark as done'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'convert_task',
                            child: Row(
                              children: [
                                Icon(Icons.add_task_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Convert to Today Task'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(thought.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 16),
                                const SizedBox(width: 8),
                                Text(thought.isArchived ? 'Unarchive' : 'Archive thought'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_rounded, size: 16),
                                SizedBox(width: 8),
                                Text('Share (WhatsApp & apps)'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'pin',
                            child: Text(thought.isPinned ? 'Unpin' : 'Pin to top'),
                          ),
                          const PopupMenuItem(
                            value: 'copy',
                            child: Text('Copy text'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete thought', style: TextStyle(color: Colors.redAccent)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Optional prompt question
                  if (thought.promptQuestion != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Q: ${thought.promptQuestion}',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: context.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  const SizedBox(height: 10),

                  // Content
                  Text(
                    thought.content,
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: thought.isCompleted ? context.textMuted : context.textPrimary,
                      decoration: thought.isCompleted ? TextDecoration.lineThrough : null,
                      height: 1.45,
                      fontSize: 14.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


