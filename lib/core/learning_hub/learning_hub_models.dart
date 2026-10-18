const _unchangedCourseValue = Object();

class Course {
  final String id;
  final String title;
  final String description;
  final String author;
  final String category;
  final String? sourceUrl;
  final DateTime? targetCompletionDate;
  final int daysLeft;
  final int targetMinutesPerDay;
  final List<CourseModule> modules;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.title,
    this.description = '',
    this.author = 'Instructor',
    this.category = 'General',
    this.sourceUrl,
    this.targetCompletionDate,
    this.daysLeft = 30,
    this.targetMinutesPerDay = 45,
    required this.modules,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalLectures => modules.fold(0, (sum, m) => sum + m.lectures.length);

  int get completedLectures => modules.fold(
    0,
    (sum, m) => sum + m.lectures.where((l) => l.isCompleted).length,
  );

  int get remainingLectures {
    final rem = totalLectures - completedLectures;
    return rem >= 0 ? rem : 0;
  }

  int get totalDurationSeconds =>
      modules.fold(0, (sum, m) => sum + m.totalDurationSeconds);

  int get totalWatchedSeconds =>
      modules.fold(0, (sum, m) => sum + m.totalWatchedSeconds);

  int get remainingDurationSeconds {
    final rem = totalDurationSeconds - totalWatchedSeconds;
    return rem >= 0 ? rem : 0;
  }

  double get progressFraction {
    if (totalLectures == 0) return 0.0;
    return (completedLectures / totalLectures).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressFraction * 100).round();

  String get formattedTotalDuration => _formatDuration(totalDurationSeconds);
  String get formattedWatchedDuration => _formatDuration(totalWatchedSeconds);
  String get formattedRemainingDuration =>
      _formatDuration(remainingDurationSeconds);

  Lecture? get nextLecture {
    for (final module in modules) {
      for (final lecture in module.lectures) {
        if (!lecture.isCompleted) return lecture;
      }
    }
    return null;
  }

  static String _formatDuration(int seconds) {
    if (seconds <= 0) return '0m';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m';
  }

  Course sanitizeTestLectures() {
    final sanitizedModules = modules.map((m) {
      final sanitizedLectures =
          m.lectures.where((l) => !isTargetTestLecture(l)).toList();
      return m.copyWith(lectures: sanitizedLectures);
    }).toList();
    return copyWith(modules: sanitizedModules);
  }

