import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';
import '../../study_plan/study_plan_screen.dart';

/// Level 2 · Secondary: Learning Hub
/// Redesigned according to Ascent Home Redesign spec:
/// - 72dp-88dp glass surface card with 24dp radius.
/// - Clear entry points to switch courses, explore catalog, and view syllabus.
/// - Inline play/pause control on disc without leaving Home.
/// - Course name header with direct "Switch Course" catalog button.
class LearningHubCard extends ConsumerWidget {
  const LearningHubCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final state = ref.watch(learningHubProvider);
    final course = state.course;
    final active = state.activeLecture;
    final activeMod = state.activeModule;
    final hasStarted = state.hasStartedLearning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TOP COURSE CONTEXT & SWITCH COURSE CTA ────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                'Learning',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/study-plan');
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      hasStarted ? 'Switch course' : 'Catalog',
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

        const SizedBox(height: 8),

        // ── GLASS ROW CARD ────────────────────────────────────────────
        GlassSurface(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // ── 1. PLAY / PAUSE DISC BUTTON (OR BOOK ICON) ──────────
              SizedBox(
                width: 42,
                height: 42,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (hasStarted) {
                        ref.read(learningHubProvider.notifier).togglePlayPause();
                      } else {
                        context.push('/study-plan');
                      }
                    },
                    borderRadius: BorderRadius.circular(21),
                    child: Container(
                      decoration: BoxDecoration(
                        color: g.claySoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          hasStarted
                              ? (state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)
                              : Icons.menu_book_rounded,
                          size: 22,
                          color: g.clay,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ── 2. LECTURE TITLE & SUBTITLE INFO ────────────────────
              Expanded(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (hasStarted) {
                      LectureFocusPlayerSheet.show(context);
                    } else {
                      context.push('/study-plan');
                    }
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasStarted
                            ? 'Lecture ${active.id}: ${active.title}'
                            : 'Start learning',
                        style: AscentTextStyles.homeHeadline.copyWith(
                          color: g.ink,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (hasStarted) ...[
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${activeMod.title} • ${state.formattedElapsed} / ${active.formattedDuration}',
                                style: AscentTextStyles.homeSecondary.copyWith(
                                  color: g.inkSecondary,
                                  fontSize: 11.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 40,
                              height: 3,
                              child: Container(
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
                          'Spring Boot, System Design or DSA',
                          style: AscentTextStyles.homeSecondary.copyWith(
                            color: g.inkSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // ── 3. ACTION CLUSTER: SYLLABUS & FULL PLAYER ───────────
              if (hasStarted) ...[
                // Syllabus button
                IconButton(
                  tooltip: 'View Syllabus',
                  icon: Icon(Icons.format_list_bulleted_rounded, size: 19, color: g.inkMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => StudyPlanScreen(courseId: course.id),
                      ),
                    );
                  },
                ),
                // Full Player button
                IconButton(
                  tooltip: 'Open Player Sheet',
                  icon: Icon(Icons.open_in_full_rounded, size: 16, color: g.inkMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    LectureFocusPlayerSheet.show(context);
                  },
                ),
              ] else ...[
                IconButton(
                  tooltip: 'Explore Catalog',
                  icon: Icon(Icons.chevron_right_rounded, size: 20, color: g.inkMuted),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/study-plan');
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
