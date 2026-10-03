import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/settings_provider.dart';
import 'default_course_data.dart';
import 'learning_hub_models.dart';

const _kLearningProgressKey = 'ascent_learning_hub_lecture_progress_v2';
const _kActiveLectureIdKey = 'ascent_learning_hub_active_lecture_id_v2';

class LearningHubState {
  final Course course;
  final int activeLectureId;
  final bool isPlaying;
  final int currentElapsedSeconds;
  final bool isLiveFocusActive;

  const LearningHubState({
    required this.course,
    required this.activeLectureId,
    this.isPlaying = false,
    this.currentElapsedSeconds = 0,
    this.isLiveFocusActive = false,
  });

  Lecture get activeLecture {
    for (final module in course.modules) {
      for (final lecture in module.lectures) {
        if (lecture.id == activeLectureId) {
          return lecture;
        }
      }
    }
    return course.modules.first.lectures.first;
  }

  CourseModule get activeModule {
    for (final module in course.modules) {
      for (final lecture in module.lectures) {
        if (lecture.id == activeLectureId) {
          return module;
        }
      }
    }
    return course.modules.first;
  }

  int get remainingSeconds {
    final rem = activeLecture.durationSeconds - currentElapsedSeconds;
    return rem > 0 ? rem : 0;
  }

  double get progressFraction {
    if (activeLecture.durationSeconds <= 0) return 0.0;
    return (currentElapsedSeconds / activeLecture.durationSeconds).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressFraction * 100).round();

