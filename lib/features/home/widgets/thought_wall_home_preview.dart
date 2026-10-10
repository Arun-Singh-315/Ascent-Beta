import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../thought_wall/drop_thought_sheet.dart';

/// Level 3 · Supporting: Mind Space
/// Redesigned according to Ascent Home Redesign spec:
/// - Open layout with single underline input (no heavy nested boxes).
/// - Glass thought bubble for latest reflection.
/// - 44dp hit targets.
class ThoughtWallHomePreview extends ConsumerWidget {
  const ThoughtWallHomePreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final recentThoughtsAsync = ref.watch(recentThoughtsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION HEADING ───────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'Mind space',
              style: AscentTextStyles.homeTitle.copyWith(
                color: g.ink,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/thought-wall');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Open wall',
                          style: AscentTextStyles.homeSecondary.copyWith(
                            color: g.clay,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: g.clay,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── OPEN UNDERLINE INPUT ROW ──────────────────────────────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              DropThoughtSheet.show(context);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: g.line, width: 1.0)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.edit_outlined, size: 18, color: g.inkMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "What's on your mind?",
                      style: AscentTextStyles.homeBody.copyWith(
                        color: g.inkMuted,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  Text(
                    'Drop',
                    style: AscentTextStyles.homeHeadline.copyWith(
                      color: g.clay,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),

        // ── THOUGHTS BUBBLE PREVIEW (ALTERNATING LEFT/RIGHT) ───────────
        recentThoughtsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (thoughts) {
            if (thoughts.isEmpty) {
              return const SizedBox.shrink();
            }

            final previewThoughts = thoughts.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                ...List.generate(previewThoughts.length, (index) {
                  final thought = previewThoughts[index];
                  final isEven = index % 2 == 0;
                  final timeAgo = _formatTimeAgo(thought.createdAt);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: isEven ? Alignment.centerLeft : Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: GlassSurface(
                          radius: 18,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isEven ? 4 : 18),
                            bottomRight: Radius.circular(isEven ? 18 : 4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/thought-wall');
                          },
                          child: Column(
                            crossAxisAlignment: isEven ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                thought.content,
                                style: AscentTextStyles.homeHeadline.copyWith(
                                  color: thought.isCompleted ? g.inkMuted : g.ink,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w500,
                                  decoration: thought.isCompleted ? TextDecoration.lineThrough : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 5),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (thought.isCompleted) ...[
                                    Icon(Icons.check_circle_rounded, size: 12, color: g.clay),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    timeAgo,
                                    style: AscentTextStyles.homeCaption.copyWith(
                                      color: g.inkMuted,
                                      fontSize: 10.5,
                                      letterSpacing: 0.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 4),
                Center(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/thought-wall');
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: g.fill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: g.line, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bubble_chart_outlined, size: 15, color: g.clay),
                          const SizedBox(width: 6),
                          Text(
                            'View all reflections (${thoughts.length})',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: g.clay,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: g.clay),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'JUST NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    return '${diff.inDays}D AGO';
  }
}
