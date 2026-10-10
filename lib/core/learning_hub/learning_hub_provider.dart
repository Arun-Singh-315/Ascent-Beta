import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/drift.dart' as drift;

import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/time_tracking_provider.dart';
import '../notifications/notification_service.dart';
import '../streak/study_streak_provider.dart';
import 'default_course_data.dart';
import 'learning_hub_models.dart';

const _kCoursesListKey = 'ascent_learning_hub_courses_v3';
const _kActiveCourseIdKey = 'ascent_learning_hub_active_course_v3';
const _kActiveLectureIdKey = 'ascent_learning_hub_active_lecture_id_v3';
const _kLegacyProgressKey = 'ascent_learning_hub_lecture_progress_v2';
const _kLegacyActiveLectureIdKey = 'ascent_learning_hub_active_lecture_id_v2';
const _kHasStartedLearningKey = 'ascent_learning_hub_has_started_learning_v1';

class LearningHubState {
  final List<Course> courses;
  final String activeCourseId;
  final int activeLectureId;
  final bool isPlaying;
  final int currentElapsedSeconds;
  final bool isLiveFocusActive;
  final bool isFloatingDismissed;
  final DateTime? playStartedAt;
  final int sessionBaseElapsed;
  final bool hasStartedLearning;

  const LearningHubState({
    required this.courses,
    required this.activeCourseId,
    required this.activeLectureId,
    this.isPlaying = false,
    this.currentElapsedSeconds = 0,
    this.isLiveFocusActive = false,
    this.isFloatingDismissed = false,
    this.playStartedAt,
    this.sessionBaseElapsed = 0,
    this.hasStartedLearning = false,
  });

  Course get course {
    for (final c in courses) {
      if (c.id == activeCourseId) return c;
    }
    return courses.isNotEmpty ? courses.first : buildDefaultSpringBootCourse();
  }

  Lecture get activeLecture {
    final curCourse = course;
    for (final module in curCourse.modules) {
      for (final lecture in module.lectures) {
        if (lecture.id == activeLectureId) {
          return lecture;
        }
      }
    }
    if (curCourse.modules.isNotEmpty && curCourse.modules.first.lectures.isNotEmpty) {
      return curCourse.modules.first.lectures.first;
    }
    return const Lecture(
      id: 1,
      moduleId: 1,
      moduleTitle: 'General',
      title: 'Introduction',
      durationSeconds: 300,
    );
  }

  CourseModule get activeModule {
    final curCourse = course;
    for (final module in curCourse.modules) {
      for (final lecture in module.lectures) {
        if (lecture.id == activeLectureId) {
          return module;
        }
      }
    }
    if (curCourse.modules.isNotEmpty) {
      return curCourse.modules.first;
    }
    return const CourseModule(
      id: 1,
      title: 'General Module',
      durationHours: 1.0,
      lectures: [],
    );
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
    List<Course>? courses,
    String? activeCourseId,
    int? activeLectureId,
    bool? isPlaying,
    int? currentElapsedSeconds,
    bool? isLiveFocusActive,
    bool? isFloatingDismissed,
    DateTime? playStartedAt,
    int? sessionBaseElapsed,
    bool? hasStartedLearning,
  }) {
    return LearningHubState(
      courses: courses ?? this.courses,
      activeCourseId: activeCourseId ?? this.activeCourseId,
      activeLectureId: activeLectureId ?? this.activeLectureId,
      isPlaying: isPlaying ?? this.isPlaying,
      currentElapsedSeconds: currentElapsedSeconds ?? this.currentElapsedSeconds,
      isLiveFocusActive: isLiveFocusActive ?? this.isLiveFocusActive,
      isFloatingDismissed: isFloatingDismissed ?? this.isFloatingDismissed,
      playStartedAt: playStartedAt ?? this.playStartedAt,
      sessionBaseElapsed: sessionBaseElapsed ?? this.sessionBaseElapsed,
      hasStartedLearning: hasStartedLearning ?? this.hasStartedLearning,
    );
  }
}

