import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/time_tracking_provider.dart';
import '../notifications/notification_service.dart';
import '../streak/study_streak_provider.dart';
import 'default_course_data.dart';
import 'learning_hub_models.dart';
import 'learning_catalog.dart';

const _kCoursesListKey = 'ascent_learning_hub_courses_v3';
const _kActiveCourseIdKey = 'ascent_learning_hub_active_course_v3';
const _kActiveLectureIdKey = 'ascent_learning_hub_active_lecture_id_v3';
const _kLegacyProgressKey = 'ascent_learning_hub_lecture_progress_v2';
const _kLegacyActiveLectureIdKey = 'ascent_learning_hub_active_lecture_id_v2';
const _kHasStartedLearningKey = 'ascent_learning_hub_has_started_learning_v1';

/// Primary Learning catalog persistence. Injectable for failure/recovery tests.
final learningCourseSaveProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  final preferences = ref.watch(sharedPreferencesProvider);
  final database = ref.watch(databaseProvider);
  return LearningCatalog(database, preferences).saveJson;
});

final learningClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final learningElapsedClockProvider = Provider<int Function()>((ref) {
  final watch = Stopwatch()..start();
  ref.onDispose(watch.stop);
  return () => watch.elapsedMicroseconds;
});

const _unchangedLearningTime = Object();

class LearningHubState {
  final List<Course> courses;
  final String activeCourseId;
  final int activeLectureId;
  final bool isPlaying;
  final bool isSavingCompletion;
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
    this.isSavingCompletion = false,
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
    if (curCourse.modules.isNotEmpty &&
        curCourse.modules.first.lectures.isNotEmpty) {
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
    return (currentElapsedSeconds / activeLecture.durationSeconds).clamp(
      0.0,
      1.0,
    );
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
    bool? isSavingCompletion,
    int? currentElapsedSeconds,
    bool? isLiveFocusActive,
    bool? isFloatingDismissed,
    Object? playStartedAt = _unchangedLearningTime,
    int? sessionBaseElapsed,
    bool? hasStartedLearning,
  }) {
    return LearningHubState(
      courses: courses ?? this.courses,
      activeCourseId: activeCourseId ?? this.activeCourseId,
      activeLectureId: activeLectureId ?? this.activeLectureId,
      isPlaying: isPlaying ?? this.isPlaying,
      isSavingCompletion: isSavingCompletion ?? this.isSavingCompletion,
      currentElapsedSeconds:
          currentElapsedSeconds ?? this.currentElapsedSeconds,
      isLiveFocusActive: isLiveFocusActive ?? this.isLiveFocusActive,
      isFloatingDismissed: isFloatingDismissed ?? this.isFloatingDismissed,
      playStartedAt: identical(playStartedAt, _unchangedLearningTime)
          ? this.playStartedAt
          : playStartedAt as DateTime?,
      sessionBaseElapsed: sessionBaseElapsed ?? this.sessionBaseElapsed,
      hasStartedLearning: hasStartedLearning ?? this.hasStartedLearning,
    );
  }
}

class LearningHubNotifier extends Notifier<LearningHubState> {
  Timer? _ticker;
  Timer? _flushTimer;
  int? _activeSessionId;
  int _sessionEpoch = 0;
  int _sessionStudyStart = 0;
  int _sessionLoggedBase = 0;
  int get _sessionSeconds =>
      _sessionLoggedBase +
      (state.activeLecture.studySeconds - _sessionStudyStart).clamp(
        0,
        31536000,
      );
  final _sessionBaselines = <int, (int, int)>{};
  final _sessionWrites = <Future<void>>{};
  void _trackSession(Future<void> work) {
    _sessionWrites.add(work);
    unawaited(work.whenComplete(() => _sessionWrites.remove(work)));
  }

  int? _lastCreditMicros;
  bool _completionPending = false;
  Future<void> _saveQueue = Future.value();
  Future<void> _catalogReady = Future.value();
  bool _catalogLoading = true;
  int _catalogRevision = 0;
  Future<void> get ready async {
    await _catalogReady;
    if (!ref.mounted ||
        ref.read(databaseProvider).workspaceRevision != _catalogRevision) {
      throw StateError(
        'The workspace changed. Reopen Learning before continuing',
      );
    }
  }

  Future<void> get settled async {
    await _saveQueue;
    while (_sessionWrites.isNotEmpty) {
      await Future.wait([..._sessionWrites]);
    }
  }

