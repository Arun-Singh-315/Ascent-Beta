import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/glass_theme.dart';
import '../thought_wall/drop_thought_sheet.dart';
import 'chai_break_provider.dart';
import 'widgets/ambient_soundscape_bar.dart';
import 'widgets/brew_with_me_view.dart';
import 'widgets/flow_resume_card.dart';
import 'widgets/mindful_breathing_guide.dart';
import 'widgets/steaming_cup_painter.dart';

class ChaiBreakScreen extends ConsumerStatefulWidget {
  const ChaiBreakScreen({super.key});

  @override
  ConsumerState<ChaiBreakScreen> createState() => _ChaiBreakScreenState();
}

class _ChaiBreakScreenState extends ConsumerState<ChaiBreakScreen> {
  int _quoteIndex = 0;
  Timer? _quoteTimer;
  bool _isBrewWithMe = false;

  static const _mindfulQuotes = [
    'Take a slow sip. Let your eyes wander away from the screen.',
    'Relax your shoulders. Unclench your jaw. Breathe deeply.',
    'You are doing better than you realize. Enjoy this warm pause.',
    'Rest is not a reward; it is an essential part of the work.',
    'One conscious breath in, one slow exhale out.',
    'Small calm pauses fuel big, sustained breakthroughs.',
  ];

  @override
  void initState() {
    super.initState();
    _quoteTimer = Timer.periodic(const Duration(seconds: 14), (_) {
      if (mounted) {
        setState(() {
          _quoteIndex = (_quoteIndex + 1) % _mindfulQuotes.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _quoteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chaiBreakProvider);
    final notifier = ref.read(chaiBreakProvider.notifier);
    final accentColor = state.selectedSoundscape == SoundscapePreset.customSystemAudio
        ? const Color(0xFF10B981)
        : Color(state.selectedSoundscape.accentColorHex);
    final g = context.glass;

    return Scaffold(
      backgroundColor: g.bg,
      body: Container(
        decoration: BoxDecoration(
          color: g.bg,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, color: g.ink, size: 20),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      tooltip: 'Back',
                    ),
                    Row(
                      children: [
                        Icon(Icons.coffee_rounded, color: g.clay, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'CHAI & COFFEE BREAK',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: g.ink,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        state.isBreathingGuideEnabled
                            ? Icons.spa_rounded
                            : Icons.spa_outlined,
                        color: state.isBreathingGuideEnabled
                            ? g.clay
                            : g.inkMuted,
                        size: 22,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        notifier.toggleBreathingGuide();
                      },
                      tooltip: 'Toggle breathing guide',
                    ),
                  ],
                ),
              ),

              // Scrollable Body
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    // Mode Switcher (Mindful Pause vs Brew With Me)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: g.fill,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: g.edge),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (_isBrewWithMe) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _isBrewWithMe = false);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !_isBrewWithMe
                                      ? g.claySoft
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !_isBrewWithMe
                                        ? g.clay
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.spa_rounded,
                                      size: 16,
                                      color: !_isBrewWithMe ? g.clay : g.inkMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Mindful Pause',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: !_isBrewWithMe ? FontWeight.w700 : FontWeight.w500,
                                        color: !_isBrewWithMe ? g.ink : g.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                if (!_isBrewWithMe) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _isBrewWithMe = true);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _isBrewWithMe
                                      ? g.claySoft
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _isBrewWithMe
                                        ? g.clay
                                        : Colors.transparent,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.coffee_maker_rounded,
                                      size: 16,
                                      color: _isBrewWithMe ? g.clay : g.inkMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Brew With Me',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12.5,
                                        fontWeight: _isBrewWithMe ? FontWeight.w700 : FontWeight.w500,
                                        color: _isBrewWithMe ? g.ink : g.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Smart Flow Resume Card (Prominently placed at the top so user never has to scroll!)
                    const FlowResumeCard(),

                    const SizedBox(height: 16),

                    if (_isBrewWithMe) ...[
                      const BrewWithMeView(),
                    ] else ...[
                      // Duration Preset Pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PresetChip(
                            label: '5m Chai',
                            minutes: 5,
                            isSelected: state.totalDurationSeconds == 300,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setPresetMinutes(5);
                            },
                          ),
                          const SizedBox(width: 8),
                          _PresetChip(
                            label: '10m Coffee',
                            minutes: 10,
                            isSelected: state.totalDurationSeconds == 600,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setPresetMinutes(10);
                            },
                          ),
                          const SizedBox(width: 8),
                          _PresetChip(
                            label: '15m Reset',
                            minutes: 15,
                            isSelected: state.totalDurationSeconds == 900,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setPresetMinutes(15);
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Center Animated Steaming Cup
                      Center(
                        child: SteamingCupWidget(
                          isRunning: state.isRunning,
                          accentColor: accentColor,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Big Countdown Timer
                      Center(
                        child: Column(
                          children: [
                            Text(
                              state.formattedRemaining,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'remaining of ${state.totalDurationSeconds ~/ 60} minutes mindful break',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Mindful Breathing Guide (if enabled)
                      if (state.isBreathingGuideEnabled) ...[
                        MindfulBreathingGuide(
                          phase: state.breathPhase,
                          isRunning: state.isRunning,
                          accentColor: accentColor,
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Play / Pause / Reset Controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            iconSize: 22,
                            icon: const Icon(Icons.replay_rounded, color: Colors.white60),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              notifier.setPresetMinutes(state.totalDurationSeconds ~/ 60);
                            },
                            tooltip: 'Reset break timer',
                          ),
                          const SizedBox(width: 14),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                notifier.togglePlayPause();
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.7),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      state.isRunning ? 'Pause' : 'Resume',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          IconButton(
                            iconSize: 22,
                            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.white60),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop();
                            },
                            tooltip: 'Finish break early',
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Ambient Soundscape Bar
                    AmbientSoundscapeBar(
                      selectedSoundscape: state.selectedSoundscape,
                      isPlaying: state.isRunning,
                      isMuted: state.isAudioMuted,
                      customAudioName: state.customAudioName,
                      volume: state.volume,
                      onToggleMute: notifier.toggleAudioMute,
                      onSoundscapeChanged: (s) => notifier.selectSoundscape(s),
                      onPickCustomAudio: notifier.pickCustomAudioFile,
                      onClearCustomAudio: notifier.clearCustomAudio,
                      onVolumeChanged: notifier.setVolume,
                    ),

                    const SizedBox(height: 20),

                    // Mindful Quote / Reflection
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.format_quote_rounded, color: Color(0xFFE28B57), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                _mindfulQuotes[_quoteIndex],
                                key: ValueKey(_quoteIndex),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12.5,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white70,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_note_rounded, color: Colors.white54, size: 20),
                            onPressed: () => DropThoughtSheet.show(context),
                            tooltip: 'Drop a thought into Thought Wall',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final int minutes;
  final bool isSelected;
  final VoidCallback onTap;

  const _PresetChip({
    required this.label,
    required this.minutes,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFE28B57).withValues(alpha: 0.22)
                : const Color(0xFF222832),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFE28B57)
                  : Colors.white.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? const Color(0xFFE28B57) : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}