class LearningHubNotifier extends Notifier<LearningHubState> {
  Timer? _ticker;
  Timer? _flushTimer;
  int? _activeSessionId;

  Future<void> _syncStartSession(DateTime now) async {
    try {
      final sessionDao = ref.read(timeSessionDaoProvider);
      final activeLec = state.activeLecture;
      final curCourse = state.course;
      final sessionLabel = '${curCourse.title}: ${activeLec.title}';

      final existing = await sessionDao.getTodayActiveOrPausedSessionByLabel(sessionLabel);
      if (existing != null) {
        _activeSessionId = existing.id;
        if (existing.status == 'paused') {
          await sessionDao.resumeSession(existing.id);
        }
      } else {
        _activeSessionId = await sessionDao.startSession(
          label: sessionLabel,
          categoryId: 1, // Study category
          activityType: 'study',
          activityRefType: 'lecture',
          startedAt: now,
        );
      }
      if (_activeSessionId != null) {
        await sessionDao.heartbeat(_activeSessionId!, state.currentElapsedSeconds);
      }
    } catch (_) {}
  }

  void _syncPauseSession() {
    if (_activeSessionId != null) {
      final sId = _activeSessionId!;
      final currentElapsed = state.currentElapsedSeconds;
      Future.microtask(() async {
        try {
          final sessionDao = ref.read(timeSessionDaoProvider);
          await sessionDao.heartbeat(sId, currentElapsed);
          await sessionDao.pauseSession(sId);
          await sessionDao.heartbeat(sId, currentElapsed);
        } catch (_) {}
      });
    }
  }

  void _syncCompleteSession() {
    if (_activeSessionId != null) {
      final sId = _activeSessionId!;
      _activeSessionId = null;
      Future.microtask(() async {
        try {
          await ref.read(timeSessionDaoProvider).completeSession(sId);
        } catch (_) {}
      });
    }
  }

  @override
  LearningHubState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final initialCourses = _loadStoredCourses(prefs);
    final activeCourseId = prefs.getString(_kActiveCourseIdKey) ??
        (initialCourses.isNotEmpty ? initialCourses.first.id : 'spring_boot_mastery');

    Course activeCourse = initialCourses.firstWhere(
      (c) => c.id == activeCourseId,
      orElse: () => initialCourses.first,
    );

    final activeLectureId = prefs.getInt(_kActiveLectureIdKey) ??
        prefs.getInt(_kLegacyActiveLectureIdKey) ??
        (activeCourse.modules.isNotEmpty && activeCourse.modules.first.lectures.isNotEmpty
            ? activeCourse.modules.first.lectures.first.id
            : 1);

    Lecture activeLecture = const Lecture(
      id: 1,
      moduleId: 1,
      moduleTitle: 'General',
      title: 'Introduction',
      durationSeconds: 300,
    );

    for (final m in activeCourse.modules) {
      for (final l in m.lectures) {
        if (l.id == activeLectureId) {
          activeLecture = l;
          break;
        }
      }
    }

    final hasStarted = prefs.getBool(_kHasStartedLearningKey) ??
        initialCourses.any((c) =>
            c.completedLectures > 0 ||
            c.modules.any((m) => m.lectures.any((l) => l.elapsedSeconds > 0)));

    ref.onDispose(() {
      _ticker?.cancel();
      _flushTimer?.cancel();
    });

