import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/glass_theme.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';

class LectureFocusPlayerScreen extends ConsumerStatefulWidget {
  const LectureFocusPlayerScreen({super.key});

  @override
  ConsumerState<LectureFocusPlayerScreen> createState() => _LectureFocusPlayerScreenState();
}

class _LectureFocusPlayerScreenState extends ConsumerState<LectureFocusPlayerScreen> {
  bool _modulesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final state = ref.watch(learningHubProvider);
    final notifier = ref.read(learningHubProvider.notifier);
    final active = state.activeLecture;
    final activeMod = state.activeModule;

    return AscentScaffold(
      title: 'Learning Hub Timer',
      subtitle: state.course.title.isNotEmpty ? state.course.title : 'Study Focus Session',
      glow2: g.slateSoft,
      actions: [
        IconButton(
          icon: Icon(Icons.format_list_bulleted_rounded, color: g.inkMuted),
          tooltip: 'Course Catalog',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.push('/study-plan');
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // 1. Live Focus Badge
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: state.isPlaying
                    ? g.sageSoft
                    : g.claySoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: state.isPlaying ? g.sage.withValues(alpha: 0.3) : g.clay.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isPlaying ? g.sage : g.clay,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    state.isPlaying ? 'LIVE STUDY FOCUS' : 'LECTURE PAUSED',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: state.isPlaying ? g.sage : g.clay,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Module & Lecture Heading
          Text(
            activeMod.title.isNotEmpty ? activeMod.title.toUpperCase() : 'COURSE LECTURE',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: g.slate,
              letterSpacing: 0.8,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            active.title.isNotEmpty ? active.title : 'Focus Study Session',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: g.ink,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // 3. Central Countdown Clock
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: g.fill,
                border: Border.all(color: g.edge),
                boxShadow: [
                  BoxShadow(
                    color: (state.isPlaying ? g.slate : g.clay).withValues(alpha: 0.12),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: state.progressFraction,
                      strokeWidth: 8,
                      backgroundColor: g.edge.withValues(alpha: 0.5),
                      color: state.isPlaying ? g.slate : g.clay,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.formattedRemaining,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: g.ink,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'REMAINING',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: g.inkMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: g.claySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.progressPercent}% Completed',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: g.clay,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 4. Progress Slider
          Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: g.slate,
                  inactiveTrackColor: g.edge,
                  thumbColor: g.slate,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  trackHeight: 4,
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
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: g.inkMuted, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      active.formattedDuration,
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: g.inkMuted, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 5. Primary Player Controls (-10s, Play/Pause, +10s)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                iconSize: 36,
                icon: const Icon(Icons.replay_10_rounded),
                color: g.ink,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.seekBy(-10);
                },
                tooltip: 'Rewind 10s',
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  if (state.isPlaying) {
                    notifier.pause();
                  } else {
                    notifier.play();
                  }
                },
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: g.clay,
                    boxShadow: [
                      BoxShadow(
                        color: g.clay.withValues(alpha: 0.4),
                        blurRadius: 18,
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
                iconSize: 36,
                icon: const Icon(Icons.forward_10_rounded),
                color: g.ink,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  notifier.seekBy(10);
                },
                tooltip: 'Forward 10s',
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 6. Complete Lecture Action
          AscentButton.primary(
            label: active.isCompleted ? 'Lecture Completed' : 'Mark Lecture Complete',
            icon: Icons.check_circle_outline_rounded,
            onPressed: () {
              HapticFeedback.heavyImpact();
              notifier.markLectureCompleted(active.id);
            },
          ),
          const SizedBox(height: 12),
          AscentButton.outlined(
            label: _modulesExpanded ? 'Hide Course Syllabus' : 'View Course Syllabus',
            icon: _modulesExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _modulesExpanded = !_modulesExpanded);
            },
          ),
          const SizedBox(height: 16),

          // 7. Expandable Module Syllabus
          if (_modulesExpanded) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: g.fill,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: g.edge),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COURSE CURRICULUM',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: g.inkMuted, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 10),
                  ...state.course.modules.expand((mod) => mod.lectures.map((lec) {
                    final isCurrent = lec.id == active.id;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        notifier.selectLecture(lec.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: isCurrent ? g.claySoft : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              lec.isCompleted
                                  ? Icons.check_circle_rounded
                                  : (isCurrent ? Icons.play_circle_fill_rounded : Icons.radio_button_unchecked_rounded),
                              size: 18,
                              color: lec.isCompleted
                                  ? g.sage
                                  : (isCurrent ? g.clay : g.inkMuted),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lec.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  color: isCurrent ? g.clay : g.ink,
                                ),
                              ),
                            ),
                            Text(
                              lec.formattedDuration,
                              style: TextStyle(fontSize: 11, color: g.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    );
                  })),
                ],
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
