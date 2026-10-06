import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/ai/ai_service.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/app/theme/color_tokens.dart' as ascent_colors;

void main() {
  group('Activity Hub Kind & Hierarchy Tests', () {
    test('ActivityKind classifies todo, duration, and flexible correctly', () {
      const todoItem = TodayActivityItem(
        id: 'task_1',
        title: 'Buy groceries',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Personal',
        kind: ActivityKind.todo,
      );
      expect(todoItem.kind, ActivityKind.todo);
      expect(todoItem.isOverdue, isFalse);

      const durationItem = TodayActivityItem(
        id: 'task_2',
        title: 'Workout',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Health',
        kind: ActivityKind.duration,
        targetMinutes: 30,
      );
      expect(durationItem.kind, ActivityKind.duration);
      expect(durationItem.targetMinutes, 30);

      const flexibleItem = TodayActivityItem(
        id: 'task_3',
        title: 'Meditation',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Wellness',
        kind: ActivityKind.flexible,
      );
      expect(flexibleItem.kind, ActivityKind.flexible);
    });
  });

  group('Additive Multi-Course Learning Hub Models Tests', () {
    test('Course calculates duration, progress, and lecture counts from modules', () {
      final module1 = CourseModule(
        id: 1,
        title: 'Module 1: Foundations',
        lectures: [
          Lecture(
            id: 1,
            moduleId: 1,
            moduleTitle: 'Module 1: Foundations',
            title: 'Intro',
            durationSeconds: 600, // 10 mins
            isCompleted: true,
          ),
          Lecture(
            id: 2,
            moduleId: 1,
            moduleTitle: 'Module 1: Foundations',
            title: 'Setup',
            durationSeconds: 1200, // 20 mins
            isCompleted: false,
          ),
        ],
      );

      final module2 = CourseModule(
        id: 2,
        title: 'Module 2: Advanced Concepts',
        lectures: [
          Lecture(
            id: 3,
            moduleId: 2,
            moduleTitle: 'Module 2: Advanced Concepts',
            title: 'Deep Dive',
            durationSeconds: 1800, // 30 mins
            isCompleted: false,
          ),
        ],
      );

      final course = Course(
        id: 'test_course_1',
        title: 'Flutter Advanced',
        modules: [module1, module2],
      );

      expect(course.totalLectures, 3);
      expect(course.completedLectures, 1);
      expect(course.remainingLectures, 2);
      expect(course.totalDurationSeconds, 3600); // 1 hour
      expect(course.formattedTotalDuration, '1h 0m');
      expect(course.progressPercent, 33);
      expect(course.nextLecture?.title, 'Setup');
    });

    test('Course serialization to and from JSON is lossless', () {
      final original = Course(
        id: 'java_course',
        title: 'Java Masterclass',
        category: 'Backend',
        description: 'Comprehensive Java tutorial',
        modules: [
          CourseModule(
            id: 1,
            title: 'Core Java',
            lectures: [
              Lecture(
                id: 1,
                moduleId: 1,
                moduleTitle: 'Core Java',
                title: 'JVM Internals',
                durationSeconds: 900,
              ),
            ],
          ),
        ],
      );

      final json = original.toJson();
      final restored = Course.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.modules.length, 1);
      expect(restored.modules.first.lectures.length, 1);
      expect(restored.modules.first.lectures.first.title, 'JVM Internals');
    });
  });

  group('AI Riya Natural Language Parsing & Intent Upgrade Tests', () {
    final aiEngine = LocalDeterministicAiEngine();

    test('Parses "need to call saurabh at 2" with time and reminder', () {
      final parsed = aiEngine.tryParseActivityOrTask('need to call saurabh at 2');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('call saurabh'));
      expect(parsed['kind'], 'todo');
      expect(parsed['reminderTime'], isNotNull);
    });

    test('Parses "complete java spring boot today" as high priority today task', () {
      final parsed = aiEngine.tryParseActivityOrTask('complete java spring boot today');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('java spring boot'));
      expect(parsed['priority'], 'high');
    });

    test('Parses "need to finish java tutorial today"', () {
      final parsed = aiEngine.tryParseActivityOrTask('need to finish java tutorial today');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('java tutorial'));
      expect(parsed['kind'], 'todo');
    });

    test('Parses "add todo need to complete java"', () {
      final parsed = aiEngine.tryParseActivityOrTask('add todo need to complete java');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('complete java'));
      expect(parsed['kind'], 'todo');
    });

    test('Parses "I want to exercise for 30 minutes after waking up" as timed activity', () {
      final parsed = aiEngine.tryParseActivityOrTask('I want to exercise for 30 minutes after waking up');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('exercise'));
      expect(parsed['kind'], 'duration');
      expect(parsed['estimatedMinutes'], 30);
    });

    test('Parses "remind me to apply for jobs tomorrow morning" with date & reminder', () {
      final parsed = aiEngine.tryParseActivityOrTask('remind me to apply for jobs tomorrow morning');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('apply for jobs'));
      expect(parsed['kind'], 'todo');
      expect(parsed['reminderTime'], isNotNull);
    });

    test('Parses "I need to study Java for two hours today" as 120min duration activity', () {
      final parsed = aiEngine.tryParseActivityOrTask('I need to study Java for two hours today');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('study Java'));
      expect(parsed['kind'], 'duration');
      expect(parsed['estimatedMinutes'], 120);
    });

    test('Parses "add a task to call my friend" as to-do', () {
      final parsed = aiEngine.tryParseActivityOrTask('add a task to call my friend');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('call my friend'));
      expect(parsed['kind'], 'todo');
    });
  });

  group('Day Mode Composed Color Tokens Tests', () {
    test('AscentColors secondary accent and warning are calm, composed, and non-glaring in day mode', () {
      // Day mode colors should not be harsh screaming high-saturation red/orange
      expect(ascent_colors.AscentColors.accentSecondary.value, 0xFF8A513E);
      expect(ascent_colors.AscentColors.stateWarning.value, 0xFFB46824);
      expect(ascent_colors.AscentColors.stateDanger.value, 0xFFBA433C);
    });
  });
}
