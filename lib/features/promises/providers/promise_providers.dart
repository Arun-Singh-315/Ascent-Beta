import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/settings_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/providers/database_provider.dart';
import '../models/promise_model.dart';
import '../services/promise_repository.dart';

/// Provider for the singleton [PromiseRepository].
final promiseRepositoryProvider = Provider<PromiseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = PromiseRepository(db);
  return repo;
});

/// Stream of all active, non-archived promises.
final activePromisesStreamProvider = StreamProvider<List<PromiseModel>>((ref) {
  final repo = ref.watch(promiseRepositoryProvider);
  return repo.watchActivePromises();
});

/// Stream of all completed promises.
final completedPromisesStreamProvider = StreamProvider<List<PromiseModel>>((
  ref,
) {
  final repo = ref.watch(promiseRepositoryProvider);
  return repo.watchCompletedPromises();
});

/// Stream of all paused promises.
final pausedPromisesStreamProvider = StreamProvider<List<PromiseModel>>((ref) {
  final repo = ref.watch(promiseRepositoryProvider);
  return repo.watchPausedPromises();
});

/// Stream of all promises.
final allPromisesStreamProvider = StreamProvider<List<PromiseModel>>((ref) {
  final repo = ref.watch(promiseRepositoryProvider);
  return repo.watchAllPromises();
});

/// Set of IDs of promises that are marked private.
final privatePromiseIdsProvider = Provider<Set<int>>((ref) {
  final all = ref.watch(allPromisesStreamProvider).value ?? [];
  return all.where((p) => p.isPrivate).map((p) => p.id).toSet();
});

class UnlockedPromiseIdsNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => <int>{};

  void unlock(int id) {
    state = {...state, id};
  }

  void lock(int id) {
    state = {...state}..remove(id);
  }

  void lockAll() {
    state = <int>{};
  }

  void toggle(int id) {
    if (state.contains(id)) {
      lock(id);
    } else {
      unlock(id);
    }
  }
}

/// Session-wide unlocked private promise IDs.
final unlockedPromiseIdsProvider =
    NotifierProvider<UnlockedPromiseIdsNotifier, Set<int>>(
  UnlockedPromiseIdsNotifier.new,
);

