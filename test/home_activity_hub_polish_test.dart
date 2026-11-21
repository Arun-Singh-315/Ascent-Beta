import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 0,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        taskDaoProvider.overrideWithValue(db.taskDao),
        thoughtDaoProvider.overrideWithValue(db.thoughtDao),
        studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Ask Riya Button Contrast & Styling', () {

  });

  group('Activity Hub Ergonomics & Separator Removal', () {

    testWidgets(
      'Compact to-do item renders leading check target and allows completion',
      (tester) async {
        final taskDao = container.read(taskDaoProvider);
        final taskId = await taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Buy groceries',
            priority: const drift.Value('low'),
          ),
        );

        final todoActivity = TodayActivityItem(
          id: 'task_$taskId',
          title: 'Buy groceries',
          sourceType: 'task',
          categoryTag: 'Task',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          linkedTaskId: taskId,
          kind: ActivityKind.todo,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(activity: todoActivity, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check target is present with activity_action key
        final checkFinder = find.byKey(
          ValueKey('activity_action_task_$taskId'),
        );
        expect(checkFinder, findsOneWidget);

        // Tap to complete the task
        await tester.tap(checkFinder);
        await tester.pumpAndSettle();

        final updatedTask = await taskDao.getTaskById(taskId);
        expect(updatedTask?.actualCompletedDate, isNotNull);
      },
    );

    testWidgets(
      'Compact timed activity renders compact outlined start button without oversized solid block',
      (tester) async {
        final timedActivity = const TodayActivityItem(
          id: 'task_timed_1',
          title: 'Deep Focus Coding',
          sourceType: 'task',
          categoryTag: 'Task',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          kind: ActivityKind.duration,
          targetMinutes: 45,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(activity: timedActivity, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final actionFinder = find.byKey(
          const ValueKey('activity_action_task_timed_1'),
        );
        expect(actionFinder, findsOneWidget);
        expect(find.text('Start'), findsOneWidget);

        // Verify button uses OutlinedButton with compact size
        final button = tester.widget<OutlinedButton>(actionFinder);
        expect(button.style?.minimumSize?.resolve({}), const Size(0, 26));
      },
    );

    testWidgets(
      'To-do and timed activity titles are horizontally synchronized at the exact same X coordinate',
      (tester) async {
        final todoActivity = const TodayActivityItem(
          id: 'task_todo_sync',
          title: 'Regular Todo Item',
          sourceType: 'task',
          categoryTag: 'Task',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          kind: ActivityKind.todo,
        );

        final timedActivity = const TodayActivityItem(
          id: 'task_timed_sync',
          title: 'Timed Activity Item',
          sourceType: 'task',
          categoryTag: 'Task',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          kind: ActivityKind.duration,
          targetMinutes: 25,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: Column(
                  children: [
                    ActivityRowItem(activity: todoActivity, compact: true),
                    ActivityRowItem(activity: timedActivity, compact: true),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final todoTitlePos = tester.getTopLeft(
          find.byKey(const ValueKey('activity_title_task_todo_sync')),
        );
        final timedTitlePos = tester.getTopLeft(
          find.byKey(const ValueKey('activity_title_task_timed_sync')),
        );

        // Both titles must start at the exact same horizontal coordinate (dx)
        expect(todoTitlePos.dx, timedTitlePos.dx);
      },
    );

  });

  group('Swipe to Delete in To-Do and Thought', () {
    testWidgets(
      'Compact to-do item supports swipe to delete with Undo snackbar',
      (tester) async {
        final taskDao = container.read(taskDaoProvider);
        final taskId = await taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Wash car',
            priority: const drift.Value('low'),
          ),
        );

        final todoActivity = TodayActivityItem(
          id: 'task_$taskId',
          title: 'Wash car',
          sourceType: 'task',
          categoryTag: 'Task',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          linkedTaskId: taskId,
          kind: ActivityKind.todo,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(activity: todoActivity, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dismissibleFinder = find.byKey(
          ValueKey('activity_dismiss_task_$taskId'),
        );
        expect(dismissibleFinder, findsOneWidget);

        final dismissible = tester.widget<Dismissible>(dismissibleFinder);
        // Right completes, left moves or deletes (CLAUDE.md §5.2).
        expect(dismissible.direction, DismissDirection.horizontal);

        // Perform swipe left
        await tester.drag(dismissibleFinder, const Offset(-500, 0));
        await tester.pumpAndSettle();

        final confirmBtn = find.text('Delete').evaluate().isNotEmpty
            ? find.text('Delete').last
            : find.text('Archive');
        if (confirmBtn.evaluate().isNotEmpty) {
          await tester.tap(confirmBtn);
          await tester.pumpAndSettle();
        }

        // Verify task is deleted in database
        final taskAfter = await taskDao.getTaskById(taskId);
        expect(taskAfter, isNull);

        // Verify Undo snackbar appears
        expect(find.text('Undo'), findsOneWidget);
      },
    );
  });

  group('Accessibility & Rule 13 Boundary Safeguards', () {
    testWidgets(
      'Compact row fits 320px width at 2.0x text scale without RenderFlex overflows',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final timedActivity = const TodayActivityItem(
          id: 'task_timed_overflow',
          title:
              'Very Long Task Title That Could Potentially Overflow The Viewport On Small Mobile Devices',
          sourceType: 'task',
          categoryTag: 'Task',
          status: TodayActivityStatus.notStarted,
          elapsedSecondsToday: 0,
          kind: ActivityKind.duration,
          targetMinutes: 60,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                theme: AscentTheme.light(),
                home: Scaffold(
                  body: ActivityRowItem(activity: timedActivity, compact: true),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
