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

/// A glanceable learning summary; full titles and details live in the player.
class LearningHubCard extends ConsumerWidget {
  const LearningHubCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final state = ref.watch(learningHubProvider);
    final course = state.course;
    final active = state.activeLecture;
    final lectures = course.modules
        .expand((module) => module.lectures)
        .toList();
    final hasStarted = state.hasStartedLearning && lectures.isNotEmpty;
    final position = lectures.indexWhere((lecture) => lecture.id == active.id);

    void openPlayer() {
      HapticFeedback.lightImpact();
      if (hasStarted) {
        LectureFocusPlayerSheet.show(context);
      } else {
        context.push('/study-plan');
      }
    }

    void resume() {
      HapticFeedback.lightImpact();
      if (!hasStarted) {
        context.push('/study-plan');
      } else if (active.isCompleted) {
        openPlayer();
      } else {
        ref.read(learningHubProvider.notifier).togglePlayPause();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                'Growth',
                textAlign: TextAlign.center,
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Positioned(
                right: 0,
                child: TextButton(
                  onPressed: () => context.push('/study-plan'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: g.clay,
                  ),
                  child: Text(hasStarted ? 'Switch course' : 'Catalog'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: GlassSurface(
            key: const ValueKey('home_learning_card'),
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            fillColor: Colors.transparent,
            hasShadow: false,
            enableBlur: false,
            customBorder: Border.all(
              color: g.line.withValues(alpha: 0.8),
              width: 1.0,
            ),
            onTap: openPlayer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: g.clay.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: g.clay.withValues(alpha: 0.35),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: g.clay.withValues(alpha: 0.14),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      hasStarted ? Icons.play_lesson_rounded : Icons.auto_stories_rounded,
                      color: g.clay,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  hasStarted ? active.title : 'Start learning',
                  key: const ValueKey('home_learning_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.displaySmall.copyWith(
                    color: g.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      hasStarted ? course.title : 'Pick your next course',
                      key: const ValueKey('home_learning_course'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    if (hasStarted) ...[
                      Text(
                        '· ${position + 1}/${lectures.length}',
                        key: const ValueKey('home_learning_position'),
                        style: TextStyle(
                          color: g.clay,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                if (hasStarted) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: g.track,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: g.line.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: LinearProgressIndicator(
                        value: state.progressFraction.clamp(0.0, 1.0),
                        minHeight: 5,
                        color: g.clay,
                        backgroundColor: Colors.transparent,
                        semanticsLabel: 'Lecture progress',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        state.formattedElapsed,
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        active.isCompleted
                            ? 'Completed'
                            : '${(state.remainingSeconds / 60).ceil()} min left',
                        style: TextStyle(color: g.inkMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Center(
                  child: InkWell(
                    onTap: resume,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 240),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: g.clay.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: g.clay.withValues(alpha: 0.40),
                          width: 0.8,
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              !hasStarted
                                  ? Icons.explore_rounded
                                  : (state.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded),
                              size: 17,
                              color: g.clay,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              !hasStarted
                                  ? 'Explore Courses'
                                  : active.isCompleted
                                      ? 'Review'
                                      : state.isPlaying
                                          ? 'Pause'
                                          : 'Resume',
                              style: TextStyle(
                                color: g.clay,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (hasStarted) ...[
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => StudyPlanScreen(courseId: course.id),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    Icons.format_list_bulleted_rounded,
                                    color: g.clay,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