  DateTime get _now => ref.read(learningClockProvider)();

  Future<void> _saveSnapshot(List<Course> courses) {
    final json = jsonEncode(courses.map((c) => c.toJson()).toList());
    final save = ref.read(learningCourseSaveProvider);
    final ready = _catalogReady;
    final next = _saveQueue.then((_) async {
      await ready;
      if (!ref.mounted) {
        throw StateError('The learning workspace changed before saving');
      }
      if (ref.read(databaseProvider).workspaceRevision != _catalogRevision) {
        throw StateError(
          'The workspace was replaced. Restart or reopen Learning before saving',
        );
      }
      await save(json);
    });
    _saveQueue = next.catchError((Object error) {});
    return next;
  }

  void _creditEngagement() {
    if (!state.isPlaying ||
        _lastCreditMicros == null ||
        _completionPending ||
        ref.read(databaseProvider).workspaceRevision != _catalogRevision) {
      return;
    }
    final now = ref.read(learningElapsedClockProvider)();
    final seconds =
        (now - _lastCreditMicros!) ~/ Duration.microsecondsPerSecond;
    if (seconds <= 0) return;
    _lastCreditMicros =
        _lastCreditMicros! + seconds * Duration.microsecondsPerSecond;
    final lecture = state.activeLecture;
    final position = lecture.durationSeconds > 0
        ? (state.currentElapsedSeconds + seconds).clamp(
            0,
            lecture.durationSeconds,
          )
        : state.currentElapsedSeconds + seconds;
    state = state.copyWith(currentElapsedSeconds: position);
    _updateCurrentLectureInCourse(
      position,
      lecture.isCompleted,
      studySeconds: lecture.studySeconds + seconds,
    );
  }

