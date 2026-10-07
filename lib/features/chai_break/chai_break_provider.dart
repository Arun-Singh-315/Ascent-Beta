import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SoundscapePreset {
  tapriCafeRain(
    'Tapri Cafe & Rain',
    'Cozy rain on tin roof with warm cafe murmur',
    0xFFE28B57,
    'audio/tapri_rain.wav',
  ),
  acousticLofi(
    'Acoustic Lo-Fi',
    'Warm Rhodes piano & mellow cafe ambience',
    0xFF8338EC,
    'audio/acoustic_lofi.wav',
  ),
  zenRiverChimes(
    'Zen River & Chimes',
    'Gentle flowing stream & singing bowl chimes',
    0xFF38BDF8,
    'audio/zen_river.wav',
  ),
  campfireWarmth(
    'Campfire Warmth',
    'Crackling wood embers & evening mountain breeze',
    0xFFF59E0B,
    'audio/campfire_warmth.wav',
  ),
  silentZen(
    'Pure Silence',
    'Zero audio, deep silent breath',
    0xFF94A3B8,
    '',
  ),
  customSystemAudio(
    'System / My Music',
    'Play custom song or audio from your device',
    0xFF10B981,
    '',
  );

  final String title;
  final String description;
  final int accentColorHex;
  final String assetPath;

  const SoundscapePreset(
    this.title,
    this.description,
    this.accentColorHex,
    this.assetPath,
  );
}

enum BreathPhase {
  inhale('Inhale slowly...'),
  hold('Hold gently...'),
  exhale('Exhale and release...');

  final String label;
  const BreathPhase(this.label);
}

class ChaiBreakState {
  final int totalDurationSeconds;
  final int remainingSeconds;
  final bool isRunning;
  final SoundscapePreset selectedSoundscape;
  final BreathPhase breathPhase;
  final bool isBreathingGuideEnabled;
  final bool isAudioMuted;
  final String? customAudioPath;
  final String? customAudioName;
  final double volume;

  const ChaiBreakState({
    this.totalDurationSeconds = 600, // 10 minutes default
    this.remainingSeconds = 600,
    this.isRunning = true,
    this.selectedSoundscape = SoundscapePreset.tapriCafeRain,
    this.breathPhase = BreathPhase.inhale,
    this.isBreathingGuideEnabled = true,
    this.isAudioMuted = false,
    this.customAudioPath,
    this.customAudioName,
    this.volume = 0.85,
  });

  bool get isPlayingCustomAudio =>
      selectedSoundscape == SoundscapePreset.customSystemAudio &&
      customAudioPath != null &&
      customAudioPath!.isNotEmpty;

  int get elapsedSeconds => totalDurationSeconds - remainingSeconds;

  double get progressFraction {
    if (totalDurationSeconds <= 0) return 0.0;
    return (elapsedSeconds / totalDurationSeconds).clamp(0.0, 1.0);
  }

  String get formattedRemaining {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  ChaiBreakState copyWith({
    int? totalDurationSeconds,
    int? remainingSeconds,
    bool? isRunning,
    SoundscapePreset? selectedSoundscape,
    BreathPhase? breathPhase,
    bool? isBreathingGuideEnabled,
    bool? isAudioMuted,
    String? customAudioPath,
    String? customAudioName,
    double? volume,
  }) {
    return ChaiBreakState(
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      selectedSoundscape: selectedSoundscape ?? this.selectedSoundscape,
      breathPhase: breathPhase ?? this.breathPhase,
      isBreathingGuideEnabled: isBreathingGuideEnabled ?? this.isBreathingGuideEnabled,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      customAudioPath: customAudioPath ?? this.customAudioPath,
      customAudioName: customAudioName ?? this.customAudioName,
      volume: volume ?? this.volume,
    );
  }
}

class ChaiBreakNotifier extends Notifier<ChaiBreakState> {
  Timer? _timer;
  Timer? _breathTimer;
  int _breathTick = 0;
  AudioPlayer? _player;

