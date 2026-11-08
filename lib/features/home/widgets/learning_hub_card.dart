import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/merlot_palette.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import 'home_outline_surface.dart';
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
    final dark = Theme.of(context).brightness == Brightness.dark;

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
        HomeOutlineSurface(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Tooltip(
                message: hasStarted ? active.title : 'Explore learning courses',
                child: InkWell(
                  onTap: openPlayer,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!hasStarted) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: g.clay.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: g.clay.withValues(alpha: 0.25),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 13,
                                  color: g.clay,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'STUDIO ASCENT',
                                  style: TextStyle(
                                    color: g.clay,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              hasStarted
                                  ? course.title
                                  : 'Pick your next course',
                              key: const ValueKey('home_learning_course'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: g.inkSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (hasStarted) ...[
                              Text(
                                '${position + 1}/${lectures.length}',
                                key: const ValueKey('home_learning_position'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: g.clay,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          hasStarted ? active.title : 'Start learning',
                          key: const ValueKey('home_learning_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                      minHeight: 6,
                      color: g.clay,
                      backgroundColor: Colors.transparent,
                      semanticsLabel: 'Lecture progress',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      state.formattedElapsed,
                      style: TextStyle(
                        color: g.ink,
                        fontSize: 14,
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: resume,
                      style: FilledButton.styleFrom(
                        backgroundColor: dark
                            ? g.clay
                            : (g.merlot
                                  ? MerlotPalette.pillSoft
                                  : (g.frozen
                                        ? FrozenPalette.pillSoft
                                        : g.claySoft)),
                        foregroundColor: dark
                            ? Theme.of(context).colorScheme.onPrimary
                            : (g.merlot
                                  ? MerlotPalette.action
                                  : (g.frozen ? FrozenPalette.action : g.clay)),
                        side: dark
                            ? BorderSide.none
                            : BorderSide(
                                color: g.merlot
                                    ? MerlotPalette.lineSubtle
                                    : (g.frozen
                                          ? FrozenPalette.lineSubtle
                                          : g.line),
                                width: 0.75,
                              ),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        !hasStarted
                            ? 'Explore'
                            : active.isCompleted
                            ? 'Review'
                            : state.isPlaying
                            ? 'Pause'
                            : 'Resume',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (hasStarted) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'View Syllabus',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                StudyPlanScreen(courseId: course.id),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.format_list_bulleted_rounded,
                        color: g.inkSecondary,
                        size: 21,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
