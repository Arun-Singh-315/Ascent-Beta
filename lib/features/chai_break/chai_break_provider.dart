import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SoundscapePreset {
  tapriCafeRain('Tapri Cafe & Rain', 'Cozy rain on tin roof with distant cafe murmur', 0xFFE28B57),
  acousticLofi('Acoustic Lo-Fi', 'Warm Rhodes piano & mellow nylon guitar chords', 0xFF8338EC),
  zenRiverChimes('Zen River & Chimes', 'Gentle flowing stream & singing bowl chimes', 0xFF38BDF8),
  campfireWarmth('Campfire Warmth', 'Crackling wood embers & evening mountain breeze', 0xFFF59E0B),
  silentZen('Pure Silence', 'Zero audio, deep silent breath', 0xFF94A3B8);

  final String title;
  final String description;
  final int accentColorHex;

  const SoundscapePreset(this.title, this.description, this.accentColorHex);
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

  const ChaiBreakState({
    this.totalDurationSeconds = 600, // 10 minutes default
    this.remainingSeconds = 600,
    this.isRunning = true,
    this.selectedSoundscape = SoundscapePreset.tapriCafeRain,
    this.breathPhase = BreathPhase.inhale,
    this.isBreathingGuideEnabled = true,
  });

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
  }) {
    return ChaiBreakState(
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      selectedSoundscape: selectedSoundscape ?? this.selectedSoundscape,
      breathPhase: breathPhase ?? this.breathPhase,
      isBreathingGuideEnabled: isBreathingGuideEnabled ?? this.isBreathingGuideEnabled,
    );
  }
}

class ChaiBreakNotifier extends Notifier<ChaiBreakState> {
  Timer? _timer;
  Timer? _breathTimer;
  int _breathTick = 0;

  @override
  ChaiBreakState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _breathTimer?.cancel();
    });

    _startTimer();
    _startBreathCycle();

    return const ChaiBreakState();
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
  }

  void resume() {
    if (state.remainingSeconds <= 0) {
      state = state.copyWith(remainingSeconds: state.totalDurationSeconds);
    }
    state = state.copyWith(isRunning: true);
  }

  void selectSoundscape(SoundscapePreset soundscape) {
    state = state.copyWith(selectedSoundscape: soundscape);
  }

  void toggleBreathingGuide() {
    state = state.copyWith(isBreathingGuideEnabled: !state.isBreathingGuideEnabled);
  }
}

final chaiBreakProvider = NotifierProvider.autoDispose<ChaiBreakNotifier, ChaiBreakState>(ChaiBreakNotifier.new);
