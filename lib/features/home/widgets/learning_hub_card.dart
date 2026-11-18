import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/home_design.dart';
import '../../../app/theme/merlot_palette.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';
import 'home_outline_surface.dart';
import 'home_section_heading.dart';

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
    final displayPosition = position >= 0 ? position + 1 : 1;

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

    Widget buildExploreButton() {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final isMerlot = g.merlot;
      final isFrozen = g.frozen;

      Color bg;
      Color fg;
      if (isDark) {
        bg = isMerlot
            ? MerlotPalette.action
            : (isFrozen ? FrozenPalette.action : g.ink);
        fg = isMerlot
            ? MerlotPalette.darkCanvas
            : (isFrozen ? FrozenPalette.darkCanvas : g.bg);
      } else {
        bg = isMerlot
            ? MerlotPalette.pillSoft
            : (isFrozen ? FrozenPalette.pillSoft : g.ink.withValues(alpha: 0.08));
        fg = isMerlot
            ? MerlotPalette.action
            : (isFrozen ? FrozenPalette.action : g.ink);
      }

      return FilledButton(
        onPressed: openPlayer,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('Explore'),
      );
    }

    if (!hasStarted) {
      return Padding(
        key: const ValueKey('home_learning_card'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeSectionHeading(
              title: 'Learning',
              trailing: HomeSectionArrowButton(
                tooltip: 'Explore courses',
                color: HomeDesign.of(context).learningInk,
                onTap: openPlayer,
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: openPlayer,
              borderRadius: BorderRadius.circular(24),
              child: HomeOutlineSurface(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: g.ink.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_stories_outlined,
                            color: HomeDesign.of(context).learningInk,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Start learning',
                                key: const ValueKey('home_learning_title'),
                                style: AscentTextStyles.interfaceSection.copyWith(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                  color: g.ink,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Choose a course · Track lessons and resume here',
                                key: const ValueKey('home_learning_course'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: g.inkMuted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    buildExploreButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      key: const ValueKey('home_learning_card'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeading(
            title: 'Learning',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Switch course',
                  icon: Icon(Icons.swap_horiz_rounded, color: g.ink),
                  onPressed: () => context.push('/study-plan'),
                ),
                HomeSectionArrowButton(
                  tooltip: 'Open study plan',
                  color: HomeDesign.of(context).learningInk,
                  onTap: () => context.push('/study-plan'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: openPlayer,
            borderRadius: BorderRadius.circular(24),
            child: HomeOutlineSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top badge & position counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: g.ink.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_stories_outlined,
                                size: 13,
                                color: HomeDesign.of(context).learningInk,
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  course.title,
                                  key: const ValueKey('home_learning_course'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: g.inkSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Badge with exact position count (e.g. 2/5000)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$displayPosition/${lectures.length}',
                              style: TextStyle(
                                color: g.inkMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 11,
                              color: g.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Lecture Title
                  Text(
                    active.title,
                    key: const ValueKey('home_learning_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.interfaceSection.copyWith(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      color: g.ink,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Concise meta description
                  Text(
                    'Lesson $displayPosition of ${lectures.length} · ${course.completedLectures} completed',
                    key: const ValueKey('home_learning_position'),
                    style: TextStyle(
                      color: g.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Progress Indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: state.progressFraction.clamp(0.0, 1.0),
                      minHeight: 5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF7BA0C6)
                          : const Color(0xFF4A7097),
                      backgroundColor: g.ink.withValues(alpha: 0.08),
                      semanticsLabel: 'Lecture progress',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Footer: Status label & Action button
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        active.isCompleted
                            ? 'Lesson completed'
                            : '${state.formattedElapsed} studied · ${(state.remainingSeconds / 60).ceil()} min left',
                        style: TextStyle(
                          color: g.inkSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
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
            ),
          ),
        ],
      ),
    );
  }
}