  Future<void> _syncStartSession(DateTime now) async {
    final epoch = ++_sessionEpoch;
    final dao = ref.read(timeSessionDaoProvider);
    final database = ref.read(databaseProvider);
    final revision = _catalogRevision;
    if (database.workspaceRevision != revision) return;
    final lecture = state.activeLecture;
    final course = state.course;
    try {
      final today = DateTime(now.year, now.month, now.day);
      final session = await database.transaction(() async {
        if (database.workspaceRevision != revision ||
            (await database.select(database.backupRestoreTable).get())
                .isNotEmpty) {
          throw StateError('The workspace changed before starting the session');
        }
        final existing =
            await (database.select(database.timeSessionTable)
                  ..where(
                    (s) =>
                        s.learningCourseId.equals(course.id) &
                        s.learningLectureId.equals(lecture.id) &
                        s.activityRefType.equals('lecture') &
                        s.status.isIn(['running', 'paused']) &
                        s.startedAt.isBiggerOrEqualValue(today) &
                        s.startedAt.isSmallerThanValue(
                          DateTime(now.year, now.month, now.day + 1),
                        ),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (existing != null) return existing;
        final id = await dao.startSession(
          label: '${course.title}: ${lecture.title}',
          categoryId: 1,
          activityType: 'study',
          activityRefType: 'lecture',
          learningCourseId: course.id,
          learningLectureId: lecture.id,
          startedAt: now,
        );
        return (await (database.select(
          database.timeSessionTable,
        )..where((s) => s.id.equals(id))).getSingle());
      });
      if (!ref.mounted || database.workspaceRevision != revision) return;
      final id = session.id;
      final baseline = _sessionBaselines.putIfAbsent(
        id,
        () => (lecture.studySeconds, session.durationSeconds),
      );
      if (_sessionBaselines.length > 100) {
        _sessionBaselines.remove(_sessionBaselines.keys.first);
      }
      if (!ref.mounted ||
          epoch != _sessionEpoch ||
          !state.isPlaying ||
          state.activeCourseId != course.id ||
          state.activeLectureId != lecture.id) {
        await database.transaction(() async {
          if (database.workspaceRevision != revision ||
              (await database.select(database.backupRestoreTable).get())
                  .isNotEmpty) {
            return;
          }
          if (ref.mounted &&
              state.isPlaying &&
              state.activeCourseId == course.id &&
              state.activeLectureId == lecture.id) {
            return;
          }
          final owner = state.courses
              .where((c) => c.id == course.id)
              .firstOrNull;
          final latest = owner?.modules
              .expand((m) => m.lectures)
              .where((l) => l.id == lecture.id)
              .firstOrNull;
          if (latest?.isCompleted == true) {
            await dao.completeSession(id);
          } else {
            await dao.pauseSession(id);
          }
          if (latest != null) {
            await dao.heartbeat(
              id,
              baseline.$2 +
                  (latest.studySeconds - baseline.$1).clamp(0, 31536000),
            );
          }
        });
        return;
      }
      _activeSessionId = id;
      _sessionStudyStart = baseline.$1;
      _sessionLoggedBase = baseline.$2;
      await database.transaction(() async {
        if (database.workspaceRevision != revision ||
            (await database.select(database.backupRestoreTable).get())
                .isNotEmpty) {
          return;
        }
        await dao.resumeSession(id);
        await dao.heartbeat(id, _sessionSeconds);
      });
    } catch (error) {
      debugPrint('Learning session sync failed: $error');
    }
  }

  void _syncPauseSession() {
    ++_sessionEpoch;
    final id = _activeSessionId;
    if (id == null) return;
    final seconds = _sessionSeconds;
    _activeSessionId = null;
    final dao = ref.read(timeSessionDaoProvider);
    final database = ref.read(databaseProvider);
    final revision = _catalogRevision;
    _trackSession(() async {
      try {
        await database.transaction(() async {
          if (database.workspaceRevision != revision ||
              (await database.select(database.backupRestoreTable).get())
                  .isNotEmpty) {
            return;
          }
          await dao.pauseSession(id);
          await dao.heartbeat(id, seconds);
        });
      } catch (error) {
        debugPrint('Learning pause sync failed: $error');
      }
    }());
  }

  void _syncCompleteSession() {
    ++_sessionEpoch;
    final id = _activeSessionId;
    if (id == null) return;
    final seconds = _sessionSeconds;
    _activeSessionId = null;
    final dao = ref.read(timeSessionDaoProvider);
    final database = ref.read(databaseProvider);
    final revision = _catalogRevision;
    _trackSession(() async {
      try {
        await database.transaction(() async {
          if (database.workspaceRevision != revision ||
              (await database.select(database.backupRestoreTable).get())
                  .isNotEmpty) {
            return;
          }
          await dao.heartbeat(id, seconds);
          await dao.completeSession(id);
        });
      } catch (error) {
        debugPrint('Learning completion session sync failed: $error');
      }
    }());
  }

  @override
  LearningHubState build() {
    _catalogRevision = ref.read(databaseProvider).workspaceRevision;
    final prefs = ref.watch(sharedPreferencesProvider);
    final initialCourses = _loadStoredCourses(prefs);
    final activeCourseId =
        prefs.getString(_kActiveCourseIdKey) ??
        (initialCourses.isNotEmpty
            ? initialCourses.first.id
            : 'spring_boot_mastery');

    Course activeCourse = initialCourses.firstWhere(
      (c) => c.id == activeCourseId,
      orElse: () => initialCourses.isEmpty
          ? buildDefaultSpringBootCourse()
          : initialCourses.first,
    );

    final activeLectureId =
        prefs.getInt(_kActiveLectureIdKey) ??
        prefs.getInt(_kLegacyActiveLectureIdKey) ??
        (activeCourse.modules.isNotEmpty &&
                activeCourse.modules.first.lectures.isNotEmpty
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

    final hasStarted =
        prefs.getBool(_kHasStartedLearningKey) ??
        initialCourses.any(
          (c) =>
              c.completedLectures > 0 ||
              c.modules.any((m) => m.lectures.any((l) => l.elapsedSeconds > 0)),
        );

    ref.onDispose(() {
      _ticker?.cancel();
      _flushTimer?.cancel();
    });

    final catalog = LearningCatalog(ref.read(databaseProvider), prefs);
    _catalogLoading = true;
    _catalogReady = Future.microtask(() async {
      try {
        final courses = await catalog.loadOrImport(initialCourses);
        if (!ref.mounted) return;
        final active =
            courses.where((c) => c.id == state.activeCourseId).firstOrNull ??
            courses.firstOrNull;
        final lectures =
            active?.modules.expand((m) => m.lectures).toList() ?? <Lecture>[];
        final lecture =
            lectures.where((l) => l.id == state.activeLectureId).firstOrNull ??
            lectures.firstOrNull;
        state = state.copyWith(
          courses: courses,
          activeCourseId: active?.id ?? '',
          activeLectureId: lecture?.id ?? 0,
          currentElapsedSeconds: lecture?.elapsedSeconds ?? 0,
        );
      } finally {
        _catalogLoading = false;
      }
    });
    // Keep bootstrap errors observable by commands without an unhandled future.
    unawaited(
      _catalogReady.catchError((Object error) {
        debugPrint('Learning catalog load failed: $error');
      }),
    );
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
    if (prefs.getInt(_kActiveLectureIdKey) == 38) {
      prefs.remove(_kActiveLectureIdKey);
    }
    final rawJson = prefs.getString(_kCoursesListKey);
    if (rawJson != null) {
      try {
        final List<dynamic> list = jsonDecode(rawJson);
        final courses = list
            .map((item) =>
                Course.fromJson(item as Map<String, dynamic>).sanitizeTestLectures())
            .toList();
        return courses;
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
              final elapsed =
                  (item['elapsed'] as num?)?.toInt() ?? lecture.elapsedSeconds;
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
    if (_catalogLoading || _completionPending) return;
    unawaited(
      _saveSnapshot(state.courses).catchError((Object error) {
        debugPrint('Learning progress save failed: $error');
      }),
    );
    prefs.setString(_kActiveCourseIdKey, state.activeCourseId);
    prefs.setInt(_kActiveLectureIdKey, state.activeLectureId);
  }

  void startLearning({String? courseId}) {
    if (_catalogLoading) return;
    ref.read(sharedPreferencesProvider).setBool(_kHasStartedLearningKey, true);
    if (courseId != null && courseId != state.activeCourseId) {
      switchCourse(courseId);
    } else {
      state = state.copyWith(hasStartedLearning: true);
    }
  }

  void play() {
    if (_catalogLoading || _completionPending || state.isPlaying) return;
    if (!state.course.modules.any(
      (m) => m.lectures.any((l) => l.id == state.activeLectureId),
    )) {
      return;
    }

    _unDismissLecture(state.activeLectureId);
    ref.read(sharedPreferencesProvider).setBool(_kHasStartedLearningKey, true);
    final now = _now;
    _lastCreditMicros = ref.read(learningElapsedClockProvider)();
    state = state.copyWith(
      isPlaying: true,
      isLiveFocusActive: true,
      isFloatingDismissed: false,
      hasStartedLearning: true,
      playStartedAt: now,
      sessionBaseElapsed: state.currentElapsedSeconds,
    );

    // Sync active session in SQLite TimeSessionDao
    _trackSession(_syncStartSession(now));

    NotificationService.instance.showOngoingSessionNotification(
      title: state.activeLecture.title,
      body: state.course.title,
      subText: 'Lecture Active',
      elapsedSeconds: state.sessionBaseElapsed,
      payload: '/learning',
      totalSeconds: state.activeLecture.durationSeconds,
    );

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_catalogLoading ||
          _completionPending ||
          ref.read(databaseProvider).workspaceRevision != _catalogRevision) {
        return;
      }
      final startedAt = state.playStartedAt;
      if (startedAt == null) return;

      final diff = _now.difference(startedAt).inSeconds.clamp(0, 31536000);
      _creditEngagement();
      final active = state.activeLecture;
      final newElapsed = state.currentElapsedSeconds;

      // Increment active study watch seconds for strict study streak
      ref.read(studyStreakProvider.notifier).creditActiveSecond(DateTime.now());

      // Periodic 5s heartbeat to SQLite time session
      if (diff > 0 && diff % 5 == 0 && _activeSessionId != null) {
        ref
            .read(timeSessionDaoProvider)
            .heartbeat(_activeSessionId!, _sessionSeconds);
      }

      state = state.copyWith(currentElapsedSeconds: newElapsed);
      _updateCurrentLectureInCourse(newElapsed, active.isCompleted);
      if (active.durationSeconds > 0 &&
          state.activeLecture.studySeconds >= active.durationSeconds &&
          !active.isCompleted &&
          !_completionPending) {
        unawaited(markLectureCompleted(active.id));
      }
    });

    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _persistCourses();
    });
  }

