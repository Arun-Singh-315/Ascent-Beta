import 'package:drift/drift.dart' show Value, OrderingTerm;
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/streak/study_streak_provider.dart';

enum ChaiBreakMode {
  mindfulPause,
  studyWithMe,
  brewWithMe,
}

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
    0xFFEC8C38,
    'audio/acoustic_lofi.wav',
  ),
  zenRiverChimes(
    'Zen River & Chimes',
    'Gentle flowing stream & singing bowl chimes',
    0xFFF89238,
    'audio/zen_river.wav',
  ),
  campfireWarmth(
    'Campfire Warmth',
    'Crackling wood embers & evening mountain breeze',
    0xFFF59E0B,
    'audio/campfire_warmth.wav',
  ),
  deepFocusDrone(
    'Deep Focus Drone (432Hz)',
    'Continuous theta waves & calming binaural drone for deep study',
    0xFF6E8565,
    'audio/deep_concentration_drone.wav',
  ),
  monsoonFlute(
    'Monsoon Flute & Rain',
    'Slow meditative bansuri notes with gentle mountain drizzle',
    0xFF14B8A6,
    'audio/slow_monsoon_flute.wav',
  ),
  midnightLibrary(
    'Midnight Library',
    'Soft nocturnal room tones, slow warm chords & peaceful study calm',
    0xFFF6A45C,
    'audio/night_library_study.wav',
  ),
  silentZen('Pure Silence', 'Zero audio, deep silent breath', 0xFFB8A594, ''),
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
  final bool hasStarted;
  final SoundscapePreset selectedSoundscape;
  final BreathPhase breathPhase;
  final bool isBreathingGuideEnabled;
  final bool isAudioMuted;
  final String? customAudioPath;
  final String? customAudioName;
  final double volume;
  final ChaiBreakMode mode;
  final int? linkedTaskId;
  final String? linkedTaskTitle;
  final int? activeStudySessionId;

  const ChaiBreakState({
    this.totalDurationSeconds = 600, // 10 minutes default
    this.remainingSeconds = 600,
    this.isRunning = false,
    this.hasStarted = false,
    this.selectedSoundscape = SoundscapePreset.tapriCafeRain,
    this.breathPhase = BreathPhase.inhale,
    this.isBreathingGuideEnabled = true,
    this.isAudioMuted = false,
    this.customAudioPath,
    this.customAudioName,
    this.volume = 0.85,
    this.mode = ChaiBreakMode.mindfulPause,
    this.linkedTaskId,
    this.linkedTaskTitle,
    this.activeStudySessionId,
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
    bool? hasStarted,
    SoundscapePreset? selectedSoundscape,
    BreathPhase? breathPhase,
    bool? isBreathingGuideEnabled,
    bool? isAudioMuted,
    String? customAudioPath,
    String? customAudioName,
    double? volume,
    ChaiBreakMode? mode,
    int? linkedTaskId,
    String? linkedTaskTitle,
    int? activeStudySessionId,
    bool clearLinkedTask = false,
    bool clearActiveStudySessionId = false,
  }) {
    return ChaiBreakState(
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      hasStarted: hasStarted ?? this.hasStarted,
      selectedSoundscape: selectedSoundscape ?? this.selectedSoundscape,
      breathPhase: breathPhase ?? this.breathPhase,
      isBreathingGuideEnabled:
          isBreathingGuideEnabled ?? this.isBreathingGuideEnabled,
      isAudioMuted: isAudioMuted ?? this.isAudioMuted,
      customAudioPath: customAudioPath ?? this.customAudioPath,
      customAudioName: customAudioName ?? this.customAudioName,
      volume: volume ?? this.volume,
      mode: mode ?? this.mode,
      linkedTaskId: clearLinkedTask ? null : (linkedTaskId ?? this.linkedTaskId),
      linkedTaskTitle: clearLinkedTask ? null : (linkedTaskTitle ?? this.linkedTaskTitle),
      activeStudySessionId: clearActiveStudySessionId
          ? null
          : (activeStudySessionId ?? this.activeStudySessionId),
    );
  }
}

class ChaiBreakNotifier extends Notifier<ChaiBreakState> {
  Timer? _timer;
  Timer? _breathTimer;
  int _breathTick = 0;
  AudioPlayer? _player;
  String? _historySession;
  int? _activeStudySessionId;

