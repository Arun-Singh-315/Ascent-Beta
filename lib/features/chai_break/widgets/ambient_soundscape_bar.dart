import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
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
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgSurfaceElevated,
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
                      'Choose Break Audio & Music',
                      style: AppTypography.plusJakartaSans17W70076(
                        color: context.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: context.textMuted),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select an offline atmospheric soundscape or open any song from your system',
                  style: AppTypography.plusJakartaSans12Regular57(
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: 16),

                // ── PLAY FROM SYSTEM CARD ────────────────────────
                AppCard(
                  padding: const EdgeInsets.all(AppSpace.s14),
                  nightDecoration: BoxDecoration(
                    color: AppPalette.colorFF10B981.withValues(alpha: 0.12),
                    borderRadius: AppGeometry.roundedr16,
                    border: Border.all(
                      color: AppPalette.colorFF10B981.withValues(
                        alpha:
                            widget.selectedSoundscape ==
                                SoundscapePreset.customSystemAudio
                            ? 0.7
                            : 0.3,
                      ),
                      width: AppBorderScale.w1point2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppTag(
                            padding: const EdgeInsets.all(AppSpace.s8),
                            nightDecoration: BoxDecoration(
                              color: AppPalette.colorFF10B981.withValues(
                                alpha: 0.22,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.folder_open_rounded,
                              color: AppPalette.colorFF10B981,
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
                                  style: AppTypography.plusJakartaSans14W7007(
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.customAudioName != null
                                      ? 'Loaded: ${widget.customAudioName}'
                                      : 'Open MP3, WAV, M4A, FLAC from your files',
                                  style: AppStateTypography.stateType23(
                                    state0: widget.customAudioName != null,
                                    color: widget.customAudioName != null
                                        ? AppPalette.colorFF34D399
                                        : context.textMuted,
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
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                widget.onPickCustomAudio?.call();
                              },
                              style: context.surfaces.buttonStyle(
                                ElevatedButton.styleFrom(
                                  backgroundColor: AppPalette.colorFF10B981,
                                  foregroundColor: AppPalette.black,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: AppSpace.s10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppGeometry.roundedr10,
                                  ),
                                ),
                                filled: true,
                                icon: false,
                              ),
                              icon: const Icon(
                                Icons.audio_file_rounded,
                                size: 16,
                              ),
                              label: Text(
                                widget.customAudioName != null
                                    ? 'Change Song File'
                                    : 'Pick Song from System',
                                style: AppTypography.plusJakartaSans125W70078(),
                              ),
                            ),
                          ),
                          if (widget.customAudioName != null) ...[
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () {
                                widget.onClearCustomAudio?.call();
                                Navigator.of(ctx).pop();
                              },
                              style: context.surfaces.buttonStyle(
                                OutlinedButton.styleFrom(
                                  foregroundColor: context.textMuted,
                                  side: BorderSide(color: context.divider),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s12,
                                    vertical: AppSpace.s10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppGeometry.roundedr10,
                                  ),
                                ),
                                filled: false,
                                icon: false,
                              ),
                              child: const Text(
                                'Clear',
                                style: AppTypeRoles.typeRole27,
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
                  'AMBIENT SOUNDSCAPES (OFFLINE READY)',
                  style: AppTypography.jetBrainsMono10W70079(
                    color: context.textMuted,
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
                        child: Material(
                          color: AppPalette.transparent,
                          child: AppTapArea(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              widget.onSoundscapeChanged(preset);
                              Navigator.of(ctx).pop();
                            },
                            borderRadius: AppGeometry.roundedr14,
                            child: AppCard(
                              selected: isSelected,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s14,
                                vertical: AppSpace.s12,
                              ),
                              nightDecoration: BoxDecoration(
                                color: isSelected
                                    ? accent.withValues(alpha: 0.16)
                                    : context.bgSurface,
                                borderRadius: AppGeometry.roundedr14,
                                border: Border.all(
                                  color: isSelected ? accent : g.edge,
                                  width: AppBorderScale.w1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  AppTag(
                                    padding: const EdgeInsets.all(AppSpace.s8),
                                    nightDecoration: BoxDecoration(
                                      color: accent.withValues(alpha: 0.2),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          preset.title,
                                          style:
                                              AppTypography.plusJakartaSans14W60080(
                                                color: context.surfaces.contentForeground(isSelected, context.textPrimary),
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          preset.description,
                                          style:
                                              AppTypography.plusJakartaSans115Regular81(
                                                color: context.surfaces.contentForeground(isSelected, context.textMuted),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle_rounded,
                                      color: accent,
                                      size: 20,
                                    ),
                                ],
                              ),
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
    final isCustom =
        widget.selectedSoundscape == SoundscapePreset.customSystemAudio &&
        widget.customAudioName != null;
    final accent = isCustom
        ? AppPalette.colorFF10B981
        : Color(widget.selectedSoundscape.accentColorHex);

    final title = isCustom
        ? (widget.customAudioName ?? 'System Song')
        : widget.selectedSoundscape.title;
    final subtitle = isCustom
        ? 'Playing from device storage'
        : widget.selectedSoundscape.description;

    return Material(
      color: AppPalette.transparent,
      child: AppTapArea(
        onTap: () => _showSoundscapeSelector(context),
        borderRadius: AppGeometry.roundedr16,
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s12,
          ),
          nightDecoration: BoxDecoration(
            color: context.glass.fill,
            borderRadius: AppGeometry.roundedr16,
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: AppBorderScale.w1,
            ),
          ),
          child: Row(
            children: [
              // Sound icon
              AppTag(
                padding: const EdgeInsets.all(AppSpace.s7),
                nightDecoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
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
                          style: AppTypography.jetBrainsMono10W70082(
                            color: accent,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.plusJakartaSans13W70044(
                              color: context.textPrimary,
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
                      style: AppTypography.plusJakartaSans11Regular58(
                        color: context.textMuted,
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
                            color: accent.withValues(alpha: 0.9),
                            borderRadius: AppGeometry.roundedr2,
                          ),
                        );
                      }),
                    );
                  },
                ),
              if (widget.onToggleMute != null) ...[
                const SizedBox(width: 8),
                AppTapArea(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onToggleMute?.call();
                  },
                  borderRadius: AppGeometry.roundedr16,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpace.s4),
                    child: Icon(
                      widget.isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      color: widget.isMuted ? context.textMuted : accent,
                      size: 19,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down_rounded,
                color: context.textMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