  void pause({bool updateNotification = true}) {
    _creditEngagement();
    _lastCreditMicros = null;
    _ticker?.cancel();
    _flushTimer?.cancel();
    _syncPauseSession();
    _persistCourses();
    if (updateNotification) {
      NotificationService.instance.showOngoingSessionNotification(
        title: state.activeLecture.title,
        body: state.course.title,
        subText: 'Lecture Paused',
        elapsedSeconds: state.currentElapsedSeconds,
        isPaused: true,
        payload: '/learning',
        totalSeconds: state.activeLecture.durationSeconds,
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
    _creditEngagement();
    final active = state.activeLecture;
    final maxDur = active.durationSeconds > 0 ? active.durationSeconds : 3600;
    final target = (state.currentElapsedSeconds + offsetSeconds).clamp(
      0,
      maxDur,
    );

    final now = _now;
    state = state.copyWith(
      currentElapsedSeconds: target,
      sessionBaseElapsed: target,
      playStartedAt: state.isPlaying ? now : null,
    );
    _updateCurrentLectureInCourse(target, active.isCompleted);
    _persistCourses();
    NotificationService.instance.showOngoingSessionNotification(
      title: state.activeLecture.title,
      body: state.course.title,
      elapsedSeconds: state.currentElapsedSeconds,
      isPaused: !state.isPlaying,
      payload: '/learning',
      totalSeconds: state.activeLecture.durationSeconds,
    );
  }

  void seekTo(double fraction) {
    if (!fraction.isFinite) return;
    _creditEngagement();
    final active = state.activeLecture;
    if (active.durationSeconds <= 0) return;
    final target = (active.durationSeconds * fraction).round().clamp(
      0,
      active.durationSeconds,
    );

    final now = _now;
    state = state.copyWith(
      currentElapsedSeconds: target,
      sessionBaseElapsed: target,
      playStartedAt: state.isPlaying ? now : null,
    );
    _updateCurrentLectureInCourse(target, active.isCompleted);
    _persistCourses();
    NotificationService.instance.showOngoingSessionNotification(
      title: state.activeLecture.title,
      body: state.course.title,
      elapsedSeconds: state.currentElapsedSeconds,
      isPaused: !state.isPlaying,
      payload: '/learning',
      totalSeconds: state.activeLecture.durationSeconds,
    );
  }

  void _unDismissLecture(int lectureId) {
    try {
      ref
          .read(dismissedTodayActivityIdsProvider.notifier)
          .unDismissActivityId(
            'lecture_${Uri.encodeComponent(state.activeCourseId)}_$lectureId',
          );
      ref
          .read(dismissedTodayActivityIdsProvider.notifier)
          .unDismissActivityId('lecture_$lectureId');
    } catch (_) {}
  }

  void selectLecture(int lectureId, {bool autoPlay = false}) {
    if (_catalogLoading || _completionPending) return;
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
    _creditEngagement();
    _lastCreditMicros = null;
    _unDismissLecture(lectureId);
    _persistCourses();
    _ticker?.cancel();
    _flushTimer?.cancel();
    _syncPauseSession();

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

  Future<bool> markLectureCompleted(
    int lectureId, {
    bool? completed,
    String? courseId,
  }) async {
    try {
      await ready;
    } catch (_) {
      return false;
    }
    if (!ref.mounted || _completionPending || completed == false) return false;
    final ownerId = courseId ?? state.activeCourseId;
    Course? owner;
    Lecture? target;
    for (final course in state.courses) {
      if (course.id != ownerId) continue;
      owner = course;
      for (final module in course.modules) {
        for (final lecture in module.lectures) {
          if (lecture.id == lectureId) target = lecture;
        }
      }
    }
    if (owner == null || target == null) return false;
    if (target.isCompleted) return true;
    if (!target.canComplete) return false;
    _completionPending = true;
    state = state.copyWith(isSavingCompletion: true);
    final wasPlaying = state.isPlaying;
    final updatedOwner = owner.copyWith(
      modules: owner.modules
          .map(
            (module) => module.copyWith(
              lectures: module.lectures
                  .map(
                    (lecture) => lecture.id == lectureId
                        ? lecture.copyWith(isCompleted: true)
                        : lecture,
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
    final courses = state.courses
        .map((course) => course.id == ownerId ? updatedOwner : course)
        .toList();
    try {
      await _saveSnapshot(courses);
      state = state.copyWith(courses: courses);
    } catch (error) {
      debugPrint('Learning completion save failed: $error');
      return false;
    } finally {
      _completionPending = false;
      state = state.copyWith(isSavingCompletion: false);
    }
    _persistCourses();
    if (ownerId == state.activeCourseId && lectureId == state.activeLectureId) {
      _syncCompleteSession();
      final next = updatedOwner.nextLecture;
      if (next != null) {
        selectLecture(next.id, autoPlay: wasPlaying);
      } else {
        pause();
      }
    }
    return true;
  }

  void switchCourse(String courseId) {
    if (_catalogLoading || _completionPending) return;
    if (courseId == state.activeCourseId) return;
    if (!state.courses.any((c) => c.id == courseId)) {
      throw ArgumentError('This course no longer exists');
    }

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
    } else if (target.modules.isNotEmpty &&
        target.modules.first.lectures.isNotEmpty) {
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

  Future<void> _commitCatalog(List<Course> courses) async {
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    _completionPending = true;
    try {
      await _saveSnapshot(courses);
      if (!ref.mounted) {
        throw StateError(
          'The learning workspace changed before publishing the save',
        );
      }
      state = state.copyWith(courses: courses);
    } finally {
      _completionPending = false;
    }
  }

  Future<void> addCourse(Course course) async {
    await ready;
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    if (state.courses.any((c) => c.id == course.id)) {
      throw ArgumentError('A course with this ID already exists');
    }
    course = course.copyWith(
      modules: course.modules
          .map(
            (m) => m.copyWith(
              lectures: m.lectures
                  .map(
                    (l) => l.copyWith(
                      studySeconds: 0,
                      isCompleted: false,
                      completionThresholdPercent:
                          l.completionThresholdPercent == 50 ? 50 : 100,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
    final updated = [...state.courses, course];
    await _commitCatalog(updated);
    switchCourse(course.id);
  }

  Future<void> updateCourse(Course course) async {
    await ready;
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    final previous = state.courses.where((c) => c.id == course.id).firstOrNull;
    if (previous == null) throw StateError('This course no longer exists');
    final existing = {
      for (final m in previous.modules)
        for (final l in m.lectures) l.id: l,
    };
    course = course.copyWith(
      modules: course.modules
          .map(
            (m) => m.copyWith(
              lectures: m.lectures.map((l) {
                final old = existing[l.id];
                return l.copyWith(
                  isCompleted: old?.isCompleted ?? false,
                  studySeconds: old?.studySeconds ?? 0,
                );
              }).toList(),
            ),
          )
          .toList(),
    );
    final updated = state.courses
        .map((c) => c.id == course.id ? course : c)
        .toList();
    await _commitCatalog(updated);
    if (course.id == state.activeCourseId &&
        !course.modules.any(
          (m) => m.lectures.any((l) => l.id == state.activeLectureId),
        )) {
      final next =
          course.nextLecture ??
          course.modules.expand((m) => m.lectures).firstOrNull;
      state = state.copyWith(
        activeLectureId: next?.id ?? 0,
        currentElapsedSeconds: next?.elapsedSeconds ?? 0,
        sessionBaseElapsed: next?.elapsedSeconds ?? 0,
        isPlaying: false,
        playStartedAt: null,
      );
    }
  }

  Future<void> deleteCourse(String courseId) async {
    await ready;
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    if (state.courses.length <= 1) return; // Keep at least one course
    final wasActive = courseId == state.activeCourseId;
    if (wasActive) pause(updateNotification: false);
    final updated = state.courses.where((c) => c.id != courseId).toList();
    final nextCourseId = courseId == state.activeCourseId
        ? updated.first.id
        : state.activeCourseId;
    await _commitCatalog(updated);
    if (wasActive) {
      switchCourse(nextCourseId);
    }
  }

  Future<void> addModule(String courseId, CourseModule module) async {
    await ready;
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = [...course.modules, module];
    final updatedCourse = course.copyWith(modules: updatedModules);
    await updateCourse(updatedCourse);
  }

  Future<void> updateModule(String courseId, CourseModule module) async {
    await ready;
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules
        .map((m) => m.id == module.id ? module : m)
        .toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    await updateCourse(updatedCourse);
  }

  Future<void> deleteModule(String courseId, int moduleId) async {
    await ready;
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    if (courseId == state.activeCourseId &&
        state.activeLecture.moduleId == moduleId) {
      pause(updateNotification: false);
    }
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules
        .where((m) => m.id != moduleId)
        .toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    await updateCourse(updatedCourse);
  }

  /// Links an activity to one canonical lecture. Historical generic timer
  /// sessions keep their durations; they do not become watched evidence.
  Future<Lecture> saveLectureActivity({
    required String requestId,
    required String courseId,
    required int moduleId,
    required DateTime plannedDate,
    int? existingLectureId,
    int? taskId,
    String? title,
    int? durationSeconds,
    int thresholdPercent = 100,
    bool makeActive = false,
  }) async {
    await ready;
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    pause(updateNotification: false);
    _completionPending = true;
    try {
      await _saveQueue;
      final course = state.courses.where((c) => c.id == courseId).firstOrNull;
      final module = course?.modules.where((m) => m.id == moduleId).firstOrNull;
      if (course == null || module == null) {
        throw StateError('Choose an existing course and module');
      }
      if (requestId.trim().isEmpty) {
        throw ArgumentError('An operation identity is required');
      }
      final db = ref.read(databaseProvider);
      Task? source;
      if (taskId != null) {
        source = await db.taskDao.getTaskById(taskId);
        if (source == null || source.actualCompletedDate != null) {
          throw StateError('Choose an unfinished activity');
        }
        if (source.learningCourseId != null &&
            (source.learningCourseId != courseId ||
                source.learningLectureId != existingLectureId &&
                    !course.modules
                        .expand((m) => m.lectures)
                        .any(
                          (l) =>
                              l.id == source!.learningLectureId &&
                              l.originRequestId == requestId,
                        ))) {
          throw StateError('This activity already belongs to a lecture');
        }
        final children = await (db.select(
          db.taskTable,
        )..where((t) => t.parentTaskId.equals(taskId))).get();
        if (children.isNotEmpty) {
          throw StateError(
            'Convert an individual activity, keeping its checklist separate',
          );
        }
      }
      final reused = module.lectures
          .where((l) => l.originRequestId == requestId)
          .firstOrNull;
      Lecture? lecture = existingLectureId == null
          ? reused
          : module.lectures.where((l) => l.id == existingLectureId).firstOrNull;
      if (existingLectureId != null && lecture == null) {
        throw StateError('This lecture no longer exists in the chosen module');
      }
      if (lecture == null) {
        final cleanTitle = (title ?? source?.title ?? '').trim();
        if (cleanTitle.isEmpty ||
            cleanTitle.length > 300 ||
            durationSeconds == null ||
            durationSeconds <= 0 ||
            durationSeconds > 86400 ||
            ![50, 100].contains(thresholdPercent)) {
          throw ArgumentError(
            'Choose a title, duration of up to 24 hours, and completion policy',
          );
        }
        final ids = course.modules.expand((m) => m.lectures).map((l) => l.id);
        final nextId =
            ids.fold<int>(0, (largest, id) => id > largest ? id : largest) + 1;
        lecture = Lecture(
          id: nextId,
          moduleId: moduleId,
          moduleTitle: module.title,
          title: cleanTitle,
          durationSeconds: durationSeconds,
          completionThresholdPercent: thresholdPercent,
          plannedDate: plannedDate,
          originRequestId: requestId,
        );
      } else {
        lecture = lecture.copyWith(plannedDate: plannedDate);
      }
      if (source != null && lecture.isCompleted) {
        throw StateError('Choose an unfinished lecture for this activity');
      }
      final chosen = lecture;
      final updated = course.copyWith(
        modules: course.modules
            .map(
              (m) => m.id != moduleId
                  ? m
                  : m.copyWith(
                      lectures: [
                        ...m.lectures.where((l) => l.id != chosen.id),
                        chosen,
                      ],
                    ),
            )
            .toList(),
      );
      final courses = state.courses
          .map((c) => c.id == courseId ? updated : c)
          .toList();
      final catalog = LearningCatalog(db, ref.read(sharedPreferencesProvider));
      await db.transaction(() async {
        await catalog.saveCourses(courses);
        if (source != null) {
          await (db.update(
            db.taskTable,
          )..where((t) => t.id.equals(source!.id))).write(
            TaskTableCompanion(
              learningCourseId: drift.Value(courseId),
              learningLectureId: drift.Value(chosen.id),
              plannedDate: drift.Value(plannedDate),
            ),
          );
          await (db.update(
            db.timeSessionTable,
          )..where((t) => t.linkedTaskId.equals(source!.id))).write(
            TimeSessionTableCompanion(
              learningCourseId: drift.Value(courseId),
              learningLectureId: drift.Value(chosen.id),
              activityRefType: const drift.Value('lecture_history'),
            ),
          );
        }
      });
      if (makeActive) {
        state = state.copyWith(
          courses: courses,
          activeCourseId: courseId,
          activeLectureId: chosen.id,
          currentElapsedSeconds: chosen.elapsedSeconds,
          sessionBaseElapsed: chosen.elapsedSeconds,
        );
        ref
            .read(sharedPreferencesProvider)
            .setString(_kActiveCourseIdKey, courseId);
        ref
            .read(sharedPreferencesProvider)
            .setInt(_kActiveLectureIdKey, chosen.id);
      } else {
        state = state.copyWith(courses: courses);
      }
      await catalog.cache(courses);
      return chosen;
    } finally {
      _completionPending = false;
    }
  }

  Future<void> addLecture(
    String courseId,
    int moduleId,
    Lecture lecture,
  ) async {
    await ready;
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    final course = state.courses.firstWhere((c) => c.id == courseId);
    if (!course.modules.any((m) => m.id == moduleId) ||
        course.modules.any((m) => m.lectures.any((l) => l.id == lecture.id))) {
      throw ArgumentError('Choose an existing module and a unique lecture ID');
    }
    final updatedModules = course.modules.map((m) {
      if (m.id == moduleId) {
        return m.copyWith(
          lectures: [
            ...m.lectures,
            lecture.copyWith(studySeconds: 0, isCompleted: false),
          ],
        );
      }
      return m;
    }).toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    await updateCourse(updatedCourse);
  }

  Future<void> updateLecture(String courseId, Lecture lecture) async {
    await ready;
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules.map((m) {
      if (m.id == lecture.moduleId) {
        final updatedLectures = m.lectures
            .map(
              (l) => l.id == lecture.id
                  ? lecture.copyWith(
                      studySeconds: l.studySeconds,
                      isCompleted: l.isCompleted,
                      completionThresholdPercent:
                          lecture.completionThresholdPercent == 50 ? 50 : 100,
                    )
                  : l,
            )
            .toList();
        return m.copyWith(lectures: updatedLectures);
      }
      return m;
    }).toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    await updateCourse(updatedCourse);
  }

  Future<void> deleteLecture(String courseId, int lectureId) async {
    await ready;
    if (_completionPending) {
      throw StateError('Wait for the current learning save');
    }
    if (courseId == state.activeCourseId &&
        lectureId == state.activeLectureId) {
      pause(updateNotification: false);
    }
    final course = state.courses.firstWhere((c) => c.id == courseId);
    final updatedModules = course.modules.map((m) {
      final updatedLectures = m.lectures
          .where((l) => l.id != lectureId)
          .toList();
      return m.copyWith(lectures: updatedLectures);
    }).toList();
    final updatedCourse = course.copyWith(modules: updatedModules);
    await updateCourse(updatedCourse);
  }

  void dismissFloatingPlayer() {
    state = state.copyWith(isFloatingDismissed: true);
  }

  void showFloatingPlayer() {
    state = state.copyWith(isFloatingDismissed: false);
  }

  void _updateCurrentLectureInCourse(
    int? elapsed,
    bool isCompleted, {
    int? targetLectureId,
    int? studySeconds,
  }) {
    final targetId = targetLectureId ?? state.activeLectureId;
    final activeC = state.course;

    final updatedModules = activeC.modules.map((module) {
      final updatedLectures = module.lectures.map((lecture) {
        if (lecture.id == targetId) {
          return lecture.copyWith(
            elapsedSeconds: elapsed ?? lecture.elapsedSeconds,
            studySeconds: studySeconds ?? lecture.studySeconds,
            isCompleted: lecture.isCompleted || isCompleted,
            lastPlayedAt: DateTime.now(),
          );
        }
        return lecture;
      }).toList();

      return module.copyWith(lectures: updatedLectures);
    }).toList();

    final updatedCourse = activeC.copyWith(modules: updatedModules);
    final updatedCourses = state.courses
        .map((c) => c.id == updatedCourse.id ? updatedCourse : c)
        .toList();
    state = state.copyWith(courses: updatedCourses);
  }
}

final learningHubProvider =
    NotifierProvider<LearningHubNotifier, LearningHubState>(
      LearningHubNotifier.new,
    );
