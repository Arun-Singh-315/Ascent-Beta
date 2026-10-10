import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/momentum/momentum_screen.dart';
import 'package:ascent/features/study_plan/study_plan_screen.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TaskDao taskDao;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    taskDao = TaskDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Learning Lecture Completion Integrity Tests', () {
    test('LearningHubNotifier sticky completion: once completed, cannot be reverted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(learningHubProvider.notifier);
      final initialState = container.read(learningHubProvider);
      final activeLec = initialState.activeLecture;

      // Mark lecture completed
      notifier.markLectureCompleted(activeLec.id, completed: true);
      var state = container.read(learningHubProvider);
      var targetLec = state.course.modules.expand((m) => m.lectures).firstWhere((l) => l.id == activeLec.id);
      expect(targetLec.isCompleted, isTrue);

      // Attempt to un-complete lecture: must remain completed ("completed means completed")
      notifier.markLectureCompleted(activeLec.id, completed: false);
      state = container.read(learningHubProvider);
      targetLec = state.course.modules.expand((m) => m.lectures).firstWhere((l) => l.id == activeLec.id);
      expect(targetLec.isCompleted, isTrue);
    });

    testWidgets('StudyPlanScreen displays completed lectures with strikethrough decoration', (tester) async {
      SharedPreferences.setMockInitialValues({'has_started_learning': true});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      // Complete first lecture
      container.read(learningHubProvider.notifier).markLectureCompleted(1, completed: true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: StudyPlanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Lectures tab
      await tester.tap(find.text('Lectures'));
      await tester.pumpAndSettle();

      // Find lecture 1 text widget
      final lecture1Text = tester.widget<Text>(
        find.textContaining("A Beginner's Walkthrough to MongoDB").first,
      );
      expect(lecture1Text.style?.decoration, equals(TextDecoration.lineThrough));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Activity Row Completion & Timing Integrity Tests', () {
    testWidgets('Timed duration activity cannot be completed by clicking checkbox', (tester) async {
      final activity = TodayActivityItem(
        id: 'task_duration_1',
        title: 'Deep Architecture Design',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        linkedTaskId: 101,
        targetMinutes: 45,
        kind: ActivityKind.duration,
        categoryTag: 'Focus',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ActivityRowItem(activity: activity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap circular checkbox on timed activity
      final checkbox = find.byType(InkWell).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Expect snackbar explaining timed activities complete when timer ends
      expect(
        find.text('Timed activities complete automatically when the focus timer ends.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Simple Todo can be completed by clicking checkbox', (tester) async {
      final taskId = await taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Review PR comments',
          priority: const drift.Value('High'),
        ),
      );

      final activity = TodayActivityItem(
        id: 'task_$taskId',
        title: 'Review PR comments',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        linkedTaskId: taskId,
        kind: ActivityKind.todo,
        categoryTag: 'Task',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ActivityRowItem(activity: activity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap circular checkbox on todo activity
      final checkbox = find.byType(InkWell).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Verify task was marked completed in DAO
      final updated = await taskDao.getTaskById(taskId);
      expect(updated?.actualCompletedDate, isNotNull);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('Completed activity cannot be toggled back to active (sealed)', (tester) async {
      final activity = TodayActivityItem(
        id: 'task_completed_1',
        title: 'Completed Review Task',
        sourceType: 'task',
        status: TodayActivityStatus.done,
        elapsedSecondsToday: 1800,
        linkedTaskId: 102,
        kind: ActivityKind.todo,
        categoryTag: 'Task',
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ActivityRowItem(activity: activity),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap circular checkbox on completed activity
      final checkbox = find.byType(InkWell).first;
      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      // Expect snackbar informing that completed items cannot be reopened
      expect(
        find.text('Completed items are finished and cannot be reopened.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Thought Wall 2-Way Toggle Tests', () {
    testWidgets('ThoughtWallScreen has 2-way toggle (Today vs History & Archive, no Upcoming)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: ThoughtWallScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check segments
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('History & Archive'), findsOneWidget);
      expect(find.text('Upcoming'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });

  group('Momentum Screen Coming Soon Tests', () {
    testWidgets('MomentumScreen renders clean preview with notification CTA', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: const MaterialApp(
            home: MomentumScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Momentum'), findsOneWidget);
      expect(find.text('MOMENTUM 2.0'), findsOneWidget);
      expect(find.text('Atomic Habit Stacking'), findsOneWidget);
      expect(find.text('Adaptive Streak Guardian'), findsOneWidget);
      expect(find.text('Notify Me On Release'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
