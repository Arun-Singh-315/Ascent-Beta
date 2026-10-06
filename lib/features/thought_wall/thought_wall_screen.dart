import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/empty_state.dart';
import 'drop_thought_sheet.dart';

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

  final Map<String, String> _filterLabels = {
    'all': 'All Thoughts',
    'me_to_me': '🪞 Me to Me',
    'idea': '💡 Sparks',
    'win': '🏆 Wins',
    'future': '🔮 Future Me',
    'pinned': '📌 Pinned',
  };

  @override
  Widget build(BuildContext context) {
    final thoughtsAsync = ref.watch(allThoughtsStreamProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thought Wall',
              style: AscentTextStyles.headlineMedium.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Mind space • Me to Me talk',
              style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_rounded),
            tooltip: 'Drop a thought',
            onPressed: () => DropThoughtSheet.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8338EC),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.edit_note_rounded, size: 20),
        label: Text(
          'Drop a Thought ✨',
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
              children: _filterLabels.entries.map((entry) {
                final isSelected = _activeFilter == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Text(entry.value),
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
                  itemCount: filtered.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _JarvisMindReflectionCard(thoughts: thoughts);
                    }
                    final thought = filtered[index - 1];
                    return _ThoughtCard(
                      thought: thought,
                      index: index - 1,
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

  String _moodEmoji(String mood) {
    switch (mood) {
      case 'me_to_me':
        return '🪞';
      case 'idea':
        return '💡';
      case 'win':
        return '🏆';
      case 'future':
        return '🔮';
      case 'thought':
      default:
        return '💭';
    }
  }

  String _moodLabel(String mood) {
    switch (mood) {
      case 'me_to_me':
        return 'Me to Me';
      case 'idea':
        return 'Spark';
      case 'win':
        return 'Daily Win';
      case 'future':
        return 'Future Self';
      case 'thought':
      default:
        return 'Reflection';
    }
  }

  Color _moodColor(String mood) {
    switch (mood) {
      case 'me_to_me':
        return const Color(0xFF8338EC);
      case 'idea':
        return const Color(0xFFFFB703);
      case 'win':
        return const Color(0xFF5FA070);
      case 'future':
        return const Color(0xFFFB5607);
      case 'thought':
      default:
        return const Color(0xFF3A86FF);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodColor = _moodColor(thought.mood);
    final emoji = _moodEmoji(thought.mood);
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
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.bgSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: thought.isPinned
                  ? context.accentPrimary.withValues(alpha: 0.5)
                  : moodColor.withValues(alpha: 0.25),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: moodColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
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
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_horiz_rounded, size: 18, color: context.textMuted),
                    color: context.bgSurface,
                    padding: EdgeInsets.zero,
                    onSelected: (action) async {
                      if (action == 'pin') {
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
                  color: context.textPrimary,
                  height: 1.45,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JarvisMindReflectionCard extends ConsumerWidget {
  final List<Thought> thoughts;

  const _JarvisMindReflectionCard({required this.thoughts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assistantName = ref.watch(assistantNameProvider);
    final wins = thoughts.where((t) => t.mood == 'win').length;
    final sparks = thoughts.where((t) => t.mood == 'idea').length;

    String insight;
    if (thoughts.isEmpty) {
      insight = 'Mind space initialized. This wall is encrypted and stored strictly on-device. Feel free to speak your mind freely.';
    } else if (wins > 0 && wins >= sparks) {
      insight = 'You have logged $wins wins recently. Your trajectory shows high agency and consistent execution.';
    } else if (sparks > 0) {
      insight = 'You have captured $sparks creative sparks. Great breakthroughs start with raw unfiltered notes.';
    } else {
      insight = 'You have ${thoughts.length} reflective notes logged. Unloading cognitive load clears bandwidth for deep work.';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF0096C7).withValues(alpha: 0.3),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0096C7).withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                  ),
                ),
                child: const Icon(Icons.blur_on_rounded, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                '${assistantName.toUpperCase()} MIND REFLECTION',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: const Color(0xFF00B4D8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF0096C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${thoughts.length} thoughts',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: const Color(0xFF00B4D8),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight,
            style: AscentTextStyles.bodySmall.copyWith(
              color: context.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
