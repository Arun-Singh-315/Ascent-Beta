import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';

/// Bottom action bar docked at the base of the Chai & Coffee Break screen.
/// Docks destination buttons to take the user directly back to their learning
/// or todo/focus timer without cluttering clock digits or requiring scrolling.
class ChaiBreakResumeDock extends ConsumerWidget {
  const ChaiBreakResumeDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learningState = ref.watch(learningHubProvider);
    final trackingState = ref.watch(timeTrackingProvider);

    final activeLecture = learningState.activeLecture;
    final activeModule = learningState.activeModule;
    final hasLectureProgress = learningState.currentElapsedSeconds > 0 || learningState.hasStartedLearning;

    final activeSession = trackingState.activeSession;
    final hasActiveTaskSession = activeSession != null;

    if (!hasLectureProgress && !hasActiveTaskSession) {
      return const SizedBox.shrink();
    }

    final accentOrange = const Color(0xFFE28B57);
    final accentEmerald = const Color(0xFF2E7D56);

    Widget buildLearningButton({required bool isCompact}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.mediumImpact();
            ref.read(learningHubProvider.notifier).play();
            Navigator.of(context).pop();
            LectureFocusPlayerSheet.show(context);
          },
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16, vertical: 10),
            decoration: BoxDecoration(
              color: accentOrange,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.play_arrow_rounded, color: Color(0xFF1E140C), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${activeModule.title} • ${activeLecture.title}',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF332014),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Go to Learning',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF120E0A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget buildTaskButton({required bool isCompact}) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(timeTrackingProvider.notifier).resumeSession();
            Navigator.of(context).pop();
          },
          child: Ink(
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 16, vertical: 10),
            decoration: BoxDecoration(
              color: accentEmerald,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeSession!.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Go to Todo',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
        child: (hasLectureProgress && hasActiveTaskSession)
            ? Row(
                children: [
                  Expanded(child: buildLearningButton(isCompact: true)),
                  const SizedBox(width: 10),
                  Expanded(child: buildTaskButton(isCompact: true)),
                ],
              )
            : (hasLectureProgress
                ? buildLearningButton(isCompact: false)
                : buildTaskButton(isCompact: false)),
      ),
    );
  }
}
