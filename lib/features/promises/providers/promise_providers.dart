import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/core/providers/database_provider.dart';
import '../models/promise_model.dart';
import '../services/promise_repository.dart';

/// Provider for the singleton [PromiseRepository].
final promiseRepositoryProvider = Provider<PromiseRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = PromiseRepository(db);
  repo.initialize();
  return repo;
});

/// Stream of all active, non-archived promises.
final activePromisesStreamProvider = StreamProvider<List<PromiseModel>>((ref) {
  final repo = ref.watch(promiseRepositoryProvider);
  return repo.watchActivePromises();
});

/// Stream of all completed promises.
final completedPromisesStreamProvider = StreamProvider<List<PromiseModel>>((ref) {
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

/// Computes the single most urgent, relevant active promise for the Home screen.
/// Never returns a completed or paused promise.
final priorityPromiseProvider = Provider<PromiseModel?>((ref) {
  final activeAsync = ref.watch(activePromisesStreamProvider);
  return activeAsync.when(
    data: (promises) {
      if (promises.isEmpty) return null;

      final now = DateTime.now();

      // Sort by priority:
      // 1. Duration promises with an active/partial session
      // 2. Due today or overdue
      // 3. Frequency promises with lowest completion ratio
      // 4. Most recently created
      final sorted = List<PromiseModel>.from(promises)..sort((a, b) {
        // Active session taking place
        final aPartial = a.trackingType == PromiseTrackingType.duration && a.currentValue > 0 && a.currentValue < a.targetValue;
        final bPartial = b.trackingType == PromiseTrackingType.duration && b.currentValue > 0 && b.currentValue < b.targetValue;
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

      return sorted.first;
    },
    loading: () => null,
    error: (_, __) => null,
  );
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

  @override
  PromiseSessionState build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const PromiseSessionState();
  }

  void startSession(int promiseId) {
    if (state.promiseId == promiseId && state.isRunning) return;
    _timer?.cancel();
    state = PromiseSessionState(
      promiseId: promiseId,
      elapsedSeconds: 0,
      isRunning: true,
    );
    _startTimer();
  }

  void pauseSession() {
    _timer?.cancel();
    state = state.copyWith(isRunning: false);
  }

  void resumeSession() {
    if (state.promiseId == null || state.isRunning) return;
    state = state.copyWith(isRunning: true);
    _startTimer();
  }

  void stopSession() {
    _timer?.cancel();
    state = const PromiseSessionState();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(elapsedSeconds: state.elapsedSeconds + 1);
    });
  }
}

final activePromiseSessionProvider =
    NotifierProvider<PromiseSessionNotifier, PromiseSessionState>(
  PromiseSessionNotifier.new,
);
