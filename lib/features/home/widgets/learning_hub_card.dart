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

/// An iOS media-player style learning card on the Ascent Home screen.
/// Features a minimal, high-contrast, structured player layout with timeline scrubber.
class LearningHubCard extends ConsumerWidget {
  const LearningHubCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

      return FilledButton.icon(
        onPressed: openPlayer,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          minimumSize: const Size(0, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 18),
        label: const Text('Explore'),
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
              borderRadius: BorderRadius.circular(22),
              child: HomeOutlineSurface(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Media player idle badge
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: g.ink.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_stories_outlined,
                              size: 13,
                              color: HomeDesign.of(context).learningInk,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'READY TO STUDY',
                              style: TextStyle(
                                color: g.inkSecondary,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Start learning',
                      key: const ValueKey('home_learning_title'),
                      textAlign: TextAlign.center,
                      style: AscentTextStyles.interfaceSection.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: g.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose a course · Track lessons and resume here',
                      key: const ValueKey('home_learning_course'),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(child: buildExploreButton()),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── NOW STUDYING / MEDIA PLAYER CARD ──
    final progressFraction = state.progressFraction.clamp(0.0, 1.0);

    return Padding(
      key: const ValueKey('home_learning_card'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeading(
            title: 'Learning',
            trailing: HomeSectionArrowButton(
              tooltip: 'Open study plan',
              color: HomeDesign.of(context).learningInk,
              onTap: () => context.push('/study-plan'),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: openPlayer,
            borderRadius: BorderRadius.circular(22),
            child: HomeOutlineSurface(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top row: Track course badge & exact position pill
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: g.ink.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: g.ink.withValues(alpha: 0.10),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                state.isPlaying
                                    ? Icons.graphic_eq_rounded
                                    : Icons.auto_stories_outlined,
                                size: 12.5,
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
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Position counter pill (e.g. 2/5000)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: g.ink.withValues(alpha: 0.10),
                          ),
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
                              size: 10,
                              color: g.inkMuted,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 2. Big bold Lecture Title
                  Text(
                    active.title,
                    key: const ValueKey('home_learning_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.interfaceSection.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: g.ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 3. Concise meta description
                  Text(
                    'Lesson $displayPosition of ${lectures.length} · ${course.completedLectures} completed',
                    key: const ValueKey('home_learning_position'),
                    style: TextStyle(
                      color: g.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. Slim progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(end: progressFraction),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: g.ink.withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          HomeDesign.of(context).learningInk,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. Media Player Controls Row: Progress % & Sleek Action
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: g.ink.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(progressFraction * 100).toInt()}%',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: g.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            active.isCompleted
                                ? 'Lesson completed'
                                : (state.isPlaying
                                      ? 'Studying now'
                                      : '${(state.remainingSeconds / 60).ceil()} min left'),
                            style: TextStyle(
                              color: g.inkSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
