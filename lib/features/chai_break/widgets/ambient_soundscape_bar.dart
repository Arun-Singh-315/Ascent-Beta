import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../chai_break_provider.dart';

class AmbientSoundscapeBar extends StatefulWidget {
  final SoundscapePreset selectedSoundscape;
  final bool isPlaying;
  final bool isMuted;
  final VoidCallback? onToggleMute;
  final ValueChanged<SoundscapePreset> onSoundscapeChanged;

  const AmbientSoundscapeBar({
    super.key,
    required this.selectedSoundscape,
    required this.isPlaying,
    this.isMuted = false,
    this.onToggleMute,
    required this.onSoundscapeChanged,
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
    if (widget.isPlaying && widget.selectedSoundscape != SoundscapePreset.silentZen) {
      _animController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AmbientSoundscapeBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldAnimate = widget.isPlaying && widget.selectedSoundscape != SoundscapePreset.silentZen;
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181C22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose Break Ambience',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...SoundscapePreset.values.map((preset) {
                  final isSelected = preset == widget.selectedSoundscape;
                  final accent = Color(preset.accentColorHex);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onSoundscapeChanged(preset);
                          Navigator.of(ctx).pop();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? accent.withValues(alpha: 0.16) : const Color(0xFF222832),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? accent : Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      preset.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      preset.description,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.white60,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: accent, size: 20),
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
    final accent = Color(widget.selectedSoundscape.accentColorHex);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showSoundscapeSelector(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E232B).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Sound icon
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.selectedSoundscape == SoundscapePreset.silentZen
                      ? Icons.volume_off_rounded
                      : Icons.music_note_rounded,
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
                          'AMBIENCE: ',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        Text(
                          widget.selectedSoundscape.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      widget.selectedSoundscape.description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Equalizer Waveform Bars
              if (widget.selectedSoundscape != SoundscapePreset.silentZen)
                AnimatedBuilder(
                  animation: _animController,
                  builder: (context, _) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(4, (index) {
                        final phase = (_animController.value + (index * 0.25)) % 1.0;
                        final height = widget.isPlaying
                            ? 6.0 + math.sin(phase * math.pi) * 14.0
                            : 4.0;
                        return Container(
                          width: 3.2,
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
              if (widget.onToggleMute != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    widget.onToggleMute?.call();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      widget.isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      color: widget.isMuted ? Colors.white38 : accent,
                      size: 19,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down_rounded, color: Colors.white54, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
