import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../shared/widgets/ascent_atmosphere.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/history_action.dart';
import 'chai_break_provider.dart';
import 'widgets/ambient_soundscape_bar.dart';
import 'widgets/brew_with_me_view.dart';
import 'widgets/mindful_breathing_guide.dart';

enum ChaiBreakMode {
  mindfulPause,
  brewWithMe,
}

/// Apple Mindfulness & Zen-inspired Pause Screen
/// Minimalist, serene, tactile, informative with a clean single-view chill sanctuary.
class ChaiBreakScreen extends ConsumerStatefulWidget {
  const ChaiBreakScreen({super.key});

  @override
  ConsumerState<ChaiBreakScreen> createState() => _ChaiBreakScreenState();
}

class _ChaiBreakScreenState extends ConsumerState<ChaiBreakScreen> {
  ChaiBreakMode _selectedMode = ChaiBreakMode.mindfulPause;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chaiBreakProvider);
    final notifier = ref.read(chaiBreakProvider.notifier);
    final todayBreaksAsync = ref.watch(todayBreaksProvider);
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final router = GoRouter.maybeOf(context);
    final canPopNow = router != null ? router.canPop() : Navigator.of(context).canPop();

    return PopScope(
      canPop: canPopNow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (router != null) {
            router.go('/home');
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
      backgroundColor: g.bg,
      body: AscentAtmosphereBackground(
        child: SafeArea(
          child: Column(
            children: [
            // ── Top Navigation Bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s8,
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
                      final router = GoRouter.maybeOf(context);
                      if (router != null && router.canPop()) {
                        router.pop();
                      } else if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else if (router != null) {
                        router.go('/home');
                      }
                    },
                    tooltip: 'Back',
                  ),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.coffee_rounded, color: g.clay, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Pause',
                            style: AscentTextStyles.cardTitle.copyWith(
                              color: g.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      const HistoryAction(module: 'breaks'),
                    ],
                  ),
                ],
              ),
            ),

            // ── Chill Sanctuary Body (Single-View Optimized) ────────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s20,
                  vertical: AppSpace.s4,
                ),
                children: [
                  // 1. Canonical Segmented Mode Switcher
                  AscentSegmentedControl<ChaiBreakMode>(
                    segments: const [
                      AscentSegment(
                        value: ChaiBreakMode.mindfulPause,
                        label: 'Mindful Pause',
                      ),
                      AscentSegment(
                        value: ChaiBreakMode.brewWithMe,
                        label: 'Brew With Me',
                      ),
                    ],
                    selected: _selectedMode,
                    onChanged: (mode) => setState(() => _selectedMode = mode),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    _selectedMode == ChaiBreakMode.brewWithMe
                        ? 'Follow a step-by-step artisanal brewing guide.'
                        : 'Choose a short pause, breathe and enjoy your drink.',
                    textAlign: TextAlign.center,
                    style: AscentTextStyles.captionMedium.copyWith(
                      color: g.inkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (_selectedMode == ChaiBreakMode.brewWithMe) ...[
                    const BrewWithMeView(),
                  ] else ...[
                    // Duration Preset Pills
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _ApplePresetPill(
                          label: '5m Chai',
                          isSelected: state.totalDurationSeconds == 300,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.setPresetMinutes(5);
                          },
                        ),
                        _ApplePresetPill(
                          label: '10m Coffee',
                          isSelected: state.totalDurationSeconds == 600,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.setPresetMinutes(10);
                          },
                        ),
                        _ApplePresetPill(
                          label: '15m Reset',
                          isSelected: state.totalDurationSeconds == 900,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            notifier.setPresetMinutes(15);
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // 2. Serene Mindfulness Glowing Countdown Dial (Compact & Calm)
                    Center(
                      child: _AppleMindfulnessTimerDial(
                        state: state,
                        isDark: isDark,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Optional Breathing Phase Banner
                    if (state.isBreathingGuideEnabled) ...[
                      MindfulBreathingGuide(
                        phase: state.breathPhase,
                        isRunning: state.isRunning,
                        accentColor: g.clay,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 3. Synchronized Controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Reset button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: g.line.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: IconButton(
                            iconSize: 18,
                            icon: Icon(
                              Icons.replay_rounded,
                              color: g.inkMuted,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              notifier.setPresetMinutes(
                                state.totalDurationSeconds ~/ 60,
                              );
                            },
                            tooltip: 'Reset break timer',
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Primary Start / Pause button
                        AscentButton.primary(
                          label: state.isRunning ? 'Pause' : 'Resume',
                          icon: state.isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          expanded: false,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            notifier.togglePlayPause();
                          },
                        ),
                        const SizedBox(width: 16),

                        // Finish early button
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.04),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: g.line.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: IconButton(
                            iconSize: 18,
                            icon: Icon(
                              Icons.check_circle_outline_rounded,
                              color: g.inkMuted,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              final router = GoRouter.maybeOf(context);
                              if (router != null && router.canPop()) {
                                router.pop();
                              } else if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              } else if (router != null) {
                                router.go('/home');
                              }
                            },
                            tooltip: 'Finish break early',
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 4. Ambient Soundscape Bar (Compact chill audio dock)
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

                  const SizedBox(height: 14),

                  // 5. Break History & Pauses Today (Compact with full view link)
                  _TodayBreakHistorySection(
                    todayBreaksAsync: todayBreaksAsync,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
}

/// Serene Apple Watch Mindfulness-style glowing countdown dial
class _AppleMindfulnessTimerDial extends StatelessWidget {
  final ChaiBreakState state;
  final bool isDark;

  const _AppleMindfulnessTimerDial({
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final progress = state.progressFraction;

    return SizedBox(
      width: 154,
      height: 154,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer subtle glowing boundary
          Container(
            width: 154,
            height: 154,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? g.clay.withValues(alpha: 0.05)
                  : g.clay.withValues(alpha: 0.04),
              border: Border.all(
                color: g.line.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
          ),

          // Glowing Concentric Progress Ring
          CustomPaint(
            size: const Size(146, 146),
            painter: _MindfulnessRingPainter(
              progress: progress,
              trackColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              progressColor: g.clay,
              isRunning: state.isRunning,
            ),
          ),

          // Digital Timer Center
          Padding(
            padding: const EdgeInsets.all(16),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    state.formattedRemaining,
                    style: AscentTextStyles.displaySmall.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 38,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    state.isRunning && state.isBreathingGuideEnabled
                        ? state.breathPhase.label
                        : '${state.totalDurationSeconds ~/ 60}m mindful pause',
                    style: AscentTextStyles.captionMedium.copyWith(
                      color: state.isRunning ? g.clay : g.inkMuted,
                      fontWeight: FontWeight.w600,
                    ),
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

/// Custom painter for the serene circular countdown ring
class _MindfulnessRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final bool isRunning;

  _MindfulnessRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 9.0;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    // Active Arc
    final sweepAngle = (progress * 2 * 3.1415926535).clamp(0.0, 2 * 3.1415926535);
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.1415926535 / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MindfulnessRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.isRunning != isRunning;
  }
}

/// Apple-style duration preset pill
class _ApplePresetPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ApplePresetPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? g.claySoft
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? g.clay
                : g.line.withValues(alpha: 0.4),
            width: isSelected ? 1.4 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: AscentTextStyles.bodyMedium.copyWith(
            color: isSelected ? g.clay : g.inkMuted,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// Today's Break History Section with High-Volume Data Protection
class _TodayBreakHistorySection extends StatelessWidget {
  final AsyncValue<List<dynamic>> todayBreaksAsync;

  const _TodayBreakHistorySection({required this.todayBreaksAsync});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return todayBreaksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (events) {
        final today = DateTime.now();
        final todayBreaks = events.where((e) {
          final dt = e.occurredAt as DateTime;
          return dt.year == today.year &&
              dt.month == today.month &&
              dt.day == today.day;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'PAUSE HISTORY',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.inkMuted,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${todayBreaks.length} today',
                  style: AscentTextStyles.captionMedium.copyWith(
                    color: g.inkMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            AscentCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s10,
              ),
              child: Column(
                children: [
                  if (todayBreaks.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(
                        children: [
                          Icon(
                            Icons.coffee_outlined,
                            size: 28,
                            color: g.inkMuted.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No mindful breaks logged today',
                            style: AscentTextStyles.captionMedium.copyWith(
                              color: g.inkMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Complete a pause to track your daily rest',
                            style: AscentTextStyles.captionMedium.copyWith(
                              color: g.inkMuted.withValues(alpha: 0.7),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // High-volume protection: cap to top 3 breaks
                    for (var i = 0; i < math.min(3, todayBreaks.length); i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          color: g.line.withValues(alpha: 0.4),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: g.claySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.coffee_rounded,
                                size: 16,
                                color: g.clay,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    todayBreaks[i].title.toString().isNotEmpty
                                        ? todayBreaks[i].title.toString()
                                        : 'Mindful Break',
                                    style: AscentTextStyles.bodyMedium.copyWith(
                                      color: g.ink,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    todayBreaks[i].detail?.toString() ?? 'Pause recorded',
                                    style: AscentTextStyles.captionMedium.copyWith(
                                      color: g.inkMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              DateFormat('h:mm a').format(todayBreaks[i].occurredAt as DateTime),
                              style: AscentTextStyles.captionMedium.copyWith(
                                color: g.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],

                  Divider(height: 1, color: g.line.withValues(alpha: 0.4)),
                  // Direct Link to Breaks in History Module
                  InkWell(
                    onTap: () => context.push('/history?module=breaks'),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 15,
                            color: g.inkMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'View Full Pause History',
                            style: AscentTextStyles.captionMedium.copyWith(
                              color: g.inkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
