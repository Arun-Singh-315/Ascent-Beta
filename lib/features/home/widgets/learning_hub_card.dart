import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';

/// Level 2 · Secondary: Learning Hub
/// Redesigned according to Ascent Home Redesign spec:
/// - 72dp glass surface row with 24dp radius.
/// - Clay soft icon disc (40dp) with study icon.
/// - Shows "Start learning" (empty) or active lecture & progress (active).
/// - Clean chevron link.
class LearningHubCard extends ConsumerWidget {
  const LearningHubCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final state = ref.watch(learningHubProvider);
    final course = state.course;
    final active = state.activeLecture;
    final isLive = state.isPlaying || state.isLiveFocusActive;
    final hasStarted = state.hasStartedLearning;

    return GlassSurface(
      radius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () {
        HapticFeedback.lightImpact();
        if (isLive) {
          LectureFocusPlayerSheet.show(context);
        } else {
          context.push('/study-plan');
        }
      },
      child: Row(
        children: [
          // ── ICON DISC ───────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: g.claySoft,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                isLive
                    ? (state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)
                    : Icons.menu_book_rounded,
                size: 20,
                color: g.clay,
              ),
            ),
          ),

          const SizedBox(width: 14),

          // ── TITLE & SUBTITLE COLUMN ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isLive
                      ? 'Lecture ${active.id}: ${active.title}'
                      : (hasStarted ? 'Continue ${course.title}' : 'Start learning'),
                  style: AscentTextStyles.homeHeadline.copyWith(
                    color: g.ink,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                if (isLive) ...[
                  Row(
                    children: [
                      Text(
                        '${state.formattedElapsed} / ${active.formattedDuration}',
                        style: AscentTextStyles.homeSecondary.copyWith(
                          color: g.inkSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: g.track,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: state.progressFraction.clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: g.inkSecondary,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Text(
                    hasStarted ? active.title : 'Spring Boot, System Design or DSA',
                    style: AscentTextStyles.homeSecondary.copyWith(
                      color: g.inkSecondary,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── CHEVRON OR QUICK CONTROLS ──────────────────────────────
          if (isLive) ...[
            IconButton(
              iconSize: 22,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: Icon(
                state.isPlaying ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                color: g.clay,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(learningHubProvider.notifier).togglePlayPause();
              },
            ),
          ] else ...[
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: g.inkMuted,
            ),
          ],
        ],
      ),
    );
  }
}
