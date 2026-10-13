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
                style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
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
                    Icon(Icons.chevron_right_rounded, size: 16, color: g.clay),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ── HERO GLASS SURFACE CARD ──────────────────────────────────
        GlassSurface(
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── 1. PROMINENT HERO PLAY / PAUSE BUTTON ───────────
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (hasStarted) {
                            ref
                                .read(learningHubProvider.notifier)
                                .togglePlayPause();
                          } else {
                            context.push('/study-plan');
                          }
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          decoration: BoxDecoration(
                            color: g.clay,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: g.clay.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              hasStarted
                                  ? (state.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded)
                                  : Icons.play_arrow_rounded,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ── 2. LECTURE TITLE & HERO RESUME BADGE ────────────
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
                              color: (hasStarted && active.isCompleted)
                                  ? g.inkMuted
                                  : g.ink,
                              decoration: (hasStarted && active.isCompleted)
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: g.inkMuted,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (hasStarted) ...[
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: g.claySoft,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Resume · ${(state.remainingSeconds / 60).ceil()} min left',
                                    style: AscentTextStyles.captionMedium
                                        .copyWith(
                                          color: g.clay,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    activeMod.title,
                                    style: AscentTextStyles.homeSecondary
                                        .copyWith(
                                          color: g.inkSecondary,
                                          fontSize: 11.5,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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

                  // ── 3. ACTION CLUSTER: SYLLABUS & FULL PLAYER ───────
                  if (hasStarted) ...[
                    IconButton(
                      tooltip: 'View Syllabus',
                      icon: Icon(
                        Icons.format_list_bulleted_rounded,
                        size: 20,
                        color: g.inkMuted,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) =>
                                StudyPlanScreen(courseId: course.id),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Open Player Sheet',
                      icon: Icon(
                        Icons.open_in_full_rounded,
                        size: 17,
                        color: g.inkMuted,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        LectureFocusPlayerSheet.show(context);
                      },
                    ),
                  ] else ...[
                    IconButton(
                      tooltip: 'Explore Catalog',
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: g.inkMuted,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/study-plan');
                      },
                    ),
                  ],
                ],
              ),

              if (hasStarted) ...[
                const SizedBox(height: 14),

                // ── 4. THICK HERO PROGRESS BAR ────────────────────────
                SizedBox(
                  height: 7,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: g.track,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: state.progressFraction.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: g.clay,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: g.clay.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ── 5. TIME STATS LABELS ──────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${state.formattedElapsed} elapsed',
                      style: AscentTextStyles.captionMedium.copyWith(
                        color: g.inkMuted,
                        fontSize: 10.5,
                      ),
                    ),
                    Text(
                      '${active.formattedDuration} total',
                      style: AscentTextStyles.captionMedium.copyWith(
                        color: g.inkMuted,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
