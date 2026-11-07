import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/ascent_card.dart';
import '../chai_break_provider.dart';

class AmbientSoundscapeBar extends StatefulWidget {
  final SoundscapePreset selectedSoundscape;
  final bool isPlaying;
  final bool isMuted;
  final String? customAudioName;
  final double volume;
  final VoidCallback? onToggleMute;
  final ValueChanged<SoundscapePreset> onSoundscapeChanged;
  final VoidCallback? onPickCustomAudio;
  final VoidCallback? onClearCustomAudio;
  final ValueChanged<double>? onVolumeChanged;

  const AmbientSoundscapeBar({
    super.key,
    required this.selectedSoundscape,
    required this.isPlaying,
    this.isMuted = false,
    this.customAudioName,
    this.volume = 0.85,
    this.onToggleMute,
    required this.onSoundscapeChanged,
    this.onPickCustomAudio,
    this.onClearCustomAudio,
    this.onVolumeChanged,
  });

  @override
  State<AmbientSoundscapeBar> createState() => _AmbientSoundscapeBarState();
}

class _AmbientSoundscapeBarState extends State<AmbientSoundscapeBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isPlaying &&
        widget.selectedSoundscape != SoundscapePreset.silentZen) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AmbientSoundscapeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate =
        widget.isPlaying &&
        widget.selectedSoundscape != SoundscapePreset.silentZen &&
        !widget.isMuted;
    if (shouldAnimate && !_animController.isAnimating) {
      _animController.repeat();
    } else if (!shouldAnimate && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showSoundscapeSelector(BuildContext context) {
    HapticFeedback.lightImpact();
    final g = context.glass;
    final dark = g.isDark;

    showModalBottomSheet(
      context: context,
      backgroundColor: g.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s20,
              vertical: AppSpace.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Break Audio & Soundscapes',
                      style: AscentTextStyles.cardTitle.copyWith(
                        color: g.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: g.inkMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Select an atmospheric soundscape or play any song from your device',
                  style: AscentTextStyles.captionMedium.copyWith(
                    color: g.inkMuted,
                  ),
                ),
                const SizedBox(height: 16),

                // ── PLAY FROM SYSTEM CARD ────────────────────────
                AscentCard(
                  padding: const EdgeInsets.all(AppSpace.s14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpace.s8),
                            decoration: BoxDecoration(
                              color: g.claySoft,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.folder_open_rounded,
                              color: g.clay,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Play from System / Device',
                                  style: AscentTextStyles.bodyMedium.copyWith(
                                    color: g.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.customAudioName != null
                                      ? 'Loaded: ${widget.customAudioName}'
                                      : 'Open MP3, WAV, M4A from your storage',
                                  style: AscentTextStyles.captionMedium.copyWith(
                                    color: widget.customAudioName != null
                                        ? g.clay
                                        : g.inkMuted,
                                    fontWeight: widget.customAudioName != null
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                widget.onPickCustomAudio?.call();
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: g.line.withValues(alpha: dark ? 0.35 : 0.25),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpace.s10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: Icon(
                                Icons.audio_file_rounded,
                                size: 16,
                                color: g.clay,
                              ),
                              label: Text(
                                widget.customAudioName != null
                                    ? 'Change Song File'
                                    : 'Choose Audio File',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: g.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (widget.customAudioName != null) ...[
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () {
                                widget.onClearCustomAudio?.call();
                              },
                              child: Text(
                                'Clear',
                                style: TextStyle(
                                  color: SharedControlColors.dueRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  'ATMOSPHERIC SOUNDSCAPES (OFFLINE)',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.inkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),

                // ── PRESET SOUNDSCAPES ────────────────────────────
                ...SoundscapePreset.values
                    .where((p) => p != SoundscapePreset.customSystemAudio)
                    .map((preset) {
                  final isSelected =
                      preset == widget.selectedSoundscape &&
                      widget.customAudioName == null;
                  final accent = Color(preset.accentColorHex);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSoundscapeChanged(preset);
                        Navigator.of(ctx).pop();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s14,
                          vertical: AppSpace.s12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? g.claySoft
                              : (dark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.black.withValues(alpha: 0.03)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? g.clay
                                : g.line.withValues(alpha: dark ? 0.35 : 0.2),
                            width: isSelected ? 1.4 : 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpace.s8),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.16),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                preset == SoundscapePreset.silentZen
                                    ? Icons.volume_off_rounded
                                    : Icons.music_note_rounded,
                                color: accent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    preset.title,
                                    style: AscentTextStyles.bodyMedium.copyWith(
                                      color: isSelected ? g.clay : g.ink,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    preset.description,
                                    style: AscentTextStyles.captionMedium.copyWith(
                                      color: g.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: g.clay,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isCustom =
        widget.selectedSoundscape == SoundscapePreset.customSystemAudio &&
        widget.customAudioName != null;
    final accent = isCustom
        ? g.clay
        : Color(widget.selectedSoundscape.accentColorHex);

    final title = isCustom
        ? (widget.customAudioName ?? 'System Song')
        : widget.selectedSoundscape.title;
    final subtitle = isCustom
        ? 'Playing from device storage'
        : widget.selectedSoundscape.description;

    return GestureDetector(
      onTap: () => _showSoundscapeSelector(context),
      child: AscentCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: AppSpace.s12,
        ),
        child: Row(
          children: [
            // Sound icon
            Container(
              padding: const EdgeInsets.all(AppSpace.s7),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCustom
                    ? Icons.folder_open_rounded
                    : (widget.selectedSoundscape == SoundscapePreset.silentZen
                        ? Icons.volume_off_rounded
                        : Icons.music_note_rounded),
                color: accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            // Track Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isCustom ? 'MY SONG: ' : 'AMBIENCE: ',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.clay,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          style: AscentTextStyles.bodyMedium.copyWith(
                            color: g.ink,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: AscentTextStyles.captionMedium.copyWith(
                      color: g.inkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Equalizer Waveform Bars
            if (widget.selectedSoundscape != SoundscapePreset.silentZen &&
                !widget.isMuted)
              AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(4, (index) {
                      final phase =
                          (_animController.value + (index * 0.25)) % 1.0;
                      final height = widget.isPlaying
                          ? 6.0 + math.sin(phase * math.pi) * 14.0
                          : 4.0;
                      return Container(
                        width: 3.2,
                        height: height,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s1point5,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  );
                },
              ),
            if (widget.onToggleMute != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onToggleMute?.call();
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s4),
                  child: Icon(
                    widget.isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: widget.isMuted ? g.inkMuted : g.clay,
                    size: 19,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down_rounded,
              color: g.inkMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