  @override
  ChaiBreakState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _breathTimer?.cancel();
      _disposeAudioPlayer();
    });

    _initAudioPlayer();
    _startTimer();
    _startBreathCycle();

    return const ChaiBreakState();
  }

  void _initAudioPlayer() {
    final isTestEnv = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isTestEnv) return;

    try {
      _player = AudioPlayer();
      _player?.setReleaseMode(ReleaseMode.loop).catchError((_) {});
      _playCurrentSoundscape();
    } catch (_) {}
  }

  Future<void> _disposeAudioPlayer() async {
    try {
      await _player?.stop().catchError((_) {});
      await _player?.dispose().catchError((_) {});
    } catch (_) {}
  }

  Future<void> _playCurrentSoundscape() async {
    if (_player == null) return;
    try {
      if (state.isAudioMuted || !state.isRunning) {
        await _player?.pause().catchError((_) {});
        return;
      }

      await _player?.setVolume(state.volume).catchError((_) {});

      if (state.selectedSoundscape == SoundscapePreset.customSystemAudio) {
        if (state.customAudioPath != null && state.customAudioPath!.isNotEmpty) {
          await _player?.play(DeviceFileSource(state.customAudioPath!)).catchError((_) {});
        } else {
          await _player?.pause().catchError((_) {});
        }
        return;
      }

      final asset = state.selectedSoundscape.assetPath;
      if (asset.isEmpty) {
        await _player?.pause().catchError((_) {});
      } else {
        await _player?.play(AssetSource(asset)).catchError((_) {});
      }
    } catch (_) {
      // Graceful fallback for offline mode or mock testing environments
    }
  }

  void toggleAudioMute() {
    state = state.copyWith(isAudioMuted: !state.isAudioMuted);
    _playCurrentSoundscape();
  }

  void setVolume(double vol) {
    final clamped = vol.clamp(0.0, 1.0);
    state = state.copyWith(volume: clamped);
    _player?.setVolume(clamped).catchError((_) {});
  }

  Future<void> pickCustomAudioFile() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac', 'opus'],
      );

      if (picked != null && picked.path != null) {
        final path = picked.path!;
        final name = picked.name;
        state = state.copyWith(
          selectedSoundscape: SoundscapePreset.customSystemAudio,
          customAudioPath: path,
          customAudioName: name,
        );
        await _playCurrentSoundscape();
      }
    } catch (_) {}
  }

  void clearCustomAudio() {
    state = state.copyWith(
      selectedSoundscape: SoundscapePreset.tapriCafeRain,
      customAudioPath: null,
      customAudioName: null,
    );
    _playCurrentSoundscape();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning) return;
      if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        pause();
      }
    });
  }

  void _startBreathCycle() {
    _breathTimer?.cancel();
    // 8-second cycle: 4s inhale (0-3), 2s hold (4-5), 4s exhale (6-9)
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning || !state.isBreathingGuideEnabled) return;
      _breathTick = (_breathTick + 1) % 10;
      if (_breathTick < 4) {
        if (state.breathPhase != BreathPhase.inhale) {
          state = state.copyWith(breathPhase: BreathPhase.inhale);
        }
      } else if (_breathTick < 6) {
        if (state.breathPhase != BreathPhase.hold) {
          state = state.copyWith(breathPhase: BreathPhase.hold);
        }
      } else {
        if (state.breathPhase != BreathPhase.exhale) {
          state = state.copyWith(breathPhase: BreathPhase.exhale);
        }
      }
    });
  }

  void setPresetMinutes(int minutes) {
    final seconds = minutes * 60;
    state = state.copyWith(
      totalDurationSeconds: seconds,
      remainingSeconds: seconds,
      isRunning: true,
    );
    _startTimer();
    _startBreathCycle();
    _playCurrentSoundscape();
  }

  void togglePlayPause() {
    if (state.isRunning) {
      pause();
    } else {
      resume();
    }
  }

  void pause() {
    state = state.copyWith(isRunning: false);
    _playCurrentSoundscape();
  }

  void resume() {
    if (state.remainingSeconds <= 0) {
      state = state.copyWith(remainingSeconds: state.totalDurationSeconds);
    }
    state = state.copyWith(isRunning: true);
    _playCurrentSoundscape();
  }

  void selectSoundscape(SoundscapePreset soundscape) {
    state = state.copyWith(selectedSoundscape: soundscape);
    _playCurrentSoundscape();
  }

  void toggleBreathingGuide() {
    state = state.copyWith(isBreathingGuideEnabled: !state.isBreathingGuideEnabled);
  }
}

final chaiBreakProvider = NotifierProvider.autoDispose<ChaiBreakNotifier, ChaiBreakState>(ChaiBreakNotifier.new);
