import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/today/task_board_screen.dart';

Future<List<TodayActivityItem>> readTodayActivities(ProviderContainer container) async {
  final current = container.read(todayActivitiesProvider);
  if (current.hasValue) {
    return current.value!;
  }
  final completer = Completer<List<TodayActivityItem>>();
  final sub = container.listen(todayActivitiesProvider, (prev, next) {
    if (next.hasValue && !completer.isCompleted) {
      completer.complete(next.value!);
    }
  }, fireImmediately: true);
  final result = await completer.future;
  sub.close();
  return result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Lecture Activity Lifecycle & Dismissal Guarantee Tests', () {
    test('Swiping lecture removes it from today activities without deleting from course catalog', () async {
      final hubNotifier = container.read(learningHubProvider.notifier);
      hubNotifier.startLearning();

      final learningState = container.read(learningHubProvider);
      final activeLec = learningState.activeLecture;
      final course = learningState.course;

      // Verify active lecture exists in the course
      expect(activeLec.id, isNotNull);
      final totalLecturesBefore = course.modules.expand((m) => m.lectures).length;

      // Construct TodayActivityItem corresponding to active lecture
      final lectureActivity = TodayActivityItem(
        id: 'lecture_${activeLec.id}',
        title: '${course.title}: ${activeLec.title}',
        sourceType: 'lecture',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        linkedTaskId: null,
        linkedSessionId: null,
        categoryTag: 'Study',
        kind: ActivityKind.duration,
        targetMinutes: 5,
        plannedDate: DateTime.now(),
        isOverdue: false,
      );

      // Perform dismissal via deleteTodayActivity
      await deleteTodayActivity(container, lectureActivity);

      // 1. Verify lecture ID is marked as dismissed for today
      final dismissedSet = container.read(dismissedTodayActivityIdsProvider);
      expect(dismissedSet.contains('lecture_${activeLec.id}'), isTrue);

      // 2. Verify lecture was NOT deleted from the course catalog
      final learningStateAfter = container.read(learningHubProvider);
      final totalLecturesAfter = learningStateAfter.course.modules.expand((m) => m.lectures).length;
      expect(totalLecturesAfter, equals(totalLecturesBefore));
      final stillExists = learningStateAfter.course.modules
          .expand((m) => m.lectures)
          .any((l) => l.id == activeLec.id);
      expect(stillExists, isTrue, reason: 'Course lecture must never be deleted from course catalog');
    });

    test('Dismissed lecture does NOT resurrect upon stream rebuild or update', () async {
      final hubNotifier = container.read(learningHubProvider.notifier);
      hubNotifier.startLearning();

      final activeLec = container.read(learningHubProvider).activeLecture;
      final lectureActivityId = 'lecture_${activeLec.id}';

      // Dismiss the lecture activity
      await container.read(dismissedTodayActivityIdsProvider.notifier).dismissActivityId(lectureActivityId);

      // Read today activities stream
      final todayList = await readTodayActivities(container);

      // Verify it is not present in Today's list
      expect(todayList.any((it) => it.id == lectureActivityId), isFalse);
    });

    test('User explicit play or selection un-dismisses lecture from today list', () async {
      final hubNotifier = container.read(learningHubProvider.notifier);
      hubNotifier.startLearning();

      final activeLec = container.read(learningHubProvider).activeLecture;
      final lectureActivityId = 'lecture_${activeLec.id}';

      // Dismiss it
      await container.read(dismissedTodayActivityIdsProvider.notifier).dismissActivityId(lectureActivityId);
      expect(container.read(dismissedTodayActivityIdsProvider).contains(lectureActivityId), isTrue);

      // User explicitly starts playback or selects lecture
      hubNotifier.play();

      // Verify it was un-dismissed
      expect(container.read(dismissedTodayActivityIdsProvider).contains(lectureActivityId), isFalse);
      hubNotifier.pause();
    });

    test('Completed lecture remains visible in Completed activities for the day', () async {
      final hubNotifier = container.read(learningHubProvider.notifier);
      hubNotifier.startLearning();

      final activeLec = container.read(learningHubProvider).activeLecture;

      // Mark lecture completed
      hubNotifier.markLectureCompleted(activeLec.id, completed: true);

      // Fetch today's activities
      final todayList = await readTodayActivities(container);

      final completedItem = todayList.firstWhere(
        (it) => it.id == 'lecture_${activeLec.id}',
        orElse: () => throw Exception('Completed lecture not found in today activities'),
      );

      expect(completedItem.status, equals(TodayActivityStatus.done));
    });
  });

  group('One-Way Completion & Non-Dismissible Completed Items Widget Tests', () {
    testWidgets('Active activity has endToStart swipe direction; completed activity has none', (tester) async {
      final activeActivity = TodayActivityItem(
        id: 'lecture_101',
        title: 'Spring Boot: Architecture Overview',
        sourceType: 'lecture',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        linkedTaskId: null,
        linkedSessionId: null,
        categoryTag: 'Study',
        kind: ActivityKind.duration,
        targetMinutes: 10,
        plannedDate: DateTime.now(),
        isOverdue: false,
      );

      final completedActivity = TodayActivityItem(
        id: 'lecture_102',
        title: 'Spring Boot: Initial Setup',
        sourceType: 'lecture',
        status: TodayActivityStatus.done,
        elapsedSecondsToday: 600,
        linkedTaskId: null,
        linkedSessionId: null,
        categoryTag: 'Study',
        kind: ActivityKind.duration,
        targetMinutes: 10,
        plannedDate: DateTime.now(),
        isOverdue: false,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ActivityRowItem(activity: activeActivity),
                  ActivityRowItem(activity: completedActivity),
                ],
              ),
            ),
          ),
        ),
      );

      final dismissibles = tester.widgetList<Dismissible>(find.byType(Dismissible)).toList();
      expect(dismissibles.length, 2);

      // Active activity can be dismissed (endToStart)
      expect(dismissibles[0].direction, equals(DismissDirection.endToStart));

      // Completed activity CANNOT be dismissed (none) - must remain visible full day
      expect(dismissibles[1].direction, equals(DismissDirection.none));
    });

    testWidgets('Tapping completed activity does not un-complete it (one-way only)', (tester) async {
      final completedActivity = TodayActivityItem(
        id: 'lecture_103',
        title: 'Spring Boot: Dependency Injection',
        sourceType: 'lecture',
        status: TodayActivityStatus.done,
        elapsedSecondsToday: 300,
        linkedTaskId: null,
        linkedSessionId: null,
        categoryTag: 'Study',
        kind: ActivityKind.duration,
        targetMinutes: 5,
        plannedDate: DateTime.now(),
        isOverdue: false,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ActivityRowItem(activity: completedActivity),
            ),
          ),
        ),
      );

      // Find the circular check target
      final checkIcon = find.byIcon(Icons.check_rounded);
      expect(checkIcon, findsOneWidget);

      // Tap the completed check target
      await tester.tap(checkIcon);
      await tester.pumpAndSettle();

      // Verify that it remains checked
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('Swiping active lecture displays "Removed from today\'s activities" snackbar', (tester) async {
      final activeLectureActivity = TodayActivityItem(
        id: 'lecture_1',
        title: 'Spring Boot: Intro',
        sourceType: 'lecture',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        linkedTaskId: null,
        linkedSessionId: null,
        categoryTag: 'Study',
        kind: ActivityKind.duration,
        targetMinutes: 5,
        plannedDate: DateTime.now(),
        isOverdue: false,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ActivityRowItem(activity: activeLectureActivity),
            ),
          ),
        ),
      );

      // Swipe from right to left
      await tester.drag(find.text('Spring Boot: Intro'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Verify SnackBar text says "Removed from today's activities" (never "deleted")
      expect(find.text('Removed from today\'s activities'), findsOneWidget);
      expect(find.textContaining('deleted'), findsNothing);

      // Advance clock past SnackBar duration (2s) so pending timer clears cleanly
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('TaskBoardScreen enforces one-way completion and prevents dismissing completed tasks', (tester) async {
      // Insert one active task and one completed task
      final activeId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Active Task 1',
          plannedDate: drift.Value(DateTime.now()),
          priority: const drift.Value('medium'),
        ),
      );

      final completedId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Completed Task 2',
          plannedDate: drift.Value(DateTime.now()),
          actualCompletedDate: drift.Value(DateTime.now()),
          priority: const drift.Value('low'),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TaskBoardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Active Task 1'), findsOneWidget);

      // Verify DismissDirection on active Task item tile
      final activeDismissible = tester.widget<Dismissible>(find.byKey(ValueKey('task_$activeId')));
      expect(activeDismissible.direction, equals(DismissDirection.horizontal));

      // Switch to Completed tab to verify completed task
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();

      expect(find.text('Completed Task 2'), findsOneWidget);

      final completedDismissible = tester.widget<Dismissible>(find.byKey(ValueKey('task_$completedId')));
      expect(completedDismissible.direction, equals(DismissDirection.none),
          reason: 'Completed task cannot be swiped away from completed view');

      // Tap on completed task check icon
      final completedCheck = find.descendant(
        of: find.byKey(ValueKey('task_$completedId')),
        matching: find.byIcon(Icons.check_rounded),
      );
      expect(completedCheck, findsOneWidget);

      await tester.tap(completedCheck);
      await tester.pumpAndSettle();

      // Verify task in DB remains completed (one-way only)
      final taskInDb = await db.taskDao.getTaskById(completedId);
      expect(taskInDb?.actualCompletedDate, isNotNull, reason: 'Completed task cannot be undone back to active');

      // Unmount TaskBoardScreen and flush zero-delay Drift cancel timers
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}
