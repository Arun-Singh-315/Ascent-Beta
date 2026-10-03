import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_hub_provider.dart';

class LectureFocusPlayerSheet extends ConsumerStatefulWidget {
  const LectureFocusPlayerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const LectureFocusPlayerSheet(),
    );
  }

  @override
  ConsumerState<LectureFocusPlayerSheet> createState() => _LectureFocusPlayerSheetState();
}

class _LectureFocusPlayerSheetState extends ConsumerState<LectureFocusPlayerSheet> {
  bool _switcherExpanded = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningHubProvider);
    final notifier = ref.read(learningHubProvider.notifier);
    final active = state.activeLecture;
    final activeMod = state.activeModule;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 1. Top Header Handle + Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 28),
                  onPressed: () => Navigator.pop(context),
                  color: context.textPrimary,
                ),
                Text(
                  'Lecture Focus Player',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: state.isPlaying
                        ? context.accentSecondary.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isPlaying ? context.accentSecondary : Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        state.isPlaying ? 'LIVE FOCUS' : 'PAUSED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: state.isPlaying ? context.accentSecondary : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1EFEA)),

          // Main scrollable player content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              children: [
                // Breadcrumbs
                Text(
                  '${state.course.title.toUpperCase()} / ${activeMod.title}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.accentPrimary,
                    letterSpacing: 0.4,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Lecture Title
                Text(
                  'Lecture ${active.id}: ${active.title}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    height: 1.25,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 14),

                // Progress slider
                Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: context.accentSecondary,
                        inactiveTrackColor: context.divider,
                        thumbColor: context.accentSecondary,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        trackHeight: 3.5,
                      ),
                      child: Slider(
                        value: state.progressFraction,
                        onChanged: (val) => notifier.seekTo(val),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            state.formattedElapsed,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: context.textMuted,
                            ),
                          ),
                          Text(
                            active.formattedDuration,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Circular countdown ring
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 170,
                        height: 170,
                        child: CircularProgressIndicator(
                          value: state.progressFraction,
                          strokeWidth: 9,
                          backgroundColor: const Color(0xFFF1EFEA),
                          color: context.accentSecondary,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.formattedRemaining,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: context.textPrimary,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'REMAINING',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.textMuted,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.accentSecondary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${state.progressPercent}% Completed',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.accentSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Playback Controls (-10s, Play/Pause, +10s)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(Icons.replay_10_rounded),
                      color: context.textPrimary,
                      onPressed: () => notifier.seekBy(-10),
                    ),
                    const SizedBox(width: 20),
                    InkWell(
                      onTap: () => notifier.togglePlayPause(),
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: context.accentSecondary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.accentSecondary.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          size: 38,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      iconSize: 34,
                      icon: const Icon(Icons.forward_10_rounded),
                      color: context.textPrimary,
                      onPressed: () => notifier.seekBy(10),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Mark Lecture Completed
                Center(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: active.isCompleted ? context.accentSecondary : context.divider,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () {
                      notifier.markLectureCompleted(active.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Lecture ${active.id} completed! Progress saved.'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(
                      active.isCompleted ? Icons.check_circle_rounded : Icons.check_rounded,
                      color: active.isCompleted ? context.accentSecondary : context.textPrimary,
                      size: 20,
                    ),
                    label: Text(
                      active.isCompleted ? 'Lecture Completed' : 'Mark Lecture Completed',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: active.isCompleted ? context.accentSecondary : context.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Swift Lecture Switcher Card
                Container(
                  decoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.divider.withValues(alpha: 0.8)),
                  ),
                  child: Column(
                    children: [
                      // Header
                      InkWell(
                        onTap: () {
                          setState(() {
                            _switcherExpanded = !_switcherExpanded;
                          });
                        },
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.playlist_play_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Swift Lecture Switcher',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: context.bgSurface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${state.course.totalLectures} Total',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: context.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Icon(
                                _switcherExpanded
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                color: context.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (_switcherExpanded) ...[
                        const Divider(height: 1, color: Color(0xFFF1EFEA)),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: state.course.modules.expand((m) => m.lectures).length,
                          itemBuilder: (context, index) {
                            final all = state.course.modules.expand((m) => m.lectures).toList();
                            final lec = all[index];
                            final isCurrent = lec.id == state.activeLectureId;

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? context.accentSecondary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isCurrent
                                    ? Border.all(color: context.accentSecondary.withValues(alpha: 0.4))
                                    : null,
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                leading: Container(
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCurrent
                                        ? context.accentSecondary
                                        : (lec.isCompleted
                                            ? context.accentPrimary.withValues(alpha: 0.2)
                                            : context.divider.withValues(alpha: 0.6)),
                                  ),
                                  child: Center(
                                    child: lec.isCompleted
                                        ? Icon(Icons.check, size: 14, color: context.accentPrimary)
                                        : Text(
                                            '${lec.id}',
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: isCurrent ? Colors.white : context.textPrimary,
                                            ),
                                          ),
                                  ),
                                ),
                                title: Text(
                                  lec.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                    color: context.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      lec.formattedDuration,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        color: isCurrent ? context.accentSecondary : context.textMuted,
                                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: isCurrent ? context.accentSecondary : context.textMuted,
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  notifier.selectLecture(lec.id, autoPlay: true);
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
