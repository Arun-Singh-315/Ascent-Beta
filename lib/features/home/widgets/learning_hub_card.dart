import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';

/// A sleek, lightweight Apple-style learning player card on the Ascent Home screen.
/// Composed with balanced spacing, clean typography, dynamic playback controls,
/// and a refined timeline scrubber.
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
    final textScaler = MediaQuery.textScalerOf(context);
    final isScaled = textScaler.scale(14) > 20;

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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 1. COMPACT CARD HEADER ──
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: BorderRadius.circular(AppRadius.iconChip),
                ),
                child: Icon(
                  Icons.auto_stories_rounded,
                  size: 16,
                  color: c.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Learning',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                ),
              ),
              if (hasStarted) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.border.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '$displayPosition/${lectures.length}',
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              InkResponse(
                onTap: openPlayer,
                radius: 18,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),

          if (!hasStarted) ...[
            // ── 2A. NOT STARTED STATE (CENTERED) ──
            const SizedBox(height: 16),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accentTint,
                    ),
                    child: Icon(
                      Icons.school_outlined,
                      size: 22,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Start learning',
                    key: const ValueKey('home_learning_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.title.isNotEmpty
                        ? course.title
                        : 'Explore courses in your study plan',
                    key: const ValueKey('home_learning_course'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: openPlayer,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                    label: const Text(
                      'Start Lesson',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── 2B. ACTIVE SLEEK MEDIA PLAYER ──
            const SizedBox(height: 12),

            // Top Row: Lecture Info + Action Button
            if (isScaled) ...[
              // High accessibility scale vertical stack
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title.toUpperCase(),
                    key: const ValueKey('home_learning_course'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    active.title,
                    key: const ValueKey('home_learning_title'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Lesson $displayPosition · ${(state.remainingSeconds / 60).ceil()} min left',
                    key: const ValueKey('home_learning_position'),
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(c, active, state, resume),
                ],
              ),
            ] else ...[
              // Standard balanced horizontal layout
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sleek mini artwork squircle
                  GestureDetector(
                    onTap: openPlayer,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: c.accentTint,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: c.accent.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          state.isPlaying
                              ? Icons.graphic_eq_rounded
                              : Icons.headphones_rounded,
                          size: 20,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Middle Lecture Title & Eyebrow
                  Expanded(
                    child: GestureDetector(
                      onTap: openPlayer,
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.title.toUpperCase(),
                            key: const ValueKey('home_learning_course'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: c.accent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            active.title,
                            key: const ValueKey('home_learning_title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Lesson $displayPosition · ${(state.remainingSeconds / 60).ceil()} min left',
                            key: const ValueKey('home_learning_position'),
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Action Button
                  _buildActionButton(c, active, state, resume),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Continuous Scrubber Track
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: progressFraction),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 3.5,
                  backgroundColor: c.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(c.accent),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Monospace Timestamps
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  state.formattedElapsed,
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                Text(
                  '-${state.formattedRemaining}',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
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

  Widget _buildActionButton(
    AppColors c,
    dynamic active,
    dynamic state,
    VoidCallback resume,
  ) {
    final String label = active.isCompleted
        ? 'Review'
        : (state.isPlaying ? 'Pause' : 'Resume');
    final IconData icon = active.isCompleted
        ? Icons.replay_rounded
        : (state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: resume,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: state.isPlaying
                ? c.accentTint
                : c.accent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: state.isPlaying
                  ? c.accent.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: state.isPlaying ? c.accent : Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: state.isPlaying ? c.accent : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
