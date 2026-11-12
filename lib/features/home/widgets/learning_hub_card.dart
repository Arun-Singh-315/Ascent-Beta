import '../../../shared/widgets/ascent_button.dart';
import 'home_section_heading.dart';
import 'home_module_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/home_design.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';

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

    if (!hasStarted) {
      return HomeModuleRow(
        key: const ValueKey('home_learning_card'),
        title: 'Start learning',
        subtitle: 'Choose a course · Track lessons and resume here',
        icon: Icons.auto_stories_outlined,
        onTap: openPlayer,
      );
    }

    return Padding(
      key: const ValueKey('home_learning_card'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeading(
            title: 'Learning',
            trailing: IconButton(
              tooltip: 'Switch course',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () => context.push('/study-plan'),
            ),
          ),
          InkWell(
            onTap: openPlayer,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    color: HomeDesign.of(context).learningInk,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active.title,
                          key: const ValueKey('home_learning_title'),
                          style: HomeType.section.copyWith(
                            fontSize: 17,
                            color: g.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          course.title,
                          key: const ValueKey('home_learning_course'),
                          style: HomeType.supporting.copyWith(
                            color: g.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Lesson ${position + 1} of ${lectures.length} · ${course.completedLectures} completed',
                          key: const ValueKey('home_learning_position'),
                          style: HomeType.supporting.copyWith(
                            color: g.inkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: state.progressFraction.clamp(0.0, 1.0),
            minHeight: 3,
            color: HomeDesign.of(context).action,
            backgroundColor: g.track,
            semanticsLabel: 'Lecture progress',
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                active.isCompleted
                    ? 'Lesson completed'
                    : '${state.formattedElapsed} studied · ${(state.remainingSeconds / 60).ceil()} min left',
                style: HomeType.supporting.copyWith(color: g.inkSecondary),
              ),
              AscentButton.tonal(
                compact: true,
                onPressed: resume,
                icon: state.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                label: active.isCompleted
                    ? 'Review'
                    : state.isPlaying
                    ? 'Pause'
                    : 'Resume',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