  Course copyWith({
    String? id,
    String? title,
    String? description,
    String? author,
    String? category,
    Object? sourceUrl = _unchangedCourseValue,
    Object? targetCompletionDate = _unchangedCourseValue,
    int? daysLeft,
    int? targetMinutesPerDay,
    List<CourseModule>? modules,
    DateTime? createdAt,
  }) {
    return Course(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      category: category ?? this.category,
      sourceUrl: identical(sourceUrl, _unchangedCourseValue)
          ? this.sourceUrl
          : sourceUrl as String?,
      targetCompletionDate:
          identical(targetCompletionDate, _unchangedCourseValue)
          ? this.targetCompletionDate
          : targetCompletionDate as DateTime?,
      daysLeft: daysLeft ?? this.daysLeft,
      targetMinutesPerDay: targetMinutesPerDay ?? this.targetMinutesPerDay,
      modules: modules ?? this.modules,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'author': author,
      'category': category,
      'sourceUrl': sourceUrl,
      'targetCompletionDate': targetCompletionDate?.toIso8601String(),
      'daysLeft': daysLeft,
      'targetMinutesPerDay': targetMinutesPerDay,
      'modules': modules.map((m) => m.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id:
          json['id']?.toString() ??
          'course_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title']?.toString() ?? 'Untitled Course',
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Instructor',
      category: json['category']?.toString() ?? 'General',
      sourceUrl: json['sourceUrl']?.toString(),
      targetCompletionDate: json['targetCompletionDate'] != null
          ? DateTime.tryParse(json['targetCompletionDate'].toString())
          : null,
      daysLeft: (json['daysLeft'] as num?)?.toInt() ?? 30,
      targetMinutesPerDay: (json['targetMinutesPerDay'] as num?)?.toInt() ?? 45,
      modules:
          (json['modules'] as List<dynamic>?)
              ?.map((m) => CourseModule.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class CourseModule {
  final int id;
  final String title;
  final String description;
  final double durationHours;
  final List<Lecture> lectures;
  final String? originRequestId;

  const CourseModule({
    required this.id,
    required this.title,
    this.description = '',
    this.durationHours = 1.0,
    required this.lectures,
    this.originRequestId,
  });

  int get totalDurationSeconds =>
      lectures.fold(0, (sum, l) => sum + l.durationSeconds);

  int get totalWatchedSeconds => lectures.fold(
    0,
    (sum, l) =>
        sum +
        l.studySeconds.clamp(
          0,
          l.durationSeconds > 0 ? l.durationSeconds : l.studySeconds,
        ),
  );

  int get completedCount => lectures.where((l) => l.isCompleted).length;

  double get progressFraction {
    if (lectures.isEmpty) return 0.0;
    return (completedCount / lectures.length).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressFraction * 100).round();

  bool get isCompleted =>
      lectures.isNotEmpty && completedCount == lectures.length;

  CourseModule copyWith({
    int? id,
    String? title,
    String? description,
    double? durationHours,
    List<Lecture>? lectures,
    String? originRequestId,
  }) {
    return CourseModule(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      durationHours: durationHours ?? this.durationHours,
      lectures: lectures ?? this.lectures,
      originRequestId: originRequestId ?? this.originRequestId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'durationHours': durationHours,
      'lectures': lectures.map((l) => l.toJson()).toList(),
      'originRequestId': originRequestId,
    };
  }

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    return CourseModule(
      originRequestId: json['originRequestId'] as String?,
      id: (json['id'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? 'Module',
      description: json['description']?.toString() ?? '',
      durationHours: (json['durationHours'] as num?)?.toDouble() ?? 1.0,
      lectures:
          (json['lectures'] as List<dynamic>?)
              ?.map((l) => Lecture.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class Lecture {
  final int id;
  final int moduleId;
  final String moduleTitle;
  final String title;
  final String description;
  final String author;
  final int durationSeconds;
  final int elapsedSeconds;

  /// Credited active study time; seeking never changes this evidence.
  final int studySeconds;
  final int completionThresholdPercent;
  final bool isCompleted;
  final DateTime? lastPlayedAt;
  final DateTime? plannedDate;
  final String? originRequestId;

  const Lecture({
    required this.id,
    required this.moduleId,
    required this.moduleTitle,
    required this.title,
    this.description = '',
    this.author = 'Engineering Digest',
    required this.durationSeconds,
    this.elapsedSeconds = 0,
    this.studySeconds = 0,
    this.completionThresholdPercent = 100,
    this.isCompleted = false,
    this.lastPlayedAt,
    this.plannedDate,
    this.originRequestId,
  });

  int get requiredStudySeconds =>
      (durationSeconds * completionThresholdPercent / 100).ceil();

  bool get canComplete =>
      durationSeconds > 0 && studySeconds >= requiredStudySeconds;

  int get studyProgressPercent => durationSeconds <= 0
      ? 0
      : (studySeconds * 100 / durationSeconds).floor().clamp(0, 100);

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

  String get formattedElapsed {
    final m = elapsedSeconds ~/ 60;
    final s = elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Lecture copyWith({
    int? id,
    int? moduleId,
    String? moduleTitle,
    String? title,
    String? description,
    String? author,
    int? durationSeconds,
    int? elapsedSeconds,
    int? studySeconds,
    int? completionThresholdPercent,
    bool? isCompleted,
    DateTime? lastPlayedAt,
    DateTime? plannedDate,
    String? originRequestId,
  }) {
    return Lecture(
      id: id ?? this.id,
      moduleId: moduleId ?? this.moduleId,
      moduleTitle: moduleTitle ?? this.moduleTitle,
      title: title ?? this.title,
      description: description ?? this.description,
      author: author ?? this.author,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      studySeconds: studySeconds ?? this.studySeconds,
      completionThresholdPercent:
          completionThresholdPercent ?? this.completionThresholdPercent,
      isCompleted: isCompleted ?? this.isCompleted,
      lastPlayedAt: lastPlayedAt ?? this.lastPlayedAt,
      plannedDate: plannedDate ?? this.plannedDate,
      originRequestId: originRequestId ?? this.originRequestId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'moduleId': moduleId,
      'moduleTitle': moduleTitle,
      'title': title,
      'description': description,
      'author': author,
      'durationSeconds': durationSeconds,
      'elapsedSeconds': elapsedSeconds,
      'studySeconds': studySeconds,
      'completionThresholdPercent': completionThresholdPercent,
      'isCompleted': isCompleted,
      'lastPlayedAt': lastPlayedAt?.toIso8601String(),
      'plannedDate': plannedDate?.toIso8601String(),
      'originRequestId': originRequestId,
    };
  }

  factory Lecture.fromJson(Map<String, dynamic> json) {
    return Lecture(
      plannedDate: DateTime.tryParse(json['plannedDate']?.toString() ?? ''),
      originRequestId: json['originRequestId'] as String?,
      id: (json['id'] as num?)?.toInt() ?? 1,
      moduleId: (json['moduleId'] as num?)?.toInt() ?? 1,
      moduleTitle: json['moduleTitle']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Lecture',
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? 'Engineering Digest',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 300,
      elapsedSeconds: ((json['elapsedSeconds'] as num?)?.toInt() ?? 0).clamp(
        0,
        31536000,
      ),
      studySeconds: ((json['studySeconds'] as num?)?.toInt() ?? 0).clamp(
        0,
        31536000,
      ),
      completionThresholdPercent: json['completionThresholdPercent'] == 50
          ? 50
          : 100,
      isCompleted: json['isCompleted'] == true,
      lastPlayedAt: json['lastPlayedAt'] != null
          ? DateTime.tryParse(json['lastPlayedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => toJson();
}

/// Identifies unwanted/corrupted test lectures (such as test lecture 38, "test )(", or 90min test entries).
bool isTargetTestLecture(Lecture lecture) {
  if (lecture.id == 38) return true;
  final title = lecture.title.toLowerCase();
  if (title.contains('test )(') || title.contains(')(')) return true;
  if (title.contains('lecture 38')) return true;
  if (lecture.durationSeconds == 5400 && title.contains('test')) return true;
  if (lecture.id >= 38 && (title.contains('test') || lecture.durationSeconds == 5400)) return true;
  return false;
}
