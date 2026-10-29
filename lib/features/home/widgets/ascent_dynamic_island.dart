import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/providers/daily_briefing_provider.dart';
import '../../chai_break/chai_break_provider.dart';
import '../../promises/providers/promise_providers.dart';

/// Apple-inspired translucent micro-color tokens for subtle, refined vibrancy.
class DynamicIslandColors {
  DynamicIslandColors._();

  static const Color aquaTeal = Color(0xFF00C4B4);
  static const Color azureBlue = Color(0xFF0A84FF);
  static const Color emeraldMint = Color(0xFF30D158);
  static const Color solarAmber = Color(0xFFFF9F0A);
  static const Color coralRose = Color(0xFFFF375F);
  static const Color royalIndigo = Color(0xFF5E5CE6);
}

/// The multi-app, reactive Dynamic Island for Ascent.
///
/// Intelligently adapts its presence:
/// 1. Active Focus Timer (running session countdown & controls)
/// 2. Chai Break Soundscape Audio (ambient audio track & equalizer)
/// 3. Yesterday's Leftover Summary Alert (overdue task resolution)
/// 4. Ambient Multi-App Hub (Apple micro-color shortcut pods & All Apps drawer)
class AscentDynamicIsland extends ConsumerStatefulWidget {
  const AscentDynamicIsland({
    super.key,
    this.shortcuts,
    this.activeShortcutId,
    this.onSelectShortcut,
    this.initiallyExpanded = false,
  });

  final List<String>? shortcuts;
  final String? activeShortcutId;
  final ValueChanged<String?>? onSelectShortcut;
  final bool initiallyExpanded;

  @override
  ConsumerState<AscentDynamicIsland> createState() =>
      _AscentDynamicIslandState();
}

