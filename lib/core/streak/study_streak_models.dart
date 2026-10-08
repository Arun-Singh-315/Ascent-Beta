class StudyStreakStatus {
  final int todaySeconds;
  final int targetSeconds;
  final int priorStreakDays;
  final int currentStreakDays;
  final int displayStreakDays;
  final int longestStreakDays;
  final int shortestStreakDays;
  final bool isTodaySecured;
  final bool isRescueMode;
  final bool isRescuedToday;
  final int yesterdayDeficitSeconds;
  final bool isUrgent;
  final int hoursRemainingInDay;

  const StudyStreakStatus({
    required this.todaySeconds,
    this.targetSeconds = 7200, // 120 minutes = 2 hours
    this.priorStreakDays = 0,
    this.currentStreakDays = 0,
    this.displayStreakDays = 0,
    this.longestStreakDays = 0,
    this.shortestStreakDays = 1,
    this.isTodaySecured = false,
    this.isRescueMode = false,
    this.isRescuedToday = false,
    this.yesterdayDeficitSeconds = 0,
    this.isUrgent = false,
    this.hoursRemainingInDay = 24,
  });

  int get todayMinutes => todaySeconds ~/ 60;
  int get targetMinutes => targetSeconds ~/ 60;
  int get remainingSeconds => (targetSeconds - todaySeconds).clamp(0, targetSeconds);
  int get remainingMinutes => (remainingSeconds / 60).ceil();
  int get yesterdayDeficitMinutes => (yesterdayDeficitSeconds / 60).ceil();

  double get progressFraction {
    if (targetSeconds <= 0) return 1.0;
    return (todaySeconds / targetSeconds).clamp(0.0, 1.0);
  }

  int get progressPercent => (progressFraction * 100).round();

  StudyStreakStatus copyWith({
    int? todaySeconds,
    int? targetSeconds,
    int? priorStreakDays,
    int? currentStreakDays,
    int? displayStreakDays,
    int? longestStreakDays,
    int? shortestStreakDays,
    bool? isTodaySecured,
    bool? isRescueMode,
    bool? isRescuedToday,
    int? yesterdayDeficitSeconds,
    bool? isUrgent,
    int? hoursRemainingInDay,
  }) {
    return StudyStreakStatus(
      todaySeconds: todaySeconds ?? this.todaySeconds,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      priorStreakDays: priorStreakDays ?? this.priorStreakDays,
      currentStreakDays: currentStreakDays ?? this.currentStreakDays,
      displayStreakDays: displayStreakDays ?? this.displayStreakDays,
      longestStreakDays: longestStreakDays ?? this.longestStreakDays,
      shortestStreakDays: shortestStreakDays ?? this.shortestStreakDays,
      isTodaySecured: isTodaySecured ?? this.isTodaySecured,
      isRescueMode: isRescueMode ?? this.isRescueMode,
      isRescuedToday: isRescuedToday ?? this.isRescuedToday,
      yesterdayDeficitSeconds: yesterdayDeficitSeconds ?? this.yesterdayDeficitSeconds,
      isUrgent: isUrgent ?? this.isUrgent,
      hoursRemainingInDay: hoursRemainingInDay ?? this.hoursRemainingInDay,
    );
  }
}
