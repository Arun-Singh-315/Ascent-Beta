import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_card.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';
import '../../study_plan/study_plan_screen.dart';

class LearningHubCard extends ConsumerWidget {
  const LearningHubCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(learningHubProvider);
    final course = state.course;
    final active = state.activeLecture;
    final activeMod = state.activeModule;
    final isLive = state.isPlaying || state.isLiveFocusActive;

    if (!state.hasStartedLearning) {
      return _buildStartLearningCard(context, ref);
    }

    if (isLive) {
      // ── Rich Expanded Active Lecture Container ────────────────────────
      return Container(
        decoration: BoxDecoration(
          color: context.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: context.accentSecondary.withValues(alpha: 0.6),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.accentSecondary.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Live Focus Badge & View Hub CTA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/study-plan');
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: state.isPlaying ? context.accentSecondary : context.stateWarning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          state.isPlaying ? 'LIVE LECTURE IN PROGRESS' : 'LECTURE PAUSED',
                          style: GoogleFonts.jetBrainsMono(
                            color: state.isPlaying ? context.accentSecondary : context.stateWarning,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/study-plan');
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.bgBase,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: context.divider.withValues(alpha: 0.8),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'View Hub',
                            style: GoogleFonts.plusJakartaSans(
                              color: context.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 10,
                            color: context.accentSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Course & Module Hierarchy
            InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push('/study-plan');
              },
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${course.title} • ${activeMod.title}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 3),

            // Lecture Title
            Text(
              'Lecture ${active.id}: ${active.title}',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: state.progressFraction,
                minHeight: 6,
                backgroundColor: context.bgBase,
                valueColor: AlwaysStoppedAnimation<Color>(context.accentSecondary),
              ),
            ),
            const SizedBox(height: 6),

            // Elapsed / Remaining Time Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${state.formattedElapsed} / ${active.formattedDuration}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: state.isPlaying ? context.accentSecondary : context.textPrimary,
                  ),
                ),
                Text(
                  '${state.formattedRemaining} left (${state.progressPercent}%)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Interactive Controls Row
            Row(
              children: [
                IconButton(
                  tooltip: 'Rewind 15s',
                  icon: const Icon(Icons.replay_10_rounded, size: 20),
                  color: context.textPrimary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(learningHubProvider.notifier).seekBy(-15);
                  },
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.isPlaying
                          ? context.stateWarning
                          : context.accentPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(
                      state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 18,
                    ),
                    label: Text(
                      state.isPlaying ? 'Pause' : 'Resume Focus',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(learningHubProvider.notifier).togglePlayPause();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Forward 15s',
                  icon: const Icon(Icons.forward_10_rounded, size: 20),
                  color: context.textPrimary,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(learningHubProvider.notifier).seekBy(15);
                  },
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Open Full Player Sheet',
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                  color: context.textMuted,
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    LectureFocusPlayerSheet.show(context);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }

    return AscentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LEARNING HUB',
                    style: GoogleFonts.jetBrainsMono(
                      color: context.accentSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/study-plan'),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'View all courses ›',
                    style: TextStyle(
                      color: context.accentSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Course Title
          InkWell(
            onTap: () => context.push('/study-plan'),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    course.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${course.progressPercent}% done',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.accentSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Slim Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: course.progressFraction,
              minHeight: 4.5,
              backgroundColor: context.bgBase,
              valueColor: AlwaysStoppedAnimation<Color>(context.accentSecondary),
            ),
          ),
          const SizedBox(height: 8),

          // Up Next Lecture Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.bgBase,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.divider, width: 0.7),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.accentSecondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'NEXT #${active.id}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: context.accentSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    active.title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  active.formattedDuration,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons: Resume + Syllabus
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                  label: Text(
                    'Continue Lecture ${active.id}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(learningHubProvider.notifier).play();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: context.divider),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
                  ),
                  icon: const Icon(Icons.format_list_bulleted_rounded, size: 14),
                  label: Text(
                    'Syllabus',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => StudyPlanScreen(courseId: course.id),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Open Focus Player',
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                color: context.textMuted,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  LectureFocusPlayerSheet.show(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartLearningCard(BuildContext context, WidgetRef ref) {
    return AscentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'LEARNING HUB',
                    style: GoogleFonts.jetBrainsMono(
                      color: context.accentSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/study-plan');
                },
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    'Explore catalog ›',
                    style: TextStyle(
                      color: context.accentSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Start Learning',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'You haven\'t started a course yet. Choose a track from Spring Boot, System Design, or DSA to begin your structured practice.',
            style: AscentTextStyles.bodySmall.copyWith(
              color: context.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          AscentButton.primary(
            label: 'Start Learning & Select Course',
            icon: Icons.rocket_launch_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/study-plan');
            },
          ),
        ],
      ),
    );
  }
}
