import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/notifications/notification_presentation.dart';
import 'package:ascent/core/learning_hub/learning_plan_summary.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/streak/study_streak_models.dart';
import 'package:ascent/core/streak/streak_explanation.dart';

void main() {
  test('reminder content is primary, full text is retained for expansion', () {
    final title = List.filled(20, 'Call the accountant').join(' ');
    final copy = ReminderNotificationCopy(title);
    expect(copy.title, startsWith('Call the accountant'));
    expect(copy.title.length, lessThanOrEqualTo(80));
    expect(copy.body.length, lessThanOrEqualTo(120));
    expect(copy.expandedBody, title);
    expect(copy.body, isNot(contains('5-Min')));
  });
  test('all completed courses have no next unfinished lecture', () {
    final course = Course(
      id: 'done',
      title: 'Done',
      modules: [
        CourseModule(
          id: 1,
          title: 'One',
          lectures: [
            Lecture(
              id: 1,
              moduleId: 1,
              moduleTitle: 'One',
              title: 'Done',
              durationSeconds: 600,
              isCompleted: true,
              elapsedSeconds: 600,
            ),
          ],
        ),
      ],
    );
    expect(course.nextLecture, isNull);
    expect(LearningPlanSummary(course).sessionsRemaining, 0);
  });
  test(
    'pace estimates round up real remaining duration and avoid zero division',
    () {
      final course = Course(
        id: 'one',
        title: 'One',
        targetMinutesPerDay: 20,
        modules: [
          CourseModule(
            id: 1,
            title: 'One',
            lectures: [
              Lecture(
                id: 1,
                moduleId: 1,
                moduleTitle: 'One',
                title: 'One',
                durationSeconds: 2500,
                elapsedSeconds: 500,
                studySeconds: 500,
              ),
            ],
          ),
        ],
      );
      expect(LearningPlanSummary(course).sessionsRemaining, 2);
      expect(
        LearningPlanSummary(
          course.copyWith(targetMinutesPerDay: 0),
        ).sessionsRemaining,
        isNull,
      );
    },
  );
  test('streak copy states actual restrictions and exact recovery target', () {
    const status = StudyStreakStatus(
      todaySeconds: 0,
      targetSeconds: 12600,
      isRescueMode: true,
      yesterdayDeficitSeconds: 5400,
    );
    final text = streakExplanation(status);
    expect(text, contains('120'));
    expect(text, contains('90'));
    expect(text, contains('210'));
    expect(text, contains('midnight'));
    expect(text, contains('paused'));
    expect(text, contains('checkbox'));
  });
}
