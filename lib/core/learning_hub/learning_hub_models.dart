class Course {
  final String id;
  final String title;
  final String description;
  final String author;
  final int daysLeft;
  final int targetMinutesPerDay;
  final List<CourseModule> modules;

  const Course({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.daysLeft,
    required this.targetMinutesPerDay,
    required this.modules,
  });

  int get totalLectures => modules.fold(0, (sum, m) => sum + m.lectures.length);

  int get completedLectures => modules.fold(
      0, (sum, m) => sum + m.lectures.where((l) => l.isCompleted).length);

  int get totalDurationSeconds =>
      modules.fold(0, (sum, m) => sum + m.totalDurationSeconds);

  int get totalWatchedSeconds =>
      modules.fold(0, (sum, m) => sum + m.totalWatchedSeconds);

  double get progressFraction {
    if (totalLectures == 0) return 0.0;
    return completedLectures / totalLectures;
  }

  int get progressPercent => (progressFraction * 100).round();
}

class CourseModule {
  final int id;
  final String title;
  final String description;
  final double durationHours;
  final List<Lecture> lectures;

  const CourseModule({
    required this.id,
    required this.title,
    required this.description,
    required this.durationHours,
    required this.lectures,
  });

  int get totalDurationSeconds =>
      lectures.fold(0, (sum, l) => sum + l.durationSeconds);

  int get totalWatchedSeconds =>
      lectures.fold(0, (sum, l) => sum + l.elapsedSeconds);

  int get completedCount => lectures.where((l) => l.isCompleted).length;

  double get progressFraction {
    if (lectures.isEmpty) return 0.0;
    return completedCount / lectures.length;
  }

  int get progressPercent => (progressFraction * 100).round();

  bool get isCompleted =>
      lectures.isNotEmpty && completedCount == lectures.length;
}

class Lecture {
  final int id;
  final int moduleId;
  final String moduleTitle;
  final String title;
  final String author;
  final int durationSeconds;
  final int elapsedSeconds;
  final bool isCompleted;
  final DateTime? lastPlayedAt;

  const Lecture({
    required this.id,
    required this.moduleId,
    required this.moduleTitle,
    required this.title,
    this.author = 'Engineering Digest',
    required this.durationSeconds,
    this.elapsedSeconds = 0,
    this.isCompleted = false,
    this.lastPlayedAt,
  });

  int get remainingSeconds {
    final rem = durationSeconds - elapsedSeconds;
    return rem > 0 ? rem : 0;
  }

  double get progressFraction {
    if (durationSeconds <= 0) return 0.0;
    final f = elapsedSeconds / durationSeconds;
    return f.clamp(0.0, 1.0);
  }

  int get progressPercent => (progressFraction * 100).round();

  String get formattedDuration {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedRemaining {
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Lecture copyWith({
    int? elapsedSeconds,
    bool? isCompleted,
    DateTime? lastPlayedAt,
  }) {
    return Lecture(
      id: id,
      moduleId: moduleId,
      moduleTitle: moduleTitle,
      title: title,
      author: author,
      durationSeconds: durationSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lecture_id': id,
      'module_id': moduleId,
      'elapsed_seconds': elapsedSeconds,
      'is_completed': isCompleted ? 1 : 0,
      'last_played_at': lastPlayedAt?.toIso8601String(),
    };
  }
}
