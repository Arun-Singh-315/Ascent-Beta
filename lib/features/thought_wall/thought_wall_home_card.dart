import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_card.dart';
import 'drop_thought_sheet.dart';
import 'thought_wall_screen.dart';

/// Aesthetic preview card on Home screen displaying the latest / pinned thought
/// with 1-tap shortcut to drop thoughts or open the full Thought Wall.
class ThoughtWallHomeCard extends ConsumerWidget {
  const ThoughtWallHomeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentThoughtsAsync = ref.watch(recentThoughtsStreamProvider);
    final todayCountAsync = ref.watch(todayThoughtsCountStreamProvider);

    return AscentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.accentPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.accentPrimary.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(Icons.psychology_alt_rounded, color: context.accentPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'MIND SPACE',
                          style: AscentTextStyles.labelSmall.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: context.accentPrimary,
                          ),
                        ),
                        todayCountAsync.when(
                          data: (count) {
                            if (count <= 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: context.accentPrimary.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$count today',
                                style: AscentTextStyles.captionMedium.copyWith(
                                  color: context.accentPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10,
                                ),
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, _) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Thought Wall & Self-Talk',
                      style: AscentTextStyles.headlineMedium.copyWith(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              // Open Wall button
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/thought-wall');
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open Wall',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: context.accentPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 14, color: context.accentPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Content Box
          recentThoughtsAsync.when(
            loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox.shrink(),
            data: (thoughts) {
              if (thoughts.isEmpty) {
                return InkWell(
                  onTap: () => DropThoughtSheet.show(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.bgBase,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.accentPrimary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.psychology_alt_rounded, size: 18, color: context.accentPrimary),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'What are you telling yourself today?',
                                style: AscentTextStyles.labelMedium.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Drop an unfiltered reflection or note to future you.',
                                style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.add_circle_outline_rounded, size: 20, color: context.accentPrimary),
                      ],
                    ),
                  ),
                );
              }

              final top = thoughts.first;
              final dateStr = DateFormat('MMM d, h:mm a').format(top.createdAt);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.bgBase,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: top.isPinned
                        ? context.accentPrimary.withValues(alpha: 0.4)
                        : context.divider,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          top.isPinned ? '📌 PINNED REFLECTION' : 'LATEST THOUGHT',
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: top.isPinned ? context.accentPrimary : context.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          dateStr,
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: context.textMuted,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.share_outlined, size: 14, color: context.textMuted),
                          tooltip: 'Share via WhatsApp & apps',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () => shareThought(top),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      top.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        height: 1.4,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 1-Tap Quick Action Button to drop a new thought
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: const Text('Drop a Thought'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.accentPrimary,
                    side: BorderSide(color: context.accentPrimary.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    DropThoughtSheet.show(context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: Icon(Icons.auto_awesome_rounded, size: 14, color: context.accentPrimary),
                label: const Text('Prompt'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.textPrimary,
                  side: BorderSide(color: context.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  DropThoughtSheet.show(
                    context,
                    initialPrompt: 'What is one honest truth you needed to hear today?',
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
