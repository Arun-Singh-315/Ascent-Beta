import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../thought_wall/drop_thought_sheet.dart';
import 'chai_break_provider.dart';
import 'widgets/ambient_soundscape_bar.dart';
import 'widgets/brew_with_me_view.dart';
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
    const accentColor = AppPalette.colorFF6B3A1C;
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: g.bg,
      body: AppCard(
        nightDecoration: BoxDecoration(color: g.bg),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: AppSpace.s10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: g.ink,
                        size: 20,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      tooltip: 'Back',
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.coffee_rounded, color: g.clay, size: 18),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Chai & Coffee',
                              style: AppTypography.plusJakartaSans13W70016(
                                color: g.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s20,
                    vertical: AppSpace.s8,
                  ),
                  children: [
                    // Mode Switcher (Mindful Pause vs Brew With Me)
                    AppCard(
                      padding: const EdgeInsets.all(AppSpace.s4),
                      nightDecoration: BoxDecoration(
                        color: g.fill,
                        borderRadius: AppGeometry.roundedr16,
                        border: Border.all(color: g.edge),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTapArea(
                              onTap: () {
                                if (_isBrewWithMe) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _isBrewWithMe = false);
                                }
                              },
                              borderRadius: AppGeometry.roundedr12,
                              child: AppCard(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.s12,
                                ),
                                alignment: Alignment.center,
                                nightDecoration: BoxDecoration(
                                  color: !_isBrewWithMe
                                      ? g.claySoft
                                      : AppPalette.transparent,
                                  borderRadius: AppGeometry.roundedr12,
                                  border: Border.all(
                                    color: !_isBrewWithMe
                                        ? g.clay
                                        : AppPalette.transparent,
                                    width: AppBorderScale.w1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.spa_rounded,
                                      size: 16,
                                      color: !_isBrewWithMe
                                          ? g.clay
                                          : g.inkMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Mindful Pause',
                                        style: AppStateTypography.stateType9(
                                          state0: !_isBrewWithMe,
                                          color: !_isBrewWithMe
                                              ? g.ink
                                              : g.inkMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: AppTapArea(
                              onTap: () {
                                if (!_isBrewWithMe) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _isBrewWithMe = true);
                                }
                              },
                              borderRadius: AppGeometry.roundedr12,
                              child: AppCard(
                                constraints: const BoxConstraints(
                                  minHeight: 48,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.s12,
                                ),
                                alignment: Alignment.center,
                                nightDecoration: BoxDecoration(
                                  color: _isBrewWithMe
                                      ? g.claySoft
                                      : AppPalette.transparent,
                                  borderRadius: AppGeometry.roundedr12,
                                  border: Border.all(
                                    color: _isBrewWithMe
                                        ? g.clay
                                        : AppPalette.transparent,
                                    width: AppBorderScale.w1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.coffee_maker_rounded,
                                      size: 16,
                                      color: _isBrewWithMe
                                          ? g.clay
                                          : g.inkMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Brew With Me',
                                        style: AppStateTypography.stateType9(
                                          state0: _isBrewWithMe,
                                          color: _isBrewWithMe
                                              ? g.ink
                                              : g.inkMuted,
                                        ),
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

                    const SizedBox(height: 12),
                    Text(
                      _isBrewWithMe
                          ? 'Follow a gentle guide while you make your drink.'
                          : 'Choose a short pause, breathe and enjoy your drink.',
                      textAlign: TextAlign.center,
                      style: AppTypography.plusJakartaSans13Regular18(
                        color: g.inkMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_isBrewWithMe) ...[
                      const BrewWithMeView(),
                    ] else ...[
                      // Duration presets wrap comfortably at larger text sizes.
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
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
                          _PresetChip(
                            label: '10m Coffee',
                            minutes: 10,
                            isSelected: state.totalDurationSeconds == 600,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              notifier.setPresetMinutes(10);
                            },
                          ),
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
                              style: AppTypography.jetBrainsMono48W70019(
                                color: isDark ? AppPalette.white : g.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'remaining of ${state.totalDurationSeconds ~/ 60} minutes mindful break',
                              style: AppTypography.plusJakartaSans12W50020(
                                color: isDark ? AppPalette.white54 : g.inkMuted,
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
                            icon: Icon(
                              Icons.replay_rounded,
                              color: isDark ? AppPalette.white60 : g.inkMuted,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              notifier.setPresetMinutes(
                                state.totalDurationSeconds ~/ 60,
                              );
                            },
                            tooltip: 'Reset break timer',
                          ),
                          const SizedBox(width: 14),
                          Material(
                            color: AppPalette.transparent,
                            child: AppTapArea(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                notifier.togglePlayPause();
                              },
                              borderRadius: AppGeometry.roundedr30,
                              child: AppCard(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.s24,
                                  vertical: AppSpace.s12,
                                ),
                                nightDecoration: BoxDecoration(
                                  color: accentColor.withValues(
                                    alpha: isDark ? 0.22 : 0.16,
                                  ),
                                  borderRadius: AppGeometry.roundedr30,
                                  border: Border.all(
                                    color: accentColor.withValues(
                                      alpha: isDark ? 0.7 : 0.8,
                                    ),
                                    width: AppBorderScale.w1point2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      state.isRunning
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: isDark ? AppPalette.white : g.ink,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      state.isRunning ? 'Pause' : 'Resume',
                                      style:
                                          AppTypography.plusJakartaSans14W70021(
                                            color: isDark
                                                ? AppPalette.white
                                                : g.ink,
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
                            icon: Icon(
                              Icons.check_circle_outline_rounded,
                              color: isDark ? AppPalette.white60 : g.inkMuted,
                            ),
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
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s16,
                        vertical: AppSpace.s12,
                      ),
                      nightDecoration: BoxDecoration(
                        color: isDark
                            ? AppPalette.white.withValues(alpha: 0.04)
                            : AppPalette.black.withValues(alpha: 0.03),
                        borderRadius: AppGeometry.roundedr14,
                        border: Border.all(
                          color: isDark
                              ? AppPalette.white.withValues(alpha: 0.08)
                              : AppPalette.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.format_quote_rounded,
                            color: AppPalette.colorFFE28B57,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              child: Text(
                                _mindfulQuotes[_quoteIndex],
                                key: ValueKey(_quoteIndex),
                                style: AppTypography.plusJakartaSans14Regular22(
                                  color: isDark ? AppPalette.white70 : g.ink,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit_note_rounded,
                              color: isDark ? AppPalette.white54 : g.inkMuted,
                              size: 20,
                            ),
                            onPressed: () => DropThoughtSheet.show(context),
                            tooltip: 'Drop a thought into Thought Wall',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final g = context.glass;

    return Material(
      color: AppPalette.transparent,
      child: AppTapArea(
        onTap: onTap,
        borderRadius: AppGeometry.roundedr12,
        child: AppCard(
          selected: isSelected,
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s14,
            vertical: AppSpace.s12,
          ),
          nightDecoration: BoxDecoration(
            color: isSelected
                ? (isDark
                      ? AppPalette.colorFFE28B57.withValues(alpha: 0.22)
                      : g.claySoft)
                : (isDark
                      ? AppPalette.colorFF322922
                      : AppPalette.black.withValues(alpha: 0.04)),
            borderRadius: AppGeometry.roundedr12,
            border: Border.all(
              color: isSelected
                  ? AppPalette.colorFFE28B57
                  : (isDark
                        ? AppPalette.white.withValues(alpha: 0.08)
                        : AppPalette.black.withValues(alpha: 0.08)),
              width: AppBorderScale.w1,
            ),
          ),
          child: Text(
            label,
            style: AppStateTypography.stateType9(
              state0: isSelected,
              color: context.surfaces.contentForeground(isSelected, isSelected
                  ? (isDark ? AppPalette.colorFFE28B57 : g.clay)
                  : (isDark ? AppPalette.white70 : g.ink)),
            ),
          ),
        ),
      ),
    );
  }
}