  Future<void> _startStudySessionIfNeeded() async {
    if (!ref.mounted) return;
    if (state.mode != ChaiBreakMode.studyWithMe || _activeStudySessionId != null) return;
    try {
      final dao = ref.read(timeSessionDaoProvider);
      final categories = await dao.getAllCategories();
      final categoryId = categories.isNotEmpty ? categories.first.id : 1;
      final label = state.linkedTaskTitle != null && state.linkedTaskTitle!.isNotEmpty
          ? 'Chai Study: ${state.linkedTaskTitle}'
          : 'Chai Study & Flow';
      _activeStudySessionId = await dao.startSession(
        label: label,
        categoryId: categoryId,
        activityType: 'study',
        linkedTaskId: state.linkedTaskId,
        activityRefType: 'chai_session',
      );
      if (ref.mounted) {
        state = state.copyWith(activeStudySessionId: _activeStudySessionId);
      }
    } catch (e) {
      debugPrint('Chai study session start deferred: $e');
    }
  }

  Future<void> _completeStudySessionIfNeeded() async {
    final sessionId = _activeStudySessionId ?? state.activeStudySessionId;
    if (sessionId == null) return;
    _activeStudySessionId = null;
    try {
      if (!ref.mounted) return;
      final dao = ref.read(timeSessionDaoProvider);
      await dao.completeSession(sessionId);
      if (ref.mounted) {
        ref.invalidate(homeQuickStatsProvider);
        ref.invalidate(todayTasksStreamProvider);
      }
    } catch (e) {
      debugPrint('Chai study session complete deferred: $e');
    }
    if (ref.mounted) {
      state = state.copyWith(clearActiveStudySessionId: true);
    }
  }

  void setMode(ChaiBreakMode newMode) {
    if (state.mode == newMode) return;
    if (state.isRunning) {
      stop();
    }
    final int defaultSeconds = (newMode == ChaiBreakMode.studyWithMe) ? 1500 : 600;
    state = state.copyWith(
      mode: newMode,
      totalDurationSeconds: defaultSeconds,
      remainingSeconds: defaultSeconds,
      isRunning: false,
      hasStarted: false,
    );
  }

  void linkTask(int taskId, String taskTitle) {
    state = state.copyWith(
      linkedTaskId: taskId,
      linkedTaskTitle: taskTitle,
    );
  }

  void unlinkTask() {
    state = state.copyWith(
      clearLinkedTask: true,
    );
  }

  void stop() {
    if (state.hasStarted) _record('cancelled');
    _finish();
  }

  void _record(String action) {
    _historySession ??= DateTime.now().microsecondsSinceEpoch.toString();
    final now = DateTime.now();
    final db = ref.read(databaseProvider);
    final title = state.mode == ChaiBreakMode.studyWithMe
        ? (state.linkedTaskTitle != null && state.linkedTaskTitle!.isNotEmpty
            ? 'Chai Study: ${state.linkedTaskTitle}'
            : 'Chai Study & Flow')
        : state.selectedSoundscape.title;
    final totalMins = state.totalDurationSeconds ~/ 60;
    final elapsedSecs = state.totalDurationSeconds - state.remainingSeconds;
    final entry = HistoryEventTableCompanion.insert(
      id: 'break:$_historySession:$action:${now.microsecondsSinceEpoch}',
      module: state.mode == ChaiBreakMode.studyWithMe ? 'study' : 'breaks',
      entityId: _historySession!,
      action: action,
      title: title,
      detail: Value(
        state.mode == ChaiBreakMode.studyWithMe
            ? '$elapsedSecs seconds of a $totalMins-minute study session'
            : '$elapsedSecs seconds of a $totalMins-minute break',
      ),
      occurredAt: now,
    );
    unawaited(
      db.into(db.historyEventTable).insert(entry).then<void>((_) {
        if (ref.mounted) {
          ref.invalidate(todayBreaksProvider);
          if (state.mode == ChaiBreakMode.studyWithMe) {
            ref.invalidate(homeQuickStatsProvider);
            ref.invalidate(todayTasksStreamProvider);
          }
        }
      }).catchError(
        (Object error) {
          debugPrint('Break history save deferred: $error');
        },
      ),
    );
  }

