import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import 'app_surfaces.dart';

/// External playback companion for background focus & lecture study sessions.
/// Operates independently of Ascent's study timer without media button competition.
class MusicCompanionCard extends StatefulWidget {
  const MusicCompanionCard({super.key});

  @override
  State<MusicCompanionCard> createState() => _MusicCompanionCardState();
}

class _MusicCompanionCardState extends State<MusicCompanionCard>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  static const _channel = MethodChannel('ascent/music');
  Timer? _timer;
  Map<String, dynamic>? _status;
  bool _busy = false;
  bool _reading = false;
  bool _foreground = true;
  String? _error;

  late final AnimationController _eqController;

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _eqController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (_supported) {
      unawaited(_refresh());
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (_foreground && TickerMode.valuesOf(context).enabled) {
          unawaited(_refresh());
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _supported) unawaited(_refresh());
  }

  bool get _isTesting =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  Future<void> _refresh() async {
    if (_reading) return;
    _reading = true;
    try {
      final value = await _channel.invokeMapMethod<String, dynamic>('status');
      if (mounted) {
        final isPlaying = value?['playing'] == true;
        if (!_isTesting) {
          if (isPlaying && !_eqController.isAnimating) {
            _eqController.repeat();
          } else if (!isPlaying && _eqController.isAnimating) {
            _eqController.stop();
          }
        }
        setState(() {
          _status = value;
          _error = null;
        });
      }
    } on PlatformException {
      if (mounted) {
        setState(() {
          _status = null;
          _error = 'Music access is unavailable. Try again.';
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _error = 'Music companion requires the updated Android app.';
        });
      }
    } finally {
      _reading = false;
    }
  }

  Future<void> _settings() async {
    HapticFeedback.selectionClick();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect your music'),
        content: const Text(
          'Android notification access lets Ascent show media titles and control your player. Android grants broad notification access; Ascent only uses active media sessions and does not read or store notification messages or listening history. Enable Ascent music companion in Settings. You can revoke access there anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    try {
      await _channel.invokeMethod<void>('settings');
    } on PlatformException {
      if (mounted) {
        setState(() {
          _error = 'Could not open notification settings.';
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() {
          _error = 'Install the updated Android app to connect music.';
        });
      }
    }
  }

  Future<void> _control(String action) async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() {
      _busy = true;
    });
    try {
      final sent = await _channel.invokeMethod<bool>('control', {
        'package': _status?['package'],
        'action': action,
      });
      if (sent != true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Player is unavailable. Open your music app and try again.',
            ),
          ),
        );
      }
      await _refresh();
    } on PlatformException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not control this player.')),
        );
      }
    } on MissingPluginException {
      await _refresh();
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _eqController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supported) return const SizedBox.shrink();

    final access = _status?['access'] == true;
    final title = _status?['title'] as String?;
    final playing = _status?['playing'] == true;
    final artist = _status?['artist'] as String?;
    final source = _status?['source'] as String? ?? 'Media Player';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s6),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12,
          vertical: AppSpace.s10,
        ),
        nightDecoration: BoxDecoration(
          color: context.bgSurface.withValues(alpha: 0.85),
          borderRadius: AppGeometry.roundedr16,
          border: Border.all(
            color: playing
                ? context.accentPrimary.withValues(alpha: 0.35)
                : context.divider.withValues(alpha: 0.7),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppPalette.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _buildContent(
          context: context,
          access: access,
          title: title,
          playing: playing,
          artist: artist,
          source: source,
        ),
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required bool access,
    required String? title,
    required bool playing,
    required String? artist,
    required String source,
  }) {
    if (_error != null) {
      return Row(
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: context.accentPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: AppTypography.plusJakartaSans12Regular57(color: context.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _refresh,
            child: const Text('Try again'),
          ),
        ],
      );
    }

    // 1. Disconnected / Needs Permission
    if (!access && _status != null) {
      return Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.accentPrimary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.headphones_rounded,
              size: 16,
              color: context.accentPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Study Soundtrack',
                  style: AscentTextStyles.labelMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Bring your music into your focus space.',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _settings,
            icon: const Icon(Icons.link_rounded, size: 16),
            label: const Text('Connect music'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      );
    }

    // 2. Connected but Idle (No active media session)
    if (title == null) {
      return Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.accentPrimary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.headphones_rounded,
              size: 16,
              color: context.accentPrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Study Soundtrack',
                  style: AscentTextStyles.labelMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Play audio in your music app for focus ambience.',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Music access settings',
            onPressed: _settings,
            icon: Icon(Icons.tune_rounded, size: 18, color: context.textMuted),
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }

    // 3. Active Track
    return Row(
      children: [
        // Live equalizer / waveform indicator
        _EqualizerBars(
          controller: _eqController,
          isPlaying: playing,
          color: context.accentPrimary,
        ),
        const SizedBox(width: 10),

        // Title and artist
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.labelMedium.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      [
                        if (artist != null && artist.isNotEmpty) artist,
                        source,
                        playing ? 'Playing' : 'Paused',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tactile playback controls
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: playing ? 'Pause music' : 'Play music',
              onPressed: !_busy && _status?['toggle'] == true
                  ? () => _control('toggle')
                  : null,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 22,
                color: context.accentPrimary,
              ),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Next track',
              onPressed: !_busy && _status?['next'] == true
                  ? () => _control('next')
                  : null,
              icon: Icon(
                Icons.skip_next_rounded,
                size: 20,
                color: _status?['next'] == true ? context.textPrimary : context.divider,
              ),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Music access settings',
              onPressed: _settings,
              icon: Icon(Icons.tune_rounded, size: 16, color: context.textMuted),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ],
    );
  }
}

/// Subtle 4-bar equalizer that animates during playback.
class _EqualizerBars extends StatelessWidget {
  final AnimationController controller;
  final bool isPlaying;
  final Color color;

  const _EqualizerBars({
    required this.controller,
    required this.isPlaying,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = controller.value;
        final h1 = isPlaying
            ? 6.0 + 8.0 * (0.5 + 0.5 * math.sin(progress * 2 * math.pi))
            : 6.0;
        final h2 = isPlaying
            ? 8.0 + 10.0 * (0.5 + 0.5 * math.sin((progress + 0.3) * 2 * math.pi))
            : 12.0;
        final h3 = isPlaying
            ? 5.0 + 11.0 * (0.5 + 0.5 * math.sin((progress + 0.6) * 2 * math.pi))
            : 8.0;
        final h4 = isPlaying
            ? 4.0 + 7.0 * (0.5 + 0.5 * math.sin((progress + 0.85) * 2 * math.pi))
            : 5.0;

        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _bar(h1),
              const SizedBox(width: 2),
              _bar(h2),
              const SizedBox(width: 2),
              _bar(h3),
              const SizedBox(width: 2),
              _bar(h4),
            ],
          ),
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 2.5,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
