import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';

class FlowResumeCard extends ConsumerWidget {
  const FlowResumeCard({super.key});

  String _formatSeconds(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learningState = ref.watch(learningHubProvider);
    final trackingState = ref.watch(timeTrackingProvider);

    final activeLecture = learningState.activeLecture;
    final activeModule = learningState.activeModule;
    final lectureElapsed = learningState.currentElapsedSeconds;
    final lectureDuration = activeLecture.durationSeconds;
    final hasLectureProgress = lectureElapsed > 0 || learningState.hasStartedLearning;

    final activeSession = trackingState.activeSession;
    final hasActiveTaskSession = activeSession != null;

    final accentOrange = const Color(0xFFE28B57);
    final accentEmerald = const Color(0xFF38664D);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B241E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentOrange.withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentOrange.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flash_on_rounded, size: 16, color: accentOrange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FLOW MOMENTUM LOCKED IN',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: accentOrange,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Ready to return to focus?',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Exact spot saved',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 1. Lecture Focus Resume Option
          if (hasLectureProgress) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF382E26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school_rounded, size: 15, color: Color(0xFFE28B57)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${activeModule.title} • ${activeLecture.title}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Paused at ${_formatSeconds(lectureElapsed)} / ${_formatSeconds(lectureDuration)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: const Color(0xFFE28B57),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${learningState.progressPercent}% finished',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: learningState.progressFraction,
                      minHeight: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFE28B57)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentOrange,
                  foregroundColor: const Color(0xFF120E0A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  'Resume Lecture at ${_formatSeconds(lectureElapsed)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  // 1. Resume lecture right from exact elapsed second
                  ref.read(learningHubProvider.notifier).play();
                  // 2. Pop break screen
                  Navigator.of(context).pop();
                  // 3. Open lecture focus player sheet
                  LectureFocusPlayerSheet.show(context);
                },
              ),
            ),
          ],

          // 2. Task Session Resume Option (if task timer is running/paused)
          if (hasActiveTaskSession) ...[
            if (hasLectureProgress) const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF382E26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accentEmerald.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.timer_rounded, size: 16, color: Color(0xFF78CCA0)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeSession.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Timer paused at ${trackingState.formattedTime}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: const Color(0xFF78CCA0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Resume Timer'),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(timeTrackingProvider.notifier).resumeSession();
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ],

          // 3. If no lecture or task was running yet
          if (!hasLectureProgress && !hasActiveTaskSession) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentOrange,
                  foregroundColor: const Color(0xFF120E0A),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
                label: Text(
                  'Start Flow: ${learningState.course.title}',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref.read(learningHubProvider.notifier).startLearning();
                  ref.read(learningHubProvider.notifier).play();
                  Navigator.of(context).pop();
                  LectureFocusPlayerSheet.show(context);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
