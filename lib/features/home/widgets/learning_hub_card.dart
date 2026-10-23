import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/merlot_palette.dart';
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                'Learning',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/study-plan'),
                child: Text(hasStarted ? 'Switch course' : 'Catalog'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GlassSurface(
          radius: 22,
          enableBlur: false,
          fillColor: dark
              ? null
              : (g.merlot
                    ? MerlotPalette.surface
                    : (g.frozen ? FrozenPalette.surface : Colors.white)),
          customBorder: dark
              ? null
              : Border.all(
                  color: g.merlot
                      ? MerlotPalette.line
                      : (g.frozen
                            ? FrozenPalette.line
                            : g.edge.withValues(alpha: 0.45)),
                  width: 1.0,
                ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Tooltip(
                message: hasStarted ? active.title : 'Explore learning courses',
                child: InkWell(
                  onTap: openPlayer,
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                hasStarted
                                    ? course.title
                                    : 'Pick your next course',
                                key: const ValueKey('home_learning_course'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: g.inkSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            if (hasStarted) ...[
                              const SizedBox(width: 8),
                              Text(
                                '${position + 1}/${lectures.length}',
                                key: const ValueKey('home_learning_position'),
                                style: TextStyle(
                                  color: g.clay,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 16,
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
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: state.progressFraction.clamp(0.0, 1.0),
                    minHeight: 6,
                    color: g.clay,
                    backgroundColor: g.track,
                    semanticsLabel: 'Lecture progress',
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
                        fontSize: 15,
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
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
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