  String get formattedRemaining {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedElapsed {
    final m = currentElapsedSeconds ~/ 60;
    final s = currentElapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  LearningHubState copyWith({
    Course? course,
    int? activeLectureId,
    bool? isPlaying,
    int? currentElapsedSeconds,
    bool? isLiveFocusActive,
  }) {
    return LearningHubState(
      course: course ?? this.course,
      activeLectureId: activeLectureId ?? this.activeLectureId,
      isPlaying: isPlaying ?? this.isPlaying,
      currentElapsedSeconds: currentElapsedSeconds ?? this.currentElapsedSeconds,
      isLiveFocusActive: isLiveFocusActive ?? this.isLiveFocusActive,
    );
  }
}

class LearningHubNotifier extends Notifier<LearningHubState> {
  Timer? _ticker;
  Timer? _flushTimer;

  @override
  LearningHubState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final initialCourse = _loadStoredProgress(prefs);
    final activeId = prefs.getInt(_kActiveLectureIdKey) ?? 1;

    Lecture initialActive = initialCourse.modules.first.lectures.first;
    for (final m in initialCourse.modules) {
      for (final l in m.lectures) {
        if (l.id == activeId) {
          initialActive = l;
          break;
        }
      }
    }

    ref.onDispose(() {
      _ticker?.cancel();
      _flushTimer?.cancel();
    });

    return LearningHubState(
      course: initialCourse,
      activeLectureId: activeId,
      currentElapsedSeconds: initialActive.elapsedSeconds,
      isPlaying: false,
    );
  }

  Course _loadStoredProgress(SharedPreferences prefs) {
    final baseCourse = buildDefaultSpringBootCourse();
    final rawJson = prefs.getString(_kLearningProgressKey);
    if (rawJson == null) return baseCourse;

    try {
      final Map<String, dynamic> data = jsonDecode(rawJson);
      final updatedModules = baseCourse.modules.map((module) {
        final updatedLectures = module.lectures.map((lecture) {
          final key = lecture.id.toString();
          if (data.containsKey(key)) {
            final item = data[key] as Map<String, dynamic>;
            final elapsed = (item['elapsed'] as num?)?.toInt() ?? lecture.elapsedSeconds;
            final completed = item['completed'] == true;
            return lecture.copyWith(
              elapsedSeconds: elapsed,
              isCompleted: completed,
            );
          }
          return lecture;
        }).toList();

        return CourseModule(
          id: module.id,
          title: module.title,
          description: module.description,
          durationHours: module.durationHours,
          lectures: updatedLectures,
        );
      }).toList();

      return Course(
        id: baseCourse.id,
        title: baseCourse.title,
        description: baseCourse.description,
        author: baseCourse.author,
        daysLeft: baseCourse.daysLeft,
        targetMinutesPerDay: baseCourse.targetMinutesPerDay,
        modules: updatedModules,
      );
    } catch (_) {
      return baseCourse;
    }
  }

  void _persistProgress() {
    final prefs = ref.read(sharedPreferencesProvider);
    final Map<String, dynamic> map = {};
    for (final mod in state.course.modules) {
      for (final lec in mod.lectures) {
        map[lec.id.toString()] = {
          'elapsed': lec.id == state.activeLectureId
              ? state.currentElapsedSeconds
              : lec.elapsedSeconds,
          'completed': lec.isCompleted,
        };
      }
    }
    prefs.setString(_kLearningProgressKey, jsonEncode(map));
    prefs.setInt(_kActiveLectureIdKey, state.activeLectureId);
  }

  void play() {
    if (state.isPlaying) return;
    state = state.copyWith(isPlaying: true, isLiveFocusActive: true);

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final active = state.activeLecture;
      final newElapsed = state.currentElapsedSeconds + 1;

      if (newElapsed >= active.durationSeconds) {
        // Lecture completed automatically
        markLectureCompleted(active.id);
      } else {
        state = state.copyWith(currentElapsedSeconds: newElapsed);
        _updateCurrentLectureInCourse(newElapsed, active.isCompleted);
      }
    });

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _persistProgress();
    });
  }

  void pause() {
    _ticker?.cancel();
    _flushTimer?.cancel();
    _persistProgress();
    state = state.copyWith(isPlaying: false);
  }

  void togglePlayPause() {
    if (state.isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void seekBy(int offsetSeconds) {
    final active = state.activeLecture;
    final target = (state.currentElapsedSeconds + offsetSeconds)
        .clamp(0, active.durationSeconds);
    state = state.copyWith(currentElapsedSeconds: target);
    _updateCurrentLectureInCourse(target, active.isCompleted);
    _persistProgress();
  }

  void seekTo(double fraction) {
    final active = state.activeLecture;
    final target = (active.durationSeconds * fraction).round().clamp(0, active.durationSeconds);
    state = state.copyWith(currentElapsedSeconds: target);
    _updateCurrentLectureInCourse(target, active.isCompleted);
    _persistProgress();
  }

  void selectLecture(int lectureId, {bool autoPlay = false}) {
    // Save current lecture
    _persistProgress();
    _ticker?.cancel();
    _flushTimer?.cancel();

    // Find new lecture
    Lecture? targetLecture;
    for (final mod in state.course.modules) {
      for (final lec in mod.lectures) {
        if (lec.id == lectureId) {
          targetLecture = lec;
          break;
        }
      }
    }

    if (targetLecture == null) return;

    state = state.copyWith(
      activeLectureId: lectureId,
      currentElapsedSeconds: targetLecture.elapsedSeconds,
      isPlaying: false,
    );

    ref.read(sharedPreferencesProvider).setInt(_kActiveLectureIdKey, lectureId);

    if (autoPlay) {
      play();
    }
  }

  void markLectureCompleted(int lectureId) {
    _updateCurrentLectureInCourse(state.currentElapsedSeconds, true, targetLectureId: lectureId);
    _persistProgress();

    // Advance to next lecture if available
    final allLectures = state.course.modules.expand((m) => m.lectures).toList();
    final currentIndex = allLectures.indexWhere((l) => l.id == lectureId);
    if (currentIndex != -1 && currentIndex + 1 < allLectures.length) {
      final nextLec = allLectures[currentIndex + 1];
      selectLecture(nextLec.id, autoPlay: state.isPlaying);
    } else {
      pause();
    }
  }

  void _updateCurrentLectureInCourse(int elapsed, bool isCompleted, {int? targetLectureId}) {
    final targetId = targetLectureId ?? state.activeLectureId;
    final updatedModules = state.course.modules.map((module) {
      final updatedLectures = module.lectures.map((lecture) {
        if (lecture.id == targetId) {
          return lecture.copyWith(
            elapsedSeconds: elapsed,
            isCompleted: isCompleted,
            lastPlayedAt: DateTime.now(),
          );
        }
        return lecture;
      }).toList();

      return CourseModule(
        id: module.id,
        title: module.title,
        description: module.description,
        durationHours: module.durationHours,
        lectures: updatedLectures,
      );
    }).toList();

    final updatedCourse = Course(
      id: state.course.id,
      title: state.course.title,
      description: state.course.description,
      author: state.course.author,
      daysLeft: state.course.daysLeft,
      targetMinutesPerDay: state.course.targetMinutesPerDay,
      modules: updatedModules,
    );

    state = state.copyWith(course: updatedCourse);
  }
}

final learningHubProvider = NotifierProvider<LearningHubNotifier, LearningHubState>(
  LearningHubNotifier.new,
);