  @override
  ChaiBreakState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _breathTimer?.cancel();
      _disposeAudioPlayer();
      NotificationService.instance.cancelOngoingChaiBreakNotification();
    });

    return const ChaiBreakState();
  }

  void _initAudioPlayer() {
    final isTestEnv = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (isTestEnv) return;

    try {
      _player = AudioPlayer();
      _player?.setReleaseMode(ReleaseMode.loop).catchError((_) {});
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
        if (state.customAudioPath != null &&
            state.customAudioPath!.isNotEmpty) {
          await _player
              ?.play(DeviceFileSource(state.customAudioPath!))
              .catchError((_) {});
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
    int tickCount = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.isRunning) return;
      if (state.remainingSeconds > 0) {
        final remaining = state.remainingSeconds - 1;
        state = state.copyWith(remainingSeconds: remaining);
        if (state.mode == ChaiBreakMode.studyWithMe) {
          try {
            ref.read(studyStreakProvider.notifier).creditActiveSecond(DateTime.now());
          } catch (_) {}
        }
        if (remaining == 0) {
          _finish();
          return;
        }
        tickCount++;
        if (tickCount % 5 == 0 || remaining == 0) {
          NotificationService.instance.showOngoingChaiBreakNotification(
            remainingSeconds: remaining,
            soundscapeTitle: state.selectedSoundscape.title,
            isPaused: false,
          );
        }
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    if (state.hasStarted) _record('completed');
    _completeStudySessionIfNeeded();
    _historySession = null;
    _timer?.cancel();
    _breathTimer?.cancel();
    state = state.copyWith(isRunning: false, hasStarted: false);
    _playCurrentSoundscape();
    NotificationService.instance.cancelOngoingChaiBreakNotification();
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
    if (state.hasStarted) _record('cancelled');
    _completeStudySessionIfNeeded();
    _historySession = null;
    final seconds = minutes * 60;
    state = state.copyWith(
      totalDurationSeconds: seconds,
      remainingSeconds: seconds,
      isRunning: true,
      hasStarted: true,
    );
    _record('started');
    if (state.mode == ChaiBreakMode.studyWithMe) {
      _startStudySessionIfNeeded();
    }
    _initAudioPlayerIfNeeded();
    _startTimer();
    _startBreathCycle();
    _playCurrentSoundscape();
    NotificationService.instance.showOngoingChaiBreakNotification(
      remainingSeconds: seconds,
      soundscapeTitle: state.selectedSoundscape.title,
      isPaused: false,
    );
  }

  void togglePlayPause() {
    if (state.isRunning) {
      pause();
    } else {
      resume();
    }
  }

  void pause() {
    if (state.hasStarted && state.isRunning) _record('paused');
    state = state.copyWith(isRunning: false);
    _playCurrentSoundscape();
    NotificationService.instance.showOngoingChaiBreakNotification(
      remainingSeconds: state.remainingSeconds,
      soundscapeTitle: state.selectedSoundscape.title,
      isPaused: true,
    );
  }

  void _initAudioPlayerIfNeeded() {
    if (_player == null) _initAudioPlayer();
  }

  void resume() {
    _record(state.hasStarted ? 'resumed' : 'started');
    if (state.remainingSeconds <= 0) {
      state = state.copyWith(remainingSeconds: state.totalDurationSeconds);
    }
    state = state.copyWith(isRunning: true, hasStarted: true);
    if (state.mode == ChaiBreakMode.studyWithMe) {
      _startStudySessionIfNeeded();
    }
    _initAudioPlayerIfNeeded();
    _startTimer();
    _startBreathCycle();
    _playCurrentSoundscape();
    NotificationService.instance.showOngoingChaiBreakNotification(
      remainingSeconds: state.remainingSeconds,
      soundscapeTitle: state.selectedSoundscape.title,
      isPaused: false,
    );
  }

  void selectSoundscape(SoundscapePreset soundscape) {
    state = state.copyWith(selectedSoundscape: soundscape);
    _playCurrentSoundscape();
    if (!state.hasStarted) return;
    NotificationService.instance.showOngoingChaiBreakNotification(
      remainingSeconds: state.remainingSeconds,
      soundscapeTitle: soundscape.title,
      isPaused: !state.isRunning,
    );
  }

  void toggleBreathingGuide() {
    state = state.copyWith(
      isBreathingGuideEnabled: !state.isBreathingGuideEnabled,
    );
  }
}

final chaiBreakProvider = NotifierProvider<ChaiBreakNotifier, ChaiBreakState>(
  ChaiBreakNotifier.new,
);

final todayBreaksProvider = FutureProvider.autoDispose<List<HistoryEvent>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.historyEventTable)
    ..where((t) => t.module.equals('breaks'))
    ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
    ..limit(10)
  ).get();
});
