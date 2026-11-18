import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';

/// An iOS media-player style learning card on the Ascent Home screen.
/// Features an enclosed glass card with rich typography, timeline scrubber, and tactile transport controls.
class LearningHubCard extends ConsumerWidget {
  const LearningHubCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
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

    final progressFraction = state.progressFraction.clamp(0.0, 1.0);

    return Container(
      key: const ValueKey('home_learning_card'),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.border.withValues(alpha: 0.7), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: c.warmShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. UNIFIED CARD HEADER ──
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: BorderRadius.circular(AppRadius.iconChip),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 18,
                  color: c.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Learning',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                ),
              ),
              if (hasStarted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.border.withValues(alpha: 0.6)),
                  ),
                  child: Text(
                    '$displayPosition of ${lectures.length}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              InkResponse(
                onTap: openPlayer,
                radius: 20,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          if (!hasStarted) ...[
            // ── 2A. NOT STARTED STATE ──
            const SizedBox(height: 20),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accentTint,
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 26,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start learning',
                    key: const ValueKey('home_learning_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.title.isNotEmpty
                        ? course.title
                        : 'Explore courses in your study plan',
                    key: const ValueKey('home_learning_course'),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: openPlayer,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text(
                      'Start Lesson',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── 2B. ACTIVE MEDIA-PLAYER STATE ──
            const SizedBox(height: 16),

            // Course Title (Eyebrow Tag)
            Text(
              course.title.toUpperCase(),
              key: const ValueKey('home_learning_course'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),

            // Lecture Title
            Text(
              active.title,
              key: const ValueKey('home_learning_title'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                letterSpacing: -0.3,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 4),

            // Meta description
            Text(
              'Lesson $displayPosition of ${lectures.length} · ${course.completedLectures} completed · ${(state.remainingSeconds / 60).ceil()} min left',
              key: const ValueKey('home_learning_position'),
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),

            // Apple-style Continuous Scrubber Track
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progressFraction),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: c.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // JetBrains Mono Timestamps
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.formattedElapsed,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                Text(
                  '-${state.formattedRemaining}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Transport Controls Row (Tactile, minimal, Apple Media Player style)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Replay 10s
                IconButton(
                  tooltip: 'Replay 10s',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(learningHubProvider.notifier).seekBy(-10);
                  },
                  icon: Icon(Icons.replay_10_rounded, size: 22, color: c.textPrimary),
                ),
                const SizedBox(width: 18),

                // Center Play/Pause Primary button
                GestureDetector(
                  onTap: resume,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent,
                      boxShadow: [
                        BoxShadow(
                          color: c.accent.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      state.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 18),

                // Forward 10s
                IconButton(
                  tooltip: 'Forward 10s',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(learningHubProvider.notifier).seekBy(10);
                  },
                  icon: Icon(Icons.forward_10_rounded, size: 22, color: c.textPrimary),
                ),
                const SizedBox(width: 14),

                // Syllabus/queue button
                IconButton(
                  tooltip: 'View Syllabus',
                  onPressed: openPlayer,
                  icon: Icon(
                    Icons.queue_music_rounded,
                    size: 20,
                    color: c.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