class _AscentDynamicIslandState extends ConsumerState<AscentDynamicIsland>
    with SingleTickerProviderStateMixin {
  late bool _isExpanded;
  bool _showAllApps = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) _showAllApps = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final timeState = ref.watch(timeTrackingProvider);
    final chaiState = ref.watch(chaiBreakProvider);
    final briefingAsync = ref.watch(
      dailyBriefingProvider(briefingDay(DateTime.now())),
    );
    final overdueCount = briefingAsync.value?.overdue ?? 0;

    final isFocusRunning = timeState.isRunning;
    final isAudioPlaying = chaiState.isRunning &&
        !chaiState.isAudioMuted &&
        chaiState.selectedSoundscape != SoundscapePreset.silentZen;

    return Semantics(
      label: 'Ascent Dynamic Island',
      container: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF000000),
          borderRadius: BorderRadius.circular(_isExpanded ? 24 : 28),
          border: Border.all(
            color: Colors.black,
            width: 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isFocusRunning
                  ? DynamicIslandColors.emeraldMint.withValues(alpha: 0.20)
                  : isAudioPlaying
                      ? DynamicIslandColors.solarAmber.withValues(alpha: 0.20)
                      : overdueCount > 0
                          ? DynamicIslandColors.solarAmber.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.60),
              blurRadius: _isExpanded ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_isExpanded ? 22 : 26),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _buildIslandContent(
              context: context,
              g: g,
              isDark: isDark,
              timeState: timeState,
              chaiState: chaiState,
              overdueCount: overdueCount,
              isFocusRunning: isFocusRunning,
              isAudioPlaying: isAudioPlaying,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIslandContent({
    required BuildContext context,
    required AscentGlass g,
    required bool isDark,
    required TimeTrackingState timeState,
    required ChaiBreakState chaiState,
    required int overdueCount,
    required bool isFocusRunning,
    required bool isAudioPlaying,
  }) {
    if (isFocusRunning) {
      return _buildFocusIsland(context, g, isDark, timeState);
    }

    if (isAudioPlaying) {
      return _buildAudioIsland(context, g, isDark, chaiState);
    }

    if (overdueCount > 0 && !_isExpanded) {
      return _buildOverdueIslandCompact(context, g, isDark, overdueCount);
    }

    return _buildAmbientMultiAppIsland(
      context: context,
      g: g,
      isDark: isDark,
      overdueCount: overdueCount,
    );
  }

  // ── 1. ACTIVE FOCUS TIMER ISLAND ──────────────────────────────────────────

  Widget _buildFocusIsland(
    BuildContext context,
    AscentGlass g,
    bool isDark,
    TimeTrackingState state,
  ) {
    if (!_isExpanded) {
      return InkWell(
        key: const ValueKey('dynamic_island_focus_compact'),
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: DynamicIslandColors.emeraldMint,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.timer_rounded,
                size: 16,
                color: DynamicIslandColors.emeraldMint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  state.activeSession?.label.isNotEmpty == true
                      ? state.activeSession!.label
                      : 'Deep Focus',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                state.formattedTime,
                style: AscentTextStyles.labelMedium.copyWith(
                  color: DynamicIslandColors.emeraldMint,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  state.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                  size: 18,
                  color: g.ink,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final notifier = ref.read(timeTrackingProvider.notifier);
                  if (state.isPaused) {
                    notifier.resumeSession();
                  } else {
                    notifier.pauseSession();
                  }
                },
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DynamicIslandColors.emeraldMint.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: DynamicIslandColors.emeraldMint.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_rounded,
                          size: 13,
                          color: DynamicIslandColors.emeraldMint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'ACTIVE FOCUS',
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: DynamicIslandColors.emeraldMint,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close_fullscreen_rounded, size: 16, color: g.inkMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _toggleExpanded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.activeSession?.label ?? 'Focus Session',
            style: AscentTextStyles.cardTitle.copyWith(
              color: g.ink,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            state.formattedTime,
            style: AscentTextStyles.displayMedium.copyWith(
              color: DynamicIslandColors.emeraldMint,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    final notifier = ref.read(timeTrackingProvider.notifier);
                    if (state.isPaused) {
                      notifier.resumeSession();
                    } else {
                      notifier.pauseSession();
                    }
                  },
                  icon: Icon(
                    state.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 18,
                  ),
                  label: Text(state.isPaused ? 'Resume' : 'Pause'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DynamicIslandColors.emeraldMint.withValues(
                      alpha: 0.20,
                    ),
                    foregroundColor: g.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Open Focus Screen',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/focus');
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 2. ACTIVE CHAI BREAK AUDIO ISLAND ─────────────────────────────────────

  Widget _buildAudioIsland(
    BuildContext context,
    AscentGlass g,
    bool isDark,
    ChaiBreakState state,
  ) {
    if (!_isExpanded) {
      return InkWell(
        key: const ValueKey('dynamic_island_audio_compact'),
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              const Text('☕', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.isPlayingCustomAudio
                      ? (state.customAudioName ?? 'Custom Song')
                      : state.selectedSoundscape.title,
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.ink,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              _AudioWaveIndicator(color: DynamicIslandColors.solarAmber),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  state.isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  size: 17,
                  color: g.ink,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref.read(chaiBreakProvider.notifier).togglePlayPause();
                },
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: DynamicIslandColors.solarAmber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: DynamicIslandColors.solarAmber.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('☕', style: TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(
                          'CHAI BREAK AUDIO',
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: DynamicIslandColors.solarAmber,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close_fullscreen_rounded, size: 16, color: g.inkMuted),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _toggleExpanded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            state.isPlayingCustomAudio
                ? (state.customAudioName ?? 'Custom Device Audio')
                : state.selectedSoundscape.title,
            style: AscentTextStyles.cardTitle.copyWith(
              color: g.ink,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            state.selectedSoundscape.description,
            style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(chaiBreakProvider.notifier).togglePlayPause();
                  },
                  icon: Icon(
                    state.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 18,
                  ),
                  label: Text(state.isRunning ? 'Pause Sanctuary' : 'Play Sanctuary'),
                  style: FilledButton.styleFrom(
                    backgroundColor: DynamicIslandColors.solarAmber.withValues(
                      alpha: 0.20,
                    ),
                    foregroundColor: g.ink,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Open Chai Break',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/chai-break');
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. OVERDUE TASK ALERT COMPACT ─────────────────────────────────────────

  Widget _buildOverdueIslandCompact(
    BuildContext context,
    AscentGlass g,
    bool isDark,
    int count,
  ) {
    return InkWell(
      key: const ValueKey('dynamic_island_overdue_compact'),
      onTap: _toggleExpanded,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: DynamicIslandColors.solarAmber.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: DynamicIslandColors.solarAmber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count leftover ${count == 1 ? 'task' : 'tasks'} from yesterday',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: g.ink,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: DynamicIslandColors.solarAmber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Review →',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: DynamicIslandColors.solarAmber,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. AMBIENT MULTI-APP HUB & SHORTCUTS (APPLE MICRO-COLORS) ─────────────

  Widget _buildAmbientMultiAppIsland({
    required BuildContext context,
    required AscentGlass g,
    required bool isDark,
    required int overdueCount,
  }) {
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final thoughtCount = ref.watch(todayThoughtsCountStreamProvider).value ?? 0;
    final activePromises =
        ref.watch(activePromisesStreamProvider).value?.length ?? 0;
    final nextReminder = ref.watch(nextUpcomingReminderProvider).value;

    if (!_isExpanded) {
      return InkWell(
        key: const ValueKey('dynamic_island_ambient_compact'),
        onTap: _toggleExpanded,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Aqua Teal Water Glanceable
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: DynamicIslandColors.aquaTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${waterMl}ml',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: DynamicIslandColors.aquaTeal,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 12, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(width: 10),

                      // Azure Sky Thought Glanceable
                      const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 14,
                        color: DynamicIslandColors.azureBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$thoughtCount',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: DynamicIslandColors.azureBlue,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, height: 12, color: Colors.white.withValues(alpha: 0.15)),
                      const SizedBox(width: 10),

                      // Sacred Promises
                      const Icon(
                        Icons.bookmark_added_outlined,
                        size: 14,
                        color: DynamicIslandColors.coralRose,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$activePromises',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: DynamicIslandColors.coralRose,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.60),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: DynamicIslandColors.emeraldMint,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: DynamicIslandColors.emeraldMint.withValues(alpha: 0.8),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ascent Dynamic Island',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.close_fullscreen_rounded,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.60),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                onPressed: _toggleExpanded,
              ),
            ],
          ),

          // Upcoming Activity Alert if any
          if (nextReminder != null && nextReminder.isActive) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: DynamicIslandColors.azureBlue.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: DynamicIslandColors.azureBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Next: ${nextReminder.title}',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/reminders');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        'View →',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: DynamicIslandColors.azureBlue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Yesterday's Leftover Alert if any
          if (overdueCount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: DynamicIslandColors.solarAmber.withValues(alpha: 0.40),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_repeat_rounded,
                    size: 16,
                    color: DynamicIslandColors.solarAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$overdueCount tasks from yesterday need a decision',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/today');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      child: Text(
                        'Review →',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: DynamicIslandColors.solarAmber,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 4 Curated Apple Micro-Color Pods
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 310;
              final pod1 = _buildMicroColorPod(
                color: DynamicIslandColors.aquaTeal,
                icon: Icons.water_drop_rounded,
                label: 'Water',
                metric: '${waterMl}ml',
                subActionText: '+250ml',
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.onSelectShortcut != null) {
                    widget.onSelectShortcut!('hydration');
                  } else {
                    context.push('/hydration');
                  }
                },
                onSubAction: () async {
                  HapticFeedback.mediumImpact();
                  await ref.read(waterDaoProvider).addWater(250);
                },
              );
              final pod2 = _buildMicroColorPod(
                color: DynamicIslandColors.azureBlue,
                icon: Icons.lightbulb_outline_rounded,
                label: 'Thoughts',
                metric: '$thoughtCount saved',
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.onSelectShortcut != null) {
                    widget.onSelectShortcut!('thought-wall');
                  } else {
                    context.push('/thought-wall');
                  }
                },
              );
              final pod3 = _buildMicroColorPod(
                color: DynamicIslandColors.coralRose,
                icon: Icons.bookmark_added_outlined,
                label: 'Promises',
                metric: '$activePromises active',
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.onSelectShortcut != null) {
                    widget.onSelectShortcut!('promises');
                  } else {
                    context.push('/promises');
                  }
                },
              );
              final pod4 = _buildMicroColorPod(
                color: DynamicIslandColors.royalIndigo,
                icon: Icons.shield_outlined,
                label: 'Vault',
                metric: 'Secure',
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (widget.onSelectShortcut != null) {
                    widget.onSelectShortcut!('vault');
                  } else {
                    context.push('/vault');
                  }
                },
              );

              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: pod1),
                        const SizedBox(width: 8),
                        Expanded(child: pod2),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: pod3),
                        const SizedBox(width: 8),
                        Expanded(child: pod4),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: pod1),
                  const SizedBox(width: 8),
                  Expanded(child: pod2),
                  const SizedBox(width: 8),
                  Expanded(child: pod3),
                  const SizedBox(width: 8),
                  Expanded(child: pod4),
                ],
              );
            },
          ),

          const SizedBox(height: 12),

          // Drawer Toggle for All Tools & Apps
          Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _showAllApps = !_showAllApps);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showAllApps
                            ? Icons.expand_less_rounded
                            : Icons.grid_view_rounded,
                        size: 14,
                        color: g.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _showAllApps ? 'Hide App Suite' : 'View All Tools & Apps',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Expandable Full App Grid
          if (_showAllApps) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: g.claySoft.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: g.line),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.spaceAround,
                children: [
                  _buildAppTile(context, g, 'Focus Timer', Icons.timer_outlined, '/focus', DynamicIslandColors.emeraldMint),
                  _buildAppTile(context, g, 'Chai Break', Icons.coffee_outlined, '/chai-break', DynamicIslandColors.solarAmber),
                  _buildAppTile(context, g, 'Today Tasks', Icons.calendar_today_rounded, '/today', DynamicIslandColors.azureBlue),
                  _buildAppTile(context, g, 'Reminders', Icons.notifications_none_rounded, '/reminders', DynamicIslandColors.coralRose),
                  _buildAppTile(context, g, 'Challenges', Icons.flag_outlined, '/momentum', DynamicIslandColors.coralRose),
                  _buildAppTile(context, g, 'Money', Icons.account_balance_wallet_outlined, '/money', DynamicIslandColors.emeraldMint),
                  _buildAppTile(context, g, 'Learning', Icons.school_outlined, '/learning', DynamicIslandColors.azureBlue),
                  _buildAppTile(context, g, 'Walk', Icons.directions_walk_rounded, '/walk', DynamicIslandColors.aquaTeal),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMicroColorPod({
    required Color color,
    required IconData icon,
    required String label,
    required String metric,
    VoidCallback? onSubAction,
    String? subActionText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.38),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AscentTextStyles.labelSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.90),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  metric,
                  style: AscentTextStyles.labelSmall.copyWith(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onSubAction != null && subActionText != null) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: onSubAction,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: color.withValues(alpha: 0.45),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      subActionText,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppTile(
    BuildContext context,
    AscentGlass g,
    String label,
    IconData icon,
    String route,
    Color color,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(route);
      },
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AscentTextStyles.labelSmall.copyWith(
                fontSize: 10.5,
                color: g.ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle 3-bar animated audio equalizer waveform indicator.
class _AudioWaveIndicator extends StatefulWidget {
  const _AudioWaveIndicator({required this.color});
  final Color color;

  @override
  State<_AudioWaveIndicator> createState() => _AudioWaveIndicatorState();
}

class _AudioWaveIndicatorState extends State<_AudioWaveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final val = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              width: 2.5,
              height: 4 + (val * 8),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: 2.5,
              height: 12 - (val * 6),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: 2.5,
              height: 6 + (val * 7),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          ],
        );
      },
    );
  }
}
