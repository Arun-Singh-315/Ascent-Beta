import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_card.dart';
import '../../thought_wall/drop_thought_sheet.dart';

class ThoughtWallHomePreview extends ConsumerWidget {
  const ThoughtWallHomePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentThoughtsAsync = ref.watch(recentThoughtsStreamProvider);
    final accentPurple = const Color(0xFF8338EC);

    return AscentCard(
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentPurple.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 15, color: accentPurple),
              ),
              const SizedBox(width: 8),
              Text(
                'MIND SPACE • SELF-TALK',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: accentPurple,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/thought-wall');
                },
                child: Text(
                  'Open Wall ›',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: accentPurple,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Quick Spark Prompt Capsule
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                DropThoughtSheet.show(context);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: context.bgBase,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.divider.withValues(alpha: 0.8),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 14, color: context.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "What's on your mind? Tap to drop thought...",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: context.textMuted,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentPurple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Drop',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: accentPurple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Pinned / Latest Thought Preview
          recentThoughtsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (thoughts) {
              if (thoughts.isEmpty) return const SizedBox.shrink();

              final thought = thoughts.first;
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: accentPurple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accentPurple.withValues(alpha: 0.2),
                      width: 0.6,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        thought.isPinned ? Icons.push_pin_rounded : Icons.bubble_chart_outlined,
                        size: 13,
                        color: accentPurple,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          thought.content,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