    return LearningHubState(
      courses: initialCourses,
      activeCourseId: activeCourse.id,
      activeLectureId: activeLecture.id,
      currentElapsedSeconds: activeLecture.elapsedSeconds,
      isPlaying: false,
      hasStartedLearning: hasStarted,
    );
  }

  List<Course> _loadStoredCourses(SharedPreferences prefs) {
    final rawJson = prefs.getString(_kCoursesListKey);
    if (rawJson != null) {
      try {
        final List<dynamic> list = jsonDecode(rawJson);
        final courses = list.map((item) => Course.fromJson(item as Map<String, dynamic>)).toList();
        if (courses.isNotEmpty) {
          final javaCourse = buildCompleteJava2026Course();
          if (!courses.any((c) => c.id == javaCourse.id)) {
            courses.add(javaCourse);
          }
          final springCourse = buildDefaultSpringBootCourse();
          if (!courses.any((c) => c.id == springCourse.id)) {
            courses.insert(0, springCourse);
          }
          return courses;
        }
      } catch (_) {}
    }

    final javaCourse = buildCompleteJava2026Course();
    final defaultCourse = buildDefaultSpringBootCourse();
    final legacyRaw = prefs.getString(_kLegacyProgressKey);
    if (legacyRaw != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(legacyRaw);
        final updatedModules = defaultCourse.modules.map((module) {
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

        final migrated = defaultCourse.copyWith(modules: updatedModules);
        return [migrated, javaCourse];
      } catch (_) {}
    }

    return [defaultCourse, javaCourse];
  }

  void _persistCourses() {
    final prefs = ref.read(sharedPreferencesProvider);
    final jsonStr = jsonEncode(state.courses.map((c) => c.toJson()).toList());
    prefs.setString(_kCoursesListKey, jsonStr);
    prefs.setString(_kActiveCourseIdKey, state.activeCourseId);
    prefs.setInt(_kActiveLectureIdKey, state.activeLectureId);

    // Durable SQLite persistence via CourseDao
    Future.microtask(() async {
      try {
        final courseDao = ref.read(courseDaoProvider);
        for (final c in state.courses) {
          await courseDao.upsertCourse(
            CourseTableCompanion.insert(
              id: c.id,
              title: c.title,
              description: drift.Value(c.description),
              author: drift.Value(c.author),
              category: drift.Value(c.category),
              sourceUrl: drift.Value(c.sourceUrl),
              targetCompletionDate: drift.Value(c.targetCompletionDate),
              daysLeft: drift.Value(c.daysLeft),
              targetMinutesPerDay: drift.Value(c.targetMinutesPerDay),
              modulesJson: jsonEncode(c.modules.map((m) => m.toJson()).toList()),
              updatedAt: drift.Value(DateTime.now()),
            ),
          );
        }
      } catch (e) {
        debugPrint('CourseDao persistence sync warning: $e');
      }
    });
  }

  void startLearning({String? courseId}) {
    ref.read(sharedPreferencesProvider).setBool(_kHasStartedLearningKey, true);
    if (courseId != null && courseId != state.activeCourseId) {
      switchCourse(courseId);
    } else {
      state = state.copyWith(hasStartedLearning: true);
    }
  }

  void play() {
    if (state.isPlaying) return;

    _unDismissLecture(state.activeLectureId);
    ref.read(sharedPreferencesProvider).setBool(_kHasStartedLearningKey, true);
    final now = DateTime.now();
    state = state.copyWith(
      isPlaying: true,
      isLiveFocusActive: true,
      isFloatingDismissed: false,
      hasStartedLearning: true,
      playStartedAt: now,
      sessionBaseElapsed: state.currentElapsedSeconds,
    );

    // Sync active session in SQLite TimeSessionDao
    _syncStartSession(now);

    NotificationService.instance.showOngoingSessionNotification(
      title: 'Playing: ${state.activeLecture.title}',
      body: '${state.course.title} • Ascent Study Player',
      subText: 'Lecture Active',
      elapsedSeconds: state.sessionBaseElapsed,
      payload: '/learning',
    );

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = state.playStartedAt;
      if (startedAt == null) return;

      final diff = DateTime.now().difference(startedAt).inSeconds;
      final active = state.activeLecture;
      final newElapsed = state.sessionBaseElapsed + diff;

      // Increment active study watch seconds for strict study streak
      ref.read(studyStreakProvider.notifier).addStudySeconds(1);

      // Periodic 5s heartbeat to SQLite time session
      if (diff > 0 && diff % 5 == 0 && _activeSessionId != null) {
        ref.read(timeSessionDaoProvider).heartbeat(_activeSessionId!, newElapsed);
      }

      if (active.durationSeconds > 0 && newElapsed >= active.durationSeconds) {
        // Lecture completed automatically
        markLectureCompleted(active.id);
      } else {
        state = state.copyWith(currentElapsedSeconds: newElapsed);
        _updateCurrentLectureInCourse(newElapsed, active.isCompleted);
      }
    });

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _persistCourses();
    });
  }

  void pause({bool updateNotification = true}) {
    _ticker?.cancel();
    _flushTimer?.cancel();
    _syncPauseSession();
    _persistCourses();
    if (updateNotification) {
      NotificationService.instance.showOngoingSessionNotification(
        title: 'Lecture: ${state.activeLecture.title}',
        body: '${state.course.title} • Ascent Study Player',
        subText: 'Lecture Paused',
        elapsedSeconds: state.currentElapsedSeconds,
        isPaused: true,
        payload: '/learning',
      );
    } else {
      NotificationService.instance.cancelOngoingLectureNotification();
    }
    state = state.copyWith(
      isPlaying: false,
      playStartedAt: null,
      sessionBaseElapsed: state.currentElapsedSeconds,
    );
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
    final maxDur = active.durationSeconds > 0 ? active.durationSeconds : 3600;
    final target = (state.currentElapsedSeconds + offsetSeconds).clamp(0, maxDur);

    final now = DateTime.now();
    state = state.copyWith(
      currentElapsedSeconds: target,
      sessionBaseElapsed: target,
      playStartedAt: state.isPlaying ? now : null,
    );
    _updateCurrentLectureInCourse(target, active.isCompleted);
    _persistCourses();
  }

  void seekTo(double fraction) {
    final active = state.activeLecture;
    if (active.durationSeconds <= 0) return;
    final target = (active.durationSeconds * fraction).round().clamp(0, active.durationSeconds);

    final now = DateTime.now();
    state = state.copyWith(
      currentElapsedSeconds: target,
      sessionBaseElapsed: target,
      playStartedAt: state.isPlaying ? now : null,
    );
    _updateCurrentLectureInCourse(target, active.isCompleted);
    _persistCourses();
  }

  void _unDismissLecture(int lectureId) {
    try {
      ref.read(dismissedTodayActivityIdsProvider.notifier).unDismissActivityId('lecture_$lectureId');
    } catch (_) {}
  }

  void selectLecture(int lectureId, {bool autoPlay = false}) {
    _unDismissLecture(lectureId);
    _persistCourses();
    _ticker?.cancel();
    _flushTimer?.cancel();
    _syncPauseSession();

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

    ref.read(sharedPreferencesProvider).setBool(_kHasStartedLearningKey, true);
    state = state.copyWith(
      activeLectureId: lectureId,
      currentElapsedSeconds: targetLecture.elapsedSeconds,
      isPlaying: false,
      isFloatingDismissed: false,
      hasStartedLearning: true,
      playStartedAt: null,
      sessionBaseElapsed: targetLecture.elapsedSeconds,
    );

    ref.read(sharedPreferencesProvider).setInt(_kActiveLectureIdKey, lectureId);

    if (autoPlay) {
      play();
    }
  }

  void markLectureCompleted(int lectureId, {bool? completed}) {
    final curLec = state.activeLecture;
    final markValue = completed ?? true;
    _updateCurrentLectureInCourse(
      lectureId == curLec.id ? state.currentElapsedSeconds : null,
      markValue,
      targetLectureId: lectureId,
    );
    _persistCourses();
    _syncCompleteSession();

    if (markValue && lectureId == state.activeLectureId) {
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
  }


  void switchCourse(String courseId) {
    if (courseId == state.activeCourseId) return;

    pause();

    final target = state.courses.firstWhere(
      (c) => c.id == courseId,
      orElse: () => state.courses.first,
    );

    Lecture active = const Lecture(
      id: 1,
      moduleId: 1,
      moduleTitle: 'General',
      title: 'Introduction',
      durationSeconds: 300,
    );

    final nextUnfinished = target.nextLecture;
    if (nextUnfinished != null) {
      active = nextUnfinished;
    } else if (target.modules.isNotEmpty && target.modules.first.lectures.isNotEmpty) {
      active = target.modules.first.lectures.first;
    }

    ref.read(sharedPreferencesProvider).setBool(_kHasStartedLearningKey, true);
    state = state.copyWith(
      activeCourseId: target.id,
      activeLectureId: active.id,
      currentElapsedSeconds: active.elapsedSeconds,
      isPlaying: false,
      isFloatingDismissed: false,
      hasStartedLearning: true,
      playStartedAt: null,
      sessionBaseElapsed: active.elapsedSeconds,
    );

    _persistCourses();
  }

  void addCourse(Course course) {
    final updated = [...state.courses, course];
    state = state.copyWith(courses: updated);
    _persistCourses();
    switchCourse(course.id);
  }

  void updateCourse(Course course) {
    final updated = state.courses.map((c) => c.id == course.id ? course : c).toList();
    state = state.copyWith(courses: updated);
    _persistCourses();
  }

  void deleteCourse(String courseId) {
    if (state.courses.length <= 1) return; // Keep at least one course
    final updated = state.courses.where((c) => c.id != courseId).toList();
    final nextCourseId = courseId == state.activeCourseId ? updated.first.id : state.activeCourseId;
    state = state.copyWith(courses: updated);
    _persistCourses();
    if (courseId == state.activeCourseId) {
      switchCourse(nextCourseId);
    }
  }

  void addModule(String courseId, CourseModule module) {
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = [...course.modules, module];
    final updatedCourse = course.copyWith(modules: updatedModules);
    updateCourse(updatedCourse);
  }

  void updateModule(String courseId, CourseModule module) {
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules.map((m) => m.id == module.id ? module : m).toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    updateCourse(updatedCourse);
  }

  void deleteModule(String courseId, int moduleId) {
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules.where((m) => m.id != moduleId).toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    updateCourse(updatedCourse);
  }

  void addLecture(String courseId, int moduleId, Lecture lecture) {
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules.map((m) {
      if (m.id == moduleId) {
        return m.copyWith(lectures: [...m.lectures, lecture]);
      }
      return m;
    }).toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    updateCourse(updatedCourse);
  }

  void updateLecture(String courseId, Lecture lecture) {
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules.map((m) {
      if (m.id == lecture.moduleId) {
        final updatedLectures = m.lectures.map((l) => l.id == lecture.id ? lecture : l).toList();
        return m.copyWith(lectures: updatedLectures);
      }
      return m;
    }).toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    updateCourse(updatedCourse);
  }

  void deleteLecture(String courseId, int lectureId) {
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules.map((m) {
      final updatedLectures = m.lectures.where((l) => l.id != lectureId).toList();
      return m.copyWith(lectures: updatedLectures);
    }).toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    updateCourse(updatedCourse);
  }

  void dismissFloatingPlayer() {
    state = state.copyWith(isFloatingDismissed: true);
  }

  void showFloatingPlayer() {
    state = state.copyWith(isFloatingDismissed: false);
  }

  void _updateCurrentLectureInCourse(int? elapsed, bool isCompleted, {int? targetLectureId}) {
    final targetId = targetLectureId ?? state.activeLectureId;
    final activeC = state.course;

    final updatedModules = activeC.modules.map((module) {
      final updatedLectures = module.lectures.map((lecture) {
        if (lecture.id == targetId) {
          return lecture.copyWith(
            elapsedSeconds: elapsed ?? lecture.elapsedSeconds,
            isCompleted: lecture.isCompleted || isCompleted,
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

    final updatedCourse = activeC.copyWith(modules: updatedModules);
    final updatedCourses = state.courses.map((c) => c.id == updatedCourse.id ? updatedCourse : c).toList();
    state = state.copyWith(courses: updatedCourses);
  }
}

final learningHubProvider = NotifierProvider<LearningHubNotifier, LearningHubState>(
  LearningHubNotifier.new,
);
