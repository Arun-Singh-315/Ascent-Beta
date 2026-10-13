import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';

void main() {
  const lecture = Lecture(
    id: 1,
    moduleId: 1,
    moduleTitle: 'Module',
    title: 'Lesson',
    durationSeconds: 100,
  );
  test('Seeking and legacy elapsed time do not earn completion evidence', () {
    expect(lecture.copyWith(elapsedSeconds: 100).canComplete, isFalse);
    final restored = Lecture.fromJson(
      {...lecture.toJson(), 'elapsedSeconds': 100}..remove('studySeconds'),
    );
    expect(restored.studySeconds, 0);
    expect(restored.canComplete, isFalse);
  });
  test('Full and flexible thresholds have exact independent boundaries', () {
    expect(lecture.copyWith(studySeconds: 99).canComplete, isFalse);
    expect(lecture.copyWith(studySeconds: 100).canComplete, isTrue);
    final flexible = lecture.copyWith(completionThresholdPercent: 50);
    expect(flexible.copyWith(studySeconds: 49).canComplete, isFalse);
    expect(flexible.copyWith(studySeconds: 50).canComplete, isTrue);
    expect(flexible.copyWith(studySeconds: 100).canComplete, isTrue);
  });
  test('Legacy completed state survives without fabricated study evidence', () {
    final restored = Lecture.fromJson(
      {...lecture.toJson(), 'isCompleted': true}..remove('studySeconds'),
    );
    expect(restored.isCompleted, isTrue);
    expect(restored.studySeconds, 0);
  });
  test('Unknown duration does not become automatically eligible', () {
    expect(
      lecture.copyWith(durationSeconds: 0, studySeconds: 500).canComplete,
      isFalse,
    );
  });
  test('Evidence and policy round trip and malformed evidence is bounded', () {
    final restored = Lecture.fromJson(
      lecture
          .copyWith(studySeconds: 40, completionThresholdPercent: 50)
          .toJson(),
    );
    expect(restored.studySeconds, 40);
    expect(restored.completionThresholdPercent, 50);
    expect(
      Lecture.fromJson({
        ...lecture.toJson(),
        'studySeconds': -20,
        'completionThresholdPercent': 0,
      }).studySeconds,
      0,
    );
    expect(
      Lecture.fromJson({
        ...lecture.toJson(),
        'completionThresholdPercent': 0,
      }).completionThresholdPercent,
      100,
    );
  });
}