/// Computes the single most urgent, relevant active promise for the Home screen.
/// Never returns a completed or paused promise.
final priorityPromiseProvider = Provider<PromiseModel?>((ref) {
  final activeAsync = ref.watch(activePromisesStreamProvider);
  return activeAsync.when(
    data: (promises) {
      if (promises.isEmpty) return null;

      // Sort by priority:
      // 1. Duration promises with an active/partial session
      // 2. Due today or overdue
      // 3. Frequency promises with lowest completion ratio
      // 4. Most recently created
      final sorted =
          List<PromiseModel>.from(
            promises.where((p) => p.canActAt(DateTime.now())),
          )..sort((a, b) {
            // Active session taking place
            final aPartial =
                a.trackingType == PromiseTrackingType.duration &&
                a.currentValue > 0 &&
                a.currentValue < a.targetValue;
            final bPartial =
                b.trackingType == PromiseTrackingType.duration &&
                b.currentValue > 0 &&
                b.currentValue < b.targetValue;
            if (aPartial && !bPartial) return -1;
            if (!aPartial && bPartial) return 1;

            // Due date closeness
            if (a.targetDate != null && b.targetDate != null) {
              return a.targetDate!.compareTo(b.targetDate!);
            }
            if (a.targetDate != null) return -1;
            if (b.targetDate != null) return 1;

            // Scheduled reminder hour closeness
            if (a.reminderTime != null && b.reminderTime != null) {
              return a.reminderTime!.compareTo(b.reminderTime!);
            }

            // Newest creation
            return b.createdAt.compareTo(a.createdAt);
          });

      return sorted.firstOrNull;
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

final promiseByIdProvider = StreamProvider.family<PromiseModel?, int>(
  (ref, id) => ref
      .watch(promiseRepositoryProvider)
      .watchAllPromises()
      .map((all) => all.where((p) => p.id == id).firstOrNull),
);
final promiseEventsProvider =
    FutureProvider.family<List<PromiseProgressEvent>, int>((ref, id) {
      ref.watch(promiseByIdProvider(id));
      return ref.watch(promiseRepositoryProvider).getProgressEvents(id);
    });
final promiseCalendarProvider =
    FutureProvider.family<List<PromiseDayRecord>, (int, int, int)>((ref, key) {
      ref.watch(promiseByIdProvider(key.$1));
      return ref
          .watch(promiseRepositoryProvider)
          .calendar(key.$1, DateTime(key.$2, key.$3));
    });

/// State of an in-progress timed session for a duration promise.
class PromiseSessionState {
  const PromiseSessionState({
    this.promiseId,
    this.elapsedSeconds = 0,
    this.isRunning = false,
  });

  final int? promiseId;
  final int elapsedSeconds;
  final bool isRunning;

  int get elapsedMinutes => (elapsedSeconds / 60).floor();

  PromiseSessionState copyWith({
    int? promiseId,
    int? elapsedSeconds,
    bool? isRunning,
  }) {
    return PromiseSessionState(
      promiseId: promiseId ?? this.promiseId,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isRunning: isRunning ?? this.isRunning,
    );
  }
}

/// Controller for live duration sessions across screen navigation.
class PromiseSessionNotifier extends Notifier<PromiseSessionState> {
  Timer? _timer;
  DateTime? _started;
  int _baseSeconds = 0;
  SharedPreferences? _preferences;
  static const storageKey = 'promise_session_v1';
  @override
  PromiseSessionState build() {
    ref.onDispose(() => _timer?.cancel());
    try {
      _preferences = ref.read(sharedPreferencesProvider);
    } catch (_) {
      /* Headless tests. */
    }
    try {
      final raw = _preferences?.getString(storageKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map;
        _baseSeconds = data['seconds'] as int;
        _started = DateTime.tryParse(data['started'] as String? ?? '');
        if (_started != null) _startTimer();
        return PromiseSessionState(
          promiseId: data['id'] as int,
          elapsedSeconds: _elapsed,
          isRunning: _started != null,
        );
      }
    } catch (_) {
      _started = null;
      _baseSeconds = 0;
    }
    return const PromiseSessionState();
  }

  int get _elapsed =>
      _baseSeconds +
      (_started == null
          ? 0
          : DateTime.now().difference(_started!).inSeconds.clamp(0, 31536000));
  Future<void> _persist() async {
    final prefs = _preferences;
    if (prefs == null) return;
    final ok = state.promiseId == null
        ? await prefs.remove(storageKey)
        : await prefs.setString(
            storageKey,
            jsonEncode({
              'id': state.promiseId,
              'seconds': _baseSeconds,
              'started': _started?.toUtc().toIso8601String(),
            }),
          );
    if (!ok) throw StateError('Could not keep the timer. Please try again.');
  }

  Future<void> startSession(int promiseId) async {
    if (state.promiseId != null) {
      if (state.promiseId != promiseId) {
        throw StateError('Finish your other timer first.');
      }
      return resumeSession();
    }
    _baseSeconds = 0;
    _started = DateTime.now();
    state = PromiseSessionState(promiseId: promiseId, isRunning: true);
    _startTimer();
    await _persist();
  }

  Future<void> pauseSession() async {
    if (!state.isRunning) return;
    _baseSeconds = _elapsed;
    _started = null;
    _timer?.cancel();
    state = state.copyWith(elapsedSeconds: _baseSeconds, isRunning: false);
    await _persist();
  }

  Future<void> resumeSession() async {
    if (state.promiseId == null || state.isRunning) return;
    _started = DateTime.now();
    state = state.copyWith(isRunning: true);
    _startTimer();
    await _persist();
  }

  Future<void> stopSession() async {
    _timer?.cancel();
    _started = null;
    _baseSeconds = 0;
    state = const PromiseSessionState();
    await _persist();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: _elapsed);
    });
  }
}

final activePromiseSessionProvider =
    NotifierProvider<PromiseSessionNotifier, PromiseSessionState>(
      PromiseSessionNotifier.new,
    );
