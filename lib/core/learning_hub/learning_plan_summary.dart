import 'learning_hub_models.dart';

class LearningPlanSummary {
  const LearningPlanSummary(this.course);
  final Course course;
  int get remainingSeconds => course.modules
      .expand((m) => m.lectures)
      .where((l) => !l.isCompleted)
      .fold(
        0,
        (total, l) =>
            total +
            (l.durationSeconds - l.elapsedSeconds).clamp(0, l.durationSeconds),
      );
  int? get sessionsRemaining => course.targetMinutesPerDay <= 0
      ? null
      : (remainingSeconds / (course.targetMinutesPerDay * 60)).ceil();
  String get paceLabel => course.totalLectures == 0 ? 'Add lectures to estimate your plan' : sessionsRemaining == null
      ? 'Set a daily pace to estimate your plan'
      : sessionsRemaining == 0
      ? 'Course completed — review whenever you like'
      : 'About $sessionsRemaining sessions at ${course.targetMinutesPerDay} min/day';
}
